# 2026-05-06T18:58:18.309886853
import vitis

client = vitis.create_client()
client.set_workspace(path="workspace")

platform = client.create_platform_component(name = "platform",hw_design = "$COMPONENT_LOCATION/../../bnt_seq/seq_det_wrapper.xsa",os = "standalone",cpu = "ps7_cortexa9_0",domain_name = "standalone_ps7_cortexa9_0",compiler = "gcc")

comp = client.create_app_component(name="seq_det",platform = "$COMPONENT_LOCATION/../platform/export/platform/platform.xpfm",domain = "standalone_ps7_cortexa9_0")

comp = client.get_component(name="seq_det")
status = comp.import_files(from_loc="", files=["/home/kagamirudo/ECE661/Midterm/real/sw/main.c"], is_skip_copy_sources = False)

platform = client.get_component(name="platform")
status = platform.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = comp.import_files(from_loc="$COMPONENT_LOCATION/../../sw", files=["main.c"], dest_dir_in_cmp = "src", is_skip_copy_sources = False)

status = platform.build()

comp.build()

vitis.dispose()

