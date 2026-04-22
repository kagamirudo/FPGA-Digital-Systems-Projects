#include <unistd.h>

#include "platform.h"
#include "xgpio.h"
#include "xil_printf.h"
#include "xparameters.h"

#define BTNS_DEVICE_ID XPAR_AXI_GPIO_1_BASEADDR
#define LEDS_DEVICE_ID XPAR_AXI_GPIO_0_BASEADDR

#define LED_COUNT 6
#define LED_MASK ((1U << LED_COUNT) - 1)
#define STEP_DELAY_US 500000 /* 500 ms per chase step */

#define BTN0 0x01
#define BTN1 0x02

/* rgb_leds_tri_o bit -> board net (see top.xdc):
 *   bit 0 = LD0_R, bit 1 = LD0_G, bit 2 = LD0_B
 *   bit 3 = LD1_R, bit 4 = LD1_G, bit 5 = LD1_B
 */
static const int seq_rgb[LED_COUNT] = {0, 1, 2, 3, 4, 5}; /* R,G,B - R,G,B */
static const int seq_bgr[LED_COUNT] = {2, 1, 0, 5, 4, 3}; /* B,G,R - B,G,R */

int main() {
    init_platform();
    XGpio btn_gpio, led_gpio;

    if (XGpio_Initialize(&btn_gpio, BTNS_DEVICE_ID) != XST_SUCCESS)
        return XST_FAILURE;
    if (XGpio_Initialize(&led_gpio, LEDS_DEVICE_ID) != XST_SUCCESS)
        return XST_FAILURE;

    XGpio_SetDataDirection(&btn_gpio, 1, 0xFF); /* all inputs */
    XGpio_SetDataDirection(&led_gpio, 1, 0x00); /* all outputs */

    const int *seq = seq_rgb; /* default: RGB order */
    int idx = 0;
    xil_printf("Mode: RGB (btn1=RGB, btn0=BGR)\r\n");

    while (1) {
        XGpio_DiscreteWrite(&led_gpio, 1, (1U << seq[idx]) & LED_MASK);
        usleep(STEP_DELAY_US);

        u32 raw = XGpio_DiscreteRead(&btn_gpio, 1);
        if ((raw & BTN1) && seq != seq_rgb) {
            seq = seq_rgb;
            xil_printf("Mode: RGB\r\n");
        } else if ((raw & BTN0) && seq != seq_bgr) {
            seq = seq_bgr;
            xil_printf("Mode: BGR\r\n");
        }

        idx = (idx + 1) % LED_COUNT;
    }

    cleanup_platform();
    return 0;
}
