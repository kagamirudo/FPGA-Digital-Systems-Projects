# 2026-04-08T20:32:30.600712627
import vitis

client = vitis.create_client()
client.set_workspace(path="workspace")

platform = client.get_component(name="platform")
status = platform.build()

status = platform.build()

status = platform.build()

client.delete_component(name="platform")

client.delete_component(name="componentName")

platform = client.create_platform_component(name = "platform",hw_design = "$COMPONENT_LOCATION/../../system_wrapper.xsa",os = "standalone",cpu = "ps7_cortexa9_0",domain_name = "standalone_ps7_cortexa9_0",compiler = "gcc")

status = platform.build()

status = platform.build()

comp = client.get_component(name="led_control_rgb")
comp.build()

status = platform.build()

comp.build()

vitis.dispose()

