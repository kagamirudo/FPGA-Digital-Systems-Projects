## ECEC 661 Midterm - Sequence Detector
## Target: Digilent Cora Z7-07S (xc7z007sclg400-1)
##
## External ports created from the block design:
##   rgb_leds_tri_o[5:0]   - axi_gpio_0 (LEDs, output)
##                            bit 0 = LD0_R
##                            bit 1 = LD0_G   <- detection LED (toggled on match)
##                            bit 2 = LD0_B
##                            bit 3 = LD1_R
##                            bit 4 = LD1_G
##                            bit 5 = LD1_B
##   btns_2bits_tri_i[1:0] - axi_gpio_1 (buttons, input)
##                            bit 0 = BTN0
##                            bit 1 = BTN1

## RGB LEDs ----------------------------------------------------------------
set_property -dict { PACKAGE_PIN N15 IOSTANDARD LVCMOS33 } [get_ports { rgb_leds_tri_o[0] }]; # LD0_R
set_property -dict { PACKAGE_PIN G17 IOSTANDARD LVCMOS33 } [get_ports { rgb_leds_tri_o[1] }]; # LD0_G  detection LED
set_property -dict { PACKAGE_PIN L15 IOSTANDARD LVCMOS33 } [get_ports { rgb_leds_tri_o[2] }]; # LD0_B
set_property -dict { PACKAGE_PIN M15 IOSTANDARD LVCMOS33 } [get_ports { rgb_leds_tri_o[3] }]; # LD1_R
set_property -dict { PACKAGE_PIN L14 IOSTANDARD LVCMOS33 } [get_ports { rgb_leds_tri_o[4] }]; # LD1_G
set_property -dict { PACKAGE_PIN G14 IOSTANDARD LVCMOS33 } [get_ports { rgb_leds_tri_o[5] }]; # LD1_B

## Buttons -----------------------------------------------------------------
set_property -dict { PACKAGE_PIN D20 IOSTANDARD LVCMOS33 } [get_ports { btns_2bits_tri_i[0] }]; # BTN0
set_property -dict { PACKAGE_PIN D19 IOSTANDARD LVCMOS33 } [get_ports { btns_2bits_tri_i[1] }]; # BTN1
