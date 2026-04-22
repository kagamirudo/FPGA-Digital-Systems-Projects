# 2026-04-09T04:14:20.450903714
import vitis

client = vitis.create_client()
client.set_workspace(path="workspace")

platform = client.get_component(name="platform")
status = platform.build()

comp = client.get_component(name="led_control_rgb")
comp.build()

status = platform.build()

status = platform.build()

comp.build()

vitis.dispose()

