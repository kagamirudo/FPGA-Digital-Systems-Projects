/*
 * main.c
 *
 * ECEC 661 - Homework 3 - Problem 8.7.1 Fibonacci Number Generator
 *
 * Bare-metal test application for the custom "fib_axi" AXI4-Lite IP.
 * The PS drives N and the START bit, polls the DONE flag and reads
 * back F(N), the OVERFLOW flag and the iteration counter, then prints
 * every case over UART1 for PuTTY capture.
 *
 * Register map (byte offsets from XPAR_FIB_AXI_0_S00_AXI_BASEADDR):
 *   0x00  CTRL_STAT  W: [0] START         R: [1] DONE [2] OVERFLOW [3] BUSY
 *   0x04  N_REG      R/W target index
 *   0x08  FIB_REG    R/O F(N)
 *   0x0C  CYCLES     R/O iteration count
 */

#include <stdio.h>
#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xil_types.h"
#include "sleep.h"

/* --------------------------------------------------------------------------
 * Base address.  Vitis generates XPAR_FIB_AXI_0_S00_AXI_BASEADDR when the
 * IP is present in the block design.  Fall back to the default 0x43C00000
 * slot so the file still compiles if the platform hasn't been built yet.
 * --------------------------------------------------------------------------
 */
#ifdef XPAR_FIB_AXI_0_S00_AXI_BASEADDR
#define FIB_BASE            XPAR_FIB_AXI_0_S00_AXI_BASEADDR
#else
#warning "XPAR_FIB_AXI_0_S00_AXI_BASEADDR not found - using default 0x43C00000"
#define FIB_BASE            0x43C00000U
#endif

#define FIB_CTRL_OFFSET     0x00U
#define FIB_N_OFFSET        0x04U
#define FIB_RESULT_OFFSET   0x08U
#define FIB_CYCLES_OFFSET   0x0CU

#define FIB_CTRL_START      (1U << 0)
#define FIB_STAT_DONE       (1U << 1)
#define FIB_STAT_OVERFLOW   (1U << 2)
#define FIB_STAT_BUSY       (1U << 3)

#define FIB_POLL_TIMEOUT    1000000U

/* --------------------------------------------------------------------------
 * Software reference (64-bit) used to cross-check the hardware.
 * --------------------------------------------------------------------------
 */
static u64 sw_fib(u32 n)
{
    u64 a = 0, b = 1, t;
    for (u32 i = 0; i < n; i++) {
        t = a + b;
        a = b;
        b = t;
    }
    return a;
}

/* --------------------------------------------------------------------------
 * Drive a single compute on the HW.
 * --------------------------------------------------------------------------
 */
static u32 fib_compute(u32 n, int *overflow_out, u32 *cycles_out)
{
    Xil_Out32(FIB_BASE + FIB_N_OFFSET, n);
    Xil_Out32(FIB_BASE + FIB_CTRL_OFFSET, FIB_CTRL_START);

    u32 ctrl = 0;
    u32 timeout = FIB_POLL_TIMEOUT;
    do {
        ctrl = Xil_In32(FIB_BASE + FIB_CTRL_OFFSET);
    } while (!(ctrl & FIB_STAT_DONE) && --timeout);

    u32 result = Xil_In32(FIB_BASE + FIB_RESULT_OFFSET);
    if (cycles_out)   *cycles_out   = Xil_In32(FIB_BASE + FIB_CYCLES_OFFSET);
    if (overflow_out) *overflow_out = (ctrl & FIB_STAT_OVERFLOW) ? 1 : 0;

    if (timeout == 0) {
        xil_printf("   [!] timeout waiting for DONE (ctrl=0x%08x)\r\n", ctrl);
    }
    return result;
}

int main(void)
{
    const u32 test_n[] = { 0, 1, 2, 5, 10, 20, 30, 46, 47, 48 };
    const unsigned n_tests = sizeof(test_n) / sizeof(test_n[0]);

    /* startup window so the serial monitor can attach; also proves UART works
     * before any AXI access. Remove once UART output is confirmed.           */
    for (int i = 3; i > 0; i--) {
        xil_printf("fib_gen starting in %d...\r\n", i);
        sleep(1);
    }

    xil_printf("\r\n");
    xil_printf("==========================================================\r\n");
    xil_printf("   ECEC 661 HW3 - Fibonacci AXI IP test application\r\n");
    xil_printf("   IP base address : 0x%08x\r\n", (unsigned) FIB_BASE);
    xil_printf("==========================================================\r\n");
    xil_printf("  n   |    fib(n) hex |      fib(n) dec |  ovf |  cycles | check\r\n");
    xil_printf("------+---------------+-----------------+------+---------+------\r\n");

    unsigned pass = 0, fail = 0;

    for (unsigned i = 0; i < n_tests; i++) {
        u32 n      = test_n[i];
        int ovf    = 0;
        u32 cyc    = 0;
        u32 hwval  = fib_compute(n, &ovf, &cyc);
        u64 swval  = sw_fib(n);
        int sw_ovf = (swval > 0xFFFFFFFFULL) ? 1 : 0;

        int ok;
        if (sw_ovf) {
            ok = (ovf == 1);
        } else {
            ok = (ovf == 0) && (hwval == (u32) swval);
        }

        xil_printf("  %2u  | 0x%08x    |     %10u  |  %d   |  %5u  |  %s\r\n",
                   (unsigned) n,
                   (unsigned) hwval,
                   (unsigned) hwval,
                   ovf,
                   (unsigned) cyc,
                   ok ? "OK " : "BAD");

        if (ok) pass++; else fail++;

        /* small delay so the UART buffer is comfortable */
        usleep(10000);
    }

    xil_printf("\r\n");
    xil_printf("----------------------------------------------------------\r\n");
    xil_printf("   Summary : %u passed, %u failed (total %u)\r\n",
               pass, fail, n_tests);
    xil_printf("----------------------------------------------------------\r\n");

    while (1) {
        /* idle forever; the JTAG/UART session stays open for the snip */
    }

    return 0;
}
