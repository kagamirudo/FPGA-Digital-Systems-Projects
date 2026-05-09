# 2026-05-07T23:44:32.334592340
import vitis

client = vitis.create_client()
client.set_workspace(path="workspace")

platform = client.get_component(name="platform")
status = platform.build()

comp = client.create_app_component(name="cord_sqr_app",platform = "$COMPONENT_LOCATION/../platform/export/platform/platform.xpfm",domain = "standalone_ps7_cortexa9_0")

comp = client.get_component(name="cord_sqr_app")
status = comp.import_files(from_loc="", files=["/home/kagamirudo/ECEC661/Homework_4/cordic_sqrt/sw/main.c"], is_skip_copy_sources = False)

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = comp.import_files(from_loc="$COMPONENT_LOCATION/../../sw", files=["main.c"], is_skip_copy_sources = False)

status = platform.build()

comp.build()

status = comp.import_files(from_loc="$COMPONENT_LOCATION/../../sw", files=["main.c"], is_skip_copy_sources = False)

status = platform.build()

comp.build()

status = comp.import_files(from_loc="$COMPONENT_LOCATION/../../sw", files=["main.c"], is_skip_copy_sources = False)

status = platform.build()

comp.build()

status = comp.import_files(from_loc="$COMPONENT_LOCATION/../../sw", files=["main.c"], is_skip_copy_sources = False)

status = platform.build()

comp.build()

vitis.dispose()

