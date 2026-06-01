/*
 * main.c
 *
 * ECEC 661 - Homework 5 - Stack Processor 101 + new `scpb` block-copy
 *
 * Bare-metal Vitis test application for the custom `sp101_axi` AXI4-Lite
 * IP packaged from Homework_5/stackprocessor_101.  This app exercises the
 * new block-copy instruction `scpb` end-to-end on real silicon (Cora Z7-07S),
 * matching the assignment PDF's reference C snippet's register layout.
 *
 * Register map (byte offsets from XPAR_SP101_AXI_0_S00_AXI_BASEADDR):
 *
 *     0x00  slv_reg0  R/W  control bits
 *                            bit 0 = run
 *                            bit 1 = reset
 *                            bit 2 = bus2mem_en
 *                            bit 3 = bus2mem_we
 *     0x04  slv_reg1  R/W  bus2mem_addr (lower 10 bits)
 *     0x08  slv_reg2  R/W  bus2mem_data_in (32 bit)
 *     0x0C  slv_reg3  R    sp2bus_data_out (32 bit)
 *     0x10  slv_reg4  R    done (bit 0)
 *
 * Programming model for `scpb`:
 *     sc dest  sc source  sc count  scpb  halt
 * After the program runs, memory[source .. source+count-1] has been
 * copied to memory[dest .. dest+count-1].
 *
 * The bench runs three scenarios:
 *
 *   * count = 3 multi-word copy
 *   * count = 1 single-word copy (off-by-one guard)
 *   * count = 0 no-op (must leave the destination block untouched)
 *
 * Each scenario:
 *   1) writes a sentinel block at the destination,
 *   2) writes the source words,
 *   3) loads the canonical `sc dest sc src sc count scpb halt` program,
 *   4) lowers bus2mem_en/bus2mem_we, raises run,
 *   5) spins on done,
 *   6) re-enables the bus and reads back the destination block,
 *   7) compares to expected and prints PASS/FAIL,
 *   8) writes reset (slv_reg0 bit 1) to clear processor state between runs.
 */

#include <stdio.h>
#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xil_types.h"
#include "sleep.h"

/* --------------------------------------------------------------------------
 * Base address.  Vitis exposes the IP base as XPAR_SP101_AXI_0_*; fall back
 * to 0x43C30000 (one 64 KB aperture above HW4 at 0x43C20000) if the platform
 * has not been generated yet so the file still compiles standalone.
 * --------------------------------------------------------------------------
 */
#ifdef XPAR_SP101_AXI_0_S00_AXI_BASEADDR
#define BASEADDR        XPAR_SP101_AXI_0_S00_AXI_BASEADDR
#else
#warning "XPAR_SP101_AXI_0_S00_AXI_BASEADDR not found - using 0x43C30000"
#define BASEADDR        0x43C30000U
#endif

#define SP101_mWriteReg(base, ofst, val) \
    Xil_Out32((u32)(base) + (u32)(ofst), (u32)(val))
#define SP101_mReadReg(base, ofst) \
    Xil_In32((u32)(base) + (u32)(ofst))

/* slv_reg0 control bits */
#define CTRL_RUN        (1U << 0)
#define CTRL_RESET      (1U << 1)
#define CTRL_BUS_EN     (1U << 2)
#define CTRL_BUS_WE     (1U << 3)

/* Register byte offsets */
#define REG_CTRL        0x00U
#define REG_BUS_ADDR    0x04U
#define REG_BUS_DIN     0x08U
#define REG_SP_DOUT     0x0CU
#define REG_DONE        0x10U

/* Opcodes (must match user_logic.vhd) */
#define OP_SC           0x00000001U
#define OP_SL           0x00000011U
#define OP_SS           0x00000021U
#define OP_SADD         0x00000031U
#define OP_SCP          0x00000101U
#define OP_SCPB         0x00000201U
#define OP_HALT         0x000000FFU

/* --------------------------------------------------------------------------
 * Low-level memory access via the bus2mem_* register interface.
 *
 * IMPORTANT: never assert CTRL_RESET while reading.  user_logic.vhd's
 * mem_data_out register chain is forced to 0 while reset='1', so any
 * mem_read() that holds reset comes back as 0x00000000 -- which silently
 * masks both the pre-written sentinel and the scpb result.
 *
 * Instead we pulse reset once per scenario in processor_reset(), then
 * keep reset deasserted but the bus owned (bus2mem_en='1', run='0').
 * That parks the core in idle (busy='1' keeps the run-to-fetch check
 * from firing) without zeroing the BRAM read pipe.
 * --------------------------------------------------------------------------
 */
static void mem_write(u32 addr, u32 data)
{
    /* bus owned, write enabled, no reset (core is parked in idle) */
    SP101_mWriteReg(BASEADDR, REG_CTRL,     CTRL_BUS_EN | CTRL_BUS_WE);
    SP101_mWriteReg(BASEADDR, REG_BUS_ADDR, addr & 0x3FFU);
    SP101_mWriteReg(BASEADDR, REG_BUS_DIN,  data);
}

static u32 mem_read(u32 addr)
{
    /* bus owned, write disabled, no reset (otherwise mem_data_out is
     * clamped to 0 inside user_logic and every read returns 0). */
    SP101_mWriteReg(BASEADDR, REG_CTRL,     CTRL_BUS_EN);
    SP101_mWriteReg(BASEADDR, REG_BUS_ADDR, addr & 0x3FFU);
    /* Settle: BRAM (1 cycle) + mem_data_out_pre (1) + mem_data_out (1).
     * The AXI handshakes already cover this on real silicon, but we add
     * a small busy-wait so a 2026.x toolchain that compiles this faster
     * keeps a healthy margin. */
    for (volatile int s = 0; s < 64; s++) { }
    return SP101_mReadReg(BASEADDR, REG_SP_DOUT);
}

static void processor_reset(void)
{
    /* Pulse reset high (bus owned, no writes) so the core drops into
     * idle and clears done_FF on the following cycle. */
    SP101_mWriteReg(BASEADDR, REG_CTRL,
                    CTRL_RESET | CTRL_BUS_EN);
    for (volatile int s = 0; s < 64; s++) { }
    /* Drop reset, keep the bus owned so the core stays parked in idle
     * (busy='1' from bus2mem_en blocks the idle->fetch transition until
     * we explicitly raise run in processor_run_and_wait). */
    SP101_mWriteReg(BASEADDR, REG_CTRL, CTRL_BUS_EN);
}

static void processor_run_and_wait(void)
{
    /* Release the bus and raise run.  reset stays low. */
    SP101_mWriteReg(BASEADDR, REG_CTRL, CTRL_RUN);
    while ((SP101_mReadReg(BASEADDR, REG_DONE) & 0x1U) == 0U) {
        /* spin until done */
    }
    /* Drop run; the next mem_read/mem_write will re-acquire the bus
     * (and the next processor_reset will pulse reset again). */
    SP101_mWriteReg(BASEADDR, REG_CTRL, 0U);
}

/* --------------------------------------------------------------------------
 * Load a canonical `sc dest  sc src  sc count  scpb  halt` program at
 * memory[0..7].
 * --------------------------------------------------------------------------
 */
static void load_scpb_program(u32 dest, u32 src, u32 count)
{
    const u32 prog[8] = {
        OP_SC,  dest,
        OP_SC,  src,
        OP_SC,  count,
        OP_SCPB,
        OP_HALT
    };
    for (u32 i = 0; i < 8U; i++) {
        mem_write(i, prog[i]);
    }
}

/* --------------------------------------------------------------------------
 * Run one scenario.  Returns 0 if every dest word matched its expected
 * value, otherwise the number of mismatches.
 * --------------------------------------------------------------------------
 */
static unsigned run_scpb_scenario(const char *label,
                                  u32        dest_base,
                                  u32        src_base,
                                  u32        count,
                                  const u32 *dest_pre,
                                  const u32 *src_data,
                                  const u32 *expected,
                                  u32        pre_len,
                                  u32        src_len,
                                  u32        check_len)
{
    unsigned mismatches = 0;

    xil_printf("\r\n---- Scenario: %s ----\r\n", label);
    xil_printf("  dest=%u  src=%u  count=%u\r\n",
               (unsigned) dest_base, (unsigned) src_base, (unsigned) count);

    processor_reset();

    /* Pre-write destination sentinels (so we can detect a no-op for count=0
     * and so a previous run's data does not poison this one).             */
    for (u32 i = 0; i < pre_len; i++) {
        mem_write(dest_base + i, dest_pre[i]);
    }

    /* Pre-write source words */
    for (u32 i = 0; i < src_len; i++) {
        mem_write(src_base + i, src_data[i]);
    }

    /* Load program */
    load_scpb_program(dest_base, src_base, count);

    /* Run */
    processor_run_and_wait();

    /* Re-acquire bus, read back, compare */
    xil_printf("  -- destination dump --\r\n");
    for (u32 i = 0; i < check_len; i++) {
        u32 got = mem_read(dest_base + i);
        u32 exp = expected[i];
        const char *chk = (got == exp) ? "  OK" : " BAD";
        xil_printf("    [%3u] got=0x%08x  expect=0x%08x  %s\r\n",
                   (unsigned) (dest_base + i),
                   (unsigned) got,
                   (unsigned) exp,
                   chk);
        if (got != exp) {
            mismatches++;
        }
    }

    if (mismatches == 0U) {
        xil_printf("  RESULT: PASS\r\n");
    } else {
        xil_printf("  RESULT: FAIL (%u mismatch%s)\r\n",
                   mismatches, (mismatches == 1U) ? "" : "es");
    }

    return mismatches;
}

int main(void)
{
    for (int i = 3; i > 0; i--) {
        xil_printf("sp101 scpb starting in %d...\r\n", i);
        sleep(1);
    }

    xil_printf("\r\n");
    xil_printf("==========================================================\r\n");
    xil_printf("   ECEC 661 HW5 - Stack Processor 101 + scpb block copy\r\n");
    xil_printf("   IP base address : 0x%08x\r\n", (unsigned) BASEADDR);
    xil_printf("==========================================================\r\n");

    unsigned total_mismatch = 0;
    unsigned scenarios      = 0;
    unsigned passed         = 0;

    /* ---------- Scenario 1 : count = 3 ---------- */
    {
        static const u32 dest_pre[] = { 0u, 0u, 0u };
        static const u32 src_data[] = { 0x0Bu, 0x16u, 0x21u };
        static const u32 expected[] = { 0x0Bu, 0x16u, 0x21u };
        unsigned mm = run_scpb_scenario(
            "scpb count=3 (multi-word)",
            200u, 100u, 3u,
            dest_pre, src_data, expected,
            3u, 3u, 3u);
        total_mismatch += mm;
        scenarios++;
        if (mm == 0U) passed++;
    }

    /* ---------- Scenario 2 : count = 1 ---------- */
    {
        static const u32 dest_pre[] = { 0u };
        static const u32 src_data[] = { 0x63u };
        static const u32 expected[] = { 0x63u };
        unsigned mm = run_scpb_scenario(
            "scpb count=1 (single word)",
            210u, 110u, 1u,
            dest_pre, src_data, expected,
            1u, 1u, 1u);
        total_mismatch += mm;
        scenarios++;
        if (mm == 0U) passed++;
    }

    /* ---------- Scenario 3 : count = 0 (no-op) ---------- */
    {
        static const u32 dest_pre[] = { 0xDEADBEEFu };
        static const u32 src_data[] = { 0x55u };
        static const u32 expected[] = { 0xDEADBEEFu };
        unsigned mm = run_scpb_scenario(
            "scpb count=0 (no-op)",
            220u, 120u, 0u,
            dest_pre, src_data, expected,
            1u, 1u, 1u);
        total_mismatch += mm;
        scenarios++;
        if (mm == 0U) passed++;
    }

    xil_printf("\r\n");
    xil_printf("----------------------------------------------------------\r\n");
    if (total_mismatch == 0U) {
        xil_printf("   Summary : %u/%u scenarios PASSED\r\n",
                   passed, scenarios);
    } else {
        xil_printf("   Summary : %u/%u scenarios passed, %u mismatch(es)\r\n",
                   passed, scenarios, total_mismatch);
    }
    xil_printf("----------------------------------------------------------\r\n");

    while (1) {
        /* idle forever so the UART session stays open for the screenshot */
    }

    return 0;
}
