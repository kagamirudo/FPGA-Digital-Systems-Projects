# 2026-04-17T17:16:22.785850265
import vitis

client = vitis.create_client()
client.set_workspace(path="workspace")

platform = client.get_component(name="platform")
status = platform.build()

comp = client.get_component(name="led_kagami")
comp.build()

vitis.dispose()

