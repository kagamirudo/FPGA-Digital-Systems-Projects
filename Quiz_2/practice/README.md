# Quiz 2 Practice - Custom IP Flow

Practice target based on the Quiz 2 preparation note:

- write/simulate custom `user_logic`
- wrap it as an AXI4-Lite custom IP
- package the IP
- build a block diagram with Zynq PS + the custom IP
- export an `.xsa`
- no Vitis app and no FPGA board required

This practice uses a small 8-entry stack as the user logic because it is close
to the stack-processor topic mentioned before the quiz, but still small enough
to finish quickly.

## Layout

```
Quiz_2/practice/
  rtl/
    user_logic.vhd                         - custom stack user logic
    stack_practice_axi_v1_0_S00_AXI.vhd    - AXI4-Lite register map
    stack_practice_axi_v1_0.vhd            - packager top level
  tb/
    tb_user_logic.vhd                      - user-logic-only self-checking TB
  docs/
    register_map.md                        - AXI offsets and command bits
  scripts/
    setup.tcl                              - add sources and set tops
    package.tcl                            - IP Packager metadata helper
    create_bd.tcl                          - optional block-design helper
```

## 1. Create / Open Vivado Project

Create a new RTL project in `Quiz_2/practice/`.

- Project name: `q2_practice` or `quiz2_practice`
- Part: `xc7z007sclg400-1` (Cora Z7-07S), or any Zynq-7000 part if you only
  need the block diagram and XSA practice.
- Do not copy sources into the project.

In the Tcl console:

```tcl
cd [file dirname [get_property DIRECTORY [current_project]]]
source scripts/setup.tcl
```

The script adds the RTL/TB files, sets the simulation top to `tb_user_logic`,
and sets the design top to `stack_practice_axi_v1_0`.

## 2. Simulate User Logic

Run behavioral simulation and type:

```tcl
run all
```

Expected console shape:

```text
[PASS] reset count = 0
[PASS] reset empty = '1'
[PASS] count after three pushes = 3
[PASS] pop returns newest word = 51
[PASS] second pop returns next word = 34
[PASS] pop from empty sets error = '1'

+--------------------------------------------------+
|       user_logic stack practice - summary        |
+--------------------------------------------------+
   checks executed : 14
   errors          : 0
+--------------------------------------------------+
```

Wave signals to add:

```tcl
add_wave /tb_user_logic/ck /tb_user_logic/resetn
add_wave /tb_user_logic/cmd_valid /tb_user_logic/cmd
add_wave -radix hex /tb_user_logic/data_in /tb_user_logic/data_out
add_wave -radix unsigned /tb_user_logic/count
add_wave /tb_user_logic/empty /tb_user_logic/full /tb_user_logic/error
restart
run all
```

## 3. Package The Custom IP

1. `Tools -> Create and Package New IP`.
2. Choose `Package your current project`.
3. IP location:

   ```text
   Quiz_2/practice/ip_repo/stack_practice_axi_1.0
   ```

4. When the IP Packager project opens, run:

   ```tcl
   source scripts/package.tcl
   ```

5. Check these pages in the IP Packager:
   - `Identification`: name should be `stack_practice_axi`, version `1.0`.
   - `File Groups`: VHDL files are present.
   - `Ports and Interfaces`: `s00_axi` is inferred as AXI4-Lite.
   - `Review and Package`: click `Re-Package IP`.

6. Close the packager project and reopen the main `Quiz_2/practice` project.
7. Add the repository:

   ```tcl
   set_property ip_repo_paths [list [file normalize ip_repo]] [current_project]
   update_ip_catalog
   ```

## 4. Build The Block Diagram

Create block design `stack_practice`.

Add these blocks:

- `ZYNQ7 Processing System`
- `Processor System Reset`
- `AXI Interconnect` or `SmartConnect`
- `stack_practice_axi` from `UserIP`

Use `Run Connection Automation` for the Zynq PS and AXI connections. The final
shape should be:

| Source | Destination |
|--------|-------------|
| `processing_system7_0/M_AXI_GP0` | interconnect slave side |
| interconnect master side | `stack_practice_axi_0/s00_axi` |
| `processing_system7_0/FCLK_CLK0` | all AXI clocks and reset block clock |
| `proc_sys_reset_0/peripheral_aresetn` | `stack_practice_axi_0/s00_axi_aresetn` and interconnect resets |

Address Editor:

- Assign `stack_practice_axi_0/S00_AXI`
- Offset: `0x43C0_0000`
- Range: `4K`

Then:

1. `Validate Design`.
2. `Generate Output Products`.
3. `Create HDL Wrapper`.
4. Set `stack_practice_wrapper` as top.

Optional helper:

```tcl
source scripts/create_bd.tcl
```

Use the GUI checklist above if the helper script differs from the lab machine's
Vivado automation rules.

## 5. Export XSA

For quiz practice, the important part is knowing where the command lives and
what file is produced. After the block design wrapper exists, run synthesis and
implementation if your instructor expects a fully built hardware platform.

Then export:

```tcl
file mkdir xsa
write_hw_platform -fixed -force -file xsa/stack_practice.xsa
```

If the quiz asks for bitstream included:

```tcl
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
write_hw_platform -fixed -include_bit -force -file xsa/stack_practice.xsa
```

## What To Be Ready To Explain

- Which file is the pure user logic: `rtl/user_logic.vhd`.
- Which file maps software registers to user logic: `rtl/stack_practice_axi_v1_0_S00_AXI.vhd`.
- Why `s00_axi_aclk` needs `FREQ_HZ`, `ASSOCIATED_BUSIF`, and `ASSOCIATED_RESET` in packaging.
- What blocks are needed in the diagram: Zynq PS, reset, interconnect, custom IP.
- What `.xsa` contains: exported hardware platform metadata for the block design.
