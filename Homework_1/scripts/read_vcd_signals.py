#!/usr/bin/env python3
"""
XSim-style VCD waveform plotter.

Reads a VCD produced by XSim, renders dark-background waveforms with bus
polygons and digital traces, and saves a PNG.

Dependencies:
  pip install vcdvcd matplotlib
"""
from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass, field
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    pass

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon as MplPolygon
from matplotlib.ticker import MultipleLocator


# ---------------------------------------------------------------------------
# Colour palettes
# ---------------------------------------------------------------------------
_DARK = dict(
    bg="#1a1a2e",
    fg="#d0d0d0",
    grid="#333350",
    axis="#555580",
    bus_colors=["#33cc66", "#e6cc33", "#33bbee", "#ee6633", "#cc66ff",
                "#66cccc", "#ff9966", "#99cc33"],
    bit_color="#33cc66",
    bit_fill="#1a4d2e",
    label_fg="#e0e0e0",
    value_fg="#a0a0c0",
    time_fg="#8888aa",
)

_LIGHT = dict(
    bg="#ffffff",
    fg="#222222",
    grid="#cccccc",
    axis="#888888",
    bus_colors=["#228833", "#ccbb44", "#4477aa", "#ee6677", "#aa3377",
                "#66ccee", "#ee8866", "#bbcc33"],
    bit_color="#228833",
    bit_fill="#c8e8d0",
    label_fg="#222222",
    value_fg="#555555",
    time_fg="#666666",
)


# ---------------------------------------------------------------------------
# Data helpers
# ---------------------------------------------------------------------------
@dataclass
class SigData:
    name: str
    short: str
    width: int
    times_ps: list[int] = field(default_factory=list)
    raw_vals: list[str] = field(default_factory=list)


def _int_val(raw: str, width: int, signed: bool) -> int:
    if width <= 1:
        return int(raw, 2) if raw in ("0", "1") else int(raw)
    n = int(raw, 2)
    if signed and n >= (1 << (width - 1)):
        n -= 1 << width
    return n


def _format_val(raw: str, width: int, signed: bool, radix: str) -> str:
    n = _int_val(raw, width, signed)
    if radix == "hex":
        return format(n if n >= 0 else (n + (1 << width)), "x")
    if radix == "bin":
        return raw
    return str(n)


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------
_ROW_H_BIT = 0.55
_ROW_H_BUS = 0.95
_TRANS_FRAC = 0.08


def _draw_bus(ax, sig: SigData, t_end: float, scale: float,
              color: str, theme: dict, signed: bool, radix: str) -> None:
    """Draw bus waveform as filled polygons with value labels."""
    rail_lo, rail_hi = 0.15, 0.85

    times = sig.times_ps
    vals = sig.raw_vals

    for idx in range(len(times)):
        t0 = times[idx] * scale
        t1 = (times[idx + 1] * scale) if idx + 1 < len(times) else t_end * scale

        seg_w = t1 - t0
        tw = min(seg_w * _TRANS_FRAC, 1.5)

        # Polygon: top-left -> top-right -> (transition) -> bottom-right -> bottom-left -> (transition)
        poly_x = [t0 + tw, t1 - tw, t1, t1 - tw, t0 + tw, t0]
        poly_y = [rail_hi, rail_hi, 0.5, rail_lo, rail_lo, 0.5]

        p = MplPolygon(list(zip(poly_x, poly_y)),
                       closed=True, facecolor=color, edgecolor=color,
                       alpha=0.25, linewidth=0)
        ax.add_patch(p)
        # Outline
        ax.plot(poly_x + [poly_x[0]], poly_y + [poly_y[0]],
                color=color, linewidth=1.0, solid_capstyle="round")

        # Value label
        label = _format_val(vals[idx], sig.width, signed, radix)
        cx = (t0 + t1) / 2
        min_label_w = len(label) * 0.9 * scale
        if seg_w > min_label_w and seg_w > 2 * scale:
            ax.text(cx, 0.5, label, ha="center", va="center",
                    fontsize=10, color=theme["label_fg"],
                    fontfamily="monospace", fontweight="bold",
                    clip_on=True)


def _draw_bit(ax, sig: SigData, t_end: float, scale: float,
              theme: dict) -> None:
    """Draw single-bit digital waveform."""
    rail_lo, rail_hi = 0.1, 0.9
    color = theme["bit_color"]
    fill_c = theme["bit_fill"]

    xs: list[float] = []
    ys: list[float] = []

    for idx in range(len(sig.times_ps)):
        t = sig.times_ps[idx] * scale
        v = rail_hi if sig.raw_vals[idx] in ("1",) else rail_lo
        if xs:
            xs.append(t)
            ys.append(ys[-1])
        xs.append(t)
        ys.append(v)

    xs.append(t_end * scale)
    ys.append(ys[-1])

    ax.fill_between(xs, rail_lo, ys, color=fill_c, step=None)
    ax.plot(xs, ys, color=color, linewidth=1.2, solid_capstyle="butt")


def render(sigs: list[SigData], out_path: str, *,
           signed: bool, radix: str, time_unit: str,
           dpi: int, dark: bool, title: str) -> None:

    theme = _DARK if dark else _LIGHT
    scale_map = {"ps": 1.0, "ns": 1e-3, "us": 1e-6}
    scale = scale_map[time_unit]

    t_end_ps = max(
        (s.times_ps[-1] for s in sigs if s.times_ps), default=1
    )
    for s in sigs:
        if s.times_ps:
            last = s.times_ps[-1]
            if last > t_end_ps:
                t_end_ps = last
    t_end_plot = t_end_ps * scale

    n = len(sigs)
    heights = [_ROW_H_BIT if s.width <= 1 else _ROW_H_BUS for s in sigs]
    total_h = sum(heights) + 0.35
    fig_w = max(14, t_end_plot / 6)
    fig = plt.figure(figsize=(min(fig_w, 22), max(total_h, 1.5)))
    fig.patch.set_facecolor(theme["bg"])

    left_margin = 0.09
    right_margin = 0.02
    top_margin = 0.40 / total_h
    bot_margin = 0.10 / total_h

    y_cursor = 1.0 - top_margin
    axes = []

    for i, sig in enumerate(sigs):
        h_frac = heights[i] / total_h
        y_cursor -= h_frac
        ax = fig.add_axes([left_margin, y_cursor,
                           1 - left_margin - right_margin, h_frac])
        ax.set_facecolor(theme["bg"])

        ax.set_xlim(0, t_end_plot)
        ax.set_ylim(0, 1)
        ax.set_yticks([])

        for spine in ax.spines.values():
            spine.set_visible(False)

        ax.tick_params(axis="x", colors=theme["time_fg"], labelsize=6,
                       direction="in", length=3)
        ax.xaxis.set_tick_params(labeltop=(i == 0), labelbottom=False)
        if i == 0:
            ax.xaxis.set_label_position("top")
            ax.set_xlabel(f"time ({time_unit})", fontsize=7,
                          color=theme["time_fg"], labelpad=2)

        ax.grid(True, axis="x", color=theme["grid"], linewidth=0.4,
                alpha=0.6)

        # Signal label on the left
        ax.text(-0.005, 0.5, sig.short, transform=ax.transAxes,
                ha="right", va="center", fontsize=8, color=theme["label_fg"],
                fontfamily="monospace", fontweight="bold")

        # Current (last) value on the right
        if sig.raw_vals:
            last_str = _format_val(sig.raw_vals[-1], sig.width, signed, radix)
            ax.text(1.005, 0.5, last_str, transform=ax.transAxes,
                    ha="left", va="center", fontsize=7,
                    color=theme["value_fg"], fontfamily="monospace")

        # Draw the waveform
        if sig.width <= 1:
            _draw_bit(ax, sig, t_end_ps, scale, theme)
        else:
            cidx = i % len(theme["bus_colors"])
            _draw_bus(ax, sig, t_end_ps, scale,
                      theme["bus_colors"][cidx], theme, signed, radix)

        axes.append(ax)

    if title:
        fig.text(0.5, 1.0 - top_margin * 0.35, title,
                 ha="center", va="center", fontsize=10,
                 color=theme["fg"], fontweight="bold")

    fig.savefig(out_path, dpi=dpi, facecolor=fig.get_facecolor(),
                bbox_inches="tight", pad_inches=0.15)
    plt.close(fig)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main() -> None:
    p = argparse.ArgumentParser(
        description="XSim-style VCD waveform plotter."
    )
    p.add_argument("vcd", nargs="?", default="waves.vcd", help="Path to .vcd")
    p.add_argument(
        "--signal", "-s", action="append", dest="signals",
        help="Hierarchical signal name (repeatable)",
    )
    p.add_argument("-o", "--output", default="waveform.png")
    p.add_argument("--time-unit", choices=("ps", "ns", "us"), default="ns")
    p.add_argument("--signed", action="store_true",
                   help="Interpret multi-bit values as two's complement")
    p.add_argument("--radix", choices=("dec", "hex", "bin"), default="dec")
    p.add_argument("--dpi", type=int, default=180)
    p.add_argument("--dark", action="store_true", default=True,
                   help="Dark theme (default)")
    p.add_argument("--light", action="store_true",
                   help="Light theme")
    p.add_argument("--title", default="", help="Figure title")
    p.add_argument("--print", action="store_true",
                   help="Print transitions to stdout")
    args = p.parse_args()

    use_dark = not args.light

    default_signals = [
        "tb_accumulator_top.ck",
        "tb_accumulator_top.sclr",
        "tb_accumulator_top.x",
        "tb_accumulator_top.q",
    ]
    want = args.signals or default_signals

    try:
        from vcdvcd import VCDVCD
    except ImportError:
        print("Install:  pip install vcdvcd matplotlib", file=sys.stderr)
        sys.exit(1)

    v = VCDVCD(args.vcd)
    sigs: list[SigData] = []

    for name in want:
        if name not in v.signals:
            print(f"Unknown signal {name!r}. Available:", file=sys.stderr)
            for s in sorted(v.signals):
                print(f"  {s}", file=sys.stderr)
            sys.exit(2)

        sig_obj = v[name]
        width = int(sig_obj.size)
        short = name.split(".")[-1] or name
        sd = SigData(name=name, short=short, width=width)

        for t, val in sig_obj.tv:
            sd.times_ps.append(int(t))
            sd.raw_vals.append(val)

        sigs.append(sd)

        if getattr(args, "print", False):
            print(f"# {name} width={sig_obj.size}")
            for t, val in sig_obj.tv:
                print(f"  {t} ps  {val}")

    render(sigs, args.output,
           signed=args.signed, radix=args.radix,
           time_unit=args.time_unit, dpi=args.dpi,
           dark=use_dark, title=args.title)
    print(f"Wrote {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
