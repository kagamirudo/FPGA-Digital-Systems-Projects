# `sp101_axi` register map and instruction set

The Homework 5 IP packages the assignment's Stack Processor 101 (the
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

This map is identical to the assignment PDF's reference C snippet, so the
file's `mWriteReg`/`mReadReg` offsets (0, 4, 8, 12, 16) map one-to-one to
the registers above.

## Control bit conventions

The bare-metal driver writes whole 32-bit values into `slv_reg0`, treating
the low four bits as the control field:

| Operation                | `slv_reg0` value | Meaning                                  |
|--------------------------|------------------|------------------------------------------|
| Power-on / soft reset    | `0x0E`           | `reset=1`, `bus2mem_en=1`, `bus2mem_we=1` |
| Bus write phase          | `0x0C`           | `reset=0`, `bus2mem_en=1`, `bus2mem_we=1` |
| Bus read phase           | `0x04`           | `reset=0`, `bus2mem_en=1`, `bus2mem_we=0` |
| Processor run            | `0x01`           | `reset=0`, `bus2mem_en=0`, `bus2mem_we=0`, `run=1` |

## Instruction set

The processor honors every opcode from the PDF plus the new `scpb`:

| Mnemonic | Code         | Stack effect                                   | Description                                       |
|----------|--------------|------------------------------------------------|---------------------------------------------------|
| `halt`   | `0x000000FF` | -                                              | Set `done=1`, halt fetch.                         |
| `sc`     | `0x00000001` | push `constant`                                | Push the constant pointed to by `pc`.             |
| `sl`     | `0x00000011` | pop `a`, push `mem[a]`                         | Indirect load.                                    |
| `ss`     | `0x00000021` | pop `data`, pop `addr`, `mem[addr] <= data`    | Indirect store.                                   |
| `sadd`   | `0x00000031` | pop `a`, pop `b`, push `a+b`                   | Stack add.                                        |
| `scp`    | `0x00000101` | pop `src`, pop `dst`, `mem[dst] <= mem[src]`   | Single-word copy.                                 |
| `scpb`   | `0x00000201` | pop `count`, pop `src`, pop `dst`, block copy  | **NEW** : copy `count` words `mem[src..]` -> `mem[dst..]` |

The `scpb` programming convention is therefore:

```text
sc dest_addr   sc source_addr   sc number_of_data   scpb   halt
```

After the block copy the words at `mem[dest_addr .. dest_addr+count-1]`
match the corresponding words at `mem[source_addr ..
source_addr+count-1]`; the stack is left empty of these arguments.

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

## `scpb` micro-architecture

`scpb` walks a 13-step micro-program inside the user_logic FSM.  The pop
phase reads three values out of the stack (count, source, dest), the loop
phase iterates the BRAM copy, and the loop-tail bookkeeping decrements
`copy_cnt` and increments the source/destination pointers.

```
SCPB        init pop count
SCPB2       init pop source
SCPB3       init pop dest
SCPB4       BRAM read latency
SCPB5       mem_data_out valid : count   -> copy_cnt
SCPB6       mem_data_out valid : source  -> copy_src
SCPB7       mem_data_out valid : dest    -> copy_dst
SCPB_L      if copy_cnt = 0 -> fetch; else init read mem[copy_src]
SCPB_R1..3  BRAM read latency
SCPB_R4     mem_data_out valid : source word ; schedule write to copy_dst
SCPB_W      write fires; bump copy_src/dst; copy_cnt-- ; return to SCPB_L
```

Pre-loop overhead is 7 cycles, each iteration is 6 cycles, and the
terminal check adds one more.  So the total cycle count for an N-word
block copy is roughly `7 + 6*N + 1 = 6N + 8` (plus the usual `fetch`
overhead).

## Address space

The recommended assigned base address is `0x43C3_0000` with a `4 KB`
range, i.e. `0x43C3_0000 .. 0x43C3_0FFF`.  This sits one 64 KB aperture
above Homework 4's `cordic_sqrt_axi` IP at `0x43C2_0000`, so all three
custom peripherals (HW3 `fix_acc`, HW4 `cordic_sqrt`, HW5 `sp101`) can
coexist on the same PL image.
