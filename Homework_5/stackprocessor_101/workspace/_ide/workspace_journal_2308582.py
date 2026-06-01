# 2026-06-01T07:23:18.271757953
import vitis

client = vitis.create_client()
client.set_workspace(path="workspace")

platform = client.create_platform_component(name = "platform",hw_design = "$COMPONENT_LOCATION/../../../sp101/sp101_wrapper.xsa",os = "standalone",cpu = "ps7_cortexa9_0",domain_name = "standalone_ps7_cortexa9_0",compiler = "gcc")

