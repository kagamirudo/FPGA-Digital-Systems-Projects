#-------------------------------------------------------------------------------
# scripts/create_bd.tcl
#
# Optional helper after stack_practice_axi has been packaged and added to the
# project's IP repository list.  It creates the same block-design shape the quiz
# is likely to ask for:
#   ZYNQ7 Processing System -> AXI Interconnect -> custom AXI4-Lite IP
#
# Run from Quiz_2/practice with the main Vivado project open:
#     source scripts/create_bd.tcl
#
# If automation fails on a lab machine, use README.md section 4 as the GUI
# checklist; the block design is intentionally small.
#-------------------------------------------------------------------------------

set bd_name stack_practice
set xsa_dir [file normalize xsa]

set_property ip_repo_paths [list [file normalize ip_repo]] [current_project]
update_ip_catalog

if {[llength [get_bd_designs -quiet $bd_name]] == 0} {
    create_bd_design $bd_name
} else {
    current_bd_design $bd_name
}

if {[llength [get_bd_cells -quiet processing_system7_0]] == 0} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
}

# Board presets are convenient but not guaranteed to exist on every quiz PC.
catch {
    apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
        -config {make_external "FIXED_IO, DDR" apply_board_preset "1"} \
        [get_bd_cells processing_system7_0]
}

set_property -dict [list \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {0} \
    CONFIG.PCW_EN_CLK0_PORT {1} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100.000000} \
] [get_bd_cells processing_system7_0]

if {[llength [get_bd_cells -quiet stack_practice_axi_0]] == 0} {
    create_bd_cell -type ip -vlnv user:user:stack_practice_axi:1.0 stack_practice_axi_0
}

catch {
    apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
        -config {Master "/processing_system7_0/M_AXI_GP0" Slave "/stack_practice_axi_0/s00_axi" Clk_master "/processing_system7_0/FCLK_CLK0" Clk_slave "/processing_system7_0/FCLK_CLK0" Clk_xbar "/processing_system7_0/FCLK_CLK0"} \
        [get_bd_intf_pins stack_practice_axi_0/s00_axi]
}

assign_bd_address
set segs [get_bd_addr_segs -quiet stack_practice_axi_0/s00_axi/Reg]
if {[llength $segs] > 0} {
    set_property offset 0x43C00000 $segs
    set_property range  4K         $segs
}

validate_bd_design
save_bd_design

make_wrapper -files [get_files ${bd_name}.bd] -top
set wrapper [get_files -quiet */${bd_name}_wrapper.vhd]
if {[llength $wrapper] > 0 && [llength [get_files -quiet [lindex $wrapper 0]]] > 0} {
    add_files -norecurse $wrapper
}
set_property TOP ${bd_name}_wrapper [current_fileset]
update_compile_order -fileset sources_1

file mkdir $xsa_dir
puts "== Block design complete."
puts "   To create an XSA after synthesis/implementation:"
puts "      write_hw_platform -fixed -force -file [file join $xsa_dir stack_practice.xsa]"
