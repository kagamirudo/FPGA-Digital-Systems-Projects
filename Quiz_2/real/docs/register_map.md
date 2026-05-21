# Add-(-1) AXI4-Lite Register Map

Base address used in the practice walkthrough: `0x43C0_0000`, range `4K`.

| Offset | Name      | Access | Description                                                  |
|--------|-----------|--------|--------------------------------------------------------------|
| `0x00` | `X_IN`    | R/W    | 32-bit signed input. Software writes `x` here.               |
| `0x04` | `Z_OUT`   | R      | 32-bit signed result `z = x + (-1) = x - 1`.                |
| `0x08` | -         | R/W    | Reserved (returns 0; writes ignored).                        |
| `0x0C` | -         | R/W    | Reserved (returns 0; writes ignored).                        |

## Why no "go" / "done" handshake

The IP-Catalog Adder/Subtractor is configured with **Latency = 0** and **no
clock enable**, so `user_logic` is purely combinational:

```
slv_reg0 (X_IN)  ->  user_logic.x  ->  c_addsub_0.A
                                       c_addsub_0.S  ->  user_logic.z  ->  read mux for Z_OUT
                                                B = -1 (constant)
```

Any AXI write to `X_IN` propagates immediately, so a subsequent AXI read of
`Z_OUT` returns the corresponding `z = x - 1`.

## Manual Sequence (memory poke, no Vitis required)

```text
write 0xFFFFFFFF  -> X_IN     (-1)
read  Z_OUT       -> 0xFFFFFFFE   (-2)

write 0x00000000  -> X_IN     ( 0)
read  Z_OUT       -> 0xFFFFFFFF   (-1)

write 0x00000003  -> X_IN     ( 3)
read  Z_OUT       -> 0x00000002   ( 2)
```
