# Quiz 2 (real) - Add-Constant-(-1) Custom AXI-Lite IP

**ECEC 661/402 Quiz 2** - Build a custom AXI4-Lite IP that wraps the Vivado
IP-Catalog **Adder/Subtractor** (`c_addsub`), configured with `B` held to a
constant `-1` (signed 32-bit, all ones). The user logic effectively computes
`z = x + (-1) = x - 1`. See [`prob.md`](prob.md) for the verbatim problem
statement, scanned hand-out, and reference test vectors.

## Layout

```
Quiz_2/real/
  rtl/
    user_logic.vhd                       - quiz user logic; wraps c_addsub_0
    add_const_axi_v1_0_S00_AXI.vhd       - AXI4-Lite slave (X_IN / Z_OUT)
    add_const_axi_v1_0.vhd               - IP top, wires the slave through
  tb/
    tb_user_logic.vhd                    - self-checking testbench (VHDL-2008)
  sw/
    main.c                               - bare-metal Vitis test app (UART)
  docs/
    quiz2_problem.png                    - scanned hand-out
    register_map.md                      - offsets and behavior
  scripts/
    setup.tcl                            - generate c_addsub_0 + add sources
    package.tcl                          - IP packager metadata helper
    create_bd.tcl                        - block design helper (PS + custom IP)
  q2_real/                               - Vivado project (q2_real.xpr)
```

Deliverables map to this tree (per the hand-out):

| Deliverable                                                 | File / Step                                       | Pts |
|-------------------------------------------------------------|---------------------------------------------------|-----|
| User-logic project + simulation                             | `rtl/user_logic.vhd`, `tb/tb_user_logic.vhd`      | 4   |
| Package the user logic as AXI-Lite IP                       | `rtl/add_const_axi_v1_0_S00_AXI.vhd` + packager   | 3   |
| Test-bench project as Zynq peripheral, bitstream, XSA       | block design + `xsa/add_const.xsa`                | 3   |

The Vitis test app is **not** required for this quiz.

## 1. Set Up The Vivado Project

Create (or open) `q2_real/q2_real.xpr` in Vivado 2025.2 with the Cora Z7-07S
part `xc7z007sclg400-1` (any Zynq-7000 part works; we only need to package
the IP and produce an XSA). In the Tcl console:

```tcl
cd [file dirname [get_property DIRECTORY [current_project]]]
source scripts/setup.tcl
```

That script:

- generates `c_addsub_0` with `Implementation=Fabric`, `A=Signed/32`,
  `B=Signed/32 (constant=32'b1...1=-1)`, `Out=32`, `Add Mode=Add`,
  `Latency=0`, `CE=false`,
- adds the three RTL files to Design Sources and the TB to Simulation
  Sources,
- sets file types (VHDL for RTL so the packager is happy; VHDL 2008 for
  the TB),
- sets the simulation top to `tb_user_logic` and the design top to
  `add_const_axi_v1_0`.

To force a clean IP rebuild after a configuration change:

```tcl
set ::env(QUIZ2_REAL_FORCE_IP) 1
source scripts/setup.tcl
unset ::env(QUIZ2_REAL_FORCE_IP)
```

## 2. Simulate The User Logic (4 pts)

1. Flow Navigator -> *Run Simulation* -> *Run Behavioral Simulation*.
2. In the xsim console: `run all`.

Expected end-of-run:

```text
[PASS] x=-5  z=-6
[PASS] x=-4  z=-5
[PASS] x=-3  z=-4
[PASS] x=-2  z=-3
[PASS] x=-1  z=-2
[PASS] x=0   z=-1
[PASS] x=1   z=0
[PASS] x=2   z=1
[PASS] x=3   z=2
[PASS] x=2147483647  z=2147483646
[PASS] x=-2147483648 z=2147483647

+--------------------------------------------------+
|        tb_user_logic  -  add-(-1) summary        |
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

Wave snip for the report (set `x` and `z` to **Signed Decimal**):

```tcl
add_wave -radix dec /tb_user_logic/x
add_wave -radix dec /tb_user_logic/z
restart
run all
```

## 3. Package The Custom IP (3 pts)

1. *Tools -> Create and Package New IP*.
2. Choose *Package your current project*. Set the IP location to:

   ```text
   Quiz_2/real/ip_repo/add_const_axi_1.0
   ```

3. Once the packager project is open, run:

   ```tcl
   source scripts/package.tcl
   ```

   That sets:
   - identification (name `add_const_axi`, version `1.0`, etc.),
   - the **sub-core reference** `xilinx.com:ip:c_addsub:12.0` under both
     VHDL Synthesis and VHDL Simulation file groups,
   - `FREQ_HZ`, `ASSOCIATED_BUSIF`, `ASSOCIATED_RESET` on `s00_axi_aclk`.

4. *Review and Package* -> *Re-Package IP*. The usual `19-11888`,
   `19-896`, `19-11770`, `19-7067` warnings should be cleared.
5. Close the packager project; reopen `q2_real/q2_real.xpr`.
6. *Settings -> IP -> Repository* -> add `Quiz_2/real/ip_repo/add_const_axi_1.0`
   (or run the equivalent `set_property ip_repo_paths` from `create_bd.tcl`).

## 4. Build The Block Design (`bd/add_const.bd`)

1. Create block design `add_const`. Add:
   - `ZYNQ7 Processing System` (apply Cora Z7-07S preset if available).
   - `Processor System Reset`.
   - `AXI Interconnect` (1 slave, 1 master) or `SmartConnect`.
   - `add_const_axi` (our IP, `user/user/add_const_axi/1.0`).

2. *Run Connection Automation* on the green banner; tick every entry.
   Expected wiring:

   | Source                                  | Destination                                                                                |
   |-----------------------------------------|--------------------------------------------------------------------------------------------|
   | `processing_system7_0/FCLK_CLK0`        | every `aclk` (PS `M_AXI_GP0_ACLK`, interconnect `ACLK / S00_ACLK / M00_ACLK`, `add_const_axi_0/s00_axi_aclk`, `proc_sys_reset_0/slowest_sync_clk`) |
   | `processing_system7_0/FCLK_RESET0_N`    | `proc_sys_reset_0/ext_reset_in`                                                            |
   | `proc_sys_reset_0/interconnect_aresetn` | `axi_interconnect_0/ARESETN`                                                               |
   | `proc_sys_reset_0/peripheral_aresetn`   | `axi_interconnect_0/S00_ARESETN`, `axi_interconnect_0/M00_ARESETN`, `add_const_axi_0/s00_axi_aresetn` |

3. **Data path.**

   | Source                              | Destination                       |
   |-------------------------------------|-----------------------------------|
   | `processing_system7_0/M_AXI_GP0`    | `axi_interconnect_0/S00_AXI`      |
   | `axi_interconnect_0/M00_AXI`        | `add_const_axi_0/s00_axi`         |

4. **Address Editor.** Assign `add_const_axi_0/S00_AXI` at
   `0x4300_0000` or `0x43C0_0000` (any 4K-aligned slot in the PS GP0
   range works). Default in `scripts/create_bd.tcl` is `0x43C0_0000`.

5. *Validate Design*. *Generate Output Products*. *Create HDL Wrapper*.
6. Set `add_const_wrapper` as the top module.

Optional helper for steps 1-6:

```tcl
source scripts/create_bd.tcl
```

## 5. Bitstream + XSA Export (3 pts)

After the wrapper is the top module:

```tcl
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

file mkdir xsa
write_hw_platform -fixed -include_bit -force -file xsa/add_const.xsa
```

The exported file `xsa/add_const.xsa` is the deliverable for part 3.

## 6. Vitis Test App (Optional)

> The Vitis test-app result is **not** required for the quiz, but `sw/main.c`
> is provided to exercise the IP over UART after the XSA is loaded.

Steps (Vitis 2025.2 Unified IDE; same flow as Homework 3 / 4):

1. *File -> New Component -> Platform Component*; point at
   `xsa/add_const.xsa`. Use `standalone` OS and the Cora Z7-07S preset (or
   default `ps7_cortexa9_0`). Name the platform `add_const_platform`.
2. *File -> New Component -> Application Component*; name it
   `add_const_app`, pick the platform above, choose `Empty Application
   (C)`, processor `ps7_cortexa9_0`.
3. In `add_const_app/src/`, add the file `sw/main.c` from this folder
   (Vitis -> *Import Sources*, or `cp Quiz_2/real/sw/main.c
   <ws>/add_const_app/src/`).
4. *Build* the application. Connect the Cora Z7-07S over the USB-UART
   bridge, open *Vitis Serial Monitor* at `115200 8N1` on the right
   `/dev/ttyUSB*` (Linux) or `COM*` (Windows), then *Run -> Launch
   Hardware (Single Application Debug)*.

Expected console output (boxed banner; widths defined in `sw/main.c`):

```text
+==============================================================+
|                  ECEC 661 / 402  Quiz 2                      |
|             Add Constant -1   AXI4-Lite Custom IP            |
|                                                              |
|              IP base address : 0x43C00000                    |
+==============================================================+

  Register map
  ------------
    0x00  X_IN   R/W   32-bit signed input
    0x04  Z_OUT  R     z = x + (-1) = x - 1

  IP test vectors  (z expected = x - 1)
+-----+--------------+------------+--------------+------------+--------+
|  #  |   x (dec)    |  x (hex)   |    z (dec)   |  z (hex)   | check  |
+-----+--------------+------------+--------------+------------+--------+
|   0 |          -5  | 0xFFFFFFFB |          -6  | 0xFFFFFFFA |  [OK]  |
|   1 |          -4  | 0xFFFFFFFC |          -5  | 0xFFFFFFFB |  [OK]  |
|   2 |          -3  | 0xFFFFFFFD |          -4  | 0xFFFFFFFC |  [OK]  |
|   3 |          -2  | 0xFFFFFFFE |          -3  | 0xFFFFFFFD |  [OK]  |
|   4 |          -1  | 0xFFFFFFFF |          -2  | 0xFFFFFFFE |  [OK]  |
|   5 |           0  | 0x00000000 |          -1  | 0xFFFFFFFF |  [OK]  |
|   6 |           1  | 0x00000001 |           0  | 0x00000000 |  [OK]  |
|   7 |           2  | 0x00000002 |           1  | 0x00000001 |  [OK]  |
|   8 |           3  | 0x00000003 |           2  | 0x00000002 |  [OK]  |
|   9 |         100  | 0x00000064 |          99  | 0x00000063 |  [OK]  |
|  10 |       -1000  | 0xFFFFFC18 |       -1001  | 0xFFFFFC17 |  [OK]  |
|  11 |  2147483647  | 0x7FFFFFFF |  2147483646  | 0x7FFFFFFE |  [OK]  |
|  12 | -2147483648  | 0x80000000 |  2147483647  | 0x7FFFFFFF |  [OK]  |
+-----+--------------+------------+--------------+------------+--------+

+==============================================================+
|         Summary : 13 / 13 PASSED  (0 failed)                 |
|         RESULT  : add_const_axi behaves correctly            |
+==============================================================+
```

Vector `#12` exercises the signed-wrap case at `INT32_MIN`: the IP computes
`-2147483648 + (-1)` modulo `2^32`, which is `0x7FFFFFFF` (= `INT32_MAX`).

### Troubleshooting

If the serial monitor stops after the table header (no rows printed), the
first `Xil_Out32` to the IP is hanging or hitting a data abort. The app
prints a `Probing IP at 0x...` smoke test before the table; use it to
narrow down the cause:

| Symptom                                                | Cause / Fix                                                                                       |
|--------------------------------------------------------|---------------------------------------------------------------------------------------------------|
| Hangs *before* the probe banner                        | Bitstream not programmed or platform out of date. Right-click the platform component -> *Build*, then re-launch the app. |
| `*** AXI probe FAILED ***` shown                       | Wrong base address, missing reset, or interconnect not wired. See checks below.                   |
| `XPAR_ADD_CONST_AXI_0_S00_AXI_BASEADDR not found` warn | Vitis is using the fallback `0x43C00000`. Rebuild the platform from the new XSA so `xparameters.h` is regenerated. |

Quick checks in Vivado before re-exporting the XSA:

1. **Validate Design** is green and **Address Editor** shows
   `add_const_axi_0/S00_AXI/Reg` mapped at `0x43C0_0000`, range `4K`,
   under `processing_system7_0/Data`.
2. `processing_system7_0/FCLK_CLK0` drives every `aclk` (PS, interconnect,
   reset block, custom IP).
3. `proc_sys_reset_0/peripheral_aresetn` drives
   `add_const_axi_0/s00_axi_aresetn` *and* the interconnect resets.
4. `add_const_axi_0` shows the `s00_axi` AXI4-Lite interface (not just
   raw ports) - if it appears as scalar pins, re-package the IP with
   `scripts/package.tcl` so the bus interface is inferred.
5. After fixing, regenerate the XSA:
   ```tcl
   write_hw_platform -fixed -include_bit -force -file xsa/add_const.xsa
   ```
   Then in Vitis right-click the platform -> *Update Hardware Specification*
   and rebuild.

## 7. What To Hand In

- `rtl/user_logic.vhd` (deliverable: user-logic VHDL code).
- `rtl/add_const_axi_v1_0_S00_AXI.vhd` (deliverable: `S_AXI` code with the
  user-logic component instantiation and port map; see the `U_LOGIC :
  user_logic port map (...)` block).
- A screenshot of the validated block design.
- The exported `xsa/add_const.xsa`.
- The xsim simulation snippet (waveform with `x`/`z` in signed decimal,
  console showing the `[PASS]` / `TESTBENCH PASSED` banner).

Optional (not required for the quiz):

- `sw/main.c` (Vitis bare-metal test app).
- PuTTY/Vitis Serial Monitor screenshot of the boxed test-app output.
