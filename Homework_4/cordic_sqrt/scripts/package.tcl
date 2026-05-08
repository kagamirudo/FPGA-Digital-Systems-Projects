#-------------------------------------------------------------------------------
# scripts/package.tcl
#
# Helpers for the IP packager.  Run this AFTER you have:
#     1. Launched Tools -> Create and Package New IP -> Package your current
#        project, pointing the IP location at:
#            Homework_4/cordic_sqrt/ip_repo/cordic_sqrt_axi_1.0
#     2. The packager project has opened.
#
# Then in that packager project's Tcl console:
#     source scripts/package.tcl
#
# What this does:
#   * Sets Vendor / Library / Name / Version / Display / Description /
#     Category to clear the usual packager warnings (19-11888, 19-896).
#   * Adds a Sub-Core Reference to xilinx.com:ip:cordic:6.0 under both
#     the VHDL Synthesis and VHDL Simulation file groups.
#   * Registers FREQ_HZ / ASSOCIATED_BUSIF / ASSOCIATED_RESET on
#     s00_axi_aclk (clears warnings 19-11770 and 19-7067).
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
set_property vendor       user                                              $core
set_property library      user                                              $core
set_property name         cordic_sqrt_axi                                   $core
set_property version      1.0                                               $core
set_property display_name "CORDIC Square Root AXI4-Lite Core"               $core
set_property description  "10-bit unsigned-fraction CORDIC square root (cordic v6.0) wrapped in an AXI4-Lite slave; software pushes 2Q7 samples and reads 1Q8 results." $core
set_property taxonomy     /UserIP                                           $core

#-------------------------------------------------------------------------------
# Sub-core references.  Add once per file group.
#-------------------------------------------------------------------------------
foreach fg {xilinx_vhdlsynthesis xilinx_vhdlbehavioralsimulation} {
    set group [ipx::get_file_groups $fg -of_objects $core]
    if {$group eq ""} {
        continue
    }
    set existing [ipx::get_subcore_references xilinx.com:ip:cordic:6.0 \
                      -of_objects $group -quiet]
    if {[llength $existing] == 0} {
        puts "== Adding sub-core reference xilinx.com:ip:cordic:6.0 to $fg"
        ipx::add_subcore_reference xilinx.com:ip:cordic:6.0 $group
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

puts "== cordic_sqrt_axi metadata saved.  Now click:"
puts "     Review and Package -> Re-Package IP"
