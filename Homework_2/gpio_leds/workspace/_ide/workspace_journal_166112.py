# 2026-04-17T12:25:05.366553017
import vitis

client = vitis.create_client()
client.set_workspace(path="workspace")

platform = client.get_component(name="platform")
status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../system_wrapper.xsa")

status = platform.build()

comp = client.clone_component(name="platform",new_name="platform1")

vitis.dispose()

