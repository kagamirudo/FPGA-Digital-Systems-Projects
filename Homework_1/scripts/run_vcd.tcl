# Headless waveform dump for XSim (no Vivado/XSim GUI).
#
# 1) Elaborate with debug (required for VCD/log_vcd; run again after HDL changes):
#    xelab tb_accumulator_top -s sim_acc -debug typical
#
# 2) Run (from this directory). If xsim auto-sources xsim.dir/sim_acc/xsim_script.tcl,
#    point that script at this file, or run the inner xsim it invokes:
#    xsim sim_acc -tclbatch run_vcd.tcl -onfinish quit
#
# Output: waves.vcd — open in GTKWave, or parse with read_vcd_signals.py

restart
open_vcd waves.vcd
log_vcd /*
run all
close_vcd
