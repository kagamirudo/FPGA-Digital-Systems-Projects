#-------------------------------------------------------------------------------
# scripts/setup.tcl
#
# Run from the Vivado Tcl console with fix_acc.xpr open:
#     source scripts/setup.tcl
#
# Idempotent.  Performs every non-GUI step that the plan lists up to the
# behavioral simulation, so the only manual clicks that remain are:
#     * Run Simulation
#     * Create and Package New IP (packager runs in its own project anyway)
#     * Create block design, Synthesis, Implementation, Generate Bitstream,
#       Export Hardware
#
# What this script does:
#   1. Generates the Vivado IP-Catalog Accumulator (c_accum_0) if it is not
#      already present under fix_acc.srcs/sources_1/ip.
#   2. Adds the three fix_acc RTL files to Design Sources and the testbench
#      to Simulation Sources.
#   3. Sets file types:  RTL = VHDL (packager friendly),
#                        TB  = VHDL 2008 (needs to_hstring() etc.).
#   4. Sets the simulation top to tb_fix_acc_core.
#-------------------------------------------------------------------------------

set proj_dir [get_property DIRECTORY [current_project]]
puts "== fix_acc setup.tcl running in [current_project] ($proj_dir)"

#-------------------------------------------------------------------------------
# 1. Generate c_accum_0 from the Vivado IP Catalog
#
# Notes on CONFIG.* names:
#   * The exact CONFIG.* parameter names vary slightly between Vivado releases.
#   * On some installs there is no CONFIG.Add_Mode / CONFIG.Bypass parameter
#     (the default value is simply "Add" / "false" and cannot be overridden),
#     so we set each property individually inside a `catch` and warn rather
#     than aborting the whole script when a name is unknown.
#   * To see every parameter your Vivado exposes for this IP, open the Tcl
#     console after create_ip and run:
#         report_property [get_ips c_accum_0]
#-------------------------------------------------------------------------------
set ip_name c_accum_0

# If a previous run created the IP but failed mid-configuration, remove it so
# we start from a clean state.  We detect this by the absence of the .xci file
# on disk for the ip object, or by the user asking for a forced rebuild.
if {[info exists env(FIX_ACC_FORCE_IP)] && $env(FIX_ACC_FORCE_IP) eq "1"} {
    if {[llength [get_ips -quiet $ip_name]] > 0} {
        puts "== FIX_ACC_FORCE_IP=1 -> removing existing $ip_name"
        remove_files -quiet [get_files -quiet ${ip_name}.xci]
        catch { export_ip_user_files -of_objects [get_ips $ip_name] -no_script -reset -force -quiet }
    }
}

if {[llength [get_ips -quiet $ip_name]] == 0} {
    puts "== Generating IP Catalog block $ip_name (xilinx.com:ip:c_accum:12.0)"
    create_ip -name c_accum -vendor xilinx.com -library ip -version 12.0 \
              -module_name $ip_name
} else {
    puts "== $ip_name already present - reapplying configuration"
}

# Per-property configuration with `catch`.  If a parameter does not exist in
# your Vivado version we just log a warning and keep going.  The listed values
# are all c_accum defaults or match the book (Fig. 8.7.3).
set ip_cfg [list                                  \
    CONFIG.Implementation  {Fabric}               \
    CONFIG.Input_Width     {32}                   \
    CONFIG.Output_Width    {32}                   \
    CONFIG.Input_Type      {Signed}               \
    CONFIG.SCLR            {true}                 \
    CONFIG.CE              {false}                \
    CONFIG.Latency         {1}                    \
]

set ip_obj [get_ips $ip_name]
foreach {pname pval} $ip_cfg {
    if {[catch {set_property $pname $pval $ip_obj} msg]} {
        puts "   (warn) could not set $pname = $pval on $ip_name : $msg"
    }
}

# Show the final effective configuration so mismatches are easy to spot.
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
set rtl_files [list                                                           \
    [file normalize rtl/fix_acc_core.vhd]                                     \
    [file normalize rtl/fix_acc_axi_v1_0_S00_AXI.vhd]                         \
    [file normalize rtl/fix_acc_axi_v1_0.vhd]                                 \
]
set tb_files  [list [file normalize tb/tb_fix_acc_core.vhd]]

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
# 3. File types:  RTL in plain VHDL (so the IP packager is happy), TB in VHDL 2008
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
set_property TOP tb_fix_acc_core [get_filesets sim_1]
update_compile_order -fileset sim_1

#-------------------------------------------------------------------------------
# 5. Sources top (default - useful before the block-design wrapper exists)
#-------------------------------------------------------------------------------
set_property TOP fix_acc_axi_v1_0 [get_filesets sources_1]
update_compile_order -fileset sources_1

puts "== fix_acc setup.tcl complete."
puts "   Next:  Flow Navigator -> Run Simulation -> Run Behavioral Simulation"
puts "          Expect 'TESTBENCH PASSED - all cases match'"
