# `fix_acc_axi` register map

The IP presents a 16-byte, four-register AXI4-Lite slave; three of the four
registers are software visible (the fourth is reserved).  The base address is
assigned by the Vivado Address Editor; Vitis exposes it as
`XPAR_FIX_ACC_AXI_0_S00_AXI_BASEADDR`.

| Offset | Name   | Access | Description |
|-------:|--------|:------:|-------------|
| `0x00` | `B_IN` | R/W    | 32-bit signed accumulator input.  Writing this register advances the accumulator by the written value. |
| `0x04` | `Q_OUT`| R      | 32-bit signed accumulator output.  AXI writes to this address are ignored. |
| `0x08` | `CTRL` | R/W    | Bit 0 = `SCLR`.  Pulse `1` then `0` to synchronously zero the accumulator. |
| `0x0C` |   -    | -      | Reserved.  Reads as `0`, writes ignored. |

## How the accumulator is clocked

This IP follows the textbook design (Digital Systems Projects, section 8.7.2,
p. 445): the AXI slave's write-enable strobe `slv_reg_wren` is wired directly
to the `CLK` port of the Vivado IP-Catalog Accumulator `c_accum_0`.

Consequence: **every AXI write to any of the three software-visible registers
pulses the accumulator clock once**, which executes exactly one accumulate
step (`Q <= Q + B_IN`).  This removes the need for a separate "STEP" or
"START" register.

Writes to `CTRL` with `SCLR = 1` are also gated by `slv_reg_wren`, but
`c_accum_0`'s synchronous clear has priority over its add, so Q is zeroed for
those cycles instead of accumulated.

## Latency and the "flush" write

`c_accum_0` is configured with pipeline latency = 1, i.e. `Q` is a registered
output one clock behind `B_IN`.  In software terms, after writing `B_IN = x`
the subsequent read of `Q_OUT` returns the accumulated value **from the
previous write**, not this one.

To observe the sum after a run of `N` writes, software must issue one extra
"flush" write (any value) and then read `Q_OUT`.  This is exactly what the
book's test application does on p. 447:

```c
ACC_IP_mWriteReg(BASEADDR, 0, 0);        // prime slv_reg0
ACC_IP_mWriteReg(BASEADDR, 8, 1);        // SCLR = 1  (bit 0 of CTRL)
ACC_IP_mWriteReg(BASEADDR, 8, 0);        // SCLR = 0
for (int i = 0; i <= N; i++)
    ACC_IP_mWriteReg(BASEADDR, 0, i);    // one accumulate step per write
ACC_IP_mWriteReg(BASEADDR, 0, 0);        // flush the latency-1 pipeline
int32_t sum = (int32_t) ACC_IP_mReadReg(BASEADDR, 4);
```

For `N = 1000` the returned sum is `500,500`.

## Software handshake summary

```
write  B_IN = 0                 ; prime B_IN (any value, typically 0)
write  CTRL = 0x1               ; SCLR high
write  CTRL = 0x0               ; SCLR low

loop N times
    write  B_IN = sample_i      ; one accumulate step per iteration

write  B_IN = 0                 ; flush (latency = 1)
read   Q_OUT                    ; final accumulated sum
```

## Signedness

Both `B_IN` and `Q_OUT` are **signed 32-bit two's complement**.  In C cast the
result of `Xil_In32` to `int32_t` before printing so negative accumulations
render correctly.  Range is `-2,147,483,648 .. +2,147,483,647`; the IP wraps
silently on overflow (no overflow flag in this minimalist build).
