# 2026-06-03T19:01:01.683597509
import vitis

client = vitis.create_client()
client.set_workspace(path="workspace")

platform = client.create_platform_component(name = "platform",hw_design = "$COMPONENT_LOCATION/../../../sp101/sp101_wrapper.xsa",os = "standalone",cpu = "ps7_cortexa9_0",domain_name = "standalone_ps7_cortexa9_0",compiler = "gcc")

platform = client.get_component(name="platform")
status = platform.build()

comp = client.create_app_component(name="sp101_ssq",platform = "$COMPONENT_LOCATION/../platform/export/platform/platform.xpfm",domain = "standalone_ps7_cortexa9_0")

comp = client.get_component(name="sp101_ssq")
status = comp.import_files(from_loc="", files=["/home/kagamirudo/ECE661/Final/real/stackprocessor_101/sw/main.c"], is_skip_copy_sources = False)

status = platform.build()

comp.build()

vitis.dispose()

