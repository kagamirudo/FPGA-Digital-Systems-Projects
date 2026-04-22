#-------------------------------------------------------------------------------
# scripts/setup.tcl
#
# Run from the Vivado Tcl console with Quiz_1/real/q1_real/q1_real.xpr open:
#     cd [file dirname [get_property DIRECTORY [current_project]]]/..
#     source scripts/setup.tcl
#
# Idempotent.  Performs every non-GUI step required to reach simulation, so
# the only manual click left is "Run Simulation -> Run Behavioral Simulation".
#
# What this script does:
#   1. Generates the Vivado IP-Catalog RAM-based Shift Register
#      (c_shift_ram_0) if it is not already present.  Configuration:
#         Width = 4, Depth = 6, Fixed_Length,
#         CE enabled, SCLR enabled, initial values 0.
#   2. Adds user_logic.vhd to Design Sources and tb/tb_user_logic.vhd
#      to Simulation Sources.
#   3. Sets file types: RTL = VHDL, TB = VHDL 2008 (for std.textio.LF).
#   4. Sets the simulation top to tb_user_logic and the sources top to
#      user_logic.
#
# To force a fresh IP regeneration (e.g. after tweaking the configuration),
# set the env var QUIZ1_REAL_FORCE_IP=1 before sourcing.
#-------------------------------------------------------------------------------

set proj_dir [get_property DIRECTORY [current_project]]
puts "== quiz1/real setup.tcl running in [current_project] ($proj_dir)"

#-------------------------------------------------------------------------------
# 1. Generate c_shift_ram_0 from the Vivado IP Catalog
#
# Notes on CONFIG.* names:
#   * Property names differ slightly between Vivado releases.  Each one is
#     applied inside `catch` so an unknown name just warns.
#   * To list every valid property for your install:
#         report_property [get_ips c_shift_ram_0]
#-------------------------------------------------------------------------------
set ip_name c_shift_ram_0

if {[info exists env(QUIZ1_REAL_FORCE_IP)] && $env(QUIZ1_REAL_FORCE_IP) eq "1"} {
    if {[llength [get_ips -quiet $ip_name]] > 0} {
        puts "== QUIZ1_REAL_FORCE_IP=1 -> removing existing $ip_name"
        remove_files -quiet [get_files -quiet ${ip_name}.xci]
        catch { export_ip_user_files -of_objects [get_ips $ip_name] -no_script -reset -force -quiet }
    }
}

if {[llength [get_ips -quiet $ip_name]] == 0} {
    puts "== Generating IP Catalog block $ip_name (xilinx.com:ip:c_shift_ram:12.0)"
    create_ip -name c_shift_ram -vendor xilinx.com -library ip -version 12.0 \
              -module_name $ip_name
} else {
    puts "== $ip_name already present - reapplying configuration"
}

set ip_cfg [list                                      \
    CONFIG.ShiftRegType              {Fixed_Length}   \
    CONFIG.Width                     {4}              \
    CONFIG.Depth                     {6}              \
    CONFIG.CE                        {true}           \
    CONFIG.SCLR                      {true}           \
    CONFIG.AsyncInitVal_Hex          {0}              \
    CONFIG.SyncInitVal_Hex           {0}              \
    CONFIG.DefaultData_Hex           {0}              \
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
set rtl_files [list [file normalize rtl/user_logic.vhd]]
set tb_files  [list [file normalize tb/tb_user_logic.vhd]]

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

set_property TOP user_logic [get_filesets sources_1]
update_compile_order -fileset sources_1

puts "== quiz1/real setup.tcl complete."
puts "   Next:  Flow Navigator -> Run Simulation -> Run Behavioral Simulation"
puts {          Expect '[PASS]' per vector and 'TESTBENCH PASSED' banner.}
