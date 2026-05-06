# Midterm Practice Drills (HW1 -> HW3 Style)

Use these as timed mock midterms. Each drill is scoped to match the style of your existing work and deliverables.

## Drill 1 - Easy (HW1-style RTL + TB)

### Theme
Pure RTL with self-checking testbench. No PS/PL integration.

### Problem
Design a signed saturating accumulator:

- Input `x`: signed 4-bit
- Output `q`: signed 8-bit
- Control `sclr`: synchronous clear
- On each rising edge:
  - if `sclr='1'`, `q <= 0`
  - else `q <= q + x`, but clamp to `[-128, 127]` if overflow would occur

### Required deliverables

1. User logic VHDL
2. Self-checking testbench
3. Waveform screenshot showing:
   - normal accumulation
   - negative accumulation
   - saturation at both limits
   - clear behavior
4. One short correctness paragraph

### Time box
45 minutes total

- 20 min RTL
- 15 min TB
- 10 min sim + evidence

### Minimum test cases

- `+1` repeated 10 cycles
- `-2` repeated 10 cycles
- force positive saturation
- force negative saturation
- assert/deassert `sclr` mid-stream

### Pass criteria

- Assertions pass with zero errors
- Saturation behavior is correct in both directions
- Evidence is clear and readable

---

## Drill 2 - Medium (HW2-style Zynq GPIO + firmware)

### Theme
PS controls PL registers via AXI4-Lite; firmware prints UART status.

### Problem
Create a simple AXI4-Lite peripheral with 2 registers:

- `REG0` (write): LED pattern byte (lower 4 bits used)
- `REG1` (read): mirror/status register returning current LED pattern

Integrate with Zynq PS so firmware writes patterns and reads back status.

### Required deliverables

1. AXI slave user logic VHDL (or generated shell + custom logic section)
2. Block design screenshot with PS, reset, interconnect, IP
3. C application that:
   - writes at least 8 patterns
   - reads back status each step
   - prints `WROTE=0x.. READ=0x..` over UART
4. Serial output screenshot
5. Register map table (offset, access, meaning)

### Time box
75 minutes total

- 25 min peripheral/register logic
- 30 min BD + bitstream + XSA
- 20 min Vitis app + UART capture

### Minimum validation

- Correct base address used in C code
- Readback matches writes
- UART output has at least 8 passing lines

### Pass criteria

- No BD validation errors
- Firmware runs without hang/timeouts
- Read/write behavior matches register map

---

## Drill 3 - Hard (HW3-style custom compute IP end-to-end)

### Theme
Custom AXI compute IP + packaging + BD + Vitis + runtime verification.

### Problem
Build a moving-sum compute core with AXI registers:

- `CTRL` (write): bit0 `start`, bit1 `sclr`
- `DIN` (write): signed 16-bit input sample
- `WIN` (write): window size `N` (2..16)
- `DOUT` (read): current moving sum
- `STAT` (read): bit0 `done`, bit1 `overflow`

Behavior:
- On `start`, accept `DIN` writes and maintain rolling sum of last `N` samples.
- Set `done` after each update.
- Set `overflow` if internal sum exceeds signed 32-bit range.

### Required deliverables

1. User logic HDL + AXI wrapper
2. Self-checking TB covering:
   - warm-up phase (< N samples)
   - steady-state moving sum
   - clear/restart
   - overflow stimulus
3. IP packaging evidence (metadata and interface correctness)
4. Block design screenshot and address assignment
5. C app that streams sample vectors and checks expected sums
6. UART screenshot with summary (`passed/failed`)
7. Short debug note on one issue encountered and resolved

### Time box
110 minutes total

- 35 min core + AXI register behavior
- 20 min TB + simulation evidence
- 25 min package + BD + bitstream
- 20 min Vitis app + run
- 10 min report assembly

### Minimum validation vectors

- Vector A: `1,2,3,4,5` with `N=3` -> expected sums `1,3,6,9,12`
- Vector B: `-2,-2,5,1` with `N=2` -> expected sums `-2,-4,3,6`
- Vector C: reset in middle, then repeat Vector A

### Pass criteria

- TB self-check passes all vectors
- Hardware run matches software reference on at least 10 samples
- Done/overflow flags behave as documented

---

## Scoring rubric for self-grading (all drills)

Score each category 0-2:

- **Functionality**: Does it behave correctly?
- **Verification quality**: Are tests meaningful and self-checking?
- **Integration reliability**: Clean BD, correct addressing, stable run.
- **Evidence quality**: Screenshots/logs prove correctness quickly.
- **Time discipline**: Finished inside the target time box.

Total:

- 9-10: midterm ready
- 7-8: mostly ready; repeat hard drill once
- 5-6: redo medium + hard with stricter timing
- <=4: revisit fundamentals (Drill 1 twice before integration work)

## Suggested weekly cycle

- Day 1: Drill 1
- Day 2: Drill 2
- Day 3: Drill 3
- Day 4: Review mistakes + re-run weakest drill
