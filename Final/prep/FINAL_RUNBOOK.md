# Final Runbook (Timed)

This runbook assumes a practical final where you must build, test, integrate,
run, and explain an HW4/HW5-style design.

## 0:00 - 0:10 Read + classify

- Decide which style the problem is closest to:
  - HW4 style: compute IP, Q-format, valid/status handshake.
  - HW5 style: stack processor, custom instruction, BRAM, opcode/FSM.
- Extract the deliverables:
  - user logic HDL,
  - testbench/simulation,
  - IP packaging,
  - block design,
  - software app,
  - UART/runtime proof,
  - report.
- Write the register map and expected test vectors before opening tools.

## 0:10 - 0:45 RTL/user logic first

- For HW4-style compute IP:
  - map input/output bit widths and Q-format,
  - connect `tvalid`/status signals cleanly,
  - avoid fixed-delay assumptions in the design.
- For HW5-style stack processor:
  - define opcode constants,
  - define stack effect,
  - add working registers,
  - write micro-states in a traceable order.
- Keep the first version minimal and correct before adding extra cases.

## 0:45 - 1:15 Testbench + simulation

- Build a self-checking TB before doing block design work.
- Required case pattern:
  - nominal path,
  - boundary/off-by-one path,
  - reset/restart or zero/no-op path.
- For HW4, include known vectors such as:
  - `0x080 -> 0x100`,
  - `0x040 -> 0x0B5`,
  - `0x008 -> 0x040`.
- For HW5, include:
  - multi-word copy,
  - single-word copy,
  - zero-count no-op.
- Save a waveform screenshot after assertions pass.

## 1:15 - 1:55 Vivado integration

- Package or refresh the custom IP.
- Check IP metadata:
  - clock/reset association,
  - sub-core references,
  - file types (`VHDL` for RTL, `VHDL 2008` for TB when needed).
- Create/validate block design:
  - Zynq PS,
  - processor system reset,
  - AXI interconnect/SmartConnect,
  - custom IP.
- Assign the base address and write it down immediately.
- Generate wrapper, set wrapper as top, generate bitstream, export XSA with
  bitstream.

## 1:55 - 2:25 Vitis app + hardware run

- Create platform from the fresh XSA.
- Set BSP stdin/stdout to the correct UART and regenerate BSP.
- Write software around the register map:
  - initialize inputs,
  - assert control/start/run,
  - poll status/done,
  - read back output,
  - compare expected vs observed.
- Open serial monitor before Run.
- Capture UART output screenshot.

## 2:25 - 2:45 Report packaging

- Fill `REPORT_TEMPLATE.md`.
- Include:
  - problem summary,
  - register map,
  - user logic explanation,
  - simulation evidence,
  - block design evidence,
  - software/UART evidence,
  - one debug note.
- Do a final consistency pass:
  - base addresses match,
  - register offsets match,
  - screenshots correspond to this run,
  - test vectors in text match UART output.

## Emergency decision rules

- If simulation fails repeatedly: shrink to the smallest valid behavior and
  prove that first.
- If C output is wrong but simulation passes: check base address, register
  offsets, reset/run control bits, and stale XSA/platform.
- If UART is blank: check BSP stdin/stdout, serial port, `ps7_init`, and
  whether the app exits before the monitor is attached.
- If bitstream generation is stuck: stop feature edits and fix integration
  warnings/errors only.
- If time is short: submit a complete minimal solution with strong evidence
  instead of an ambitious partial solution.
