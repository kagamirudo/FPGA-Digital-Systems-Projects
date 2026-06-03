# Final Prep Framework (HW4 -> HW5)

This folder is a structured preparation kit for the ECEC 661 final.
It mirrors the midterm prep layout, but the technical focus is narrower:

- `Homework_4/cordic_sqrt`: CORDIC square-root IP, Q-format conversion,
  AXI4-Lite register control, and AXI-Stream valid polling.
- `Homework_5/stackprocessor_101`: Stack Processor 101, BRAM-backed
  instruction execution, AXI4-Lite bus access, and the new `scpb`
  block-copy instruction.

## What to use in this folder

- `CHECKLIST.md`: practical prep checklist you can execute line by line.
- `FINAL_RUNBOOK.md`: timed exam-day execution sequence.
- `REPORT_TEMPLATE.md`: quick report template for clean submission artifacts.
- `practice_drills.md`: timed HW4/HW5-style practice problems.

## Core outcomes to master

1. Explain and use fixed-point formats: HW4 `x` is 2Q7, HW4 `z` is 1Q8.
2. Wire software-visible AXI4-Lite registers to user logic cleanly.
3. Handle valid/ready-style compute latency by polling status, not guessing delay.
4. Build and debug a Zynq PS + custom PL IP block design.
5. Understand Stack Processor 101 opcodes, stack effects, and BRAM timing.
6. Implement/test a multi-step instruction such as `scpb` with edge cases.
7. Produce convincing evidence: simulation, block design, C app, UART output,
   and a short explanation of one real debug issue.

## Suggested prep cadence

- Session A (45 min): HW4 CORDIC/Q-format/register-map review.
- Session B (60 min): HW4-style compute-IP drill with simulation + C handshake.
- Session C (75 min): HW5 stack processor opcode and BRAM timing review.
- Session D (90 min): HW5-style custom instruction drill.
- Session E (30 min): report-writing speed run from `REPORT_TEMPLATE.md`.

Do at least one full HW4 drill and one full HW5 drill before the final.

## High-value habits

- Keep one page of base addresses, register offsets, opcodes, and control bits.
- For every hardware run, capture three screenshots: simulation, block design,
  and UART/serial output.
- When something fails, classify it fast: RTL behavior, register map, BD wiring,
  BSP/UART, or stale exported hardware.
- In reports, state the programming model first, then the proof.
