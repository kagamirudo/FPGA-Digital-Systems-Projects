# 2026-04-09T01:57:01.612805002
import vitis

client = vitis.create_client()
client.set_workspace(path="workspace")

platform = client.get_component(name="platform")
status = platform.build()

comp = client.get_component(name="led_control_rgb")
comp.build()

vitis.dispose()

