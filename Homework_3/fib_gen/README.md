# Homework 3 - Problem 8.7.1 Fibonacci Number Generator

Zynq PS + PL implementation on the Digilent Cora Z7-07S. A custom
AXI4-Lite IP (`fib_axi`) contains the Fibonacci compute core; a
bare-metal C application running on the PS drives it and prints
results over the PS UART (Cora Z7-07S: UART0 on MIO 14/15, which the
FT2232HQ bridges to the host as a USB-UART).

## Layout

```
Homework_3/fib_gen/
  rtl/
    fib_core.vhd                - FSM + 33-bit adder, 32-bit result
    fib_axi_v1_0_S00_AXI.vhd    - AXI4-Lite slave, register decode
    fib_axi_v1_0.vhd            - IP top, wires slave to core
  tb/
    tb_fib_core.vhd             - self-checking testbench (VHDL-2008)
  sw/
    main.c                      - Vitis bare-metal test app (UART)
  docs/
    register_map.md             - offsets, bit fields, handshake
  fib_gen.xpr                   - Vivado project
  fib_gen.srcs/sources_1/bd/fib - block design (empty, populate below)
```

The user deliverables required by the assignment map to this tree as:

| Deliverable | File |
|-------------|------|
| User logic HDL code | `rtl/*.vhd` |
| Test bench          | `tb/tb_fib_core.vhd` |
| Block-diagram snip  | from Vivado (`bd/fib.bd`) |
| Test application C code | `sw/main.c` |
| PuTTY output snip   | captured at run-time |

## 1. Simulate the core

1. Open `fib_gen.xpr` in Vivado 2025.2.
2. Add `rtl/fib_core.vhd`, `rtl/fib_axi_v1_0_S00_AXI.vhd`,
   `rtl/fib_axi_v1_0.vhd` to **Design Sources**.
3. Add `tb/tb_fib_core.vhd` to **Simulation Sources**.
4. **File-type settings** (important — the IP packager rejects a
   VHDL-2008 top, but the TB uses VHDL-2008 features).  Run this in the
   Tcl console:

   ```tcl
   set_property FILE_TYPE VHDL        [get_files fib_core.vhd]
   set_property FILE_TYPE VHDL        [get_files fib_axi_v1_0_S00_AXI.vhd]
   set_property FILE_TYPE VHDL        [get_files fib_axi_v1_0.vhd]
   set_property FILE_TYPE {VHDL 2008} [get_files tb_fib_core.vhd]
   ```

5. Set `tb_fib_core` as the top of the simulation set
   (`set_property TOP tb_fib_core [get_filesets sim_1]`) and run
   *Behavioral Simulation*.  Expected Tcl-console output:
   - nine `PASS n=...` notes, then
   - `TESTBENCH PASSED - all cases match`.
6. In the empty wave pane, paste this in the Tcl console to populate
   the signals (XSim uses `add_wave_group`, not `-divider`):

   ```tcl
   add_wave /tb_fib_core/clk /tb_fib_core/rst /tb_fib_core/start \
            /tb_fib_core/done /tb_fib_core/overflow /tb_fib_core/busy
   add_wave -radix unsigned /tb_fib_core/n /tb_fib_core/cycles
   add_wave -radix hex      /tb_fib_core/result
   add_wave /tb_fib_core/dut/state
   add_wave -radix hex      /tb_fib_core/dut/a /tb_fib_core/dut/b /tb_fib_core/dut/n_reg
   add_wave -radix unsigned /tb_fib_core/dut/k /tb_fib_core/dut/cyc_r
   restart
   run all
   ```

   Ctrl+S to save the layout (Vivado writes `tb_fib_core_behav.wcfg`).
   Screenshot one of the short computes (e.g. `n=10`) for the report.

### CLI-only simulation (optional)
You can re-verify entirely from a terminal without the GUI:

```bash
cd Homework_3/fib_gen
mkdir -p sim_cli && cd sim_cli
xvhdl -2008 ../rtl/fib_core.vhd ../rtl/fib_axi_v1_0_S00_AXI.vhd \
              ../rtl/fib_axi_v1_0.vhd ../tb/tb_fib_core.vhd
xelab -debug typical tb_fib_core -s tb_fib_core_snap
xsim tb_fib_core_snap --runall
```

Expected tail of the log: `TESTBENCH PASSED - all cases match`.

## 2. Package the IP

1. In Vivado: *Tools -> Create and Package New IP*.
2. Choose *Package your current project*; set the IP location to
   `Homework_3/fib_gen/ip_repo/fib_axi_1.0`.
3. **Identification tab** — these are the exact values that avoid
   Vivado's naming / description warnings:
   - Vendor: `user`
   - Library: `user`
   - Name: `fib_axi`                       *(identifier only, no spaces)*
   - Version: `1.0`
   - Display name: `Fibonacci AXI4-Lite Core`
   - Description: `32-bit Fibonacci F(N) compute engine with overflow flag, AXI4-Lite slave.`
   - Categories: `/UserIP`

   Or via Tcl once the packager project is open:

   ```tcl
   set_property name         fib_axi                                     [ipx::current_core]
   set_property display_name "Fibonacci AXI4-Lite Core"                  [ipx::current_core]
   set_property description  "32-bit Fibonacci F(N) compute engine with overflow flag, AXI4-Lite slave." [ipx::current_core]
   ipx::save_core [ipx::current_core]
   ```

4. **Ports and Interfaces tab**:
   - Confirm `s00_axi` is detected as an AXI4-Lite slave and that
     `s00_axi_aclk` / `s00_axi_aresetn` are the associated clock / reset.
   - Double-click the `s00_axi_aclk` interface row -> *Parameters* tab
     and make sure the `User Set` group contains:

     | Name              | Value              |
     |-------------------|--------------------|
     | `FREQ_HZ`         | `100000000`        |
     | `ASSOCIATED_BUSIF`| `s00_axi`          |
     | `ASSOCIATED_RESET`| `s00_axi_aresetn`  |

     Tcl equivalent (if the GUI `+` button fights you):

     ```tcl
     ipx::add_bus_parameter FREQ_HZ \
         [ipx::get_bus_interfaces s00_axi_aclk -of_objects [ipx::current_core]]
     set_property value 100000000 \
         [ipx::get_bus_parameters FREQ_HZ -of_objects \
             [ipx::get_bus_interfaces s00_axi_aclk -of_objects [ipx::current_core]]]
     set_property value_source user \
         [ipx::get_bus_parameters FREQ_HZ -of_objects \
             [ipx::get_bus_interfaces s00_axi_aclk -of_objects [ipx::current_core]]]
     set_property value_resolve_type user \
         [ipx::get_bus_parameters FREQ_HZ -of_objects \
             [ipx::get_bus_interfaces s00_axi_aclk -of_objects [ipx::current_core]]]
     ipx::save_core [ipx::current_core]
     ```

5. *Review and Package* -> *Re-Package IP*.  The following warnings
   should all be cleared by the steps above:

   | Warning | What it meant | Fix above |
   |---------|----------------|-----------|
   | `19-5655` | VHDL-2008 top not supported | step 1.4 (RTL = VHDL-93) |
   | `19-11888` | description == name        | step 2.3 |
   | `19-896`  | invalid name with spaces    | step 2.3 (Name vs Display Name) |
   | `19-11770`| clock missing FREQ_HZ       | step 2.4 |
   | `19-7067` | FREQ_HZ empty / fixed       | step 2.4 (value_resolve_type=user) |

6. Close the IP packager project; reopen `fib_gen.xpr`.
7. *Settings -> IP -> Repository*, add `ip_repo/fib_axi_1.0`.

## 3. Build the block design (`bd/fib.bd`)

1. Open `fib.bd` (empty).  Add blocks:
   - `ZYNQ7 Processing System`
     - Apply the Cora Z7-07S board preset if it is available; otherwise
       enable **UART0 on MIO 14/15**, DDR, and FCLK_CLK0 at 100 MHz
       manually.  (The FT2232HQ on the Cora Z7-07S is wired to UART0,
       not UART1.  Whichever UART you enable here *must* match the
       `stdin` / `stdout` selection in the Vitis BSP in step 4.)
   - `Processor System Reset`
   - `AXI Interconnect` (1 slave, 1 master)
   - `fib_axi` (our IP)
2. **AXI Interconnect settings** - double-click `axi_interconnect_0`
   and set *Number of Master Interfaces* to `1`.  It defaults to `2`,
   which leaves `M01_ACLK` unconnected and triggers:

   ```
   [BD 41-758] The following clock pins are not connected to a valid
   clock source: /axi_interconnect_0/M01_ACLK
   ```

   (If you need the extra master port later, drive `M01_ACLK` with
   `FCLK_CLK0` and `M01_ARESETN` with
   `proc_sys_reset_0/peripheral_aresetn` instead.)

   Vivado labels this block *"AXI Interconnect (Discontinued)"* because
   Xilinx now prefers *AXI SmartConnect*.  Either works for this
   homework.
3. Connect:
   - `FCLK_CLK0` -> every `aclk`
   - `FCLK_RESET0_N` -> `Processor System Reset.ext_reset_in`
   - `Processor System Reset.interconnect_aresetn` -> interconnect ARESETN
   - `Processor System Reset.peripheral_aresetn` -> slave and master ARESETN
   - `M_AXI_GP0` -> interconnect `S00_AXI`
   - Interconnect `M00_AXI` -> `fib_axi.s00_axi`
4. Run *Address Editor*; assign `fib_axi_0` to `0x43C00000`, range
   `4K` (default).
5. *Validate Design*.  *Generate Output Products*.  *Create HDL Wrapper*.
6. **Set the wrapper as the top module.**  Vivado synthesizes only the
   top of `sources_1`, which after creating the wrapper is *not*
   automatically switched.  Right-click `fib_wrapper` in the Sources
   tree -> *Set as Top* (it goes bold).  Tcl equivalent:

   ```tcl
   set_property TOP fib_wrapper [current_fileset]
   update_compile_order -fileset sources_1
   ```

   Sanity check: `get_property TOP [current_fileset]` should print
   `fib_wrapper`, not `fib_axi_v1_0`.
7. Run Synthesis, Implementation, and *Generate Bitstream*.
8. *File -> Export -> Export Hardware* with *Include bitstream*
   (writes `fib_wrapper.xsa`).

Capture a screenshot of the block design for the report.

## 4. Build the software in Vitis Unified 2025.2

1. Launch Vitis Unified 2025.2 and create a workspace (for example
   `fib_gen/workspace`).
2. *Create Platform Component* from the XSA exported above.  Pick the
   `standalone` domain on `ps7_cortexa9_0`.
3. *Create Application Component* on that platform using the
   `Empty Application (C)` or `Hello World` template targeting
   `ps7_cortexa9_0`.
4. Replace the generated `helloworld.c` with `sw/main.c` (or add
   `main.c` and remove the template file).
5. **Configure the BSP stdin/stdout**  (this is the #1 reason for
   "Run session completed, but PuTTY is blank"):
   - In the **Vitis Explorer** tree, expand
     `platform -> ps7_cortexa9_0 -> standalone_ps7_cortexa9_0 ->
     Board Support Package -> standalone`.
   - The right pane shows `Configuration for Os: standalone`.  Scroll
     to the `standalone_stdin` / `standalone_stdout` rows.
   - Set both to `ps7_uart_0` (for the Cora Z7-07S).  If your Vivado
     PS block has UART1 enabled instead, set both to `ps7_uart_1`.
   - Click **Regenerate BSP** at the top of that view.  Do not skip
     this - just changing the dropdowns does nothing until you
     regenerate.
   - Sanity check:
     `workspace/platform/.../standalone_ps7_cortexa9_0/bsp/include/bspconfig.h`
     must contain both
     `#define XPAR_STDIN_IS_UARTPS` and
     `#define STDOUT_BASEADDRESS 0xe0000000` (UART0) or `0xe0001000`
     (UART1).  If those lines are missing, the BSP was not
     regenerated.
   - **Do not edit the `zynq_fsbl` BSP** - that is the FSBL's own BSP
     and has no effect on the application.
6. In the FLOW panel set *Component* to `platform` and click **Build**,
   then switch to `fib_gen` and **Build** again.

## 5. Run and capture PuTTY output

### 5.1 Run configuration  (Vitis Unified 2025.2)

The Vitis 2025.2 menu names are different from older SDK versions.
Open the run configuration from the FLOW panel (the gear next to
**Run**), or *Run -> Run Configurations*.  It writes to
`fib_gen/_ide/launch.json`.  The working configuration for a bare-
metal Zynq test looks like this:

| Setting              | Value                                              |
|----------------------|----------------------------------------------------|
| Target Connection    | `Local [default]`                                  |
| Target Setup Mode    | `Baremetal Debug`                                  |
| Device               | `Auto Detect`                                      |
| Bitstream File       | `${workspaceFolder}/fib_gen/_ide/bitstream/fib_wrapper.bit` |
| Board Initialization | `TCL`                                              |
| Initialization file  | `${workspaceFolder}/fib_gen/_ide/psinit/ps7_init.tcl` |
| Run ps7_init         | checked                                            |
| Run Ps7 Post Init    | checked                                            |
| Reset Entire System  | checked                                            |
| Reset APU            | checked                                            |
| Program Device       | checked                                            |

Skipping **Run ps7_init** is the second-most-common reason UART stays
silent: without it MIO 14/15 is never muxed to UART0 and the UART
clock dividers are never programmed, so `xil_printf` writes into a
dead peripheral.

### 5.2 Serial monitor

1. Connect the Cora Z7-07S over USB-UART.  On Linux the FT2232HQ shows
   up as two nodes; the UART is typically `/dev/ttyUSB1` (the JTAG
   channel is `/dev/ttyUSB0`).  Verify with `ls -l /dev/ttyUSB*` and
   `dmesg | tail`.
2. Either open the embedded Vitis **Serial Monitor** on that port at
   `115200 8N1, no flow control`, or use an external terminal:
   ```bash
   picocom /dev/ttyUSB1 -b 115200 --imap lfcrlf
   # or
   minicom -D /dev/ttyUSB1 -b 115200
   ```
3. **Connect the serial monitor *before* clicking Run** - the app
   finishes in well under a second and any output that is already in
   the UART FIFO when you attach will be lost.
4. In the FLOW panel, set *Component* to `fib_gen` and click **Run**.
5. Expect the header, ten rows in the table, and
   `Summary : 10 passed, 0 failed`.  Row `n = 48` has `ovf = 1` and
   still reports `OK`, because the software reference also overflows
   a 32-bit result at that index.
6. Screenshot the serial monitor / PuTTY window for the report.

### 5.3 Troubleshooting "no UART output"

If `Run session completed` appears in the status bar but the serial
monitor is blank, walk this checklist in order - each step eliminates
one concrete failure mode:

1. **BSP UART matches PS configuration.**  Open the Vivado block
   design and note whether UART0 (MIO 14/15) or UART1 (MIO 48/49) is
   enabled in the Zynq PS.  The `standalone_stdin` / `standalone_stdout`
   values in the Vitis BSP *must* point to the same peripheral.  Cora
   Z7-07S default is UART0.
2. **BSP was regenerated.**  Confirm `bspconfig.h` has
   `#define STDIN_BASEADDRESS` and `STDOUT_BASEADDRESS` defined.  If
   only `xparameters.h` mentions the UART but `bspconfig.h` has no
   `STDIN_BASEADDRESS`, click *Regenerate BSP* and rebuild the
   platform + application.  (The older SDK put these macros in
   `xparameters.h`; 2025.2 puts them in `bspconfig.h`.)
3. **ps7_init ran.**  Open the XSDB console tab at the bottom of the
   IDE; after a Run you should see a line like
   `Execute 'ps7_init' for Processor ... done`.  If it is missing,
   tick **Run ps7_init** in the run configuration (see section 5.1).
4. **Bitstream was programmed.**  Tick **Program Device**.  Without a
   PL bitstream the AXI IP is not present, `fib_compute` times out,
   but UART should still work for the pre-loop countdown prints -
   *not* seeing those points back to steps 1-3.
5. **Right `/dev/ttyUSB*`.**  Try both channels.  `picocom /dev/ttyUSB0`
   and `picocom /dev/ttyUSB1` - only the UART channel will echo
   anything when the board sends.
6. **Serial monitor attached before Run.**  The 3-second startup
   countdown in `sw/main.c` exists specifically to give you time to
   attach.  If you still see nothing after the countdown window, go
   back to step 1.

## Expected hardware results (for reference)

| n  | F(n) (hex)   | F(n) (dec)    | Overflow |
|----|--------------|---------------|:--------:|
| 0  | `0x00000000` |             0 | 0 |
| 1  | `0x00000001` |             1 | 0 |
| 2  | `0x00000001` |             1 | 0 |
| 5  | `0x00000005` |             5 | 0 |
| 10 | `0x00000037` |            55 | 0 |
| 20 | `0x00001A6D` |         6,765 | 0 |
| 30 | `0x000CB228` |       832,040 | 0 |
| 46 | `0x6D73E55F` | 1,836,311,903 | 0 |
| 47 | `0xB11924E1` | 2,971,215,073 | 0 |
| 48 | truncated    | -             | 1 |
