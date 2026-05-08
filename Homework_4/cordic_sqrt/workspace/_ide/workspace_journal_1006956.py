# 2026-05-07T23:43:39.267853806
import vitis

client = vitis.create_client()
client.set_workspace(path="workspace")

platform = client.get_component(name="platform")
status = platform.build()

