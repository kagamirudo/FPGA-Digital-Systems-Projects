# 2026-04-22T16:39:10.488285289
import vitis

client = vitis.create_client()
client.set_workspace(path="workspace")

platform = client.create_platform_component(name = "platform",hw_design = "$COMPONENT_LOCATION/../../fix_acc_wrapper.xsa",os = "standalone",cpu = "ps7_cortexa9_0",domain_name = "standalone_ps7_cortexa9_0",compiler = "gcc")

comp = client.create_app_component(name="fix_acc",platform = "$COMPONENT_LOCATION/../platform/export/platform/platform.xpfm",domain = "standalone_ps7_cortexa9_0",template = "empty_application")

comp = client.get_component(name="fix_acc")
status = comp.import_files(from_loc="$COMPONENT_LOCATION/../../sw", files=["main.c"], dest_dir_in_cmp = "src", is_skip_copy_sources = False)

platform = client.get_component(name="platform")
status = platform.build()

status = platform.build()

comp.build()

status = comp.import_files(from_loc="$COMPONENT_LOCATION/../../sw", files=["main.c"], dest_dir_in_cmp = "src", is_skip_copy_sources = False)

status = platform.build()

comp.build()

status = platform.build()

comp.build()

