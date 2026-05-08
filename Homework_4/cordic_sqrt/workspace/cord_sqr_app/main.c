/*
 * main.c
 *
 * ECEC 661 - Homework 4 - CORDIC Square Root IP
 *
 * Bare-metal Vitis test app for the custom "cordic_sqrt_axi" AXI4-Lite IP.
 * The PS pushes 10-bit 2Q7 samples into slv_reg0, raises din_tvalid in
 * slv_reg1, polls dout_tvalid in slv_reg3, and reads back the 1Q8 square
 * root from slv_reg2.  Output is printed over UART0 (the Cora Z7-07S
 * USB-UART bridge), matching the screenshot in the assignment (Fig. 4).
 *
 * Q formats (problem statement):
 *   x : 2Q7 unsigned — value = (x & 0x3FF) / 2^7  (integer + 7 fractional bits)
 *   z : 1Q8 unsigned — value = (z & 0x3FF) / 2^8  (1 integer + 8 fractional bits)
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

/* 10-bit lane used by the IP */
#define Q_MASK10        0x3FFU

/* 2Q7: 7 fractional bits, scale 1/128 */
#define Q2Q7_SCALE      128U
/* 1Q8: 8 fractional bits, scale 1/256 */
#define Q1Q8_SCALE      256U

/* Table columns: one place to edit; rule line and snprintf widths stay in sync. */
#define COL_IDX  3U
#define COL_HEX  7U
#define COL_DEC  11U
#define COL_CHK  4U

static void print_table_rule(void)
{
    static const unsigned col_w[] = {
        COL_IDX, COL_HEX, COL_DEC, COL_HEX, COL_DEC, COL_CHK
    };
    const unsigned ncols = (unsigned) (sizeof col_w / sizeof col_w[0]);
    /* Same " | " between fields as snprintf() in header/row — not '+' */
    static const char between[] = " | ";
    char buf[128];
    unsigned p = 0;

    for (unsigned c = 0; c < ncols; c++) {
        for (unsigned j = 0; j < col_w[c]; j++) {
            if (p + 1U >= sizeof buf) {
                goto emit;
            }
            buf[p++] = '-';
        }
        if (c + 1U < ncols) {
            for (unsigned k = 0; k < sizeof between - 1U; k++) {
                if (p + 1U >= sizeof buf) {
                    goto emit;
                }
                buf[p++] = between[k];
            }
        }
    }
emit:
    if (p + 3U >= sizeof buf) {
        p = sizeof buf - 3U;
    }
    buf[p++] = '\r';
    buf[p++] = '\n';
    buf[p] = '\0';
    xil_printf("%s", buf);
}

/* --------------------------------------------------------------------------
 * Format fixed-point decimals without %f (buffers + xil_printf %-Ns).
 * 2Q7: int_part = v>>7, frac via milli in 0..999
 * 1Q8: int_part = v>>8, frac via milli in 0..999
 * --------------------------------------------------------------------------
 */
static void fmt_hex10(char *buf, size_t n, u32 v)
{
    (void) snprintf(buf, n, "  0x%03X", (unsigned) (v & Q_MASK10));
}

static void fmt_dec_2q7(char *buf, size_t n, u32 x_raw)
{
    u32 v = x_raw & Q_MASK10;
    u32 ip = v >> 7;
    u32 fp = v & 0x7FU;
    u32 milli = (fp * 1000U + (Q2Q7_SCALE / 2U)) / Q2Q7_SCALE;
    if (milli >= 1000U) {
        milli -= 1000U;
        ip++;
    }
    (void) snprintf(buf, n, "%2u.%03u", (unsigned) ip, (unsigned) milli);
}

static void fmt_dec_1q8(char *buf, size_t n, u32 z_raw)
{
    u32 v = z_raw & Q_MASK10;
    u32 ip = v >> 8;
    u32 fp = v & 0xFFU;
    u32 milli = (fp * 1000U + (Q1Q8_SCALE / 2U)) / Q1Q8_SCALE;
    if (milli >= 1000U) {
        milli -= 1000U;
        ip++;
    }
    (void) snprintf(buf, n, "%2u.%03u", (unsigned) ip, (unsigned) milli);
}

static void print_table_header(void)
{
    char line[160];

    xil_printf("\r\n");
    xil_printf("  (x in 2Q7: value = x/128  |  z in 1Q8: value = z/256)\r\n");
    xil_printf("\r\n");
    /* Widths from COL_* so header lines up with print_table_row() */
    (void) snprintf(line, sizeof line,
                    "%*s | %-*s | %-*s | %-*s | %-*s | %-*s\r\n",
                    (int) COL_IDX, "#",
                    (int) COL_HEX, " x(hex)",
                    (int) COL_DEC, "  x dec 2Q7",
                    (int) COL_HEX, " z(hex)",
                    (int) COL_DEC, "  z dec 1Q8",
                    (int) COL_CHK, " chk");
    xil_printf("%s", line);
    print_table_rule();
}

static void print_table_row(int idx, u32 x_in, u32 z_out, const char *chk)
{
    char line[160];
    char hx[16];
    char dx[16];
    char hz[16];
    char dz[16];

    fmt_hex10(hx, sizeof hx, x_in);
    fmt_dec_2q7(dx, sizeof dx, x_in);
    fmt_hex10(hz, sizeof hz, z_out);
    fmt_dec_1q8(dz, sizeof dz, z_out);

    (void) snprintf(line, sizeof line,
                    "%*d | %-*s | %-*s | %-*s | %-*s | %-*s\r\n",
                    (int) COL_IDX, idx,
                    (int) COL_HEX, hx,
                    (int) COL_DEC, dx,
                    (int) COL_HEX, hz,
                    (int) COL_DEC, dz,
                    (int) COL_CHK, chk);
    xil_printf("%s", line);
}

/* --------------------------------------------------------------------------
 * Test vectors
 *
 * Required (assignment §5):
 *   0x080 -> 0x100   (1.0  -> 1.0)
 *   0x040 -> 0x0B5   (0.5  -> ~0.707)
 *   0x008 -> 0x040   (1/16 -> 1/4)
 *
 * Extra checks (same scaling; expected z truncated per IP Round Mode):
 *   0x000 -> 0x000   (0 -> 0)
 *   0x020 -> 0x080   (0.25 -> 0.5)
 *   0x010 -> 0x05A   (0.125 -> sqrt(0.125)*256 ≈ 90.5 -> 90)
 *   0x180 -> 0x1BB   (3.0 in 2Q7 -> sqrt(3)*256 ≈ 443.4 -> 443)
 * --------------------------------------------------------------------------
 */
#define N_TESTS  7

static const u32 test_vector[N_TESTS] = {
    0x000U,
    0x080U,
    0x040U,
    0x008U,
    0x020U,
    0x010U,
    0x180U,
};

static const u32 expected_result[N_TESTS] = {
    0x000U,
    0x100U,
    0x0B5U,
    0x040U,
    0x080U,
    0x05AU,
    0x1BBU,
};

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

    print_table_header();

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

        const char *chk = (z_out == expected_result[i]) ? "  OK" : " BAD";

        print_table_row(i, x_in, z_out, chk);

        if (z_out != expected_result[i]) {
            char exp_dz[16];
            fmt_dec_1q8(exp_dz, sizeof exp_dz, expected_result[i]);
            xil_printf("      ERROR: expect z=0x%03X  (dec %s)\r\n",
                       (unsigned) (expected_result[i] & Q_MASK10), exp_dz);
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
