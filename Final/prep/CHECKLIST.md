# Final Prep Checklist

Use this as a repeatable training checklist. Mark each item when done.

## 1) Environment and setup

- [ ] Vivado 2025.2 opens the HW4/HW5 projects without upgrade churn.
- [ ] Vitis 2025.2 can build a standalone app from a fresh XSA.
- [ ] Cora Z7-07S USB-JTAG/UART enumerates (`/dev/ttyUSB*` on Linux).
- [ ] Serial command is ready, for example:
  `picocom /dev/ttyUSB1 -b 115200 --imap lfcrlf`.
- [ ] You know where screenshots go for each homework report.

## 2) HW4: CORDIC square root

- [ ] Explain the CORDIC configuration: Square Root, Parallel, Maximum
      pipelining, UnsignedFraction, 10-bit input/output, Truncate.
- [ ] Convert key 2Q7 inputs:
      `0x080 = 1.0`, `0x040 = 0.5`, `0x008 = 1/16`.
- [ ] Convert key 1Q8 outputs:
      `0x100 = 1.0`, `0x0B5 ~= 0.707`, `0x040 = 0.25`.
- [ ] Know why `user_logic.vhd` uses only bits `[9:0]` and zeroes `[15:10]`.
- [ ] Re-run `tb/tb_user_logic.vhd` and confirm all expected vectors pass.
- [ ] Explain why software polls `dout_tvalid` instead of using a fixed delay.

## 3) HW4: AXI register map and software

- [ ] Memorize the HW4 register offsets:
      `0x00 x`, `0x04 din_tvalid`, `0x08 z`, `0x0C dout_tvalid`.
- [ ] Practice the handshake:
      write `x`, raise `din_tvalid`, poll `dout_tvalid`, lower `din_tvalid`,
      read `z`.
- [ ] Verify the base address expected by software:
      `0x43C2_0000` / `XPAR_CORDIC_SQRT_AXI_0_S00_AXI_BASEADDR`.
- [ ] Explain the difference between AXI4-Lite software registers and the
      internal AXI-Stream CORDIC ports.

## 4) HW5: Stack Processor 101 basics

- [ ] Memorize the core opcodes:
      `halt=0xFF`, `sc=0x01`, `sl=0x11`, `ss=0x21`,
      `sadd=0x31`, `scp=0x101`, `scpb=0x201`.
- [ ] Explain stack effects for `sc`, `sl`, `ss`, `sadd`, `scp`, and `scpb`.
- [ ] Explain the `scpb` calling convention:
      `sc dest_addr  sc source_addr  sc number_of_data  scpb`.
- [ ] Trace the stack top at `scpb` entry:
      top = count, next = source, next = destination.
- [ ] Explain why the BRAM read path uses extra latency states.

## 5) HW5: `scpb` correctness

- [ ] Trace the `scpb` phases:
      pop count, pop source, pop destination, loop copy, update pointers/count.
- [ ] Know the working registers:
      `copy_cnt`, `copy_src`, `copy_dst`.
- [ ] Re-run the testbench scenarios:
      count 3, count 1, count 0.
- [ ] Verify the zero-count case leaves the destination sentinel unchanged.
- [ ] Explain the approximate cycle cost:
      `6N + 8` clocks plus fetch overhead.

## 6) HW5: AXI register map and software

- [ ] Memorize the HW5 register offsets:
      `0x00 control`, `0x04 bus address`, `0x08 bus write data`,
      `0x0C bus read data`, `0x10 done`.
- [ ] Memorize control bits:
      bit 0 `run`, bit 1 `reset`, bit 2 `bus2mem_en`, bit 3 `bus2mem_we`.
- [ ] Practice bus write, bus read, processor reset, and run/wait sequences.
- [ ] Remember the driver gotcha:
      do not hold `CTRL_RESET` during `mem_read()`.
- [ ] Verify the base address expected by software:
      `0x43C3_0000` / `XPAR_SP101_AXI_0_S00_AXI_BASEADDR`.

## 7) Block design and packaging

- [ ] Package HW4 `cordic_sqrt_axi` with correct sub-core reference to CORDIC.
- [ ] Package HW5 `sp101_axi` with the BRAM generator reference intact.
- [ ] Connect PS `M_AXI_GP0` through interconnect/SmartConnect to the custom IP.
- [ ] Drive all AXI clocks/resets from the PS FCLK/reset path.
- [ ] Assign address ranges and confirm the C code matches the Address Editor.
- [ ] Generate wrapper, set wrapper as top, generate bitstream, export XSA
      with bitstream.

## 8) Vitis bring-up and UART

- [ ] Platform is created from the correct exported XSA.
- [ ] BSP stdin/stdout are mapped to `ps7_uart_0`.
- [ ] BSP regenerated after UART setting changes.
- [ ] Run configuration programs bitstream and runs `ps7_init`.
- [ ] Serial monitor is attached before clicking Run.

## 9) Submission readiness

- [ ] User logic HDL path is easy to identify.
- [ ] Testbench path and passing evidence are captured.
- [ ] Block design screenshot is captured.
- [ ] C application path and key register snippet are ready.
- [ ] UART output screenshot proves expected vs observed results.
- [ ] Report draft completed from `REPORT_TEMPLATE.md`.
