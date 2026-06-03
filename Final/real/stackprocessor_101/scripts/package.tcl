#-------------------------------------------------------------------------------
# scripts/package.tcl
#
# Helpers for the IP packager.  Run this AFTER:
#   1. Tools -> Create and Package New IP -> Package your current project,
#      pointing the IP location at:
#         Homework_5/stackprocessor_101/ip_repo/sp101_axi_1.0
#   2. The packager project has opened.
#
# Then in that packager project's Tcl console:
#     source scripts/package.tcl
#
# What this does:
#   * Sets Vendor / Library / Name / Version / Display / Description /
#     Category to clear the usual packager warnings (19-11888, 19-896).
#   * Adds a Sub-Core Reference to xilinx.com:ip:blk_mem_gen:8.4 under both
#     the VHDL Synthesis and VHDL Simulation file groups.
#   * Registers FREQ_HZ / ASSOCIATED_BUSIF / ASSOCIATED_RESET on
#     s00_axi_aclk (clears 19-11770 and 19-7067).
#   * Saves the core.
#
# The final step - Review and Package -> Re-Package IP - still has to be
# clicked by the user.
#-------------------------------------------------------------------------------

set core [ipx::current_core]
if {$core eq ""} {
    error "package.tcl must be run inside the IP packager project"
}

#-------------------------------------------------------------------------------
# Identification
#-------------------------------------------------------------------------------
set_property vendor       user                                           $core
set_property library      user                                           $core
set_property name         sp101_axi                                      $core
set_property version      1.0                                            $core
set_property display_name "Stack Processor 101 with ssq (AXI4-Lite)"     $core
set_property description  "Assignment PDF's stack processor (sc/sl/ss/sadd/scp) extended with the new stack-the-square instruction ssq, wrapped in an AXI4-Lite slave for the ECEC 661 final." $core
set_property taxonomy     /UserIP                                        $core

#-------------------------------------------------------------------------------
# Sub-core references.  Add once per file group.
#-------------------------------------------------------------------------------
foreach fg {xilinx_vhdlsynthesis xilinx_vhdlbehavioralsimulation} {
    set group [ipx::get_file_groups $fg -of_objects $core]
    if {$group eq ""} {
        continue
    }
    set existing [ipx::get_subcore_references xilinx.com:ip:blk_mem_gen:8.4 \
                      -of_objects $group -quiet]
    if {[llength $existing] == 0} {
        puts "== Adding sub-core reference xilinx.com:ip:blk_mem_gen:8.4 to $fg"
        ipx::add_subcore_reference xilinx.com:ip:blk_mem_gen:8.4 $group
    }
}

#-------------------------------------------------------------------------------
# Clock bus parameters - FREQ_HZ, ASSOCIATED_BUSIF, ASSOCIATED_RESET
#-------------------------------------------------------------------------------
set aclk [ipx::get_bus_interfaces s00_axi_aclk -of_objects $core]
if {$aclk ne ""} {
    if {[llength [ipx::get_bus_parameters FREQ_HZ -of_objects $aclk -quiet]] == 0} {
        ipx::add_bus_parameter FREQ_HZ $aclk
    }
    set p [ipx::get_bus_parameters FREQ_HZ -of_objects $aclk]
    set_property value              100000000 $p
    set_property value_source       user      $p
    set_property value_resolve_type user      $p

    if {[llength [ipx::get_bus_parameters ASSOCIATED_BUSIF -of_objects $aclk -quiet]] == 0} {
        ipx::add_bus_parameter ASSOCIATED_BUSIF $aclk
    }
    set p [ipx::get_bus_parameters ASSOCIATED_BUSIF -of_objects $aclk]
    set_property value              s00_axi   $p
    set_property value_source       user      $p
    set_property value_resolve_type user      $p

    if {[llength [ipx::get_bus_parameters ASSOCIATED_RESET -of_objects $aclk -quiet]] == 0} {
        ipx::add_bus_parameter ASSOCIATED_RESET $aclk
    }
    set p [ipx::get_bus_parameters ASSOCIATED_RESET -of_objects $aclk]
    set_property value              s00_axi_aresetn $p
    set_property value_source       user            $p
    set_property value_resolve_type user            $p
} else {
    puts "!! s00_axi_aclk interface not found; skipping clock parameters"
}

ipx::save_core $core

puts "== sp101_axi metadata saved.  Now click:"
puts "     Review and Package -> Re-Package IP"
