#-------------------------------------------------------------------------------
# scripts/setup.tcl
#
# Run from the Vivado Tcl console with the Quiz_2/practice project open:
#     cd [file dirname [get_property DIRECTORY [current_project]]]
#     source scripts/setup.tcl
#
# This practice matches the Quiz 2 preparation note:
#   * custom user logic
#   * package as custom AXI4-Lite IP
#   * block diagram with the custom IP
#   * XSA export
#   * no Vitis test app and no FPGA board required
#
# What this script does:
#   1. Adds the user logic and AXI wrapper files to Design Sources.
#   2. Adds the user-logic-only testbench to Simulation Sources.
#   3. Sets file types (RTL = VHDL, TB = VHDL 2008).
#   4. Sets simulation top to tb_user_logic and sources top to
#      stack_practice_axi_v1_0.
#-------------------------------------------------------------------------------

set proj_dir [get_property DIRECTORY [current_project]]
puts "== quiz2/practice setup.tcl running in [current_project] ($proj_dir)"

set rtl_files [list                                                       \
    [file normalize rtl/user_logic.vhd]                                   \
    [file normalize rtl/stack_practice_axi_v1_0_S00_AXI.vhd]              \
    [file normalize rtl/stack_practice_axi_v1_0.vhd]                      \
]
set tb_files [list [file normalize tb/tb_user_logic.vhd]]

foreach f $rtl_files {
    if {[llength [get_files -quiet $f]] == 0} {
        puts "== Adding to sources_1 : $f"
        add_files -norecurse -fileset sources_1 $f
    }
}

foreach f $tb_files {
    if {[llength [get_files -quiet $f]] == 0} {
        puts "== Adding to sim_1     : $f"
        add_files -norecurse -fileset sim_1 $f
    }
}

foreach f $rtl_files {
    set_property FILE_TYPE VHDL [get_files [file tail $f]]
}
foreach f $tb_files {
    set_property FILE_TYPE {VHDL 2008} [get_files [file tail $f]]
}

set_property TOP tb_user_logic [get_filesets sim_1]
update_compile_order -fileset sim_1

set_property TOP stack_practice_axi_v1_0 [get_filesets sources_1]
update_compile_order -fileset sources_1

puts "== quiz2/practice setup.tcl complete."
puts "   First check: Run Simulation -> Run Behavioral Simulation -> run all"
puts "   Then package the custom IP using scripts/package.tcl."
