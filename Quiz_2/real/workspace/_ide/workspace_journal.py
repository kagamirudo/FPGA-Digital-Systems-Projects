# 2026-05-20T19:52:25.464584862
import vitis

client = vitis.create_client()
client.set_workspace(path="workspace")

platform = client.create_platform_component(name = "platform",hw_design = "$COMPONENT_LOCATION/../../q2_real/add_const_wrapper.xsa",os = "standalone",cpu = "ps7_cortexa9_0",domain_name = "standalone_ps7_cortexa9_0",compiler = "gcc")

comp = client.create_app_component(name="add_const",platform = "$COMPONENT_LOCATION/../platform/export/platform/platform.xpfm",domain = "standalone_ps7_cortexa9_0")

comp = client.get_component(name="add_const")
status = comp.import_files(from_loc="", files=["/home/kagamirudo/ECEC661/Quiz_2/real/sw/main.c"], is_skip_copy_sources = False)

platform = client.get_component(name="platform")
status = platform.build()

status = platform.build()

comp.build()

client.delete_component(name="platform")

client.delete_component(name="add_const")

client.delete_component(name="componentName")

client.delete_component(name="componentName")

platform = client.create_platform_component(name = "platform",hw_design = "$COMPONENT_LOCATION/../../q2_real/add_const_wrapper.xsa",os = "standalone",cpu = "ps7_cortexa9_0",domain_name = "standalone_ps7_cortexa9_0",compiler = "gcc")

status = platform.build()

comp = client.create_app_component(name="add_const",platform = "$COMPONENT_LOCATION/../platform/export/platform/platform.xpfm",domain = "standalone_ps7_cortexa9_0")

status = comp.import_files(from_loc="", files=["/home/kagamirudo/ECEC661/Quiz_2/real/sw/main.c"], is_skip_copy_sources = False)

status = platform.build()

comp.build()

vitis.dispose()

