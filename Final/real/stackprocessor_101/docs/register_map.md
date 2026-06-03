# `sp101_axi` register map and instruction set (Final, ssq)

The Final IP packages the assignment's Stack Processor 101 (the
`user_logic` from the PDF) behind a five-register AXI4-Lite slave.  All
software-visible state - control bits, the bus-to-memory shim, and the
processor's `done` flag - lives in this 32-byte aperture.  The base
address is assigned by the Vivado Address Editor; Vitis exposes it as
`XPAR_SP101_AXI_0_S00_AXI_BASEADDR`.

## Register map

| Offset | Name        | Access | Width  | Description                                                                          |
|-------:|-------------|:------:|:------:|--------------------------------------------------------------------------------------|
| `0x00` | `slv_reg0`  | R/W    | 32 bit | Control bits.  `bit 0 = run`, `bit 1 = reset`, `bit 2 = bus2mem_en`, `bit 3 = bus2mem_we` |
| `0x04` | `slv_reg1`  | R/W    | 32 bit | `bus2mem_addr` for the bus-side BRAM port (lower 10 bits used).                      |
| `0x08` | `slv_reg2`  | R/W    | 32 bit | `bus2mem_data_in` for bus-side BRAM writes.                                          |
| `0x0C` | `slv_reg3`  | R      | 32 bit | `sp2bus_data_out` - registered BRAM read data when the bus owns the port.            |
| `0x10` | `slv_reg4`  | R      | 32 bit | bit 0 = `done` flag from the processor (high after `HALT` until next reset).         |

## Control bit conventions

The bare-metal driver writes whole 32-bit values into `slv_reg0`,
treating the low four bits as the control field:

| Operation                | `slv_reg0` value | Meaning                                  |
|--------------------------|------------------|------------------------------------------|
| Power-on / soft reset    | `0x0E`           | `reset=1`, `bus2mem_en=1`, `bus2mem_we=1` |
| Bus write phase          | `0x0C`           | `reset=0`, `bus2mem_en=1`, `bus2mem_we=1` |
| Bus read phase           | `0x04`           | `reset=0`, `bus2mem_en=1`, `bus2mem_we=0` |
| Processor run            | `0x01`           | `reset=0`, `bus2mem_en=0`, `bus2mem_we=0`, `run=1` |

## Instruction set

The processor honours every opcode from the PDF plus the new `ssq`:

| Mnemonic | Code         | Stack effect                                   | Description                                       |
|----------|--------------|------------------------------------------------|---------------------------------------------------|
| `halt`   | `0x000000FF` | -                                              | Set `done=1`, halt fetch.                         |
| `sc`     | `0x00000001` | push `constant`                                | Push the constant pointed to by `pc`.             |
| `sl`     | `0x00000011` | pop `a`, push `mem[a]`                         | Indirect load.                                    |
| `ss`     | `0x00000021` | pop `data`, pop `addr`, `mem[addr] <= data`    | Indirect store.                                   |
| `sadd`   | `0x00000031` | pop `a`, pop `b`, push `a+b`                   | Stack add.                                        |
| `ssq`    | `0x00000041` | pop `x`, push `x*x`                            | **NEW** : square the top of the stack in place.   |
| `scp`    | `0x00000101` | pop `src`, pop `dst`, `mem[dst] <= mem[src]`   | Single-word copy.                                 |

### `ssq` programming convention

```text
sc x   ssq   halt
```

After the program:

- `mem[STACK_BASE] = x * x` (with `STACK_BASE = 128` from `idle`),
- `sp` still points to the next available address (no net change).

This matches the prompt's example for `sc 7 ssq halt`:

```text
mem[128] = 49
sp       = 129     (next available)
```

## Software handshake summary

```
write slv_reg0 = 0x0E       ; pull reset high while owning the bus
write slv_reg0 = 0x0C       ; lower reset, keep bus ownership
loop {
    write slv_reg1 = addr
    write slv_reg2 = data
}                            ; load program + data into BRAM

write slv_reg0 = 0x01       ; release bus, raise run
spin until slv_reg4(0) = 1  ; processor halted

write slv_reg0 = 0x04       ; re-acquire bus for read-back
loop {
    write slv_reg1 = addr
    read  slv_reg3          ; -> sp2bus_data_out
}
```

## `ssq` micro-architecture

`ssq` walks a 7-step micro-program inside the user_logic FSM:

```
SSQ      mem_addr <= sp-1            ; start read of top-of-stack value
SSQ2     latency
SSQ3     latency
SSQ4     latency
SSQ5     temp1   <= mem_data_out     ; x is now valid
SSQ6     mem_addr    <= sp-1         ; write x*x back to the same slot
         mem_data_in <= x * x
         we           = '1'
         return to fetch
```

Total cost is the usual five `fetch*` cycles plus six `SSQ*` cycles per
instruction.  Multiplication uses `numeric_std`'s `unsigned * unsigned`
and `resize(..., 32)` truncates to the low 32 bits of the product, which
is plenty for the prompt's example (`7 * 7 = 49`).

## Address space

Recommended assigned base address `0x43C3_0000` with a `4 KB` range,
mirroring the Homework 5 IP.  Vitis exposes it as
`XPAR_SP101_AXI_0_S00_AXI_BASEADDR`.
