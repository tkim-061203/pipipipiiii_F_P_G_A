VIVADO_BASE = /tools/Xilinx/Vivado/2024.2
VIVADO = $(VIVADO_BASE)/bin/vivado
XVLOG = $(VIVADO_BASE)/bin/xvlog
XELAB = $(VIVADO_BASE)/bin/xelab
GLBL = $(VIVADO_BASE)/data/verilog/src/glbl.v
TOOLCHAIN_PREFIX = /opt/riscv/bin/riscv64-unknown-elf-

export VIVADO

export RDI_VERBOSE = False

help:
	@echo ""
	@echo "Simple synthesis tests:"
	@echo "  make synth_area_{small|regular|large}"
	@echo "  make synth_speed"
	@echo ""
	@echo "System (SD-boot):"
	@echo "  make synth_system          <- synthesis (1 lần, chỉ cần khi đổi RTL/bootloader)"
	@echo "  make bootloader.hex        <- rebuild bootloader nếu bootloader.c thay đổi"
	@echo "  make sim_system"
	@echo ""
	@echo "Firmware update (KHÔNG cần synthesis lại):"
	@echo "  cd ../../firmware && make firmware"
	@echo "  cd ../../firmware && make write-sd SD_DEV=/dev/sdX"
	@echo "  (reset FPGA - bootloader tự đọc SD và load firmware)"
	@echo ""

synth_%:
	rm -f $@.log
	$(VIVADO) -nojournal -log $@.log -mode batch -source $@.tcl
	rm -rf .Xil fsm_encoding.os synth_*.backup.log usage_statistics_webtalk.xml
	-grep -B4 -A10 'Slice LUTs' $@.log
	-grep -B1 -A9 ^Slack $@.log && echo


synth_system: bootloader.hex

sim_system:
	$(XVLOG) system_tb.v synth_system.v
	$(XVLOG) $(GLBL)
	$(XELAB) -L unifast_ver -L unisims_ver -R system_tb glbl


bootloader.hex: ../../firmware/bootloader.c ../../firmware/boot_crt0.S ../../firmware/bootloader.ld
	$(TOOLCHAIN_PREFIX)gcc \
		-march=rv32i -mabi=ilp32 -Os -g \
		-ffreestanding -fno-builtin \
		-nostdlib -nostartfiles \
		-T ../../firmware/bootloader.ld \
		-o bootloader_tmp.elf \
		../../firmware/boot_crt0.S \
		../../firmware/bootloader.c
	$(TOOLCHAIN_PREFIX)objcopy -O binary bootloader_tmp.elf bootloader_tmp.bin
	python3 ../../firmware/makehex.py bootloader_tmp.bin 1024 > bootloader.hex
	rm -f bootloader_tmp.elf bootloader_tmp.bin
	@echo "[BOOT] bootloader.hex ready (1024 words = 4 KB)"
	@echo "[INFO] Re-synthesize Vivado project để nạp bootloader mới vào bitfile"

# -------------------------------------------------------
# firmware.hex (legacy — chỉ dùng cho sim, KHÔNG dùng cho synth_system)
# Nếu không cần sim có thể xóa target này
# -------------------------------------------------------
firmware.hex: firmware.S firmware.c firmware.lds
	$(TOOLCHAIN_PREFIX)gcc -Os -ffreestanding -nostdlib \
		-mabi=ilp32 -march=rv32i \
		-o firmware.elf firmware.S firmware.c \
		--std=gnu99 \
		-Wl,-Bstatic,-T,firmware.lds,-Map,firmware.map,\
--strip-debug,--build-id=none -lgcc
	$(TOOLCHAIN_PREFIX)objcopy -O binary firmware.elf firmware.bin
	python3 ../../firmware/makehex.py firmware.bin 4096 > firmware.hex

# -------------------------------------------------------
tab_%/results.txt:
	bash tabtest.sh $@

area: synth_area_small synth_area_regular synth_area_large
	-grep -B4 -A10 'Slice LUTs' \
		synth_area_small.log \
		synth_area_regular.log \
		synth_area_large.log

clean:
	rm -rf .Xil/
	rm -f firmware.bin firmware.elf firmware.hex firmware.map
	rm -f bootloader.hex bootloader_tmp.elf bootloader_tmp.bin
	rm -rf synth_*.log synth_*.mmi synth_*.bit synth_system.v
	rm -rf table.txt tab_*/ webtalk.jou
	rm -rf webtalk.log webtalk_*.jou webtalk_*.log
	rm -rf xelab.* xsim[._]* xvlog.*
