# 2026-06-01T07:26:13.812224776
import vitis

client = vitis.create_client()
client.set_workspace(path="workspace")

platform = client.get_component(name="platform")
status = platform.build()

comp = client.create_app_component(name="sp101",platform = "$COMPONENT_LOCATION/../platform/export/platform/platform.xpfm",domain = "standalone_ps7_cortexa9_0")

comp = client.get_component(name="sp101")
status = comp.import_files(from_loc="", files=["/home/kagamirudo/ECEC661/Homework_5/stackprocessor_101/sw/main.c"], is_skip_copy_sources = False)

status = platform.build()

comp.build()

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../../sp101/sp101_wrapper.xsa")

status = platform.build()

status = comp.import_files(from_loc="$COMPONENT_LOCATION/../../sw", files=["main.c"], is_skip_copy_sources = False)

status = platform.build()

comp.build()

vitis.dispose()

