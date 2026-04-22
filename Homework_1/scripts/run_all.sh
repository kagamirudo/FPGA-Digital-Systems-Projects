#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "===== Compiling all VHDL sources ====="
xvhdl output_limiter.vhd
xvhdl tb_output_limiter.vhd
xvhdl palindrome_synch_ckt.vhd
xvhdl tb_palindrome_synch_ckt.vhd
xvhdl c_accum_0.vhd
xvhdl accumulator_top.vhd
xvhdl tb_accumulator_top.vhd

echo ""
echo "===== Elaborating Part 2.6.12 (Output Limiter) ====="
xelab tb_output_limiter -s sim_limiter -debug typical

echo ""
echo "===== Elaborating Part 3.5.11 (Palindrome Checker) ====="
xelab tb_palindrome_synch_ckt -s sim_pal -debug typical

echo ""
echo "===== Elaborating Part 7.5.3 (Accumulator) ====="
xelab tb_accumulator_top -s sim_acc -debug typical

echo ""
echo "===== Simulating Part 2.6.12 (Output Limiter) ====="
xsim sim_limiter -tclbatch run_vcd_limiter.tcl -onfinish quit

echo ""
echo "===== Simulating Part 3.5.11 (Palindrome Checker) ====="
xsim sim_pal -tclbatch run_vcd_palindrome.tcl -onfinish quit

echo ""
echo "===== Simulating Part 7.5.3 (Accumulator) ====="
xsim sim_acc -tclbatch run_vcd_accumulator.tcl -onfinish quit

echo ""
echo "===== Generating Waveform PNGs ====="
python3 read_vcd_signals.py waves_limiter.vcd \
    -s tb_output_limiter.x -s tb_output_limiter.z \
    -o waveform_limiter.png

python3 read_vcd_signals.py waves_palindrome.vcd \
    -s tb_palindrome_synch_ckt.ck -s tb_palindrome_synch_ckt.reset \
    -s tb_palindrome_synch_ckt.x -s tb_palindrome_synch_ckt.y \
    -s tb_palindrome_synch_ckt.z \
    -o waveform_palindrome.png

python3 read_vcd_signals.py waves_accumulator.vcd \
    -s tb_accumulator_top.ck -s tb_accumulator_top.sclr \
    -s tb_accumulator_top.x -s tb_accumulator_top.q \
    --signed -o waveform_accumulator.png

echo ""
echo "===== Done. Artifacts: ====="
ls -lh waves_*.vcd waveform_*.png 2>/dev/null
