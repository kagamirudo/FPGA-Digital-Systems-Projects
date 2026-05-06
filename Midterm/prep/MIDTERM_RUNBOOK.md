# Midterm Runbook (Timed)

This runbook is for a practical midterm where you must build, test, and show evidence.
Use it during practice so execution becomes automatic.

## 0:00 - 0:10  Read + plan

- Parse requirements into 5 deliverables:
  1) HDL user logic
  2) testbench
  3) block diagram evidence
  4) software app
  5) runtime output evidence
- Create a mini task order on paper before touching tools.

## 0:10 - 0:35  RTL + TB first

- Build user logic with clean reset/clock behavior.
- Build TB with assertions and at least 3 meaningful cases:
  - nominal path
  - boundary/overflow path
  - reset/restart path
- Run simulation and lock a passing screenshot.

## 0:35 - 1:20  Vivado system integration

- If AXI IP is needed:
  - wire register map carefully
  - package IP with valid metadata
  - ensure clock interface parameters are set
- Create/validate BD:
  - PS, reset block, interconnect, custom IP
  - all clocks and resets driven
  - address editor assigned
- Generate wrapper, set as top, generate bitstream, export XSA.

## 1:20 - 1:45  Vitis app + hardware run

- Create platform from fresh XSA.
- Set BSP stdin/stdout UART and regenerate BSP.
- Build app; run with bitstream + `ps7_init`.
- Open serial monitor before run.
- Save successful output screenshot.

## 1:45 - 2:00  Submission packaging

- Fill report from `REPORT_TEMPLATE.md`.
- Verify all required evidence exists and is readable.
- Do a 2-minute sanity pass:
  - names/paths match actual files
  - addresses in code match BD
  - screenshots correspond to this build

## Emergency decision rules

- If simulation fails repeatedly: simplify design, pass minimal required behavior, then extend.
- If bitstream is stuck: freeze feature changes and resolve only integration errors.
- If UART is blank: check UART mapping + BSP regeneration + `ps7_init` before any other guess.
- If time is short: prioritize a complete, coherent minimal solution over incomplete extras.
