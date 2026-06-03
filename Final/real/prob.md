New instruction on the sp101, ssq "stack the square"

After executing, for example

sc 7 ssq halt

sp101 write 49 on the stack and the stack pointer points to the next available address location.

Part 1: simulate correctness of ssq (10pts)
submit sim wave

Part 2: develop custom IP (5pts)
submit vhdl of the user logic instantiation (component declaration and port map)

Part 3: FPGA dev test bench
submit:
    1. block diagram (3pts)
    2. C test app (3pts)
    3. serial terminal snip (4pts). address 128 contains the square.
