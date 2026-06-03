# ECEC 661 Final (real) - SP101 + `ssq` ("stack the square")

This folder is the final-exam solution for the `ssq` extension to Stack
Processor 101.  The prompt lives in [`prob.md`](prob.md); all source
artifacts live under [`stackprocessor_101/`](stackprocessor_101).

## Prompt recap

> New instruction on the sp101, `ssq` "stack the square".  After
> executing, for example
>
>     sc 7  ssq  halt
>
> sp101 shall write 49 on the stack and the stack pointer points to
> the next available address location.

## Programming model for `ssq`

`ssq` is a unary stack-arithmetic instruction:

```text
... x   --ssq-->   ... (x*x)
```

Stack pointer is unchanged (one pop, one push).  Because the FSM
initialises `sp = 128` in `idle`, the canonical program

```text
sc 7   ssq   halt
```

leaves `mem[128] = 49` and `sp = 129` (= next available address).

Opcode: `0x00000041` (slots into the unused `0x4x` family between
`sadd = 0x31` and `scp = 0x101`, so no other decoder constants move).

## Deliverables map

| Prompt deliverable (`prob.md`)                            | Artifact in this folder                                            |
|-----------------------------------------------------------|---------------------------------------------------------------------|
| Part 1 - simulate correctness of `ssq` (10 pts)           | [`stackprocessor_101/tb/tb_user_logic.vhd`](stackprocessor_101/tb/tb_user_logic.vhd) + Vivado sim wave (capture per Part 1 instructions below) |
| Part 2 - custom IP user logic (5 pts): component decl + port map | [`stackprocessor_101/rtl/sp101_axi_v1_0_S00_AXI.vhd`](stackprocessor_101/rtl/sp101_axi_v1_0_S00_AXI.vhd) (see snippet below) and [`stackprocessor_101/rtl/user_logic.vhd`](stackprocessor_101/rtl/user_logic.vhd) |
| Part 3.1 - FPGA dev block diagram (3 pts)                 | Vivado BD `sp101.bd` (`Homework_5/sp101/sp101.bd` for layout reference); export PNG into a `figures/` folder when capturing |
| Part 3.2 - C test app (3 pts)                             | [`stackprocessor_101/sw/main.c`](stackprocessor_101/sw/main.c)      |
| Part 3.3 - serial terminal snip (4 pts), address 128 = square | Run the C app, capture `picocom` / Vitis serial monitor output. Expected line: `address 128 = 0x00000031  (expected 0x00000031 = 49)  PASS` |

## Part 1 - simulation (10 pts)

1. In Vivado 2025.2 open (or reuse) the Homework 5 project
   `Homework_5/sp101/sp101.xpr`.
2. Add the Final RTL/TB into the project (or repoint sources):

   ```tcl
   set ROOT /path/to/ECEC661/Final/real/stackprocessor_101
   add_files -fileset sources_1 \
       $ROOT/rtl/bus_ip_mem_bridge.vhd \
       $ROOT/rtl/user_logic.vhd \
       $ROOT/rtl/sp101_axi_v1_0_S00_AXI.vhd \
       $ROOT/rtl/sp101_axi_v1_0.vhd
   add_files -fileset sim_1 $ROOT/tb/tb_user_logic.vhd
   set_property FILE_TYPE {VHDL 2008} [get_files tb_user_logic.vhd]
   set_property TOP tb_user_logic    [get_filesets sim_1]
   set_property TOP sp101_axi_v1_0   [get_filesets sources_1]
   update_compile_order -fileset sources_1
   update_compile_order -fileset sim_1
   ```

3. **Run Simulation -> Run Behavioral Simulation**, then in the xsim Tcl
   console load the pre-made wave script (decimal radix on data paths):

   ```tcl
   source /path/to/ECEC661/Final/real/stackprocessor_101/scripts/sim_waves.tcl
   restart
   run all
   ```

   The script uses `-radix unsigned` on `bus2mem_data_in`, `sp2bus_data_out`,
   `temp1`, `mem_data_in`, and `mem_data_out` so you see `7 -> 49` directly
   instead of hex.  Opcodes in `ir` stay hex because they are not numeric data.

   **Test vectors** (12 cases, same in TB and C app):

   | x | x² |
   |---|-----|
   | 7 | 49 |
   | 0 | 0 |
   | 1 | 1 |
   | 2 | 4 |
   | 3 | 9 |
   | 10 | 100 |
   | 15 | 225 |
   | 16 | 256 |
   | 255 | 65025 |
   | 1000 | 1000000 |
   | 32767 | 1073676289 |
   | 46340 | 2147395600 |

   Expected terminal banner:

   ```
   +--------------------------------------------------+
   |     sp101 + ssq  stack-the-square TB summary     |
   +--------------------------------------------------+
      checks executed : 12
      errors          : 0
   +--------------------------------------------------+

   ####################################################
   ##        TESTBENCH  PASSED  -  all cases ok      ##
   ####################################################
   ```

   Each `[PASS]` line prints decimal first, e.g.
   `got=49 expected=49 (0x00000031)`.

4. Capture the wave window (File -> Export -> Image, or screenshot) for
   submission.  Zoom out so all twelve scenarios are visible and `checks`
   reaches **12** / `errors` stays **0**.  Save into `Final/real/figures/sim.png`.

## Part 2 - user logic IP (5 pts)

The required `component declaration` and `port map` for the `user_logic`
instantiation inside the IP wrapper live at the top of
[`stackprocessor_101/rtl/sp101_axi_v1_0_S00_AXI.vhd`](stackprocessor_101/rtl/sp101_axi_v1_0_S00_AXI.vhd).
The relevant slice (lines ~101-151) is reproduced below for the report:

```vhdl
component user_logic
    generic (
        A : natural := 10
    );
    port (
        run             : in  std_logic;
        reset           : in  std_logic;
        bus2mem_en      : in  std_logic;
        bus2mem_we      : in  std_logic;
        ck              : in  std_logic;
        bus2mem_addr    : in  std_logic_vector(A-1 downto 0);
        bus2mem_data_in : in  std_logic_vector(31 downto 0);
        sp2bus_data_out : out std_logic_vector(31 downto 0);
        done            : out std_logic
    );
end component;
...
U : user_logic
    generic map (
        A => 10
    )
    port map (
        run             => slv_reg0(0),
        reset           => slv_reg0(1),
        bus2mem_en      => slv_reg0(2),
        bus2mem_we      => slv_reg0(3),
        ck              => S_AXI_ACLK,
        bus2mem_addr    => slv_reg1(9 downto 0),
        bus2mem_data_in => slv_reg2,
        sp2bus_data_out => core_sp2bus_data_out,
        done            => core_done
    );
```

The control bits are sliced directly out of `slv_reg0`; `bus2mem_addr`
takes the lower 10 bits of `slv_reg1`; `bus2mem_data_in` is the full 32
bits of `slv_reg2`; `sp2bus_data_out` and `done` feed the read mux
(`slv_reg3` and `slv_reg4`).

After RTL changes, re-package the IP from the Vivado packager Tcl
console:

```tcl
cd /path/to/ECEC661/Final/real/stackprocessor_101
source scripts/package.tcl
# then click Review and Package -> Re-Package IP
```

## Part 3 - FPGA dev test bench

### 3.1 Block diagram (3 pts)

Use the existing Homework 5 block design (`Homework_5/sp101/sp101.bd`)
as the reference layout:

- Zynq PS (Cora preset, UART0 on MIO 14/15, FCLK_CLK0 = 100 MHz),
- `Processor System Reset`,
- `AXI Interconnect` (1 slave / 1 master),
- `sp101_axi_0` from the repacked IP.

Address Editor: `sp101_axi_0` at offset **`0x43C3_0000`**, range 4 KB
(matches `XPAR_SP101_AXI_0_S00_AXI_BASEADDR` in `sw/main.c`).  Validate
-> Generate Output Products -> Create HDL Wrapper -> Generate Bitstream
-> Export Hardware (include bitstream) -> `sp101_wrapper.xsa`.  Save the
BD screenshot into `Final/real/figures/diagram.png`.

### 3.2 C test app (3 pts)

The bare-metal app is [`stackprocessor_101/sw/main.c`](stackprocessor_101/sw/main.c).
It loads `sc x ssq halt` into BRAM, polls `done`, reads `mem[128]`, and
prints a clear PASS / FAIL line per scenario (including the prompt's
`x = 7`).  In Vitis Unified 2025.2:

1. Create a platform component from `sp101_wrapper.xsa`
   (`standalone` on `ps7_cortexa9_0`).
2. Create an application component (`sp101_ssq`) - Empty Application or
   Hello World.
3. Replace the app's `main.c` with this file (copy or symlink).
4. BSP: `standalone_stdin` / `standalone_stdout` -> `ps7_uart_0`, then
   Regenerate BSP.
5. Build platform, then build the app.

### 3.3 Serial terminal snip (4 pts)

Connect to the Cora UART (`/dev/ttyUSB1` on Linux is common) BEFORE
clicking Run:

```bash
picocom /dev/ttyUSB1 -b 115200 --imap lfcrlf
```

Expected output (capture screenshot for `Final/real/figures/vitis.png`):

```
==========================================================
   ECEC 661 FINAL - Stack Processor 101 + ssq
   IP base address : 0x43c30000
==========================================================

---- Scenario: ssq x=7 -> 49 ----
  program : sc 7  ssq  halt
    address 128 = 49  (expected 49 = 7^2)  PASS
                  hex: got=0x00000031  expect=0x00000031

---- Scenario: ssq x=0 -> 0 ----
  ...

---- Scenario: ssq x=46340 -> 2147395600 ----
  program : sc 46340  ssq  halt
    address 128 = 2147395600  (expected 2147395600 = 46340^2)  PASS
                  hex: got=0x7fffd210  expect=0x7fffd210

----------------------------------------------------------
   Summary : 12/12 scenarios PASSED
----------------------------------------------------------
```

The first scenario alone satisfies the prompt's "address 128 contains
the square" requirement; the other eleven vectors cover edge cases and
wider operand ranges.

## Tree

```
Final/real/
  prob.md                          # the assignment one-pager
  README.md                        # this file (deliverables map)
  stackprocessor_101/
    rtl/
      bus_ip_mem_bridge.vhd        # bus/IP -> BRAM port mux
      user_logic.vhd               # sp101 core + ssq FSM (NEW opcode)
      sp101_axi_v1_0_S00_AXI.vhd   # AXI4-Lite slave (5 regs) + user_logic inst
      sp101_axi_v1_0.vhd           # IP top wrapper
    tb/
      tb_user_logic.vhd            # self-checking VHDL-2008 TB
    sw/
      main.c                       # bare-metal Vitis test app
    docs/
      register_map.md              # registers, opcodes, ssq micro-steps
    scripts/
      setup.tcl                    # blk_mem_gen_0 + add sources
      package.tcl                  # IP packager metadata + sub-core ref
      sim_waves.tcl                # xsim waves with decimal data-path radix
```
