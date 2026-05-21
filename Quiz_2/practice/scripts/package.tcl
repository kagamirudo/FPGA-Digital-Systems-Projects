#-------------------------------------------------------------------------------
# scripts/package.tcl
#
# Run this inside the IP Packager project after:
#   Tools -> Create and Package New IP -> Package your current project
#   IP location:
#       Quiz_2/practice/ip_repo/stack_practice_axi_1.0
#
# It sets the metadata that Vivado commonly warns about, registers the AXI
# clock/reset parameters, and saves the core.  Finish by clicking:
#   Review and Package -> Re-Package IP
#-------------------------------------------------------------------------------

set core [ipx::current_core]
if {$core eq ""} {
    error "package.tcl must be run inside the IP packager project"
}

set_property vendor       user                                      $core
set_property library      user                                      $core
set_property name         stack_practice_axi                        $core
set_property version      1.0                                       $core
set_property display_name "Quiz 2 Practice Stack AXI4-Lite Core"    $core
set_property description  "Small 8-entry stack user logic wrapped as an AXI4-Lite custom IP for Quiz 2 practice." $core
set_property taxonomy     /UserIP                                   $core

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

puts "== stack_practice_axi metadata saved."
puts "   Next: Review and Package -> Re-Package IP"
