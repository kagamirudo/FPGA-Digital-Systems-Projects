# Stack Practice AXI Register Map

Base address used in the practice walkthrough: `0x43C0_0000`, range `4K`.

| Offset | Name | Access | Bits | Description |
|--------|------|--------|------|-------------|
| `0x00` | `DATA_IN` | R/W | `[31:0]` | Word loaded before issuing `PUSH`. |
| `0x04` | `COMMAND` | W | bit `0` | Pulse `PUSH`. Pushes `DATA_IN` onto the stack. |
| `0x04` | `COMMAND` | W | bit `1` | Pulse `POP`. Pops newest word into `DATA_OUT`. |
| `0x04` | `COMMAND` | W | bit `2` | Pulse `CLEAR`. Clears stack, `DATA_OUT`, and sticky error. |
| `0x08` | `DATA_OUT` | R | `[31:0]` | Last popped value. |
| `0x0C` | `STATUS` | R | `[3:0]` | Stack count, `0..8`. |
| `0x0C` | `STATUS` | R | bit `8` | `EMPTY`. |
| `0x0C` | `STATUS` | R | bit `9` | `FULL`. |
| `0x0C` | `STATUS` | R | bit `10` | Sticky `ERROR` after overflow or underflow. |

If multiple command bits are written at once, priority is:

1. `CLEAR`
2. `POP`
3. `PUSH`

## Quick Manual Sequence

These are memory writes/reads, not a Vitis requirement. They are just a mental
model for how the AXI registers behave.

1. Write `0x00000011` to `DATA_IN`.
2. Write `0x00000001` to `COMMAND` to push.
3. Write `0x00000022` to `DATA_IN`.
4. Write `0x00000001` to `COMMAND` to push.
5. Read `STATUS`; count should be `2`, empty should be `0`.
6. Write `0x00000002` to `COMMAND` to pop.
7. Read `DATA_OUT`; value should be `0x00000022`.
8. Write `0x00000004` to `COMMAND` to clear.
9. Read `STATUS`; count should be `0`, empty should be `1`, error should be `0`.
