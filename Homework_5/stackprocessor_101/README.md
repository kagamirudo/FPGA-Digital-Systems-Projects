# Homework 5 - Stack Processor 101 + `scpb` block-copy

Zynq PS + PL implementation on the Digilent Cora Z7-07S.  A custom
AXI4-Lite IP (`sp101_axi`) wraps the assignment PDF's Stack Processor 101
(`user_logic`) extended with a brand-new machine instruction `scpb`
("**s**tack **c**o**p**y **b**lock"): pop `number_of_data`, source
address and destination address from the stack and copy `number_of_data`
consecutive 32-bit words from `source` to `dest`.

## Layout

```
Homework_5/stackprocessor_101/
  rtl/
    bus_ip_mem_bridge.vhd                - bus/IP -> BRAM port mux
    user_logic.vhd                       - sp101 core + scpb FSM (NEW opcode)
    sp101_axi_v1_0_S00_AXI.vhd           - AXI4-Lite slave (5 regs)
    sp101_axi_v1_0.vhd                   - IP top, pass-through to the slave
  tb/
    tb_user_logic.vhd                    - self-checking testbench (VHDL-2008)
  sw/
    main.c                               - Vitis bare-metal test app (UART)
  docs/
    register_map.md                      - register/opcode map, scpb micro-steps
  scripts/
    setup.tcl                            - Vivado: generate IP + add sources
    package.tcl                          - IP packager: metadata + sub-core ref
```

Deliverables map to this tree:

| Deliverable                                            | File / artifact                                          |
|--------------------------------------------------------|----------------------------------------------------------|
| User logic (sp101 + scpb)                              | `rtl/user_logic.vhd`                                     |
| Simulation for correctness                             | `tb/tb_user_logic.vhd` + xsim waveform screenshot        |
| IP packaging of sp101                                  | `rtl/sp101_axi_v1_0*.vhd` + `scripts/package.tcl`        |
| Testbench, test application, proof of correctness      | `tb/tb_user_logic.vhd` + `sw/main.c` + PuTTY screenshot  |

## Programming model for `scpb`

The instruction pops three arguments (top of stack last):

```
sc dest_addr   sc source_addr   sc number_of_data   scpb   halt
```

After execution, `memory[source_addr .. source_addr+count-1]` has been
copied into the contiguous block at `memory[dest_addr ..
dest_addr+count-1]`.

Opcodes (must match `user_logic.vhd`):

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

1. Create (or open) `sp101.xpr` in Vivado 2025.2 with the Cora Z7-07S as
   the target part (`xc7z007sclg400-1`).
2. In the Tcl console:

   ```tcl
   cd [file dirname [get_property DIRECTORY [current_project]]]
   source scripts/setup.tcl
   ```

   That script:

   - generates the IP-Catalog block `blk_mem_gen_0` (1024 x 32, single
     port, no output register),
   - adds the four RTL files to Design Sources and the TB to Simulation
     Sources,
   - sets file types (VHDL for RTL, VHDL 2008 for the TB),
   - sets the simulation top to `tb_user_logic`.

   It is idempotent; re-running is safe.

## 2. Simulate the user logic

1. Flow Navigator -> Run Simulation -> Run Behavioral Simulation.
2. In the simulator Tcl console type `run all` (or `run 5 us`).  The TB
   walks three scenarios (count = 3, 1, 0) and prints one `[PASS]` line per
   destination word followed by the banner:

   ```
   +--------------------------------------------------+
   |    sp101 + scpb  block-copy testbench summary    |
   +--------------------------------------------------+
      checks executed : 5
      errors          : 0
   +--------------------------------------------------+

   ####################################################
   ##                                                ##
   ##        TESTBENCH  PASSED  -  all cases ok      ##
   ##                                                ##
   ####################################################
   ```

3. To produce the report's waveform screenshot, paste in the wave Tcl
   console:

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
   restart
   run all
   ```

   Save the layout and screenshot the window so the report shows the
   count=3 scenario writing 0x0B, 0x16, 0x21 to addresses 200..202.

## 3. Package the IP

1. Tools -> Create and Package New IP.
2. Choose "Package your current project"; set the IP location to
   `Homework_5/stackprocessor_101/ip_repo/sp101_axi_1.0`.
3. Once the packager project is open, run:

   ```tcl
   source scripts/package.tcl
   ```

   That script sets identification metadata, adds the sub-core reference
   `xilinx.com:ip:blk_mem_gen:8.4` under both VHDL Synthesis and VHDL
   Simulation file groups, and configures `FREQ_HZ` /
   `ASSOCIATED_BUSIF` / `ASSOCIATED_RESET` on `s00_axi_aclk`.

4. Review and Package -> Re-Package IP.  The usual `19-11888`, `19-896`,
   `19-11770`, `19-7067` warnings should all be cleared.
5. Close the packager project; reopen `sp101.xpr`.
6. Settings -> IP -> Repository -> add `ip_repo/sp101_axi_1.0`.

## 4. Build the block design

1. Create block design `sp101`.  Add:
   - `ZYNQ7 Processing System` (apply the Cora Z7-07S board preset; enable
     UART0 on MIO 14/15, DDR, and `FCLK_CLK0` at 100 MHz).
   - `Processor System Reset`.
   - `AXI Interconnect` (or SmartConnect) - 1 slave, 1 master.
   - `sp101_axi` (our IP, from the repo).
2. Run Connection Automation on the green banner; tick every entry.  The
   wiring follows the same pattern as Homework 4: PS `FCLK_CLK0` ->
   every `aclk`, `FCLK_RESET0_N` -> `proc_sys_reset_0.ext_reset_in`,
   `peripheral_aresetn` -> every `S00_ARESETN` / `M00_ARESETN` /
   `s00_axi_aresetn`, `interconnect_aresetn` -> `axi_interconnect_0.ARESETN`.
3. Data path : `M_AXI_GP0` -> `S00_AXI` -> `sp101_axi_0.s00_axi`.
4. Address Editor: assign `sp101_axi_0` at **Offset Address** =
   `0x43C3_0000`, **Range** = `4K`.  This is the same
   `XPAR_SP101_AXI_0_S00_AXI_BASEADDR` that `sw/main.c` expects.
5. Validate Design.  Generate Output Products.  Create HDL Wrapper.
6. Set the wrapper as the top module:

   ```tcl
   set_property TOP sp101_wrapper [current_fileset]
   update_compile_order -fileset sources_1
   ```

7. Synthesis -> Implementation -> Generate Bitstream.
8. File -> Export -> Export Hardware (Include bitstream) -> writes
   `sp101_wrapper.xsa`.

## 5. Build the software in Vitis Unified 2025.2

1. Launch Vitis Unified 2025.2 and create a workspace (for example
   `stackprocessor_101/workspace`).
2. Create Platform Component from the XSA; pick the `standalone` domain
   on `ps7_cortexa9_0`.
3. Create Application Component on that platform using
   `Empty Application (C)` or `Hello World`.
4. Replace `helloworld.c` with `sw/main.c`.
5. Configure the BSP stdin/stdout:
   - In the Vitis Explorer, open
     `platform -> ps7_cortexa9_0 -> standalone_ps7_cortexa9_0 -> BSP -> standalone`.
   - Set `standalone_stdin` and `standalone_stdout` to `ps7_uart_0`.
   - Click **Regenerate BSP**.
6. Build the platform, then build the `sp101` application.

## 6. Run and capture serial output

1. Connect the Cora Z7-07S over USB-UART (Linux: typically `/dev/ttyUSB1`
   = UART, `/dev/ttyUSB0` = JTAG).
2. Attach the serial monitor BEFORE clicking Run:

   ```bash
   picocom /dev/ttyUSB1 -b 115200 --imap lfcrlf
   ```

3. Expect three scenarios, each followed by `RESULT: PASS`:

   ```
   ---- Scenario: scpb count=3 (multi-word) ----
     dest=200  src=100  count=3
     -- destination dump --
       [200] got=0x0000000b  expect=0x0000000b    OK
       [201] got=0x00000016  expect=0x00000016    OK
       [202] got=0x00000021  expect=0x00000021    OK
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

4. Screenshot the serial monitor window for the report; this is the
   "putty.png" deliverable referenced from `Homework_5/report/report.tex`.

## Design notes

- **Stack convention.** `scpb` matches the assignment's call form
  `sc dest sc source sc count scpb` exactly: count is on the top, source
  next, dest at the bottom.  The FSM pops them in that order and saves
  them into `copy_cnt`, `copy_src`, `copy_dst`.
- **Latency model.** The processor keeps the assignment PDF's simulation
  latency cushion (`fetch3`/`sc3`/.../`scp3`/`scp7` extra states).  The
  new `scpb` uses the same `*4` / `*R2` extra-cycle states so the existing
  `blk_mem_gen_0` simulation model lines up with the registered
  `mem_data_out`.
- **Cycle cost.** `scpb` takes about `6 * N + 8` clocks for an N-word
  block, plus the fetch overhead.  See `docs/register_map.md` for the
  full micro-step breakdown.
- **Base address `0x43C3_0000`** sits one 64 KB aperture above the
  Homework 4 `cordic_sqrt_axi` IP at `0x43C2_0000`, so all three custom
  peripherals (HW3 `fix_acc`, HW4 `cordic_sqrt`, HW5 `sp101`) can coexist
  on the same PL image.
