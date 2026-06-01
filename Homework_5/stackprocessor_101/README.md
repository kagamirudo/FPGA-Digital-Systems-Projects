# Homework 5 - Stack Processor 101 + `scpb` block-copy

Zynq PS + PL implementation on the Digilent Cora Z7-07S.  A custom
AXI4-Lite IP (`sp101_axi`) wraps the assignment PDF's Stack Processor 101
(`user_logic`) extended with a brand-new machine instruction `scpb`
("**s**tack **c**o**p**y **b**lock"): pop `number_of_data`, source
address and destination address from the stack and copy `number_of_data`
consecutive 32-bit words from `source` to `dest`.

Reference: `Homework_5/stackprocessor_101_copy_instruction.pdf` and
`Homework_5/prob.md`.

## Repository layout

Canonical **source** lives under `stackprocessor_101/`.  **Tool
projects** (Vivado, Vitis) and the **packaged IP** sit in sibling
directories under `Homework_5/` or at the repo root so they can be
regenerated without touching RTL.

```
ECEC661/
  ip_repo/
    sp101_axi_1.0/                       # packaged IP (after Re-Package IP)
      component.xml
      src/                               # copy of RTL + blk_mem_gen ref
      xgui/
  Homework_5/
    prob.md                              # assignment one-pager
    stackprocessor_101_copy_instruction.pdf
    stackprocessor_101/                  # *** source tree (edit here) ***
      README.md                          # this file
      rtl/
        bus_ip_mem_bridge.vhd            # bus/IP -> BRAM port mux
        user_logic.vhd                   # sp101 core + scpb FSM
        sp101_axi_v1_0_S00_AXI.vhd       # AXI4-Lite slave (5 regs)
        sp101_axi_v1_0.vhd               # IP top wrapper
      tb/
        tb_user_logic.vhd                # self-checking TB (VHDL-2008)
      sw/
        main.c                           # bare-metal test (copy into Vitis)
      docs/
        register_map.md                  # registers, opcodes, scpb micro-steps
      scripts/
        setup.tcl                        # Vivado: blk_mem_gen + add sources
        package.tcl                      # IP packager metadata + sub-core ref
      workspace/                         # Vitis Unified workspace (local)
        platform/                        # from exported XSA
        sp101/                           # application (main.c synced from sw/)
    sp101/                               # Vivado project (generated)
      sp101.xpr
      sp101.srcs/sources_1/bd/sp101/     # block design sp101.bd
      sp101_wrapper.xsa                  # export for Vitis platform
      tb_user_logic_behav.wcfg           # saved xsim wave config
      sp101.sim/                         # xsim run directory
    report/
      report.tex / report.pdf
      figures/
        diagram.png                      # Vivado BD screenshot
        sim.png                          # xsim full-run waveform
        vitis.png                        # UART 3/3 PASS capture
```

### What to edit vs. regenerate

| You want to change…              | Edit here                         | Then… |
|----------------------------------|-----------------------------------|-------|
| Processor / `scpb` FSM           | `rtl/user_logic.vhd`              | Re-sim; re-package IP if BD uses packaged core |
| AXI registers / slave            | `rtl/sp101_axi_v1_0_S00_AXI.vhd`  | Same |
| Simulation tests                 | `tb/tb_user_logic.vhd`            | `launch_simulation` in `sp101.xpr` |
| On-board test                    | `sw/main.c`                       | Copy into `workspace/sp101/` (or replace `src`), rebuild app |
| Register / opcode documentation  | `docs/register_map.md`            | Keep in sync with `user_logic.vhd` |
| Write-up                         | `../report/report.tex`            | `pdflatex` in `report/` |

Do **not** treat `sp101/` cache/runs or `workspace/` build trees as source of
truth—they are outputs.  After RTL changes, refresh the packaged IP under
`ip_repo/sp101_axi_1.0/` (or point Vivado at `stackprocessor_101/rtl`
directly until you re-package).

### Deliverables map

| Deliverable (from `prob.md`)              | Artifact |
|-------------------------------------------|----------|
| User logic – sp101 + `scpb`             | `rtl/user_logic.vhd`, `rtl/bus_ip_mem_bridge.vhd` |
| Simulation for correctness              | `tb/tb_user_logic.vhd` + `report/figures/sim.png` |
| IP packaging of sp101                   | `ip_repo/sp101_axi_1.0/` + `scripts/package.tcl` |
| Testbench, test app, proof on board       | `tb/tb_user_logic.vhd`, `sw/main.c`, `report/figures/vitis.png` |
| Block design (report)                   | `sp101.bd` in Vivado + `report/figures/diagram.png` |

## Programming model for `scpb`

The instruction pops three arguments (top of stack last):

```
sc dest_addr   sc source_addr   sc number_of_data   scpb   halt
```

After execution, `memory[source_addr .. source_addr+count-1]` has been
copied into the contiguous block at `memory[dest_addr ..
dest_addr+count-1]`.

Opcodes (must match `user_logic.vhd` and `docs/register_map.md`):

| Mnemonic | Hex          |
|----------|--------------|
| `halt`   | `0x000000FF` |
| `sc`     | `0x00000001` |
| `sl`     | `0x00000011` |
| `ss`     | `0x00000021` |
| `sadd`   | `0x00000031` |
| `scp`    | `0x00000101` |
| `scpb`   | `0x00000201` |

## 1. Set up the Vivado project

1. Open (or create) `Homework_5/sp101/sp101.xpr` in Vivado 2025.2 with the
   Cora Z7-07S part `xc7z007sclg400-1`.
2. Point the Tcl console at the **source** scripts (not inside `sp101/`):

   ```tcl
   cd /path/to/ECEC661/Homework_5/stackprocessor_101
   source scripts/setup.tcl
   ```

   If `setup.tcl` is already wired into the project, you can instead:

   ```tcl
   cd [file dirname [get_property DIRECTORY [current_project]]]
   # only if scripts/ was copied or linked into sp101/
   source scripts/setup.tcl
   ```

   The script:

   - generates `blk_mem_gen_0` (1024×32, single port, `Use_ENA_Pin` true),
   - adds the four RTL files to Design Sources and the TB to Simulation Sources,
   - sets VHDL-2008 on the TB,
   - sets simulation top to `tb_user_logic`.

   Re-running is idempotent.

## 2. Simulate the user logic

1. Flow Navigator → **Run Simulation** → **Run Behavioral Simulation**.
2. In the simulator Tcl console: `run all`.  The TB runs three scenarios
   (count = 3, 1, 0) and prints one `[PASS]` per destination word:

   ```
   +--------------------------------------------------+
   |    sp101 + scpb  block-copy testbench summary    |
   +--------------------------------------------------+
      checks executed : 5
      errors          : 0
   +--------------------------------------------------+

   ####################################################
   ##        TESTBENCH  PASSED  -  all cases ok      ##
   ####################################################
   ```

3. For the report waveform (`report/figures/sim.png`), use the saved config
   or paste:

   ```tcl
   add_wave /tb_user_logic/ck /tb_user_logic/reset_sig /tb_user_logic/run_sig
   add_wave /tb_user_logic/bus2mem_en /tb_user_logic/bus2mem_we
   add_wave -radix unsigned /tb_user_logic/bus2mem_addr
   add_wave -radix hex /tb_user_logic/bus2mem_data_in
   add_wave -radix hex /tb_user_logic/sp2bus_data_out
   add_wave /tb_user_logic/done_sig
   add_wave /tb_user_logic/dut/n_s
   add_wave -radix hex /tb_user_logic/dut/ir
   add_wave -radix unsigned /tb_user_logic/dut/copy_src
   add_wave -radix unsigned /tb_user_logic/dut/copy_dst
   add_wave -radix unsigned /tb_user_logic/dut/copy_cnt
   add_wave -radix unsigned /tb_user_logic/checks
   add_wave -radix unsigned /tb_user_logic/errors
   restart
   run all
   ```

   Zoom out so the full run is visible: `checks` should reach **5** and
   `errors` stay **0** across all three scenarios.

## 3. Package the IP

1. **Tools → Create and Package New IP** → *Package your current project*.
2. Set the IP location to the **repo-root** catalog (recommended):

   ```
   ECEC661/ip_repo/sp101_axi_1.0
   ```

   (Same layout as Homework 3/4 IPs under `ECEC661/ip_repo/`.)

3. In the packager Tcl console:

   ```tcl
   cd /path/to/ECEC661/Homework_5/stackprocessor_101
   source scripts/package.tcl
   ```

4. **Review and Package → Re-Package IP**, then close the packager.
5. In `sp101.xpr`: **Settings → IP → Repository** → add
   `../../ip_repo/sp101_axi_1.0` (relative to `Homework_5/sp101/`) or the
   absolute path to `ECEC661/ip_repo/sp101_axi_1.0`.

## 4. Build the block design

1. Block design `sp101` in `sp101.srcs/sources_1/bd/sp101/sp101.bd`.  IP
   instances:
   - `ZYNQ7 Processing System` (Cora preset: UART0 MIO 14/15, DDR, FCLK_CLK0
     100 MHz)
   - `Processor System Reset`
   - `AXI Interconnect` (1S / 1M)
   - `sp101_axi_0` from `ip_repo`
2. **Run Connection Automation** on the green banner.
3. Data path: `M_AXI_GP0` → `S00_AXI` → `sp101_axi_0.s00_axi`.
4. **Address Editor**: `sp101_axi_0` at offset **`0x43C3_0000`**, range **4K**
   (`XPAR_SP101_AXI_0_S00_AXI_BASEADDR` in `sw/main.c`).
5. Validate → Generate Output Products → Create HDL Wrapper → set top
   `sp101_wrapper` → bitstream → **Export Hardware (include bitstream)** →
   `sp101_wrapper.xsa`.

## 5. Build the software in Vitis Unified 2025.2

1. Workspace: `stackprocessor_101/workspace/` (already present) or create a
   new one beside this tree.
2. **Create Platform Component** from `Homework_5/sp101/sp101_wrapper.xsa`;
   domain `standalone` on `ps7_cortexa9_0`.
3. **Create Application Component** (`sp101`); use `Empty Application` or
   Hello World.
4. **Source of truth for C** is `sw/main.c`—copy or symlink into the app
   (`workspace/sp101/src/` or replace `main.c` at app root).
5. BSP: `standalone_stdin` / `standalone_stdout` → `ps7_uart_0`, then
   **Regenerate BSP**.
6. Build platform, then build `sp101`.

**SW-only fix (no new bitstream):** if you only changed `sw/main.c` (e.g.
the `mem_read()` reset gotcha below), rebuild the app and re-run; the
existing `.bit` is enough.

## 6. Run and capture serial output

1. USB-UART on Cora Z7-07S (Linux: often `/dev/ttyUSB1` = UART,
   `/dev/ttyUSB0` = JTAG).
2. Open the serial monitor **before** Run:

   ```bash
   picocom /dev/ttyUSB1 -b 115200 --imap lfcrlf
   ```

3. Expected output (also in `report/figures/vitis.png`):

   ```
   ---- Scenario: scpb count=3 (multi-word) ----
     ...
     RESULT: PASS

   ---- Scenario: scpb count=1 (single word) ----
     ...
     RESULT: PASS

   ---- Scenario: scpb count=0 (no-op) ----
     ...
     RESULT: PASS

   ----------------------------------------------------------
      Summary : 3/3 scenarios PASSED
   ----------------------------------------------------------
   ```

4. Screenshot for `Homework_5/report/figures/vitis.png`.

## Design notes

- **Stack convention.** `scpb` matches `sc dest sc source sc count scpb`:
  count on top, then source, then dest.  The FSM pops into `copy_cnt`,
  `copy_src`, `copy_dst`.
- **Latency model.** Extra micro-states (`fetch3`, `scpb4`, `scpb_r1`…)
  align the BRAM + `mem_data_out` pipeline with the assignment PDF.  A
  two-register `mem_data_out` chain (`douta` → `mem_data_out_pre` →
  `mem_data_out`) matches timing when `blk_mem_gen_0` has no output register.
- **Cycle cost.** Roughly `6·N + 8` clocks for an `N`-word block; see
  `docs/register_map.md`.
- **Base address `0x43C3_0000`** is one 64 KB slot above HW4
  `cordic_sqrt_axi` at `0x43C2_0000`.
- **Driver gotcha (`sw/main.c`).** Do **not** hold `CTRL_RESET` during
  `mem_read()`.  While `reset='1'`, the read pipeline in `user_logic` was
  originally cleared every cycle, so every dump read returned
  `0x00000000`.  Pulse reset only in `processor_reset()`; use
  `CTRL_BUS_EN` (and `CTRL_BUS_WE` for writes) for bus access.  The RTL
  `p_mdo` process no longer zero-clears on reset as a belt-and-braces fix
  if you rebuild the bitstream.

## Report

LaTeX write-up: `Homework_5/report/report.tex` → `report.pdf`.  Figures
under `report/figures/` (`diagram.png`, `sim.png`, `vitis.png`).  Build:

```bash
cd Homework_5/report
pdflatex report.tex
pdflatex report.tex   # second pass for references
```
