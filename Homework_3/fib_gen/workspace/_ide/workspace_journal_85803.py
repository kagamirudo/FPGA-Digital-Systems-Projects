# 2026-04-18T14:49:29.363403413
import vitis

client = vitis.create_client()
client.set_workspace(path="workspace")

platform = client.get_component(name="platform")
status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../fib_wrapper.xsa")

status = platform.build()

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../fib_wrapper.xsa")

status = platform.build()

domain = platform.get_domain(name="standalone_ps7_cortexa9_0")

status = domain.set_config(option = "os", param = "standalone_stdin", value = "ps7_uart_0")

status = domain.set_config(option = "os", param = "standalone_stdout", value = "ps7_uart_0")

status = domain.regenerate()

status = platform.build()

comp = client.get_component(name="fib_gen")
comp.build()

status = domain.regenerate()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

vitis.dispose()

