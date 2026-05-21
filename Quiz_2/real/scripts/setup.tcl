#-------------------------------------------------------------------------------
# scripts/setup.tcl
#
# Run from the Vivado Tcl console with Quiz_2/real/q2_real/q2_real.xpr open:
#     cd [file dirname [get_property DIRECTORY [current_project]]]/..
#     source scripts/setup.tcl
#
# Idempotent.  Performs every non-GUI step required to reach behavioral
# simulation, so the only manual click left is:
#     Flow Navigator -> Run Simulation -> Run Behavioral Simulation
#
# What this script does:
#   1. Generates the Vivado IP-Catalog Adder/Subtractor (c_addsub_0)
#      configured per the quiz hand-out:
#         Implementation : Fabric
#         Add Mode       : Add        ->  S = A + B
#         A : Signed, 32-bit
#         B : Signed, 32-bit, *Constant Input* = 32'b1...1 (= -1)
#         Output Width   : 32
#         Latency        : 0          ->  combinational, no CLK / CE
#         Clock Enable   : disabled
#   2. Adds the three RTL files to Design Sources and the testbench to
#      Simulation Sources.
#   3. Sets file types:  RTL = VHDL,  TB = VHDL 2008 (for std.textio.LF).
#   4. Sets the simulation top to tb_user_logic and the sources top to
#      add_const_axi_v1_0.
#
# To force a fresh IP regeneration (e.g. after tweaking the configuration),
# set the env var QUIZ2_REAL_FORCE_IP=1 before sourcing.
#-------------------------------------------------------------------------------

set proj_dir [get_property DIRECTORY [current_project]]
puts "== quiz2/real setup.tcl running in [current_project] ($proj_dir)"

#-------------------------------------------------------------------------------
# 1. Generate c_addsub_0 from the Vivado IP Catalog
#
# Notes on CONFIG.* names (c_addsub v12.0):
#   CONFIG.Implementation    : Fabric (vs. DSP48)
#   CONFIG.A_Type            : Signed
#   CONFIG.B_Type            : Signed
#   CONFIG.A_Width           : 32
#   CONFIG.B_Width           : 32
#   CONFIG.Out_Width         : 32
#   CONFIG.Add_Mode          : Add
#   CONFIG.B_Constant        : true     (B is a constant; not exposed as port)
#   CONFIG.B_Value           : 11111111111111111111111111111111   (32-bit -1)
#   CONFIG.Latency           : 0        (combinational; no CLK/CE/SCLR ports)
#   CONFIG.CE                : false
#   CONFIG.SCLR              : false
#
# As elsewhere in this repo, each CONFIG is set inside a `catch` so unknown
# parameter names print a single warning instead of aborting the script.
# To inspect every parameter your Vivado exposes, after create_ip run:
#     report_property [get_ips c_addsub_0]
#-------------------------------------------------------------------------------
set ip_name c_addsub_0

if {[info exists env(QUIZ2_REAL_FORCE_IP)] && $env(QUIZ2_REAL_FORCE_IP) eq "1"} {
    if {[llength [get_ips -quiet $ip_name]] > 0} {
        puts "== QUIZ2_REAL_FORCE_IP=1 -> removing existing $ip_name"
        remove_files -quiet [get_files -quiet ${ip_name}.xci]
        catch { export_ip_user_files -of_objects [get_ips $ip_name] -no_script -reset -force -quiet }
    }
}

if {[llength [get_ips -quiet $ip_name]] == 0} {
    puts "== Generating IP Catalog block $ip_name (xilinx.com:ip:c_addsub:12.0)"
    create_ip -name c_addsub -vendor xilinx.com -library ip -version 12.0 \
              -module_name $ip_name
} else {
    puts "== $ip_name already present - reapplying configuration"
}

set ip_cfg [list                                                                   \
    CONFIG.Implementation  {Fabric}                                                \
    CONFIG.A_Type          {Signed}                                                \
    CONFIG.B_Type          {Signed}                                                \
    CONFIG.A_Width         {32}                                                    \
    CONFIG.B_Width         {32}                                                    \
    CONFIG.Out_Width       {32}                                                    \
    CONFIG.Add_Mode        {Add}                                                   \
    CONFIG.B_Constant      {true}                                                  \
    CONFIG.B_Value         {11111111111111111111111111111111}                      \
    CONFIG.Latency         {0}                                                     \
    CONFIG.CE              {false}                                                 \
    CONFIG.SCLR            {false}                                                 \
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
# 2. Add RTL + TB sources if not already present
#-------------------------------------------------------------------------------
set rtl_files [list                                                       \
    [file normalize rtl/user_logic.vhd]                                   \
    [file normalize rtl/add_const_axi_v1_0_S00_AXI.vhd]                   \
    [file normalize rtl/add_const_axi_v1_0.vhd]                           \
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
# 4. Tops
#-------------------------------------------------------------------------------
set_property TOP tb_user_logic [get_filesets sim_1]
update_compile_order -fileset sim_1

set_property TOP add_const_axi_v1_0 [get_filesets sources_1]
update_compile_order -fileset sources_1

puts "== quiz2/real setup.tcl complete."
puts "   Next: Flow Navigator -> Run Simulation -> Run Behavioral Simulation"
puts {          Expect '[PASS] x=...' lines and 'TESTBENCH PASSED' banner.}
