/*
 * main.c
 *
 * ECEC 661 - Final (real) - Stack Processor 101 + new `ssq` instruction
 *
 * Bare-metal Vitis test application for the custom `sp101_axi` AXI4-Lite
 * IP packaged from Final/real/stackprocessor_101.  This exercises the new
 * `ssq` ("stack the square") machine instruction end-to-end on real
 * silicon (Cora Z7-07S) and prints proof that address 128 contains the
 * square of the operand pushed by the prior `sc` instruction.
 *
 * Register map (byte offsets from XPAR_SP101_AXI_0_S00_AXI_BASEADDR):
 *
 *     0x00  slv_reg0  R/W  control bits
 *                            bit 0 = run
 *                            bit 1 = reset
 *                            bit 2 = bus2mem_en
 *                            bit 3 = bus2mem_we
 *     0x04  slv_reg1  R/W  bus2mem_addr  (lower 10 bits)
 *     0x08  slv_reg2  R/W  bus2mem_data_in
 *     0x0C  slv_reg3  R    sp2bus_data_out
 *     0x10  slv_reg4  R    done (bit 0)
 *
 * Programming model for `ssq`:
 *     sc x  ssq  halt
 * After the program runs, mem[128] = x*x because sp101 initialises
 * sp = 128 in `idle`, `sc x` writes mem[128] = x and bumps sp to 129,
 * then `ssq` reads mem[128] = x, squares it, and writes mem[128] = x*x
 * (leaving sp = 129 = "next available address").
 *
 * Scenarios run:
 *   * x = 7  -> mem[128] = 49   (assignment prompt example)
 *   * x = 0  -> mem[128] =  0
 *   * x = 1  -> mem[128] =  1
 *   * x = 13 -> mem[128] = 169
 *
 * Each scenario:
 *   1) writes a sentinel into mem[128] so a no-op would be detected,
 *   2) loads `sc x ssq halt` into mem[0..3],
 *   3) lowers bus2mem_en/bus2mem_we and raises run,
 *   4) spins on done,
 *   5) re-enables the bus and reads back mem[128],
 *   6) compares to the expected square and prints PASS / FAIL.
 */

#include <stdio.h>
#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xil_types.h"
#include "sleep.h"

/* --------------------------------------------------------------------------
 * Base address.  Vitis exposes the IP base as XPAR_SP101_AXI_0_*; fall back
 * to 0x43C30000 if the platform has not been generated yet so the file
 * still compiles standalone.
 * -------------------------------------------------------------------------- */
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
#define OP_SSQ          0x00000041U
#define OP_HALT         0x000000FFU

/* The processor's `idle` initialises sp = 128, so the result of `sc x ssq`
 * always lands at memory[128]. */
#define STACK_BASE      128U

/* --------------------------------------------------------------------------
 * Low-level memory access via the bus2mem_* register interface.
 *
 * IMPORTANT: never assert CTRL_RESET while reading.  While reset='1' the
 * user_logic FSM stays in idle but the bus mux still works; however, in
 * some debug builds the mem_data_out chain was cleared on reset, which
 * caused every read to return 0.  Pulse reset only in processor_reset();
 * use plain CTRL_BUS_EN (+CTRL_BUS_WE for writes) for normal access.
 * -------------------------------------------------------------------------- */
static void mem_write(u32 addr, u32 data)
{
    SP101_mWriteReg(BASEADDR, REG_CTRL,     CTRL_BUS_EN | CTRL_BUS_WE);
    SP101_mWriteReg(BASEADDR, REG_BUS_ADDR, addr & 0x3FFU);
    SP101_mWriteReg(BASEADDR, REG_BUS_DIN,  data);
}

static u32 mem_read(u32 addr)
{
    SP101_mWriteReg(BASEADDR, REG_CTRL,     CTRL_BUS_EN);
    SP101_mWriteReg(BASEADDR, REG_BUS_ADDR, addr & 0x3FFU);
    /* Settle: BRAM (1 cycle) + mem_data_out_pre (1) + mem_data_out (1).
     * AXI handshakes already cover this but a small busy-wait keeps a
     * healthy margin across toolchain versions. */
    for (volatile int s = 0; s < 64; s++) { }
    return SP101_mReadReg(BASEADDR, REG_SP_DOUT);
}

static void processor_reset(void)
{
    SP101_mWriteReg(BASEADDR, REG_CTRL, CTRL_RESET | CTRL_BUS_EN);
    for (volatile int s = 0; s < 64; s++) { }
    SP101_mWriteReg(BASEADDR, REG_CTRL, CTRL_BUS_EN);
}

static void processor_run_and_wait(void)
{
    SP101_mWriteReg(BASEADDR, REG_CTRL, CTRL_RUN);
    while ((SP101_mReadReg(BASEADDR, REG_DONE) & 0x1U) == 0U) {
        /* spin until done */
    }
    SP101_mWriteReg(BASEADDR, REG_CTRL, 0U);
}

/* --------------------------------------------------------------------------
 * Load `sc x  ssq  halt` at memory[0..3].
 * -------------------------------------------------------------------------- */
static void load_ssq_program(u32 x)
{
    const u32 prog[4] = {
        OP_SC,  x,
        OP_SSQ,
        OP_HALT
    };
    for (u32 i = 0; i < 4U; i++) {
        mem_write(i, prog[i]);
    }
}

/* --------------------------------------------------------------------------
 * Run one ssq scenario.  Returns 0 on PASS, 1 on FAIL.
 * -------------------------------------------------------------------------- */
static unsigned run_ssq_scenario(const char *label, u32 x_in)
{
    const u32 expected = x_in * x_in;
    const u32 sentinel = 0xDEADBEEFU;

    xil_printf("\r\n---- Scenario: %s ----\r\n", label);
    xil_printf("  program : sc %u  ssq  halt\r\n", (unsigned) x_in);

    processor_reset();

    /* Poison mem[128] so a no-op would be obvious. */
    mem_write(STACK_BASE, sentinel);

    load_ssq_program(x_in);

    processor_run_and_wait();

    u32 got = mem_read(STACK_BASE);
    const char *verdict = (got == expected) ? "PASS" : "FAIL";

    xil_printf("    address 128 = 0x%08x  (expected 0x%08x = %u)  %s\r\n",
               (unsigned) got, (unsigned) expected, (unsigned) expected,
               verdict);

    return (got == expected) ? 0U : 1U;
}

int main(void)
{
    for (int i = 3; i > 0; i--) {
        xil_printf("sp101 ssq starting in %d...\r\n", i);
        sleep(1);
    }

    xil_printf("\r\n");
    xil_printf("==========================================================\r\n");
    xil_printf("   ECEC 661 FINAL - Stack Processor 101 + ssq\r\n");
    xil_printf("   IP base address : 0x%08x\r\n", (unsigned) BASEADDR);
    xil_printf("==========================================================\r\n");

    unsigned scenarios = 0;
    unsigned passed    = 0;

    /* Prompt example : sc 7  ssq  halt  -> mem[128] = 49 */
    scenarios++; if (run_ssq_scenario("ssq x=7  (prompt)",  7U)  == 0U) passed++;

    /* Edge cases */
    scenarios++; if (run_ssq_scenario("ssq x=0  (zero)",    0U)  == 0U) passed++;
    scenarios++; if (run_ssq_scenario("ssq x=1  (one)",     1U)  == 0U) passed++;
    scenarios++; if (run_ssq_scenario("ssq x=13 (medium)", 13U)  == 0U) passed++;

    xil_printf("\r\n");
    xil_printf("----------------------------------------------------------\r\n");
    xil_printf("   Summary : %u/%u scenarios PASSED\r\n", passed, scenarios);
    xil_printf("----------------------------------------------------------\r\n");

    while (1) {
        /* idle forever so the UART session stays open for the screenshot */
    }

    return 0;
}
