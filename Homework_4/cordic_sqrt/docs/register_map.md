# `cordic_sqrt_axi` register map

The IP presents a 16-byte, four-register AXI4-Lite slave.  All four registers
are software visible.  The base address is assigned by the Vivado Address
Editor; Vitis exposes it as `XPAR_CORDIC_SQRT_AXI_0_S00_AXI_BASEADDR`.

| Offset | Name        | Access | Width  | Description                                                    |
|-------:|-------------|:------:|:------:|----------------------------------------------------------------|
| `0x00` | `slv_reg0`  | R/W    | 32 bit | `x` input.  Lower 10 bits used = 2Q7 unsigned fraction.        |
| `0x04` | `slv_reg1`  | R/W    | 32 bit | Bit 0 = `din_tvalid` to the CORDIC AXI-stream slave port.      |
| `0x08` | `slv_reg2`  | R      | 32 bit | `z` output.  Lower 10 bits valid = 1Q8 unsigned fraction.      |
| `0x0C` | `slv_reg3`  | R      | 32 bit | Bit 0 = `dout_tvalid` from the CORDIC AXI-stream master port.  |

The mapping is the one referenced by the assignment's C-snippet directly:

```c
CORDIC_SQRT_mWriteReg(BASEADDR, 0,  test_vector[i]);   // slv_reg0 = x
CORDIC_SQRT_mWriteReg(BASEADDR, 4,  1);                // din_tvalid = slv_reg1(0)
while (!CORDIC_SQRT_mReadReg(BASEADDR, 12));           // dout_tvalid = slv_reg3(0)
CORDIC_SQRT_mWriteReg(BASEADDR, 4,  0);                // lower din_tvalid
xil_printf("sqrt(0x%X) = 0x%X\r\n",
           CORDIC_SQRT_mReadReg(BASEADDR, 0),          // x readback
           CORDIC_SQRT_mReadReg(BASEADDR, 8));         // slv_reg2 = z
```

## Register-bit-to-port mapping inside `user_logic`

The slave (`cordic_sqrt_axi_v1_0_S00_AXI.vhd`) wires its registers to the
`user_logic` instance, which in turn is just a thin wrapper over the Vivado
IP-Catalog `cordic_0` (Square Root, 10-bit unsigned fraction):

```vhdl
core_x <= slv_reg0(15 downto 0);

U : user_logic
    port map (
        ck          => S_AXI_ACLK,
        aresetn     => S_AXI_ARESETN,
        din_tvalid  => slv_reg1(0),
        x           => core_x,
        dout_tvalid => core_dout_tv,
        z           => core_z
    );
```

The read mux drives `core_z` and `core_dout_tv` straight onto offsets `0x08`
and `0x0C` respectively:

```vhdl
case loc_addr is
    when "00" => reg_data_out <= slv_reg0;
    when "01" => reg_data_out <= slv_reg1;
    when "10" => reg_data_out <= (31 downto 16 => '0') & core_z;
    when "11" => reg_data_out <= (31 downto 1  => '0') & core_dout_tv;
end case;
```

Writes to `0x08` (`z`) and `0x0C` (`dout_tvalid`) are dropped by design: the
write decoder only matches `"00"` and `"01"`, and there is no register
storage behind `slv_reg2` / `slv_reg3` because their values are driven
combinationally by the CORDIC core.

## Q-format reminders

- `x` is **2Q7** unsigned: 10 bits, scale factor `2^-7`, so `0x080 = 1.0`,
  `0x040 = 0.5`, `0x008 = 1/16`.
- `z` is **1Q8** unsigned: 10 bits, scale factor `2^-8`, so `0x100 = 1.0`,
  `0x0B5 = 0.707`, `0x040 = 0.25`.
- The CORDIC IP truncates the result (Round Mode = Truncate).  The 0.707
  result for `sqrt(0.5)` therefore comes back as `0xB5 / 256 = 0.7070...`,
  which matches the assignment's expected vector.

## Software handshake summary

```
write  slv_reg0 = x        ; sample (lower 10 bits)
write  slv_reg1 = 1        ; raise din_tvalid for one or more cycles
loop until slv_reg3 == 1   ; pipeline-depth wait (~13-15 aclk)
write  slv_reg1 = 0        ; lower din_tvalid
read   slv_reg2            ; sqrt(x) in 1Q8
```

## Address space

The recommended assigned base address is `0x43C2_0000` with a `4 KB` range,
i.e. `0x43C2_0000 .. 0x43C2_0FFF`.  This sits one 64 KB aperture above the
Homework 3 `fix_acc_axi` IP at `0x43C1_0000`, so the same PL image can host
both peripherals if desired.
