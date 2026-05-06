# Midterm - Button Sequence Detector

Zynq PS + PL implementation on the Digilent Cora Z7-07S. Two AXI GPIO
slaves connect the PS to the on-board buttons (BTN0/BTN1) and to the
RGB LEDs. A bare-metal C application running on the PS detects the
press sequence **BTN0, BTN0, BTN1** with a 4-state KMP-style Moore FSM,
turns the green segment of LD0 on while the FSM is in the detected
state `S3`, and prints a trace over UART0 (FT2232HQ USB-UART bridge).

## Layout

```
Midterm/real/
  problem.md                    one-line problem statement
  README.md                     this file (Vivado + Vitis runbook)
  docs/
    state_machine.md            KMP transition table + state diagram
  constraints/
    seq_det.xdc                 BTN0/BTN1 + 6 RGB LED pin assignments
  sw/
    main.c                      bare-metal Vitis application
  workspace/                    Vitis workspace (created at exam time)
  seq_det.xpr                   Vivado project       (created at exam time)
  seq_det_wrapper.xsa           exported hardware    (created at exam time)
```

Deliverables map to this tree:

| Deliverable           | File / artifact                          |
|-----------------------|------------------------------------------|
| Block-diagram snip    | screenshot of `bd/seq_det.bd`            |
| Constraints           | `constraints/seq_det.xdc`                |
| Test application code | `sw/main.c`                              |
| State machine notes   | `docs/state_machine.md`                  |
| PuTTY / serial snip   | captured at run time                     |
| Bitstream / XSA       | `seq_det_wrapper.xsa`                    |

## 1. Build the Vivado project

1. Launch Vivado 2025.2 -> *Create Project* in `Midterm/real/`,
   project name `seq_det`. Tick *Do not specify sources at this time*.
2. *Default Part* -> *Boards* -> **Cora Z7-07S Rev. B** (or pick part
   `xc7z007sclg400-1` directly if the board file is missing).
3. *Add Sources -> Add or Create Constraints* -> add
   `constraints/seq_det.xdc`.

   Tcl equivalent (run from the project directory):

   ```tcl
   create_project seq_det . -part xc7z007sclg400-1
   add_files -fileset constrs_1 constraints/seq_det.xdc
   ```

## 2. Build the block design (`bd/seq_det.bd`)

1. *IP Integrator -> Create Block Design*, name `seq_det`. Add blocks:
   - `ZYNQ7 Processing System`
     - Apply the Cora Z7-07S board preset if available; otherwise
       enable **UART0 on MIO 14/15**, DDR, and FCLK_CLK0 at 100 MHz
       manually. (The FT2232HQ on the Cora Z7-07S is wired to UART0,
       not UART1. Whichever UART you enable here *must* match the
       `stdin` / `stdout` selection in the Vitis BSP in section 3.)
   - `Processor System Reset`
   - `AXI Interconnect` with *Number of Slave Interfaces* = `1` and
     *Number of Master Interfaces* = `2`. Make sure you pick the
     plain `AXI Interconnect` (VLNV `xilinx.com:ip:axi_interconnect`),
     not the `AXI4-Stream Interconnect` lookalike.
   - `axi_gpio_0` - **LEDs**:
       - *All Outputs*, *GPIO Width* = `6`, *Default Output Value* =
         `0x00000000`, *Default Tri-State Value* = `0x00000000`.
       - Make `GPIO` external; rename the external port to `rgb_leds`.
   - `axi_gpio_1` - **Buttons**:
       - *All Inputs*, *GPIO Width* = `2`.
       - Make `GPIO` external; rename the external port to `btns_2bits`.

2. **Run Connection Automation** (the green banner) and tick every
   listed port. That produces the topology below:

   | Source                                   | Destination(s)                                                                       |
   |------------------------------------------|--------------------------------------------------------------------------------------|
   | `processing_system7_0.FCLK_CLK0`         | every `aclk` (PS `M_AXI_GP0_ACLK`, interconnect `ACLK/S00_ACLK/M00_ACLK/M01_ACLK`, both `axi_gpio_*.s_axi_aclk`, `proc_sys_reset_0.slowest_sync_clk`) |
   | `processing_system7_0.FCLK_RESET0_N`     | `proc_sys_reset_0.ext_reset_in`                                                      |
   | `proc_sys_reset_0.interconnect_aresetn`  | `axi_interconnect_0.ARESETN`                                                         |
   | `proc_sys_reset_0.peripheral_aresetn`    | every `S00_ARESETN/M00_ARESETN/M01_ARESETN/s_axi_aresetn`                            |
   | `processing_system7_0.M_AXI_GP0`         | `axi_interconnect_0.S00_AXI`                                                         |
   | `axi_interconnect_0.M00_AXI`             | `axi_gpio_0.S_AXI` (LEDs)                                                            |
   | `axi_interconnect_0.M01_AXI`             | `axi_gpio_1.S_AXI` (buttons)                                                         |

   If Vivado dropped in *AXI SmartConnect* instead, that block has no
   `interconnect_aresetn` / `S00_ARESETN` / `M00_ARESETN` trio - drive
   its single `aresetn` from `proc_sys_reset_0.peripheral_aresetn`.

3. **Address Editor.** *Window -> Address Editor* (or click the tab
   next to *Diagram*). Either click *Assign All* or right-click each
   slave and assign:

   | Slave         | Offset       | Range |
   |---------------|--------------|-------|
   | `axi_gpio_0`  | `0x4120_0000`| 64K   |
   | `axi_gpio_1`  | `0x4121_0000`| 64K   |

   These match the defaults in `sw/main.c`. If Vivado picks something
   else, just rebuild Vitis - the BSP will export the correct
   `XPAR_AXI_GPIO_*_BASEADDR` and `main.c` will use it.

4. *Validate Design*. *Generate Output Products*. *Create HDL Wrapper*.

5. **Set the wrapper as the top module.** Right-click `seq_det_wrapper`
   in the Sources tree -> *Set as Top* (it goes bold). Tcl:

   ```tcl
   set_property TOP seq_det_wrapper [current_fileset]
   update_compile_order -fileset sources_1
   ```

   Sanity check: `get_property TOP [current_fileset]` -> `seq_det_wrapper`.

6. Run Synthesis, Implementation, *Generate Bitstream*.

7. *File -> Export -> Export Hardware* with *Include bitstream* ->
   writes `seq_det_wrapper.xsa`.

Capture a screenshot of the block design for the report.

## 3. Build the software in Vitis Unified 2025.2

1. Launch Vitis Unified 2025.2 and create a workspace at
   `Midterm/real/workspace`.
2. *Create Platform Component* from `seq_det_wrapper.xsa`. Pick the
   `standalone` domain on `ps7_cortexa9_0`.
3. *Create Application Component* on that platform using
   *Empty Application (C)* targeting `ps7_cortexa9_0`. Name it
   `seq_det`.
4. Replace the generated `helloworld.c` (if any) with
   `Midterm/real/sw/main.c`. Either symlink it or copy it into the
   application's `src/` folder.
5. **Configure the BSP stdin/stdout** (this is the #1 reason for
   "Run session completed, but PuTTY is blank"):
   - In the Vitis Explorer, expand
     `platform -> ps7_cortexa9_0 -> standalone_ps7_cortexa9_0 -> Board Support Package -> standalone`.
   - Set `standalone_stdin` and `standalone_stdout` to `ps7_uart_0`
     (Cora Z7-07S default; use `ps7_uart_1` only if you enabled UART1
     in the PS instead).
   - Click **Regenerate BSP**. Do not skip this - changing the
     dropdowns alone does nothing until the BSP is regenerated.
   - Sanity check:
     `workspace/platform/.../standalone_ps7_cortexa9_0/bsp/include/bspconfig.h`
     must contain both `#define XPAR_STDIN_IS_UARTPS` and
     `#define STDOUT_BASEADDRESS 0xe0000000` (UART0) or `0xe0001000`
     (UART1).
6. In the FLOW panel set *Component* to `platform` and click **Build**,
   then switch to `seq_det` and **Build** again.

## 4. Run and capture serial output

### 4.1 Run configuration (Vitis Unified 2025.2)

| Setting              | Value                                                              |
|----------------------|--------------------------------------------------------------------|
| Target Connection    | `Local [default]`                                                  |
| Target Setup Mode    | `Baremetal Debug`                                                  |
| Device               | `Auto Detect`                                                      |
| Bitstream File       | `${workspaceFolder}/seq_det/_ide/bitstream/seq_det_wrapper.bit`    |
| Board Initialization | `TCL`                                                              |
| Initialization file  | `${workspaceFolder}/seq_det/_ide/psinit/ps7_init.tcl`              |
| Run ps7_init         | checked                                                            |
| Run Ps7 Post Init    | checked                                                            |
| Reset Entire System  | checked                                                            |
| Reset APU            | checked                                                            |
| Program Device       | checked                                                            |

Skipping **Run ps7_init** is the second-most-common reason UART stays
silent: without it MIO 14/15 is never muxed to UART0.

### 4.2 Serial monitor

1. Connect the Cora Z7-07S over USB-UART. On Linux the FT2232HQ shows
   up as two nodes; the UART is typically `/dev/ttyUSB1` (the JTAG
   channel is `/dev/ttyUSB0`). Verify with `ls -l /dev/ttyUSB*` and
   `dmesg | tail`.
2. Open the embedded Vitis **Serial Monitor** on that port at
   `115200 8N1, no flow control`, or use an external terminal:

   ```bash
   picocom /dev/ttyUSB1 -b 115200 --imap lfcrlf
   ```

3. **Connect the serial monitor *before* clicking Run.** The 3-second
   startup countdown in `sw/main.c` exists to give you the time to
   attach.
4. In the FLOW panel, set *Component* to `seq_det` and click **Run**.
5. Press buttons on the board and watch the trace. Screenshot a clean
   match (and ideally a KMP-extra-`btn0` case) for the report.

### 4.3 Troubleshooting "no UART output"

If `Run session completed` appears but the serial monitor is blank,
walk this checklist in order:

1. **BSP UART matches PS UART.** UART0 (MIO 14/15, `0xE000_0000`) on
   the Cora Z7-07S; the BSP's `standalone_stdin`/`standalone_stdout`
   must point to the same peripheral.
2. **BSP was regenerated** after changing those values. Confirm
   `bspconfig.h` has `STDOUT_BASEADDRESS` defined.
3. **`ps7_init` ran.** Open the XSDB console at the bottom of the IDE;
   you should see `Execute 'ps7_init' for Processor ... done` after
   each Run. If it is missing, tick **Run ps7_init** in the run
   configuration.
4. **Bitstream was programmed.** Tick **Program Device**. Without a PL
   bitstream the AXI GPIOs are not present and `XGpio_Initialize` will
   fail; the pre-loop UART countdown should still print, so missing
   *those* points back to steps 1-3.
5. **Right `/dev/ttyUSB*`.** Try both channels.
6. **Serial monitor attached before Run.** The 3-second startup window
   in `main.c` exists specifically for this; if you still see nothing
   after the countdown completes, go back to step 1.

## Expected serial output

Happy path - press BTN0, BTN0, BTN1:

```
seq_det starting in 3...
seq_det starting in 2...
seq_det starting in 1...

==========================================================
   ECEC 661 Midterm - Button sequence detector
   Pattern  : BTN0, BTN0, BTN1   (4-state Moore FSM)
   LEDs base: 0x41200000   Buttons base: 0x41210000
==========================================================
Press BTN0 / BTN1 on the Cora Z7-07S board.
LD0_G is ON while the FSM is in the detected state S3.

[press BTN0] state S0 -> S1  LED=OFF
[press BTN0] state S1 -> S2  LED=OFF
[press BTN1] state S2 -> S3  LED=ON   *** DETECTED #1 ***
```

Press BTN0 again -> the FSM leaves S3 and the LED turns back off, but
that BTN0 already opens the next match attempt:

```
[press BTN0] state S3 -> S1  LED=OFF
```

KMP path - BTN0, BTN0, BTN0, BTN1 (still detects on the trailing BTN1):

```
[press BTN0] state S0 -> S1  LED=OFF
[press BTN0] state S1 -> S2  LED=OFF
[press BTN0] state S2 -> S2  LED=OFF
[press BTN1] state S2 -> S3  LED=ON   *** DETECTED #2 ***
```

False start - BTN0, BTN1 (resets, no detection):

```
[press BTN0] state S0 -> S1  LED=OFF
[press BTN1] state S1 -> S0  LED=OFF
```
