# Homework 3 - Problem 8.7.2 Fixed-Point Accumulator IP Catalog Test App

Zynq PS + PL implementation on the Digilent Cora Z7-07S. A custom
AXI4-Lite IP (`fix_acc_axi`) wraps the Vivado IP-Catalog Accumulator
(`xilinx.com:ip:c_accum:12.0`). Each AXI write advances the accumulator
by one step (the slave's `slv_reg_wren` is wired straight to the
accumulator's `CLK`). A bare-metal C application running on the PS drives
it and prints results over UART0 (FT2232HQ USB-UART bridge).

## Layout

```
Homework_3/fix_acc/
  rtl/
    fix_acc_core.vhd              - thin wrapper around c_accum_0
    fix_acc_axi_v1_0_S00_AXI.vhd  - AXI4-Lite slave (3 regs + reserved)
    fix_acc_axi_v1_0.vhd          - IP top, wires slave through
  tb/
    tb_fix_acc_core.vhd           - self-checking testbench (VHDL-2008)
  sw/
    main.c                        - Vitis bare-metal test app (UART)
  docs/
    register_map.md               - offsets, bit fields, handshake, flush
  scripts/
    setup.tcl                     - Vivado: generate IP + add sources
    package.tcl                   - IP packager: metadata + sub-core ref
  fix_acc.xpr                     - Vivado project
```

Deliverables map to this tree:

| Deliverable | File |
|-------------|------|
| User logic HDL code           | `rtl/*.vhd` |
| Test bench                    | `tb/tb_fix_acc_core.vhd` |
| Block-diagram snip            | from Vivado (`bd/fix_acc.bd`) |
| Test application C code       | `sw/main.c` |
| PuTTY / serial-monitor snip   | captured at run-time |
| Packaged IP + sub-core ref    | `ip_repo/fix_acc_axi_1.0/` + screenshot |
| TB waveform (book Fig 8.7.3)  | screenshot from Vivado xsim |

## 1. Set up the Vivado project

1. Open `fix_acc.xpr` in Vivado 2025.2.
2. In the Tcl console:

   ```tcl
   cd [file dirname [get_property DIRECTORY [current_project]]]
   source scripts/setup.tcl
   ```

   That script:
   - generates the IP-Catalog block `c_accum_0` (Accumulator v12.0,
     32-bit B, 32-bit Q, signed, SCLR enabled, CE disabled, latency 1),
   - adds the three RTL files to Design Sources and the TB to Simulation
     Sources,
   - sets file types (VHDL for RTL so the packager is happy; VHDL 2008 for
     the TB because it needs `std.textio.LF`),
   - sets the simulation top to `tb_fix_acc_core`.

   It is idempotent; re-running is safe. Each `CONFIG.*` on `c_accum_0`
   is applied inside a `catch`, so if a future Vivado release renames or
   removes one of the parameters the script prints a single
   `(warn) could not set CONFIG.X = Y` line instead of aborting the
   whole flow. Once it finishes it dumps the effective `CONFIG.*` for
   `c_accum_0` so mismatches are easy to eyeball.

   If a previous run failed mid-configuration (e.g. an unknown
   `CONFIG.*` name) and left `c_accum_0` in a half-configured state,
   force a clean rebuild with:

   ```tcl
   set ::env(FIX_ACC_FORCE_IP) 1
   source scripts/setup.tcl
   unset ::env(FIX_ACC_FORCE_IP)
   ```

## 2. Simulate the core

1. Flow Navigator -> *Run Simulation* -> *Run Behavioral Simulation*.
2. In the simulator Tcl console type `run all` (or `run 1000 ns`). The TB
   runs 11 self-checks and emits individual `[PASS] ... Q=<n>` lines,
   followed by a summary and banner:

   ```
   [PASS] post-SCLR reset  Q=0
   [PASS] B=1 step 1  Q=1
   [PASS] B=1 step 2  Q=2
   [PASS] B=1 step 3  Q=3
   [PASS] B=1 step 4  Q=4
   [PASS] B=-2 step 1  Q=2
   [PASS] B=-2 step 2  Q=0
   [PASS] B=-2 step 3  Q=-2
   [PASS] B=-2 step 4  Q=-4
   [PASS] mid-stream SCLR  Q=0
   [PASS] Sigma(1..10)  Q=55

   +--------------------------------------------------+
   |          fix_acc_core - test summary             |
   +--------------------------------------------------+
      checks executed : 11
      errors          : 0
   +--------------------------------------------------+

   ####################################################
   ##                                                ##
   ##        TESTBENCH  PASSED  -  all cases ok      ##
   ##                                                ##
   ####################################################
   ```

   On failure the TB raises a `severity failure` with the error count so
   the sim also ends (abnormally), which is the signal `launch_simulation`
   reports back to regression scripts.

3. The stimulus process ends with a plain `wait;` (not `std.env.stop` or
   `std.env.finish`), which means Vivado will **not** jump the source
   window to a "stop" line when the run completes - the banner is the
   last thing the user sees and the editor stays put. The simulator does
   continue idling until whatever time budget you gave the `run` command
   elapses, which is harmless.

4. To reproduce the book's Fig 8.7.3 waveform, in the wave pane paste:

   ```tcl
   add_wave /tb_fix_acc_core/clk /tb_fix_acc_core/sclr
   add_wave -radix signed /tb_fix_acc_core/b /tb_fix_acc_core/q
   restart
   run all
   ```

   Save the layout (Vivado writes `tb_fix_acc_core_behav.wcfg`) and
   screenshot the 1, 2, 3, 4 / 2, 0, -2, -4 window for the report.

## 3. Package the IP

1. *Tools -> Create and Package New IP*.
2. Choose *Package your current project*; set the IP location to
   `Homework_3/fix_acc/ip_repo/fix_acc_axi_1.0`.
3. Once the packager project is open, run:

   ```tcl
   source scripts/package.tcl
   ```

   That script sets:
   - identification (name `fix_acc_axi`, display name, description, etc.),
   - the **sub-core reference** `xilinx.com:ip:c_accum:12.0` under both
     VHDL Synthesis and VHDL Simulation file groups (book p. 445),
   - `FREQ_HZ`, `ASSOCIATED_BUSIF`, `ASSOCIATED_RESET` on `s00_axi_aclk`.
4. *Review and Package* -> *Re-Package IP*. The usual `19-11888`,
   `19-896`, `19-11770`, `19-7067` warnings should all be cleared.
5. Close the packager project; reopen `fix_acc.xpr`.
6. *Settings -> IP -> Repository* -> add `ip_repo/fix_acc_axi_1.0`.

## 4. Build the block design (`bd/fix_acc.bd`)

1. Create block design `fix_acc`. Add:
   - `ZYNQ7 Processing System`
     - Apply the Cora Z7-07S board preset if available; otherwise
       enable **UART0 on MIO 14/15**, DDR, and FCLK_CLK0 at 100 MHz
       manually. The same warning applies as for `fib_gen`: the Cora
       Z7-07S USB-UART bridges to UART0, not UART1.
   - `Processor System Reset`
   - **`AXI Interconnect`** with *Number of Slave Interfaces* = `1`
     and *Number of Master Interfaces* = `1`. Make sure you pick the
     plain `AXI Interconnect` (VLNV `xilinx.com:ip:axi_interconnect`),
     not the lookalike **`AXI4-Stream Interconnect`** (VLNV ends in
     `axis_interconnect`). The streaming variant has `S00_AXIS_*` /
     `M00_AXIS_*` pins and is incompatible with AXI4-Lite slaves;
     `Validate Design` will fail with
     `[BD 41-758] ... /axis_interconnect_0/S00_AXIS_ACLK` if you grab
     the wrong one.
   - `fix_acc_axi` (our IP, from the repo).
2. **Clocks and resets.** The easy way is to click *Run Connection
   Automation* in the green banner at the top of the canvas and tick
   every port Vivado lists; that produces exactly the wiring below. If
   you'd rather wire by hand, the target topology is:

   | Source                                         | Destination(s)                                                                              |
   |------------------------------------------------|---------------------------------------------------------------------------------------------|
   | `processing_system7_0.FCLK_CLK0`               | every `aclk` (PS `M_AXI_GP0_ACLK`, interconnect `ACLK` / `S00_ACLK` / `M00_ACLK`, `fix_acc_axi_0.s00_axi_aclk`, `proc_sys_reset_0.slowest_sync_clk`) |
   | `processing_system7_0.FCLK_RESET0_N`           | `proc_sys_reset_0.ext_reset_in`                                                             |
   | `proc_sys_reset_0.interconnect_aresetn`        | `axi_interconnect_0.ARESETN`                                                                |
   | `proc_sys_reset_0.peripheral_aresetn`          | `axi_interconnect_0.S00_ARESETN`, `axi_interconnect_0.M00_ARESETN`, `fix_acc_axi_0.s00_axi_aresetn` |

   **Note**: If Vivado dropped in an *AXI SmartConnect* instead of a
   classic *AXI Interconnect*, that block has no `interconnect_aresetn`
   / `S00_ARESETN` / `M00_ARESETN` trio - it exposes a single `aresetn`
   pin that you drive from `proc_sys_reset_0.peripheral_aresetn` and
   you ignore `interconnect_aresetn` entirely.

3. **Data paths.**

   | Source                                  | Destination                     |
   |-----------------------------------------|---------------------------------|
   | `processing_system7_0.M_AXI_GP0`        | `axi_interconnect_0.S00_AXI`    |
   | `axi_interconnect_0.M00_AXI`            | `fix_acc_axi_0.s00_axi`         |

4. **Address Editor.** Tab is next to *Diagram* on the BD canvas (or
   *Window -> Address Editor* if it's hidden). Assign the peripheral:

   1. Expand `processing_system7_0 -> Data -> Unassigned Master
      Interfaces`. You should see `fix_acc_axi_0 / S00_AXI` listed.
   2. Either:
      - Click **Assign All** in the Address Editor toolbar (fastest), or
      - right-click `fix_acc_axi_0 / S00_AXI` -> **Assign** and let
        Vivado pick a default, then edit the row.
   3. Set **Offset Address** = `0x43C1_0000`, **Range** = `4K`.

   After assignment the row should read
   `0x43C1_0000 - 0x43C1_0FFF`, and it will move out of the
   *Unassigned* folder into the main map. This is the same
   `XPAR_FIX_ACC_AXI_0_BASEADDR` that `sw/main.c` uses.

   Why `0x43C10000` and not `0x43C00000`? Zynq's general-purpose
   slave window starts at `0x43C00000`; `fib_axi` from the previous
   homework problem sits at `0x43C00000`, so placing
   `fix_acc_axi @ 0x43C10000` (next 64 KB aperture) lets both IPs
   coexist on the same PL image later.

5. *Validate Design*. *Generate Output Products*. *Create HDL Wrapper*.
6. **Set the wrapper as the top module.**
   ```tcl
   set_property TOP fix_acc_wrapper [current_fileset]
   update_compile_order -fileset sources_1
   ```
7. Synthesis -> Implementation -> Generate Bitstream.
8. *File -> Export -> Export Hardware* with *Include bitstream* -> writes
   `fix_acc_wrapper.xsa`.

Capture a screenshot of the block design for the report.

## 5. Build the software in Vitis Unified 2025.2

1. Launch Vitis Unified 2025.2 and create a workspace (for example
   `fix_acc/workspace`).
2. *Create Platform Component* from the XSA. Pick the `standalone`
   domain on `ps7_cortexa9_0`.
3. *Create Application Component* on that platform using
   `Empty Application (C)` or `Hello World`.
4. Replace the generated `helloworld.c` with `sw/main.c`.
5. **Configure the BSP stdin/stdout**:
   - In the Vitis Explorer, open
     `platform -> ps7_cortexa9_0 -> standalone_ps7_cortexa9_0 -> BSP -> standalone`.
   - Set `standalone_stdin` and `standalone_stdout` to `ps7_uart_0`
     (Cora Z7-07S default).
   - Click **Regenerate BSP**.
   - Verify `bsp/include/bspconfig.h` contains
     `#define XPAR_STDIN_IS_UARTPS` and `#define STDOUT_BASEADDRESS 0xe0000000`.
6. Build the platform, then build the `fix_acc` application.

## 6. Run and capture serial output

### 6.1 Run configuration

| Setting              | Value |
|----------------------|-------|
| Target Connection    | Local [default] |
| Target Setup Mode    | Baremetal Debug |
| Device               | Auto Detect |
| Bitstream File       | `${workspaceFolder}/fix_acc/_ide/bitstream/fix_acc_wrapper.bit` |
| Board Initialization | TCL |
| Initialization file  | `${workspaceFolder}/fix_acc/_ide/psinit/ps7_init.tcl` |
| Run ps7_init         | checked |
| Run Ps7 Post Init    | checked |
| Reset Entire System  | checked |
| Reset APU            | checked |
| Program Device       | checked |

### 6.2 Serial monitor

1. Connect the Cora Z7-07S over USB-UART. Typical Linux nodes:
   `/dev/ttyUSB0` (JTAG) and `/dev/ttyUSB1` (UART).
2. **Attach the serial monitor *before* clicking Run.** The app finishes
   in well under a second after the 3 s startup window.

   ```bash
   picocom /dev/ttyUSB1 -b 115200 --imap lfcrlf
   ```

3. Expect:
   - 3 s startup countdown,
   - header with base address,
   - the book-style `slv_reg0` / `Q` table (rows for `slv_reg0 = 0..9`),
   - `Last output, latency = 1: Q = 500500`,
   - self-check rows: `Sigma(1..10) = 55`, `Sigma(1..100) = 5050`,
     `Sigma(1..1000) = 500500`, `B=-2 four times = -8`,
     `SCLR mid-stream = 0`,
   - `Summary : 5 passed, 0 failed`.
4. Screenshot the serial monitor for the report.

## Expected hardware results (for reference)

| slv_reg0 | Q (expected) |
|---------:|-------------:|
| 0 | 0 |
| 1 | 0 |
| 2 | 1 |
| 3 | 3 |
| 4 | 6 |
| 5 | 10 |
| 6 | 15 |
| 7 | 21 |
| 8 | 28 |
| 9 | 36 |
| flush (B = 0) after writing 1..1000 | 500,500 |

## Design notes

- **The `slv_reg_wren`-as-CLK trick.** Every write (regardless of the
  target register) pulses `slv_reg_wren` for one aclk, which is what
  drives the accumulator. Writes to `CTRL` with `SCLR = 1` still pulse
  `CLK`, but the IP gives SCLR priority over add, so Q is zeroed.
- **Latency = 1.** After writing `B_IN = x`, the subsequent `Q_OUT` read
  returns the previous step's accumulation. To observe the final sum,
  issue one extra dummy write (any value) before the last read. Book
  p. 447 uses `B = 0` for this flush.
- **`slv_reg1` (Q_OUT) is not software writable** by design; its AXI
  read mux returns the accumulator's live `Q`, and the write decoder
  in `fix_acc_axi_v1_0_S00_AXI.vhd` has no `"01"` case. A stray write
  to offset `0x04` has no effect.
- **Base address `0x43C10000`**, not `0x43C00000`, so `fib_axi` and
  `fix_acc_axi` can both live on the same block design if desired.

## TB coverage

The 11 self-checks in `tb_fix_acc_core.vhd` split into three groups:

| # | Tag                   | Purpose                                     |
|---|-----------------------|---------------------------------------------|
| 1 | `post-SCLR reset`     | After initial `SCLR` pulse, `Q = 0`         |
| 2 | `B=1 step 1..4`       | Book Fig 8.7.3: `Q = 1, 2, 3, 4`            |
| 3 | `B=-2 step 1..4`      | Book Fig 8.7.3: `Q = 2, 0, -2, -4`          |
| 4 | `mid-stream SCLR`     | `SCLR` asserted mid-run clears `Q` to 0     |
| 5 | `Sigma(1..10)`        | Cross-check with software: `Q = 55`         |

Check 4 must be sampled in the *same* cycle as the `SCLR` clock edge.
The c_accum core has `latency = 1` and unconditionally commits one
operation per rising edge (clear if `SCLR`, accumulate if not), so
waiting an extra cycle after dropping `SCLR` re-accumulates `B` into a
non-zero value. The TB therefore samples `Q` at `(edge + 1 ns)`, then
drives `B <= 0` before releasing `SCLR`.
