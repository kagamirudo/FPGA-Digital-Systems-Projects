# ECEC 661/402 - Quiz 2

> **Problem.** Create a custom AXI-Lite IP using the IP-catalog
> **Adder/Subtractor** (`c_addsub`). Configure the IP with a **constant
> input** of `-1`. The data is **32-bit signed** with **no CE** (clock
> enable). The user-logic effectively computes `z = x + (-1) = x - 1`.

Original hand-out: `docs/quiz2_problem.png`.

## IP Catalog Configuration

`xilinx.com:ip:c_addsub:12.0`, with these settings (Basic tab):

| Setting               | Value                                  |
|-----------------------|----------------------------------------|
| Component Name        | `c_addsub_0`                           |
| Implementation        | Fabric                                 |
| Add Mode              | Add                                    |
| A: Input Type         | Signed                                 |
| A: Input Width        | `32`                                   |
| B: Input Type         | Signed                                 |
| B: Input Width        | `32`                                   |
| B: **Constant Input** | checked                                |
| B: Constant Value (Bin) | `11111111111111111111111111111111` (= -1) |
| Output Width          | `32`                                   |
| Latency Configuration | Manual                                 |
| Latency               | `0` (combinational)                    |
| Clock Enable (CE)     | unchecked                              |

IP block symbol exposes only `A[31:0]` -> `S[31:0]`; `B` is internal.

## Deliverables

| # | Description                                                                                              | Pts |
|---|----------------------------------------------------------------------------------------------------------|-----|
| 1 | User-logic project with simulation verifying the correctness of the add-(-1) logic.                      | 4   |
| 2 | Package the user logic as an AXI4-Lite IP.                                                                | 3   |
| 3 | Test-bench project with the custom AXI-Lite IP as a peripheral of the Zynq processor; generate the bitstream and export the `.xsa` file. | 3   |

**Hand in:** user-logic VHDL code, `S_AXI` code (with the `user_logic`
component declaration / port map), and a screenshot of the block diagram.
**The Vitis test app result is NOT part of the quiz.**

## Reference Test Vectors (from the printed PuTTY screen)

```
add const -1 IP TestApp
x = -5  : z = -6
x = -4  : z = -5
x = -3  : z = -4
x = -2  : z = -3
x = -1  : z = -2
x =  0  : z = -1
x =  1  : z =  0
x =  2  : z =  1
x =  3  : z =  2
```

These vectors are reproduced by `tb/tb_user_logic.vhd` for the simulation
deliverable.
