#-------------------------------------------------------------------------------
# scripts/setup.tcl
#
# Run from the Vivado Tcl console with cordic_sqrt.xpr open:
#     cd [file dirname [get_property DIRECTORY [current_project]]]
#     source scripts/setup.tcl
#
# Idempotent.  Performs every non-GUI step up to the behavioral simulation,
# so the only manual clicks that remain are:
#     * Run Simulation
#     * Create and Package New IP (packager runs in its own project anyway)
#     * Create block design, Synthesis, Implementation, Generate Bitstream,
#       Export Hardware
#
# What this script does:
#   1. Generates the Vivado IP-Catalog CORDIC block (cordic_0) configured for
#      Square Root with the parameters required by the assignment (Fig. 1).
#   2. Adds the three cordic_sqrt RTL files to Design Sources and the
#      testbench to Simulation Sources.
#   3. Sets file types so the packager is happy and so the TB can use VHDL
#      2008 features (LF, to_hstring).
#   4. Sets the simulation top to tb_user_logic.
#-------------------------------------------------------------------------------

set proj_dir [get_property DIRECTORY [current_project]]
puts "== cordic_sqrt setup.tcl running in [current_project] ($proj_dir)"

#-------------------------------------------------------------------------------
# 1. Generate cordic_0 from the Vivado IP Catalog
#
# Notes on CONFIG.* names (CORDIC v6.0):
#   CONFIG.Functional_Selection  : Square_Root
#   CONFIG.Architectural_Configuration : Parallel
#   CONFIG.Pipelining_Mode       : Maximum
#   CONFIG.Data_Format           : UnsignedFraction
#   CONFIG.Phase_Format          : Radians   (ignored in Square_Root mode)
#   CONFIG.Input_Width           : 10
#   CONFIG.Output_Width          : 10
#   CONFIG.Round_Mode            : Truncate
#
# As in HW3 we apply each property inside a `catch` so unknown names produce
# a single warning instead of aborting the whole script.
#-------------------------------------------------------------------------------
set ip_name cordic_0

if {[info exists env(CORDIC_SQRT_FORCE_IP)] && $env(CORDIC_SQRT_FORCE_IP) eq "1"} {
    if {[llength [get_ips -quiet $ip_name]] > 0} {
        puts "== CORDIC_SQRT_FORCE_IP=1 -> removing existing $ip_name"
        remove_files -quiet [get_files -quiet ${ip_name}.xci]
        catch { export_ip_user_files -of_objects [get_ips $ip_name] -no_script -reset -force -quiet }
    }
}

if {[llength [get_ips -quiet $ip_name]] == 0} {
    puts "== Generating IP Catalog block $ip_name (xilinx.com:ip:cordic:6.0)"
    create_ip -name cordic -vendor xilinx.com -library ip -version 6.0 \
              -module_name $ip_name
} else {
    puts "== $ip_name already present - reapplying configuration"
}

set ip_cfg [list                                           \
    CONFIG.Functional_Selection         {Square_Root}      \
    CONFIG.Architectural_Configuration  {Parallel}         \
    CONFIG.Pipelining_Mode              {Maximum}          \
    CONFIG.Data_Format                  {UnsignedFraction} \
    CONFIG.Phase_Format                 {Radians}          \
    CONFIG.Input_Width                  {10}               \
    CONFIG.Output_Width                 {10}               \
    CONFIG.Round_Mode                   {Truncate}         \
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
set rtl_files [list                                                                \
    [file normalize rtl/user_logic.vhd]                                            \
    [file normalize rtl/cordic_sqrt_axi_v1_0_S00_AXI.vhd]                          \
    [file normalize rtl/cordic_sqrt_axi_v1_0.vhd]                                  \
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
# 3. File types:  RTL in plain VHDL (so the IP packager is happy),
#                 TB  in VHDL 2008 (needs to_hstring()).
#-------------------------------------------------------------------------------
foreach f $rtl_files {
    set_property FILE_TYPE VHDL [get_files [file tail $f]]
}
foreach f $tb_files {
    set_property FILE_TYPE {VHDL 2008} [get_files [file tail $f]]
}

#-------------------------------------------------------------------------------
# 4. Simulation top
#-------------------------------------------------------------------------------
set_property TOP tb_user_logic [get_filesets sim_1]
update_compile_order -fileset sim_1

#-------------------------------------------------------------------------------
# 5. Sources top (default - useful before the block-design wrapper exists)
#-------------------------------------------------------------------------------
set_property TOP cordic_sqrt_axi_v1_0 [get_filesets sources_1]
update_compile_order -fileset sources_1

puts "== cordic_sqrt setup.tcl complete."
puts "   Next:  Flow Navigator -> Run Simulation -> Run Behavioral Simulation"
puts "          Expect 'TESTBENCH PASSED - all cases ok'"
