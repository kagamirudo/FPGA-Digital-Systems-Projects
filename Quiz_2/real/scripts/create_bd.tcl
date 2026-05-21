#-------------------------------------------------------------------------------
# scripts/create_bd.tcl
#
# Optional helper after add_const_axi has been packaged and added to the
# project's IP repository list.  Builds the block diagram the quiz asks for:
#     ZYNQ7 Processing System  ->  AXI Interconnect  ->  add_const_axi_0
#
# Run from Quiz_2/real with the main Vivado project open:
#     source scripts/create_bd.tcl
#
# If automation fails on a lab machine (different board files, different
# Vivado), use README.md section 4 as the GUI checklist; the block design is
# intentionally small.
#-------------------------------------------------------------------------------

set bd_name add_const
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

# Apply the Cora Z7-07S preset if the install has it; otherwise leave the
# default config (which is enough for an XSA without Vitis testing).
catch {
    apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
        -config {make_external "FIXED_IO, DDR" apply_board_preset "1"} \
        [get_bd_cells processing_system7_0]
}

set_property -dict [list                              \
    CONFIG.PCW_USE_M_AXI_GP0           {1}            \
    CONFIG.PCW_EN_CLK0_PORT            {1}            \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100.000000}  \
    CONFIG.PCW_USE_FABRIC_INTERRUPT    {0}            \
] [get_bd_cells processing_system7_0]

if {[llength [get_bd_cells -quiet add_const_axi_0]] == 0} {
    create_bd_cell -type ip -vlnv user:user:add_const_axi:1.0 add_const_axi_0
}

catch {
    apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
        -config {Master "/processing_system7_0/M_AXI_GP0" Slave "/add_const_axi_0/s00_axi" Clk_master "/processing_system7_0/FCLK_CLK0" Clk_slave "/processing_system7_0/FCLK_CLK0" Clk_xbar "/processing_system7_0/FCLK_CLK0"} \
        [get_bd_intf_pins add_const_axi_0/s00_axi]
}

assign_bd_address
set segs [get_bd_addr_segs -quiet add_const_axi_0/S00_AXI/Reg]
if {[llength $segs] > 0} {
    set_property offset 0x43C00000 $segs
    set_property range  4K         $segs
}

validate_bd_design
save_bd_design

make_wrapper -files [get_files ${bd_name}.bd] -top
set proj_dir [get_property DIRECTORY [current_project]]
set wrappers [glob -nocomplain \
    [file join $proj_dir *.gen sources_1 bd $bd_name hdl ${bd_name}_wrapper.vhd]]
foreach w $wrappers {
    if {[llength [get_files -quiet $w]] == 0} {
        add_files -norecurse $w
    }
}
set_property TOP ${bd_name}_wrapper [current_fileset]
update_compile_order -fileset sources_1

file mkdir $xsa_dir
puts "== Block design complete."
puts "   To build the bitstream and export the XSA:"
puts "       launch_runs synth_1 -jobs 4"
puts "       wait_on_run synth_1"
puts "       launch_runs impl_1 -to_step write_bitstream -jobs 4"
puts "       wait_on_run impl_1"
puts "       write_hw_platform -fixed -include_bit -force \\"
puts "           -file [file join $xsa_dir add_const.xsa]"
