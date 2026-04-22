# `fib_axi` register map

The IP presents a 16-byte, four-register AXI4-Lite slave.  The base
address is assigned by the Vivado Address Editor; Vitis exposes it as
`XPAR_FIB_AXI_0_S00_AXI_BASEADDR`.

| Offset | Name       | Access | Description |
|-------:|------------|:------:|-------------|
| `0x00` | `CTRL_STAT`| R/W    | Control and status (see below) |
| `0x04` | `N_REG`    | R/W    | Target Fibonacci index `N` |
| `0x08` | `FIB_REG`  | R      | 32-bit unsigned `F(N)` (truncated on overflow) |
| `0x0C` | `CYCLES`   | R      | Iteration count of the last compute |

## `0x00 CTRL_STAT`

| Bit | Name       | Access | Meaning |
|----:|------------|:------:|---------|
| 0   | `START`    | W      | Writing a `1` pulses the core's start input for one AXI clock. Self-clearing: reads always return `0` for this bit. |
| 1   | `DONE`     | R      | `1` when a compute has finished. Sticky: cleared when a new `START` is written. |
| 2   | `OVERFLOW` | R      | `1` if the last compute's 32-bit adder carried out. Sticky. |
| 3   | `BUSY`     | R      | `1` while the FSM is iterating. |
| 4-31| reserved   | -      | reads as `0`, ignored on write |

## `0x04 N_REG`

32-bit unsigned target index.  Legal range for a non-overflowing 32-bit
result is `0 <= N <= 47`.  `F(48)` (= 4,807,526,976) does not fit in
32 bits and sets `OVERFLOW`.  Values `>= 48` will always overflow.

## `0x08 FIB_REG`

32-bit unsigned `F(N)`.  On overflow this register holds the
truncated low 32 bits of the last addition; the `OVERFLOW` flag in
`CTRL_STAT` indicates the value is invalid.

## `0x0C CYCLES`

Number of iterations performed by the FSM during the last compute.
For `N >= 2` this is `N - 1`; for `N = 0` or `N = 1` it is `0` because
the core answers in the same cycle that `START` is observed.

## Software handshake (recommended)

```
write  N_REG     = n
write  CTRL_STAT = 0x1       ; pulse START
loop:  read  CTRL_STAT
       if (val & 0x2) break  ; DONE
read   FIB_REG               ; result
read   CTRL_STAT bit 2       ; overflow
read   CYCLES    (optional)
```
