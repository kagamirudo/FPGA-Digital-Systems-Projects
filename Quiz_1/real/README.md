# Quiz 1 (real) - RAM-based Shift Register IP

**ECEC 402/661 Quiz 1 (50 min)** - Simulate the Vivado IP-Catalog
**RAM-based Shift Register** (c_shift_ram v12.0) configured as:

- 4-bit wide input `x`, 4-bit wide output `z`
- Depth = 6 (`z` lags `x` by six rising edges of `ck`)
- Clock enable `ce` and synchronous clear `sclr` enabled

Deliverable: HDL code + a simulation snip showing the 6-cycle delay and
that `ce` / `sclr` behave correctly.

## Required entity (verbatim from the hand-out)

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity user_logic is
    port (
        x            : in  std_logic_vector(3 downto 0);
        ck, ce, sclr : in  std_logic;
        z            : out std_logic_vector(3 downto 0)
    );
end user_logic;
```

Implemented in [user_logic.vhd](user_logic.vhd) as a thin wrapper around
`c_shift_ram_0`:

```vhdl
U_SR : c_shift_ram_0
    port map (D => x, CLK => ck, CE => ce, SCLR => sclr, Q => z);
```

## IP Catalog configuration

| Setting                  | Value                          |
|--------------------------|--------------------------------|
| Shift Register Type      | Fixed Length                   |
| Width                    | 4                              |
| Depth                    | 6                              |
| Clock Enable (CE)        | enabled                        |
| Synchronous Clear (SCLR) | enabled                        |
| Async Init Value         | 0 (hex `0`)                    |
| Sync Init Value          | 0 (hex `0`)                    |
| Default Data             | 0 (hex `0`)                    |
| Memory Type              | Auto (IP picks SRL / RAM / BRAM) |

The Tcl side is automated in [scripts/setup.tcl](scripts/setup.tcl).

## Layout

```
Quiz_1/real/
  user_logic.vhd              - entity + architecture wrapping c_shift_ram_0
  tb/tb_user_logic.vhd        - self-checking TB (VHDL-2008), 11 checks
  scripts/setup.tcl           - generates c_shift_ram_0 and wires up sources
  q1_real/                    - existing Vivado project (q1_real.xpr)
  README.md                   - this file
```

## Manual Vivado setup (no Tcl - the quiz-time flow)

### A. Open / create the project

- Double-click `q1_real/q1_real.xpr` if it already exists (a stub
  project is checked in so the part is already correct), **or** create a
  new **RTL Project** with part `xc7z007sclg400-1` (Cora Z7-07S). Any
  7-series part works, the design only needs to simulate.

### B. Generate `c_shift_ram_0` from the IP Catalog

1. **Flow Navigator -> Project Manager -> IP Catalog**.
2. Search `shift ram`. Double-click **RAM-based Shift Register** under
   `Memories & Storage Elements -> RAMs & ROMs & BRAM` (VLNV
   `xilinx.com:ip:c_shift_ram:12.0`).
3. In the customization window set:
   - **Component Name**: `c_shift_ram_0` (exact).
   - *Shift Register Type*: **Fixed Length**.
   - *Width*: `4`.
   - *Depth*: `6`.
   - Check **Clock Enable**.
   - Check **Synchronous Clear**.
   - Leave Async/Sync/Default init values at `0`.
4. Click **OK**. When prompted, **Generate Output Products** -> *Global*
   synthesis -> **Generate**. Wait for the out-of-context run to finish.
5. Verify: **Sources -> IP Sources -> c_shift_ram_0.xci** has a green
   check, and its port list shows `D[3:0]`, `CLK`, `CE`, `SCLR`,
   `Q[3:0]`.

### C. Add the two HDL files

1. **Add Sources -> Add or create design sources -> Add Files**
   -> pick `user_logic.vhd`. Uncheck *Copy sources into project*.
2. **Add Sources -> Add or create simulation sources -> Add Files**
   -> pick `tb/tb_user_logic.vhd`. Uncheck *Copy sources into project*.

### D. Set VHDL dialect on the testbench

1. In **Sources**, expand **Simulation Sources (sim_1)**.
2. Right-click `tb_user_logic.vhd` -> **Source Node Properties**.
3. Change **Type** from `VHDL` to **`VHDL 2008`** (for `std.textio.LF`
   in the summary banner).
4. Leave `user_logic.vhd` as plain `VHDL`.

### E. Set the top modules

- Design Sources: right-click `user_logic` -> **Set as Top**.
- Simulation Sources: right-click `tb_user_logic` -> **Set as Top**.

### F. Run the behavioral simulation

**Flow Navigator -> Simulation -> Run Behavioral Simulation**.
In the xsim Tcl console type `run all`.

Expected end-of-run:

```
[PASS] post-SCLR init z=0
[PASS] latency step 1 (z=x[-6]=1)  z=1
[PASS] latency step 2 (z=x[-6]=2)  z=2
[PASS] latency step 3 (z=x[-6]=3)  z=3
[PASS] latency step 4 (z=x[-6]=4)  z=4
[PASS] latency step 5 (z=x[-6]=5)  z=5
[PASS] latency step 6 (z=x[-6]=6)  z=6
[PASS] CE=0 holds z=6 for 3 edges  z=6
[PASS] CE restored, 9 reaches z after 6 edges  z=9
[PASS] pre-SCLR: pipeline full of 0xF  z=15
[PASS] SCLR clears z to 0 in one edge  z=0

+--------------------------------------------------+
|          tb_user_logic - test summary            |
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

### Waveform snip for the hand-in

Add `x`, `z`, `ce`, `sclr`, `ck` to the wave pane (right-click the
signals in the Scope / Objects pane -> *Add to Wave Window*). Set `x`
and `z` to **Unsigned Decimal** (right-click -> *Radix -> Unsigned
Decimal*) to make the 6-cycle pipeline visible at a glance.

Things the grader will look for in the waveform:

| Time region                    | Expected behaviour                                 |
|--------------------------------|----------------------------------------------------|
| After initial `sclr=1` pulse   | `z = 0`                                            |
| Six edges after `x=1,2,..,6`   | `z` starts outputting `1`, then `2,3,4,5,6`        |
| While `ce = 0`                 | `z` frozen, clock edges have no effect             |
| After `sclr = 1` for one edge  | `z` instantly drops back to `0` regardless of `x`  |

## Tcl alternative (if Tcl console is allowed during the quiz)

```tcl
cd [file dirname [get_property DIRECTORY [current_project]]]/..
source scripts/setup.tcl
```

Force a fresh IP regeneration after a config tweak:

```tcl
set ::env(QUIZ1_REAL_FORCE_IP) 1
source scripts/setup.tcl
unset ::env(QUIZ1_REAL_FORCE_IP)
```

## Quiz-time tips

- **"top is empty" warning** appears if you try to simulate before
  `user_logic.vhd` is set as Design Sources top and the IP has finished
  generating. Do B before F.
- **Unknown `CONFIG.*` name** in the Tcl script: not fatal - it just
  prints `(warn) could not set CONFIG.X = Y`. The IP defaults will
  still be sensible; finish the GUI customization dialog instead.
- **`z` shows all X in the wave** after elaboration: the IP black box
  wasn't generated yet. Run `generate_target` or right-click
  `c_shift_ram_0.xci -> Generate Output Products`.
- **Sanity check before Run Simulation**: Sources pane shows
  `user_logic.vhd` (Design), `tb_user_logic.vhd` (Simulation),
  `c_shift_ram_0` (IP Sources, green check).
