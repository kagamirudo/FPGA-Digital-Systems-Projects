/*
 * main.c
 *
 * ECEC 661 - Homework 3 - Problem 8.7.2 Fixed-Point Accumulator IP
 *
 * Bare-metal test application for the custom "fix_acc_axi" IP.  The PS
 * writes B-values to slv_reg0 (0x00) one at a time; each write pulses the
 * slave's write-enable strobe, which is wired to the IP-Catalog accumulator's
 * CLK, so each write is exactly one accumulate step.  A final "flush" write
 * is required to see the running sum on Q_OUT because the accumulator has
 * latency = 1.
 *
 * Register map (byte offsets from XPAR_FIX_ACC_AXI_0_S00_AXI_BASEADDR):
 *   0x00  B_IN   R/W  signed 32-bit input; writing advances Q by this value
 *   0x04  Q_OUT  R    signed 32-bit accumulator output
 *   0x08  CTRL   R/W  [0]=SCLR (pulse 1 then 0 to zero Q)
 *   0x0C         --   reserved
 *
 * Test layout is inspired by fib_gen/sw/main.c so the report screenshots
 * match our HW3 Problem 8.7.1 aesthetic: 3 s startup countdown, header,
 * table of test rows, pass/fail summary.
 */

#include <stdio.h>
#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xil_types.h"
#include "sleep.h"

/* --------------------------------------------------------------------------
 * Base address.  Vitis generates XPAR_FIX_ACC_AXI_0_S00_AXI_BASEADDR when
 * the IP is present in the block design.  Fall back to 0x43C10000 (the
 * address we assign in bd/fix_acc.bd) if the platform hasn't been built yet.
 * --------------------------------------------------------------------------
 */
#ifdef XPAR_FIX_ACC_AXI_0_S00_AXI_BASEADDR
#define FA_BASE            XPAR_FIX_ACC_AXI_0_S00_AXI_BASEADDR
#else
#warning "XPAR_FIX_ACC_AXI_0_S00_AXI_BASEADDR not found - using default 0x43C10000"
#define FA_BASE            0x43C10000U
#endif

#define FA_B_IN_OFFSET     0x00U
#define FA_Q_OUT_OFFSET    0x04U
#define FA_CTRL_OFFSET     0x08U

#define FA_CTRL_SCLR       (1U << 0)

/* --------------------------------------------------------------------------
 * Primitive helpers - all register-level work lives here.
 * --------------------------------------------------------------------------
 */
static inline void fa_write_b(s32 b)
{
    Xil_Out32(FA_BASE + FA_B_IN_OFFSET, (u32) b);
}

static inline s32 fa_read_q(void)
{
    return (s32) Xil_In32(FA_BASE + FA_Q_OUT_OFFSET);
}

/*
 * Reset the accumulator to zero.  Sequence (from book p. 447):
 *   1. Write B_IN = 0 so that the "flush" pulse caused by writing CTRL
 *      doesn't contaminate Q with a leftover value from a previous run.
 *   2. Write CTRL = 1 (SCLR high).
 *   3. Write CTRL = 0 (SCLR low).
 */
static void fa_sclr(void)
{
    Xil_Out32(FA_BASE + FA_B_IN_OFFSET,  0U);
    Xil_Out32(FA_BASE + FA_CTRL_OFFSET,  FA_CTRL_SCLR);
    Xil_Out32(FA_BASE + FA_CTRL_OFFSET,  0U);
}

/* --------------------------------------------------------------------------
 * Individual test scenarios.  Each returns 1 on pass, 0 on fail, and prints
 * a single table row so the UART capture reads like the fib_gen one.
 * --------------------------------------------------------------------------
 */
/*
 * All table rows share this format so the header and data columns line up:
 *   "  <tag:18> | <N:7> | <expected:10> | <got:10> | <check>"
 */
#define FA_ROW_FMT  "  %-18s | %7u | %10d | %10d | %s\r\n"

static int test_sum_1_to_N(unsigned N, s32 expected, const char *tag)
{
    fa_sclr();
    for (unsigned i = 0; i <= N; i++) {
        fa_write_b((s32) i);
    }
    fa_write_b(0);                    /* flush the latency-1 pipeline */

    s32 got = fa_read_q();
    int ok  = (got == expected);

    xil_printf(FA_ROW_FMT, tag, N, (int) expected, (int) got,
               ok ? "OK " : "BAD");
    return ok;
}

static int test_negative_accum(void)
{
    fa_sclr();
    for (int i = 0; i < 4; i++) {
        fa_write_b(-2);
    }
    fa_write_b(0);                    /* flush */

    s32 got      = fa_read_q();
    s32 expected = -8;                /* -2 * 4 */
    int ok       = (got == expected);

    xil_printf(FA_ROW_FMT, "B=-2 four times", 4U,
               (int) expected, (int) got, ok ? "OK " : "BAD");
    return ok;
}

static int test_mid_stream_sclr(void)
{
    fa_sclr();
    for (int i = 1; i <= 5; i++) {
        fa_write_b(i);
    }
    fa_write_b(0);                    /* flush - Q now = 10 */

    fa_sclr();                        /* wipe it */

    /* after SCLR Q should be 0; a flush write is required to observe it */
    fa_write_b(0);

    s32 got      = fa_read_q();
    s32 expected = 0;
    int ok       = (got == expected);

    xil_printf(FA_ROW_FMT, "SCLR mid-stream", 5U,
               (int) expected, (int) got, ok ? "OK " : "BAD");
    return ok;
}

/* --------------------------------------------------------------------------
 * main
 * --------------------------------------------------------------------------
 */
int main(void)
{
    /* Startup window so the serial monitor can attach; same idea as the
     * fib_gen app.  Remove once UART output is confirmed.                  */
    for (int i = 3; i > 0; i--) {
        xil_printf("fix_acc starting in %d...\r\n", i);
        sleep(1);
    }

    xil_printf("\r\n");
    xil_printf("==========================================================\r\n");
    xil_printf("   ECEC 661 HW3 - Fixed-Point Accumulator IP test app\r\n");
    xil_printf("   IP base address : 0x%08x\r\n", (unsigned) FA_BASE);
    xil_printf("==========================================================\r\n");
    xil_printf("\r\n");

    /* ----------------------------------------------------------------------
     * Book reproduction.  Write i = 0 .. 10 into slv_reg0, read Q after each
     * write, and print the first ten rows.  This table is the near-identical
     * output shown on p. 447 of Digital Systems Projects.
     * ---------------------------------------------------------------------- */
    xil_printf("Book reproduction (Digital Systems Projects, p. 447):\r\n");
    xil_printf("slv_reg0 |   Q\r\n");
    xil_printf("---------+-------\r\n");

    fa_sclr();
    for (int i = 0; i < 10; i++) {
        fa_write_b((s32) i);
        xil_printf("   %4d  | %6d\r\n", i, (int) fa_read_q());
    }
    /* finish the range and flush to match book's final print line */
    for (int i = 10; i <= 1000; i++) {
        fa_write_b((s32) i);
    }
    fa_write_b(0);  /* latency-1 flush */
    xil_printf("Last output, latency = 1: Q = %d (expected 500500)\r\n",
               (int) fa_read_q());

    xil_printf("\r\n");
    xil_printf("Self-checks:\r\n");
    xil_printf("  %-18s | %7s | %10s | %10s | %s\r\n",
               "scenario", "N", "expected", "got", "check");
    xil_printf("  ------------------"
               "-+-"  "-------"
               "-+-"  "----------"
               "-+-"  "----------"
               "-+-"  "-----" "\r\n");

    unsigned pass = 0, fail = 0;

    if (test_sum_1_to_N(10,   55,     "Sigma(1..10)"))    pass++; else fail++;
    if (test_sum_1_to_N(100,  5050,   "Sigma(1..100)"))   pass++; else fail++;
    if (test_sum_1_to_N(1000, 500500, "Sigma(1..1000)"))  pass++; else fail++;
    if (test_negative_accum())                            pass++; else fail++;
    if (test_mid_stream_sclr())                           pass++; else fail++;

    xil_printf("\r\n");
    xil_printf("----------------------------------------------------------\r\n");
    xil_printf("   Summary : %u passed, %u failed (total %u)\r\n",
               pass, fail, pass + fail);
    xil_printf("----------------------------------------------------------\r\n");

    while (1) {
        /* idle forever; the JTAG/UART session stays open for the screenshot */
    }

    return 0;
}
