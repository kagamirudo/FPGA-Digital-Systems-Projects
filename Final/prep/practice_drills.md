# Final Practice Drills (HW4 -> HW5 Style)

Use these as timed mock finals. They are scoped to match the workflows and
failure points from Homework 4 and Homework 5.

## Drill 1 - Easy/Medium: HW4-style compute IP

### Theme

Custom AXI4-Lite wrapper around a pipelined compute block. Software writes an
input, raises a valid bit, polls a done/valid bit, then reads the output.

### Problem

Design a simple square function IP for unsigned 8-bit fixed-point values:

- Input `x`: lower 8 bits of `slv_reg0`, interpreted as unsigned Q4.4.
- Control `slv_reg1 bit 0`: `din_valid`.
- Output `z`: lower 16 bits of `slv_reg2`, interpreted as unsigned Q8.8.
- Status `slv_reg3 bit 0`: `dout_valid`.

Behavior:

- When `din_valid='1'`, capture `x`.
- After a fixed 3-cycle pipeline, assert `dout_valid='1'` for one or more
  cycles and expose `z = x*x`.
- Software must poll `dout_valid`; it must not assume a magic delay.

### Required deliverables

1. User logic HDL.
2. Self-checking testbench.
3. AXI register map.
4. C app that writes vectors, polls status, reads output, and prints PASS/FAIL.
5. Simulation screenshot and UART screenshot.

### Time box

75 minutes total:

- 25 min RTL
- 20 min TB
- 15 min register-map/software sketch
- 15 min evidence/report notes

### Minimum validation vectors

- `x = 0x10` = 1.0 -> `z = 0x0100` = 1.0
- `x = 0x08` = 0.5 -> `z = 0x0040` = 0.25
- `x = 0x20` = 2.0 -> `z = 0x0400` = 4.0
- `x = 0x00` = 0.0 -> `z = 0x0000`

### Pass criteria

- TB assertions pass.
- Software uses register offsets correctly.
- Output is explained in fixed-point terms.

---

## Drill 2 - Medium/Hard: HW5-style custom stack instruction

### Theme

Add a new instruction to Stack Processor 101 and verify stack effects, BRAM
timing, and software-driven memory loading/readback.

### Problem

Add instruction `sfill` (stack fill):

```text
sc dest_addr   sc value   sc number_of_data   sfill
```

At entry:

- top of stack = `number_of_data`,
- next = `value`,
- next = `dest_addr`.

Behavior:

- Pop count, value, and destination.
- Write `value` into `mem[dest_addr .. dest_addr + count - 1]`.
- If count is zero, leave destination memory unchanged.

Choose opcode `0x00000301`.

### Required deliverables

1. `user_logic.vhd` changes with opcode constants and micro-states.
2. Self-checking testbench with at least three scenarios.
3. Register/opcode documentation update.
4. C app or C pseudocode that loads memory, runs the processor, polls done,
   and reads back results.
5. Short explanation of BRAM latency states.

### Time box

100 minutes total:

- 40 min FSM design
- 25 min TB
- 20 min C app/register handshake
- 15 min report/evidence

### Minimum validation scenarios

- Fill 3 words at address 200 with `0x0000002A`.
- Fill 1 word at address 210 with `0x00000063`.
- Fill 0 words at address 220 and verify sentinel `0xDEADBEEF` remains.

### Pass criteria

- Stack pops happen in the correct order.
- `copy_cnt`-like loop counter stops exactly at zero.
- Zero-count case performs no writes.
- `done` is asserted only after `halt`.

---

## Drill 3 - Hard: mixed final-style integration

### Theme

Combine HW4 register discipline with HW5 memory/program discipline.

### Problem

Create a small accelerator called `memsum_axi`:

- AXI4-Lite register `0x00`: control bits
  - bit 0 `start`
  - bit 1 `reset`
- Register `0x04`: source base address in BRAM.
- Register `0x08`: count.
- Register `0x0C`: sum output.
- Register `0x10`: status
  - bit 0 `done`
  - bit 1 `overflow`

Behavior:

- On `start`, read `count` consecutive 32-bit words from BRAM starting at
  source base.
- Accumulate a 32-bit sum.
- Assert `done` when complete.
- Assert `overflow` if unsigned addition wraps.
- Count zero should produce sum zero and done.

### Required deliverables

1. User logic HDL with BRAM read sequencing.
2. Self-checking TB.
3. Register map and software handshake.
4. Vivado BD plan: PS, reset, interconnect, `memsum_axi`.
5. C app that writes BRAM test data, starts the accelerator, polls done,
   and checks sum.
6. Report from `REPORT_TEMPLATE.md`.

### Time box

120 minutes total:

- 35 min RTL/FSM
- 25 min TB
- 25 min packaging/BD plan
- 20 min C app
- 15 min report/evidence

### Minimum validation scenarios

- Sum `[1, 2, 3, 4]` -> `10`.
- Sum `[0xFFFFFFFF, 1]` -> overflow set.
- Count zero -> sum `0`, done set, overflow clear.

### Pass criteria

- No fixed delay in software; poll `done`.
- BRAM read latency is handled explicitly.
- Control/status register behavior is documented.
- Report explains both the data path and the proof.

---

## Self-grading rubric

Score each category 0-2:

- Functionality: behavior matches the problem statement.
- Verification quality: TB is self-checking and covers edge cases.
- Integration reliability: register map, base address, clocks/resets, and
  software agree.
- Evidence quality: screenshots/logs prove correctness quickly.
- Explanation quality: report describes the programming model and one debug
  risk clearly.

Total:

- 9-10: final ready.
- 7-8: mostly ready; repeat the weakest drill.
- 5-6: redo Drill 1 and Drill 2 with stricter timing.
- <=4: revisit HW4/HW5 source and reports before another timed run.
