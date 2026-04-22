# FPGA Digital Systems Projects — ECEC 661

Coursework for **ECEC 661 – FPGA Digital Systems** at Drexel University.
Targets the **Digilent Cora Z7-07S** (Xilinx Zynq-7000 XC7Z007S) and uses
**Vivado / Vitis 2025.2**. Projects progress from pure-PL RTL through AXI-based
PS + PL systems with bare-metal C firmware.

---

## Repository layout

```
ECEC661/
├── Homework_1/            # Pure RTL: accumulator core + testbench
├── Homework_2/
│   └── gpio_leds/         # First Zynq PS+PL system: GPIO/LEDs over AXI
├── Homework_3/
│   ├── fib_gen/           # Fibonacci generator IP (custom AXI4-Lite)
│   └── fix_acc/           # Fixed-point accumulator IP wrapping Xilinx c_accum
├── ip_repo/               # Packaged custom IPs reused across projects
│   ├── fib_axi_1.0/
│   └── fix_acc_axi_1.0/
├── Cora-Z7-07S-Master.xdc # Board constraints (pinout, voltages, clocks)
├── LICENSE
└── README.md
```

Each homework directory is self-contained and has its own `README.md` with
build/run instructions, block-diagram notes, and a register map (where
applicable).

---

## Toolchain

| Tool      | Version   | Purpose                                  |
|-----------|-----------|------------------------------------------|
| Vivado    | 2025.2    | RTL synthesis, block design, bitstream   |
| Vitis     | 2025.2    | Bare-metal C application, UART debug     |
| Hardware  | Cora Z7-07S | Zynq XC7Z007S, PS UART0 on USB-UART    |
| Language  | VHDL-2008, C | RTL and PS firmware                   |

---

## Getting started

Clone and open any sub-project in Vivado:

```bash
git clone git@github.com:kagamirudo/FPGA-Digital-Systems-Projects.git
cd FPGA-Digital-Systems-Projects/Homework_3/fix_acc
vivado fix_acc.xpr
```

Most projects ship a `scripts/setup.tcl` that regenerates IP blocks and
(re)populates the source sets from a fresh checkout. From the Vivado Tcl
console:

```tcl
cd [file dirname [get_property DIRECTORY [current_project]]]
source scripts/setup.tcl
```

Board constraints come from `Cora-Z7-07S-Master.xdc`. Refer to each
sub-project README for the specific pins actually uncommented.

---

## Projects

### Homework 1 — Accumulator core
Pure-PL VHDL accumulator with a self-checking VHDL-2008 testbench. Focus:
synchronous design, reset semantics, simulation flow with xsim.

### Homework 2 — GPIO / LEDs (first PS + PL)
Introductory Zynq design — PS drives PL GPIO (Cora on-board LEDs) over an
AXI4-Lite bus assembled in IP Integrator. First Vitis bare-metal app.

### Homework 3 — Custom AXI4-Lite IPs
Two custom IPs exercising the full IP-packager flow:

- **`fib_gen`** — Fibonacci generator with AXI handshake and output FIFO.
- **`fix_acc`** — Fixed-point accumulator wrapping `xilinx.com:ip:c_accum:12.0`
  as a referenced sub-core inside the packaged IP.

Both projects include block diagrams, VHDL-2008 testbenches, Vitis C test
apps, and UART-based validation.

---

## Conventions

- **Generated artifacts are not tracked.** `.Xil/`, `*.cache/`, `*.runs/`,
  `*.sim/`, `*.gen/`, `*.ip_user_files/`, Vitis `workspace/platform/`,
  `workspace/*/Debug/`, `*.xpr` archives, `*.bit`, `*.xsa`, `*.jou`, `*.log`,
  `vivado_pid*` dumps, etc. are all ignored. Regenerate them locally from
  `scripts/setup.tcl` + IP Integrator.
- **RTL**: VHDL-2008 for RTL and testbenches.
- **Firmware**: Bare-metal C under `sw/main.c` per project, UART0 @ 115200 8N1.
- **Naming**: Packaged IPs live in `ip_repo/<name>_<version>/` and are pulled
  into Vivado via **Tools → Settings → IP → Repository**.

---

## Status

| Project       | RTL | TB | PS app | Packaged IP | Hardware test |
|---------------|:---:|:--:|:------:|:-----------:|:-------------:|
| Homework 1    |  ✅  | ✅ |   —    |      —      |       —       |
| Homework 2    |  ✅  | ✅ |   ✅   |      —      |      ✅       |
| Homework 3 — fib_gen | ✅ | ✅ | ✅ |     ✅      |      ✅       |
| Homework 3 — fix_acc | ✅ | ✅ | ✅ |     ✅      |      ✅       |

---

## License

Released under the [MIT License](./LICENSE). Course materials, problem
statements, and any third-party IP retain their original licenses and are
**not** relicensed by this repository.
