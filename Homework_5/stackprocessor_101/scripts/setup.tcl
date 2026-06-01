#-------------------------------------------------------------------------------
# scripts/setup.tcl
#
# Run from the Vivado Tcl console with sp101.xpr open:
#     cd [file dirname [get_property DIRECTORY [current_project]]]
#     source scripts/setup.tcl
#
# Idempotent.  Performs every non-GUI step up to behavioral simulation:
#   1. Generates the Vivado IP-Catalog BRAM block (blk_mem_gen_0) sized to
#      1024 x 32 bits, single-port, no output register (matching the
#      assignment PDF's `blk_mem_gen_0` reference).
#   2. Adds the four sp101 RTL files to Design Sources and the testbench to
#      Simulation Sources.
#   3. Sets file types (plain VHDL for RTL so the packager is happy; VHDL
#      2008 for the TB so LF / to_hstring work).
#   4. Sets the simulation top to tb_user_logic and the sources top to
#      sp101_axi_v1_0.
#-------------------------------------------------------------------------------

set proj_dir [get_property DIRECTORY [current_project]]
puts "== sp101 setup.tcl running in [current_project] ($proj_dir)"

#-------------------------------------------------------------------------------
# 1. Generate blk_mem_gen_0 from the Vivado IP Catalog
#
# Configuration:
#   CONFIG.Memory_Type           : Single_Port_RAM
#   CONFIG.Write_Width_A         : 32
#   CONFIG.Read_Width_A          : 32
#   CONFIG.Write_Depth_A         : 1024
#   CONFIG.Operating_Mode_A      : WRITE_FIRST   (PDF style)
#   CONFIG.Register_PortA_Output_of_Memory_Primitives : false
#
# Apply each property inside a `catch` so unknown names produce a single
# warning instead of aborting.
#-------------------------------------------------------------------------------
set ip_name blk_mem_gen_0

if {[info exists env(SP101_FORCE_IP)] && $env(SP101_FORCE_IP) eq "1"} {
    if {[llength [get_ips -quiet $ip_name]] > 0} {
        puts "== SP101_FORCE_IP=1 -> removing existing $ip_name"
        remove_files -quiet [get_files -quiet ${ip_name}.xci]
        catch { export_ip_user_files -of_objects [get_ips $ip_name] -no_script -reset -force -quiet }
    }
}

if {[llength [get_ips -quiet $ip_name]] == 0} {
    puts "== Generating IP Catalog block $ip_name (xilinx.com:ip:blk_mem_gen:8.4)"
    create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 \
              -module_name $ip_name
} else {
    puts "== $ip_name already present - reapplying configuration"
}

set ip_cfg [list                                                       \
    CONFIG.Memory_Type                                  {Single_Port_RAM} \
    CONFIG.Use_Byte_Write_Enable                        {false}        \
    CONFIG.Byte_Size                                    {8}            \
    CONFIG.Write_Width_A                                {32}           \
    CONFIG.Read_Width_A                                 {32}           \
    CONFIG.Write_Depth_A                                {1024}         \
    CONFIG.Operating_Mode_A                             {WRITE_FIRST}  \
    CONFIG.Register_PortA_Output_of_Memory_Primitives   {false}        \
    CONFIG.Use_RSTA_Pin                                 {false}        \
    CONFIG.Use_ENA_Pin                                  {true}         \
    CONFIG.Port_A_Clock                                 {100}          \
    CONFIG.Port_A_Enable_Rate                           {100}          \
]

set ip_obj [get_ips $ip_name]
foreach {pname pval} $ip_cfg {
    if {[catch {set_property $pname $pval $ip_obj} msg]} {
        puts "   (warn) could not set $pname = $pval on $ip_name : $msg"
    }
}

puts "== $ip_name final CONFIG.* values:"
foreach p [lsort [list_property $ip_obj]] {
    if {[string match CONFIG.* $p]} {
        puts [format "   %-40s = %s" $p [get_property $p $ip_obj]]
    }
}

generate_target {synthesis simulation} [get_ips $ip_name]
catch { export_ip_user_files -of_objects [get_ips $ip_name] -no_script -force -quiet }

#-------------------------------------------------------------------------------
# 2. Add RTL + TB sources if they are not already in the project
#-------------------------------------------------------------------------------
set rtl_files [list                                                       \
    [file normalize rtl/bus_ip_mem_bridge.vhd]                            \
    [file normalize rtl/user_logic.vhd]                                   \
    [file normalize rtl/sp101_axi_v1_0_S00_AXI.vhd]                       \
    [file normalize rtl/sp101_axi_v1_0.vhd]                               \
]
set tb_files  [list [file normalize tb/tb_user_logic.vhd]]

foreach f $rtl_files {
    if {[llength [get_files -quiet $f]] == 0} {
        puts "== Adding to sources_1 : $f"
        add_files -norecurse -fileset sources_1 $f
    }
}
foreach f $tb_files {
    if {[llength [get_files -quiet $f]] == 0} {
        puts "== Adding to sim_1    : $f"
        add_files -norecurse -fileset sim_1 $f
    }
}

#-------------------------------------------------------------------------------
# 3. File types
#-------------------------------------------------------------------------------
foreach f $rtl_files {
    set_property FILE_TYPE VHDL [get_files [file tail $f]]
}
foreach f $tb_files {
    set_property FILE_TYPE {VHDL 2008} [get_files [file tail $f]]
}

#-------------------------------------------------------------------------------
# 4. Simulation top + sources top
#-------------------------------------------------------------------------------
set_property TOP tb_user_logic [get_filesets sim_1]
update_compile_order -fileset sim_1

set_property TOP sp101_axi_v1_0 [get_filesets sources_1]
update_compile_order -fileset sources_1

puts "== sp101 setup.tcl complete."
puts "   Next:  Flow Navigator -> Run Simulation -> Run Behavioral Simulation"
puts "          Expect 'TESTBENCH PASSED - all cases ok'"
