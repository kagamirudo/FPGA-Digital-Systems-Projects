# 2026-04-17T17:22:29.127585406
import vitis

client = vitis.create_client()
client.set_workspace(path="workspace")

platform = client.get_component(name="platform")
status = platform.build()

status = platform.build()

comp = client.get_component(name="led_kagami")
comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp = client.get_component(name="led_control_rgb")
comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../system_wrapper.xsa")

status = platform.build()

status = platform.build()

comp.build()

client.delete_component(name="led_kagami")

client.delete_component(name="componentName")

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

vitis.dispose()

