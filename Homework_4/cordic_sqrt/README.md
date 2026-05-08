# Homework 4 - CORDIC Square Root IP

Zynq PS + PL implementation on the Digilent Cora Z7-07S.  A custom
AXI4-Lite IP (`cordic_sqrt_axi`) wraps the Vivado IP-Catalog CORDIC
block (`xilinx.com:ip:cordic:6.0`) configured for the **Square Root**
function.  Software pushes 10-bit 2Q7 samples into `slv_reg0`, raises
`din_tvalid` in `slv_reg1`, polls `dout_tvalid` in `slv_reg3`, and reads
back the 1Q8 square root from `slv_reg2`.  A bare-metal C application
running on the PS drives it and prints results over UART0.

## Layout

```
Homework_4/cordic_sqrt/
  rtl/
    user_logic.vhd                       - assignment entity; wraps cordic_0
    cordic_sqrt_axi_v1_0_S00_AXI.vhd     - AXI4-Lite slave (4 regs)
    cordic_sqrt_axi_v1_0.vhd             - IP top, wires slave through
  tb/
    tb_user_logic.vhd                    - self-checking testbench (VHDL-2008)
  sw/
    main.c                               - Vitis bare-metal test app (UART)
  docs/
    register_map.md                      - offsets, bit fields, handshake
  scripts/
    setup.tcl                            - Vivado: generate IP + add sources
    package.tcl                          - IP packager: metadata + sub-core ref
```

Deliverables map to this tree:

| Deliverable                                  | File                                                    |
|----------------------------------------------|---------------------------------------------------------|
| User logic HDL code (3 pts)                  | `rtl/user_logic.vhd`                                    |
| User logic simulation (part of 3 pts)        | `tb/tb_user_logic.vhd` + xsim waveform screenshot       |
| Custom IP slv_reg mapping snippets (2 pts)   | `rtl/cordic_sqrt_axi_v1_0_S00_AXI.vhd`, `docs/register_map.md` |
| Block diagram (part of 5 pts)                | screenshot from Vivado (`bd/cordic_sqrt.bd`)            |
| Test app C code (part of 5 pts)              | `sw/main.c`                                             |
| PuTTY result snip (part of 5 pts)            | captured at run-time on Cora Z7-07S                     |

## 1. Set up the Vivado project

1. Open (or create) `cordic_sqrt.xpr` in Vivado 2025.2 with the Cora
   Z7-07S as the target part (`xc7z007sclg400-1`).
2. In the Tcl console:

   ```tcl
   cd [file dirname [get_property DIRECTORY [current_project]]]
   source scripts/setup.tcl
   ```

   That script:
   - generates the IP-Catalog block `cordic_0` (CORDIC v6.0 - Square Root,
     Parallel architecture, Maximum pipelining, UnsignedFraction, 10-bit
     input/output, Truncate rounding),
   - adds the three RTL files to Design Sources and the TB to Simulation
     Sources,
   - sets file types (VHDL for RTL so the packager is happy; VHDL 2008 for
     the TB because it uses `to_hstring()` and `LF`),
   - sets the simulation top to `tb_user_logic`.

   It is idempotent; re-running is safe.  Each `CONFIG.*` on `cordic_0`
   is applied inside a `catch`, so unknown parameter names print a single
   `(warn) could not set CONFIG.X = Y` line instead of aborting.

   If a previous run failed mid-configuration, force a clean rebuild
   with:

   ```tcl
   set ::env(CORDIC_SQRT_FORCE_IP) 1
   source scripts/setup.tcl
   unset ::env(CORDIC_SQRT_FORCE_IP)
   ```

## 2. Simulate the user logic

1. Flow Navigator -> *Run Simulation* -> *Run Behavioral Simulation*.
2. In the simulator Tcl console type `run all` (or `run 1 us`).  The TB
   walks the assignment's stimulus sequence and emits one `[PASS]` line
   per test vector followed by a banner:

   ```
   [PASS] sqrt(0x080) = 0x100
   [PASS] sqrt(0x040) = 0x0b5
   [PASS] sqrt(0x008) = 0x040
   [PASS] sqrt(0x000) = 0x000

   +--------------------------------------------------+
   |         user_logic - cordic sqrt summary         |
   +--------------------------------------------------+
      checks executed : 4
      errors          : 0
   +--------------------------------------------------+

   ####################################################
   ##                                                ##
   ##        TESTBENCH  PASSED  -  all cases ok      ##
   ##                                                ##
   ####################################################
   ```

3. To reproduce the assignment's Fig. 3 waveform, in the wave pane paste:

   ```tcl
   add_wave /tb_user_logic/ck /tb_user_logic/aresetn /tb_user_logic/din_tvalid
   add_wave -radix hex /tb_user_logic/x
   add_wave /tb_user_logic/dout_tvalid
   add_wave -radix hex /tb_user_logic/z
   restart
   run all
   ```

   Save the layout and screenshot the window so the report shows reset
   release, the `0x80 / 0x40 / 0x08 / 0x00` input run, and the
   `0x100 / 0x0B5 / 0x040 / 0x000` output run when `dout_tvalid` is
   high.

## 3. Package the IP

1. *Tools -> Create and Package New IP*.
2. Choose *Package your current project*; set the IP location to
   `Homework_4/cordic_sqrt/ip_repo/cordic_sqrt_axi_1.0`.
3. Once the packager project is open, run:

   ```tcl
   source scripts/package.tcl
   ```

   That script sets:
   - identification (name `cordic_sqrt_axi`, display name, description, etc.),
   - the **sub-core reference** `xilinx.com:ip:cordic:6.0` under both
     VHDL Synthesis and VHDL Simulation file groups,
   - `FREQ_HZ`, `ASSOCIATED_BUSIF`, `ASSOCIATED_RESET` on `s00_axi_aclk`.

4. *Review and Package* -> *Re-Package IP*.  The usual `19-11888`,
   `19-896`, `19-11770`, `19-7067` warnings should all be cleared.
5. Close the packager project; reopen `cordic_sqrt.xpr`.
6. *Settings -> IP -> Repository* -> add `ip_repo/cordic_sqrt_axi_1.0`.

## 4. Build the block design (`bd/cordic_sqrt.bd`)

1. Create block design `cordic_sqrt`.  Add:
   - `ZYNQ7 Processing System`
     - Apply the Cora Z7-07S board preset if available; otherwise enable
       **UART0 on MIO 14/15**, DDR, and FCLK_CLK0 at 100 MHz manually.
   - `Processor System Reset`.
   - `AXI Interconnect` (or SmartConnect) - 1 slave, 1 master.
   - `cordic_sqrt_axi` (our IP, from the repo).

2. *Run Connection Automation* on the green banner; tick every entry
   it lists.  The resulting wiring will be:

   | Source                                         | Destination(s)                                                                              |
   |------------------------------------------------|---------------------------------------------------------------------------------------------|
   | `processing_system7_0.FCLK_CLK0`               | every `aclk` (PS `M_AXI_GP0_ACLK`, interconnect `ACLK / S00_ACLK / M00_ACLK`, `cordic_sqrt_axi_0.s00_axi_aclk`, `proc_sys_reset_0.slowest_sync_clk`) |
   | `processing_system7_0.FCLK_RESET0_N`           | `proc_sys_reset_0.ext_reset_in`                                                             |
   | `proc_sys_reset_0.interconnect_aresetn`        | `axi_interconnect_0.ARESETN`                                                                |
   | `proc_sys_reset_0.peripheral_aresetn`          | `axi_interconnect_0.S00_ARESETN`, `axi_interconnect_0.M00_ARESETN`, `cordic_sqrt_axi_0.s00_axi_aresetn` |

3. **Data path.**

   | Source                                  | Destination                       |
   |-----------------------------------------|-----------------------------------|
   | `processing_system7_0.M_AXI_GP0`        | `axi_interconnect_0.S00_AXI`      |
   | `axi_interconnect_0.M00_AXI`            | `cordic_sqrt_axi_0.s00_axi`       |

4. **Address Editor.**  Assign `cordic_sqrt_axi_0 / S00_AXI` at
   **Offset Address** = `0x43C2_0000`, **Range** = `4K`.  The row should
   read `0x43C2_0000 .. 0x43C2_0FFF`.  This is the same
   `XPAR_CORDIC_SQRT_AXI_0_S00_AXI_BASEADDR` that `sw/main.c` expects.

5. *Validate Design*.  *Generate Output Products*.  *Create HDL Wrapper*.
6. Set the wrapper as the top module:

   ```tcl
   set_property TOP cordic_sqrt_wrapper [current_fileset]
   update_compile_order -fileset sources_1
   ```

7. Synthesis -> Implementation -> Generate Bitstream.
8. *File -> Export -> Export Hardware* with *Include bitstream* -> writes
   `cordic_sqrt_wrapper.xsa`.

Capture a screenshot of the block design for the report (the IP block
icon shown in Fig. 2 of the assignment is the `cordic_sqrt_axi_0` block
on the canvas).

## 5. Build the software in Vitis Unified 2025.2

1. Launch Vitis Unified 2025.2 and create a workspace (for example
   `cordic_sqrt/workspace`).
2. *Create Platform Component* from the XSA.  Pick the `standalone`
   domain on `ps7_cortexa9_0`.
3. *Create Application Component* on that platform using
   `Empty Application (C)` or `Hello World`.
4. Replace the generated `helloworld.c` with `sw/main.c`.
5. **Configure the BSP stdin/stdout**:
   - In the Vitis Explorer, open
     `platform -> ps7_cortexa9_0 -> standalone_ps7_cortexa9_0 -> BSP -> standalone`.
   - Set `standalone_stdin` and `standalone_stdout` to `ps7_uart_0`
     (Cora Z7-07S USB-UART bridge).
   - Click **Regenerate BSP**.
6. Build the platform, then build the `cordic_sqrt` application.

## 6. Run and capture serial output

### 6.1 Run configuration

| Setting              | Value |
|----------------------|-------|
| Target Connection    | Local [default] |
| Target Setup Mode    | Baremetal Debug |
| Device               | Auto Detect |
| Bitstream File       | `${workspaceFolder}/cordic_sqrt/_ide/bitstream/cordic_sqrt_wrapper.bit` |
| Board Initialization | TCL |
| Initialization file  | `${workspaceFolder}/cordic_sqrt/_ide/psinit/ps7_init.tcl` |
| Run ps7_init         | checked |
| Run Ps7 Post Init    | checked |
| Reset Entire System  | checked |
| Reset APU            | checked |
| Program Device       | checked |

### 6.2 Serial monitor

1. Connect the Cora Z7-07S over USB-UART.  Typical Linux nodes:
   `/dev/ttyUSB0` (JTAG) and `/dev/ttyUSB1` (UART).
2. **Attach the serial monitor *before* clicking Run.**  The app
   finishes within a few hundred milliseconds after the 3 s startup
   countdown.

   ```bash
   picocom /dev/ttyUSB1 -b 115200 --imap lfcrlf
   ```

   Or PuTTY at 115200 8N1 (matching the assignment screenshot).

3. Expect:

   ```
   cordic sqrt
   sqrt(0x80) = 0x100
   sqrt(0x40) = 0xB5
   sqrt(0x8)  = 0x40
   ```

   followed by the `Summary : 3 passed, 0 failed` line.

4. Screenshot the serial monitor window for the report; this is the
   "putty.png" deliverable.

## Expected results (for reference)

| Test | `x`         | `x` (decimal, 2Q7) | Expected `z` | `z` (decimal, 1Q8) |
|-----:|------------:|-------------------:|-------------:|-------------------:|
| 1    | `0x080`     | 1.0                | `0x100`      | 1.0                |
| 2    | `0x040`     | 0.5                | `0x0B5`      | 0.7070...          |
| 3    | `0x008`     | 1/16 = 0.0625      | `0x040`      | 0.25               |

## Design notes

- **CORDIC Square-Root pipeline depth.** With Architecture =
  Parallel and Pipelining = Maximum, the IP inserts roughly one register
  per CORDIC iteration, so `dout_tvalid` lags `din_tvalid` by ~13-15
  clocks for a 10-bit configuration.  The Vitis app tolerates this
  automatically by polling `slv_reg3(0)` rather than spinning a fixed
  number of NOPs.
- **No "write-strobe-as-clock" trick.** Unlike the Homework 3 fixed
  accumulator design, the CORDIC core runs on `S_AXI_ACLK` and uses the
  AXI-stream `tvalid` handshake.  Software controls validity via
  `slv_reg1(0)`.
- **10-bit lower-byte usage.** The assignment specifies 16-bit input/
  output ports but the CORDIC IP is configured for 10 bits (range
  `0x000 .. 0x3FF`).  `user_logic.vhd` slices `x(9:0)` into the
  AXI-stream slave port and drives `m_axis_dout_tdata(9:0)` back into
  `z(9:0)`.  The upper six bits of both `x` and `z` are unused / forced
  to zero on the boundary.
- **Base address `0x43C2_0000`**, one aperture above the
  `fix_acc_axi @ 0x43C1_0000` from Homework 3, so both IPs can coexist
  on the same PL image.
