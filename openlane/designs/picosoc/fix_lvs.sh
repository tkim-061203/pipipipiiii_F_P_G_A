#!/bin/bash
RUN_DIR=$(ls -td /home/ultralab/shtp/by_kim/openlane/designs/picosoc/runs/RUN_* | head -1)
PDK_ROOT="/home/ultralab/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af"

# Find the Magic StreamOut GDS
GDS_FILE=$(find $RUN_DIR -name "*.gds" -path "*/klayout-streamout/*" | head -1)

echo "Using GDS: $GDS_FILE"
echo "Run dir: $RUN_DIR"

magic -dnull -noconsole -T sky130A << MAGICEOF
gds read $GDS_FILE
load system
cellname filepath sky130_sram_2kbyte_1rw1r_32x512_8 $PDK_ROOT/sky130A/libs.ref/sky130_sram_macros/maglef
flush sky130_sram_2kbyte_1rw1r_32x512_8
select top cell
extract all
ext2spice lvs
ext2spice -o $RUN_DIR/system_fixed.spice
quit
MAGICEOF

echo "Fixed spice: $RUN_DIR/system_fixed.spice"
echo ""
echo "Now run LVS manually:"
echo "netgen -batch lvs \"$RUN_DIR/system_fixed.spice system\" \"$RUN_DIR/62-netgen-lvs/schematic.spi system\" $PDK_ROOT/sky130A/libs.tech/netgen/sky130A_setup.tcl $RUN_DIR/lvs_fixed.rpt"
