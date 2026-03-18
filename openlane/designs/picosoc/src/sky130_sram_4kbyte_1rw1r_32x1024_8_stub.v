`default_nettype none
module sky130_sram_4kbyte_1rw1r_32x1024_8 (
`ifdef USE_POWER_PINS
    inout vccd1,
    inout vssd1,
`endif
    input  wire        clk0,
    input  wire        csb0,
    input  wire        web0,
    input  wire [3:0]  wmask0,
    input  wire [9:0]  addr0,
    input  wire [31:0] din0,
    output wire [31:0] dout0,
    input  wire        clk1,
    input  wire        csb1,
    input  wire [9:0]  addr1,
    output wire [31:0] dout1
);
endmodule
