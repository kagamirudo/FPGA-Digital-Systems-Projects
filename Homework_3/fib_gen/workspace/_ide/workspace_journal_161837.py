# 2026-04-18T15:24:18.674980215
import vitis

client = vitis.create_client()
client.set_workspace(path="workspace")

platform = client.get_component(name="platform")
status = platform.build()

comp = client.get_component(name="fib_gen")
comp.build()

vitis.dispose()

