# Top-level helpers for this Vivado/Vitis project (gpio_leds).
# Default: show available targets.

.PHONY: default help kill-vitis clean-vitis

default: help

help:
	@echo "Targets:"
	@echo "  kill-vitis   - stop Vitis IDE, vitis-server, hw_server, and XSCT/xsdb for this user"
	@echo "  clean-vitis  - remove Vitis workspace build outputs (build/, gen_bsp, export, IDE caches)"

kill-vitis:
	-pkill -u $$(whoami) -f '/Vitis/ide/electron-app/.*vitis-ide' 2>/dev/null
	-pkill -u $$(whoami) -f '/Vitis/bin/vitis-server' 2>/dev/null
	-pkill -u $$(whoami) -f 'com\.xilinx\.rigel\.app\.RigelApp' 2>/dev/null
	-pkill -u $$(whoami) -f 'vitis/ipc-bootstrap' 2>/dev/null
	-pkill -u $$(whoami) -f '/Vitis/bin/unwrapped/.*hw_server' 2>/dev/null
	-pkill -u $$(whoami) -f 'xsdb.*\.vitis/temp_xsct_launch_script\.tcl' 2>/dev/null
	@echo "kill-vitis: sent signals (ignore errors if nothing was running)."

# Vitis Unified IDE / CMake workspace lives under ./workspace
WORKSPACE := $(abspath workspace)

clean-vitis:
	@if [ ! -d "$(WORKSPACE)" ]; then echo "clean-vitis: no workspace at $(WORKSPACE)"; exit 1; fi
	@echo "clean-vitis: scrubbing $(WORKSPACE) ..."
	find "$(WORKSPACE)" -type d -name build -prune -exec rm -rf {} +
	find "$(WORKSPACE)" -type d -path '*/libsrc/build_configs/gen_bsp' -prune -exec rm -rf {} +
	rm -rf "$(WORKSPACE)/platform/export"
	rm -rf "$(WORKSPACE)/_ide/logs" "$(WORKSPACE)/_ide/.wsdata"
	find "$(WORKSPACE)" -type d -name _ide -path '*/_ide' ! -path '$(WORKSPACE)/_ide' | while read -r d; do \
		rm -rf "$$d/logs" "$$d/.wsdata"; \
	done
	find "$(WORKSPACE)" \( -name compile_commands.json -o -name .hash-map.txt -o -name .buildstatus -o -name .ninja_log \) -type f -delete 2>/dev/null || true
	@echo "clean-vitis: done."
