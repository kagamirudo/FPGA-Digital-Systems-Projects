# Quiz 2

Quiz 2 preparation now focuses on custom IP: user logic, IP packaging, block
diagram integration, and XSA export.  No Vitis app or physical board is needed.

| Folder | Purpose |
|--------|---------|
| [practice/](practice/) | Custom stack user logic + AXI IP packaging/XSA practice |
| [real/](real/) | Graded quiz problem + [submit/](real/submit/) hand-in |

## Quick Start

**Practice**

1. Create an RTL Vivado project under `Quiz_2/practice/` named `quiz2_practice`
   (part `xc7z007sclg400-1` or any Zynq-7000 part).
2. In the Tcl console: `source scripts/setup.tcl`
3. Run behavioral simulation; expect `[PASS]` lines and the summary banner.
4. Package `stack_practice_axi`, build a Zynq block diagram, and export
   `xsa/stack_practice.xsa` following [practice/README.md](practice/README.md).

**Real**

1. Open or create `Quiz_2/real/q2_real/q2_real.xpr` (or follow the manual steps
   in [real/README.md](real/README.md)).
2. `source scripts/setup.tcl` from the `real/` folder parent.
3. Simulate, capture wave snip, update [real/submit/](real/submit/).

Vivado-generated trees (`.cache/`, `.sim/`, `.gen/`, `*.xpr`, …) stay
gitignored; regenerate from each folder's `scripts/setup.tcl`.
