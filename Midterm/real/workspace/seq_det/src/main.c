/*
 * main.c
 *
 * ECEC 661 - Midterm
 *
 * Bare-metal sequence detector for the Digilent Cora Z7-07S.
 *
 * Hardware (Vivado block design `seq_det.bd`):
 *   - axi_gpio_0 -> 6-bit LED output  (rgb_leds_tri_o[5:0])
 *   - axi_gpio_1 -> 2-bit button input (btns_2bits_tri_i[1:0])
 *
 * Behavior:
 *   - Poll the buttons every POLL_PERIOD_US.
 *   - On a rising edge of BTN0 or BTN1, drive the 4-state KMP FSM that
 *     matches the sequence btn0, btn0, btn1.
 *   - The detection LED (LD0_G, rgb_leds_tri_o[1]) is ON while, and only
 *     while, the FSM is in the "detected" state S3.
 *   - Print every press and every state transition over UART so the
 *     PuTTY/serial-monitor capture is self-explanatory.
 */

#include "xparameters.h"
#include "xgpio.h"
#include "xil_printf.h"
#include "xil_types.h"
#include "sleep.h"

/* --------------------------------------------------------------------------
 * Base addresses.  Vitis emits XPAR_AXI_GPIO_<n>_BASEADDR after the platform
 * is built from the XSA.  Fall back to the defaults Vivado picks for two
 * AXI GPIO slaves on M_AXI_GP0 so this file still compiles before the
 * platform exists.
 * --------------------------------------------------------------------------
 */
#ifdef XPAR_AXI_GPIO_0_BASEADDR
#define LEDS_BASEADDR   XPAR_AXI_GPIO_0_BASEADDR
#else
#warning "XPAR_AXI_GPIO_0_BASEADDR not found - using default 0x41200000"
#define LEDS_BASEADDR   0x41200000U
#endif

#ifdef XPAR_AXI_GPIO_1_BASEADDR
#define BTNS_BASEADDR   XPAR_AXI_GPIO_1_BASEADDR
#else
#warning "XPAR_AXI_GPIO_1_BASEADDR not found - using default 0x41210000"
#define BTNS_BASEADDR   0x41210000U
#endif

#define GPIO_CHANNEL    1U

/* LED bit assignments inside the 6-bit rgb_leds vector.
 * Only the detection LED is exercised here; the others stay dark. */
#define LED_COUNT       6
#define LED_MASK        ((1U << LED_COUNT) - 1U)
#define LED_DETECT_BIT  (1U << 1)   /* LD0_G (rgb_leds_tri_o[1])      */

#define BTN0_MASK       (1U << 0)
#define BTN1_MASK       (1U << 1)

/* Polling cadence.  5 ms is fast enough that the user cannot press and
 * release a button without us seeing the rising edge, and slow enough
 * that natural mechanical contact bounce (~1 ms) is invisible. */
#define POLL_PERIOD_US  5000U

/* FSM states for pattern btn0, btn0, btn1 ----------------------------- */
typedef enum {
    S0 = 0,   /* nothing matched yet                                   */
    S1 = 1,   /* btn0 matched                                          */
    S2 = 2,   /* btn0, btn0 matched                                    */
    S3 = 3    /* btn0, btn0, btn1 matched - LED ON                     */
} seq_state_t;

static const char *state_name(seq_state_t s)
{
    switch (s) {
    case S0: return "S0";
    case S1: return "S1";
    case S2: return "S2";
    case S3: return "S3";
    default: return "??";
    }
}

/* --------------------------------------------------------------------------
 * 4-state KMP transition table (Moore-style; LED is purely a function of
 * the current state):
 *
 *   S0 + btn0 -> S1
 *   S0 + btn1 -> S0
 *   S1 + btn0 -> S2
 *   S1 + btn1 -> S0
 *   S2 + btn0 -> S2   (KMP self-loop: trailing btn0 starts a new match)
 *   S2 + btn1 -> S3   (DETECTED)
 *   S3 + btn0 -> S1   (KMP-aware: this btn0 could open the next match)
 *   S3 + btn1 -> S0
 * --------------------------------------------------------------------------
 */
static seq_state_t fsm_step(seq_state_t s, int btn_idx)
{
    if (btn_idx == 0) {                 /* BTN0 event */
        switch (s) {
        case S0: return S1;
        case S1: return S2;
        case S2: return S2;
        case S3: return S1;
        }
    } else {                            /* BTN1 event */
        switch (s) {
        case S0: return S0;
        case S1: return S0;
        case S2: return S3;
        case S3: return S0;
        }
    }
    return S0;
}

int main(void)
{
    XGpio led_gpio;
    XGpio btn_gpio;

    if (XGpio_Initialize(&led_gpio, LEDS_BASEADDR) != XST_SUCCESS) {
        xil_printf("XGpio_Initialize(LEDs) failed\r\n");
        return XST_FAILURE;
    }
    if (XGpio_Initialize(&btn_gpio, BTNS_BASEADDR) != XST_SUCCESS) {
        xil_printf("XGpio_Initialize(buttons) failed\r\n");
        return XST_FAILURE;
    }

    XGpio_SetDataDirection(&led_gpio, GPIO_CHANNEL, 0x00);     /* all out */
    XGpio_SetDataDirection(&btn_gpio, GPIO_CHANNEL, 0xFFFFFFFF); /* all in */

    XGpio_DiscreteWrite(&led_gpio, GPIO_CHANNEL, 0);

    /* Startup window so the serial monitor has time to attach, and so
     * UART output is confirmed working before any GPIO interaction. */
    for (int i = 3; i > 0; i--) {
        xil_printf("seq_det starting in %d...\r\n", i);
        sleep(1);
    }

    xil_printf("\r\n");
    xil_printf("==========================================================\r\n");
    xil_printf("   ECEC 661 Midterm - Button sequence detector\r\n");
    xil_printf("   Pattern  : BTN0, BTN0, BTN1   (4-state Moore FSM)\r\n");
    xil_printf("   LEDs base: 0x%08x   Buttons base: 0x%08x\r\n",
               (unsigned) LEDS_BASEADDR, (unsigned) BTNS_BASEADDR);
    xil_printf("==========================================================\r\n");
    xil_printf("Press BTN0 / BTN1 on the Cora Z7-07S board.\r\n");
    xil_printf("LD0_G is ON while the FSM is in the detected state S3.\r\n\r\n");

    seq_state_t state = S0;
    u32 prev_btns = XGpio_DiscreteRead(&btn_gpio, GPIO_CHANNEL) & 0x3U;
    unsigned detect_count = 0;

    while (1) {
        u32 cur_btns = XGpio_DiscreteRead(&btn_gpio, GPIO_CHANNEL) & 0x3U;

        /* Ignore samples where both buttons are held - ambiguous event. */
        if (cur_btns == 0x3U) {
            usleep(POLL_PERIOD_US);
            prev_btns = cur_btns;
            continue;
        }

        u32 rising = cur_btns & ~prev_btns;     /* 0->1 edges only */
        prev_btns  = cur_btns;

        /* Process at most one event per scan; if both edges hit in the
         * same 5 ms window we service BTN0 first (it never causes a
         * detection so the BTN1 event is still meaningful next scan). */
        int btn_idx = -1;
        if (rising & BTN0_MASK) {
            btn_idx = 0;
        } else if (rising & BTN1_MASK) {
            btn_idx = 1;
        }

        if (btn_idx >= 0) {
            seq_state_t prev = state;
            state = fsm_step(state, btn_idx);

            /* Moore output: LED is ON iff state == S3. Drive it on every
             * transition so leaving S3 turns it back off automatically. */
            u32 led_state = ((state == S3) ? LED_DETECT_BIT : 0U) & LED_MASK;
            XGpio_DiscreteWrite(&led_gpio, GPIO_CHANNEL, led_state);

            int just_detected = (state == S3 && prev != S3);
            if (just_detected) detect_count++;

            if (just_detected) {
                xil_printf("[press BTN%d] state %s -> %s  LED=ON   *** DETECTED #%u ***\r\n",
                           btn_idx, state_name(prev), state_name(state),
                           detect_count);
            } else {
                xil_printf("[press BTN%d] state %s -> %s  LED=%s\r\n",
                           btn_idx, state_name(prev), state_name(state),
                           (state == S3) ? "ON " : "OFF");
            }
        }

        usleep(POLL_PERIOD_US);
    }

    return 0;
}
