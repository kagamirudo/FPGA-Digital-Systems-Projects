/*
 * main.c
 *
 * ECEC 661 - Homework 4 - CORDIC Square Root IP
 *
 * Bare-metal Vitis test app for the custom "cordic_sqrt_axi" AXI4-Lite IP.
 * The PS pushes 10-bit 2Q7 samples into slv_reg0, raises din_tvalid in
 * slv_reg1, polls dout_tvalid in slv_reg3, and reads back the 1Q8 square
 * root from slv_reg2.  Output is printed over UART0 (the Cora Z7-07S
 * USB-UART bridge), matching the screenshot in the assignment (Fig. 4):
 *
 *     cordic sqrt
 *     sqrt(0x80) = 0x100
 *     sqrt(0x40) = 0xB5
 *     sqrt(0x8)  = 0x40
 *
 * Register map (byte offsets from XPAR_CORDIC_SQRT_AXI_0_S00_AXI_BASEADDR):
 *
 *     0x00  slv_reg0  R/W  x input (lower 10 bits = 2Q7 unsigned)
 *     0x04  slv_reg1  R/W  din_tvalid (bit 0)
 *     0x08  slv_reg2  R    z output  (lower 10 bits = 1Q8 unsigned)
 *     0x0C  slv_reg3  R    dout_tvalid (bit 0)
 *
 * The handshake follows the assignment's reference C snippet exactly.
 */

#include <stdio.h>
#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xil_types.h"
#include "sleep.h"

/* --------------------------------------------------------------------------
 * Base address.  Vitis exposes the IP base as XPAR_CORDIC_SQRT_AXI_0_*; fall
 * back to 0x43C20000 (next 64 KB aperture above fix_acc) if the platform
 * hasn't been built yet so the file still compiles standalone.
 * --------------------------------------------------------------------------
 */
#ifdef XPAR_CORDIC_SQRT_AXI_0_S00_AXI_BASEADDR
#define BASEADDR        XPAR_CORDIC_SQRT_AXI_0_S00_AXI_BASEADDR
#else
#warning "XPAR_CORDIC_SQRT_AXI_0_S00_AXI_BASEADDR not found - using 0x43C20000"
#define BASEADDR        0x43C20000U
#endif

/* Mimic the Xilinx-generated mWriteReg / mReadReg helper names used in the
 * assignment snippet so the call sites read identically.                    */
#define CORDIC_SQRT_mWriteReg(base, ofst, val) \
    Xil_Out32((u32)(base) + (u32)(ofst), (u32)(val))
#define CORDIC_SQRT_mReadReg(base, ofst) \
    Xil_In32((u32)(base) + (u32)(ofst))

/* --------------------------------------------------------------------------
 * Test vectors (matching the assignment specification, section 5):
 *     x = 0x080 (1.0   in 2Q7) -> z = 0x100 (1.000  in 1Q8)
 *     x = 0x040 (0.5   in 2Q7) -> z = 0x0B5 (0.707  in 1Q8)
 *     x = 0x008 (1/16  in 2Q7) -> z = 0x040 (0.250  in 1Q8)
 * --------------------------------------------------------------------------
 */
#define N_TESTS  3

static const u32 test_vector[N_TESTS]     = { 0x080U, 0x040U, 0x008U };
static const u32 expected_result[N_TESTS] = { 0x100U, 0x0B5U, 0x040U };

int main(void)
{
    /* Startup window so the serial monitor can attach in time.              */
    for (int i = 3; i > 0; i--) {
        xil_printf("cordic_sqrt starting in %d...\r\n", i);
        sleep(1);
    }

    xil_printf("\r\n");
    xil_printf("==========================================================\r\n");
    xil_printf("   ECEC 661 HW4 - CORDIC Square Root IP test app\r\n");
    xil_printf("   IP base address : 0x%08x\r\n", (unsigned) BASEADDR);
    xil_printf("==========================================================\r\n");
    xil_printf("\r\n");
    xil_printf("cordic sqrt\r\n");

    unsigned pass = 0, fail = 0;

    for (int i = 0; i < N_TESTS; i++)
    {
        CORDIC_SQRT_mWriteReg(BASEADDR, 0, test_vector[i]);  /* slv_reg0 = x */
        CORDIC_SQRT_mWriteReg(BASEADDR, 4, 1);               /* din_tvalid    */

        /* dout_tvalid -> slv_reg3(0) */
        while (!CORDIC_SQRT_mReadReg(BASEADDR, 12))
            ;

        CORDIC_SQRT_mWriteReg(BASEADDR, 4, 0);               /* lower din_tv  */

        u32 x_in = CORDIC_SQRT_mReadReg(BASEADDR, 0);
        u32 z_out = CORDIC_SQRT_mReadReg(BASEADDR, 8);

        xil_printf("sqrt(0x%X) = 0x%X\r\n",
                   (unsigned) x_in, (unsigned) z_out);

        if (z_out != expected_result[i]) {
            xil_printf("ERROR: %dth testvector 0x%X expect 0x%X\r\n",
                       i,
                       (unsigned) test_vector[i],
                       (unsigned) expected_result[i]);
            fail++;
        } else {
            pass++;
        }
    }

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
