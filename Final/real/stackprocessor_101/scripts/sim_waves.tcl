# sim_waves.tcl
#
# Paste into the Vivado xsim Tcl console after launching behavioral simulation
# for tb_user_logic.  Data-path signals use -radix unsigned so values appear
# in decimal (easier to spot 7 -> 49 than 0x7 -> 0x31).
#
# Note: XSim does NOT support "add_wave -divider" (ModelSim syntax).  Use
# add_wave_divider instead (see UG835 add_wave_divider).
#
# Usage:
#   source /path/to/Final/real/stackprocessor_101/scripts/sim_waves.tcl
#   restart
#   run all

add_wave /tb_user_logic/ck
add_wave /tb_user_logic/reset_sig /tb_user_logic/run_sig
add_wave /tb_user_logic/bus2mem_en /tb_user_logic/bus2mem_we
add_wave /tb_user_logic/done_sig

add_wave_divider bus
add_wave -radix unsigned /tb_user_logic/bus2mem_addr
add_wave -radix unsigned /tb_user_logic/bus2mem_data_in
add_wave -radix unsigned /tb_user_logic/sp2bus_data_out

add_wave_divider processor
add_wave /tb_user_logic/dut/n_s
add_wave -radix hex      /tb_user_logic/dut/ir
add_wave -radix unsigned /tb_user_logic/dut/sp
add_wave -radix unsigned /tb_user_logic/dut/pc
add_wave -radix unsigned /tb_user_logic/dut/mem_addr

add_wave_divider ssq_datapath
add_wave -radix unsigned /tb_user_logic/dut/temp1
add_wave -radix unsigned /tb_user_logic/dut/mem_data_in
add_wave -radix unsigned /tb_user_logic/dut/mem_data_out

add_wave_divider self_check
add_wave -radix unsigned /tb_user_logic/checks
add_wave -radix unsigned /tb_user_logic/errors

puts "== sim_waves.tcl loaded (decimal radix on data-path signals)"
puts "   restart; run all"
