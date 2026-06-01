# FPGA Digital Systems Projects — ECEC 661

Coursework for **ECEC 661 – FPGA Digital Systems** at Drexel University.
Targets the **Digilent Cora Z7-07S** (Xilinx Zynq-7000 XC7Z007S) and uses
**Vivado / Vitis 2025.2**. Projects progress from pure-PL RTL through AXI-based
PS + PL systems with bare-metal C firmware.

---

## Repository layout

```
ECEC661/
├── Homework_1/                 # Pure RTL: accumulator core + testbench
├── Homework_2/
│   └── gpio_leds/              # First Zynq PS+PL: GPIO/LEDs over AXI
├── Homework_3/
│   ├── fib_gen/                # Fibonacci generator (custom AXI4-Lite IP)
│   └── fix_acc/                # Fixed-point accumulator (wraps c_accum)
├── Homework_4/
│   ├── cordic_sqrt/            # CORDIC sqrt IP + AXI slave (source tree)
│   └── report/                 # LaTeX write-up + figures
├── Homework_5/
│   ├── stackprocessor_101/     # Stack Processor 101 + scpb (source tree)
│   ├── sp101/                  # Vivado project (BD, bitstream, XSA)
│   ├── report/                 # LaTeX write-up + figures
│   └── prob.md                 # assignment brief
├── Quiz_1/                     # Quiz 1 — practice + real submissions
├── Quiz_2/                     # Quiz 2 — practice + real + submit report
├── Midterm/                    # Midterm — prep + real
├── Final/                      # Final project (placeholder)
├── ip_repo/                    # Packaged custom IPs (Vivado IP catalog)
│   ├── fib_axi_1.0/
│   ├── fix_acc_axi_1.0/
│   ├── cordic_sqrt_axi_1.0/
│   ├── add_const_axi_1.0/
│   └── sp101_axi_1.0/
├── Cora-Z7-07S-Master.xdc      # Board constraints (pinout, I/O standards)
├── Makefile                    # Optional helpers (see project READMEs)
├── LICENSE
└── README.md
```

### Typical project anatomy (Homework 3–5, quizzes)

Most PS+PL assignments follow the same split:

| Path (under e.g. `Homework_5/stackprocessor_101/`) | Role |
|----------------------------------------------------|------|
| `rtl/` | User logic + AXI wrapper VHDL |
| `tb/` | Self-checking VHDL-2008 testbench (xsim) |
| `sw/main.c` | Bare-metal Vitis test app (UART @ 115200) |
| `docs/register_map.md` | AXI map, opcodes, handshake notes |
| `scripts/setup.tcl` | Regenerate catalog IP + Vivado filesets |
| `scripts/package.tcl` | IP packager metadata + sub-core references |
| `workspace/` | Vitis Unified workspace (local; mostly gitignored) |
| `../<proj>/` or sibling `sp101/` | Vivado `.xpr`, block design, `.xsa` export |

**Edit RTL/TB/C in the source tree**; treat Vivado `*.cache/`, `*.runs/`,
`*.sim/`, and Vitis `workspace/` build trees as regenerable outputs.

Each homework’s **detailed** flow lives in that folder’s `README.md` (and
the report under `Homework_*/report/` where applicable).

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

Clone and open a sub-project in Vivado (example: Homework 5):

```bash
git clone git@github.com:kagamirudo/FPGA-Digital-Systems-Projects.git
cd FPGA-Digital-Systems-Projects
vivado Homework_5/sp101/sp101.xpr
```

Regenerate IP and filesets from the **source** tree Tcl scripts:

```tcl
cd /path/to/ECEC661/Homework_5/stackprocessor_101
source scripts/setup.tcl
```

Add packaged IPs via **Settings → IP → Repository** → point at
`ECEC661/ip_repo/<name>_1.0/`.

Board constraints: `Cora-Z7-07S-Master.xdc`. Per-design pin usage is
documented in each sub-project README.

Serial monitor (typical Linux device):

```bash
picocom /dev/ttyUSB1 -b 115200 --imap lfcrlf
```

---

## Projects

### Homework 1 — Accumulator core
Pure-PL VHDL accumulator with a self-checking VHDL-2008 testbench. Focus:
synchronous design, reset semantics, xsim flow.

### Homework 2 — GPIO / LEDs (first PS + PL)
Introductory Zynq design — PS drives PL GPIO (Cora LEDs) over AXI4-Lite in IP
Integrator. First Vitis bare-metal app.

### Homework 3 — Custom AXI4-Lite IPs
Two packaged IPs:

- **`fib_gen`** — Fibonacci generator with AXI handshake and output FIFO.
- **`fix_acc`** — Fixed-point accumulator wrapping `xilinx.com:ip:c_accum:12.0`.

Both include block diagrams, VHDL-2008 testbenches, Vitis C tests, and UART
validation. See [`Homework_3/fib_gen/`](Homework_3/fib_gen/) and
[`Homework_3/fix_acc/`](Homework_3/fix_acc/).

### Homework 4 — CORDIC square root
**`cordic_sqrt_axi`** wraps Xilinx **`cordic_0`** (square root, 10-bit unsigned
fraction). **`user_logic`** bridges AXI-Stream; the slave exposes
`slv_reg0`–`slv_reg3` for \(x\), `din_tvalid`, \(z\), `dout_tvalid`.
PL base address **`0x43C2_0000`**. Full flow:
[`Homework_4/cordic_sqrt/README.md`](Homework_4/cordic_sqrt/README.md).
Report: [`Homework_4/report/report.tex`](Homework_4/report/report.tex).

### Homework 5 — Stack Processor 101 + `scpb`
Extends the course **Stack Processor 101** PDF with a new block-copy
instruction **`scpb`** (`0x00000201`): pop count, source, and destination,
then copy that many 32-bit words through the on-chip BRAM. Packaged as
**`sp101_axi`** with the same bus/IP memory bridge as the assignment.
PL base address **`0x43C3_0000`**.

| Artifact | Location |
|----------|----------|
| Source (RTL, TB, C, scripts) | [`Homework_5/stackprocessor_101/`](Homework_5/stackprocessor_101/) |
| Vivado BD / bitstream / XSA | [`Homework_5/sp101/`](Homework_5/sp101/) |
| Packaged IP | [`ip_repo/sp101_axi_1.0/`](ip_repo/sp101_axi_1.0/) |
| Write-up | [`Homework_5/report/report.tex`](Homework_5/report/report.tex) |

Build/sim/run: [`Homework_5/stackprocessor_101/README.md`](Homework_5/stackprocessor_101/README.md).

### Quizzes, midterm, final

| Folder | Contents |
|--------|----------|
| [`Quiz_1/`](Quiz_1/) | `practice/` and `real/` RTL + Vivado projects |
| [`Quiz_2/`](Quiz_2/) | `practice/`, `real/` (PS+PL), `submit/` report |
| [`Midterm/`](Midterm/) | `prep/`, `real/` (constraints, workspace, submit) |
| [`Final/`](Final/) | Final project workspace (in progress) |

---

## Custom IP catalog (`ip_repo/`)

All packaged user IPs used in block designs:

| IP directory | Used in | Typical PL offset |
|--------------|---------|-------------------|
| `fib_axi_1.0` | HW3 | (per BD) |
| `fix_acc_axi_1.0` | HW3 | (per BD) |
| `cordic_sqrt_axi_1.0` | HW4 | `0x43C2_0000` |
| `add_const_axi_1.0` | Quiz / labs | (per BD) |
| `sp101_axi_1.0` | HW5 | `0x43C3_0000` |

Re-package from each project’s `scripts/package.tcl` after RTL changes.

---

## Conventions

- **Generated artifacts are not tracked.** `.Xil/`, `*.cache/`, `*.runs/`,
  `*.sim/`, `*.gen/`, `*.ip_user_files/`, most of `workspace/`, `*.xpr`,
  `*.bit`, `*.xsa`, `*.jou`, `*.log`, `vivado_pid*`, etc. are gitignored.
  Regenerate locally via `scripts/setup.tcl` and IP Integrator.
- **RTL**: VHDL-2008 for RTL and testbenches (`to_hstring`, `LF` in TBs).
- **Firmware**: Bare-metal C in `sw/main.c`; UART0 @ 115200 8N1.
- **Naming**: Packaged IPs live in `ip_repo/<name>_1.0/` and are added in
  Vivado under **Settings → IP → Repository**.

---

## Status

| Project | RTL | TB | PS app | Packaged IP | HW test |
|---------|:---:|:--:|:------:|:-----------:|:-------:|
| Homework 1 | ✅ | ✅ | — | — | — |
| Homework 2 — gpio_leds | ✅ | ✅ | ✅ | — | ✅ |
| Homework 3 — fib_gen | ✅ | ✅ | ✅ | ✅ | ✅ |
| Homework 3 — fix_acc | ✅ | ✅ | ✅ | ✅ | ✅ |
| Homework 4 — cordic_sqrt | ✅ | ✅ | ✅ | ✅ | ✅ |
| Homework 5 — sp101 + scpb | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## License

Released under the [MIT License](./LICENSE). Course materials, problem
statements, and any third-party IP retain their original licenses and are
**not** relicensed by this repository.
