// Stub for sky130_sram_2kbyte_1rw1r_32x512_8
// Words: 512, Word size: 32, Write mask: 8-bit (4 masks)
// Port 0: RW  /  Port 1: R-only
// Reordered to match Spice subcircuit pin order for LVS
module sky130_sram_2kbyte_1rw1r_32x512_8 (
    input  wire [31:0] din0,
    input  wire [8:0]  addr0,
    input  wire [8:0]  addr1,
    input  wire        csb0,
    input  wire        csb1,
    input  wire        web0,
    input  wire        clk0,
    input  wire        clk1,
    input  wire [3:0]  wmask0,
    output wire [31:0] dout0,
    output wire [31:0] dout1
`ifdef USE_POWER_PINS
    ,
    inout  wire        vccd1,
    inout  wire        vssd1
`endif
);
endmodule
