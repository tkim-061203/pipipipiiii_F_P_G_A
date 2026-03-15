// Blackbox stub for sky130_sram_16kbyte_1rw1r_32x4096_8
// This file is used during synthesis to provide a module interface for the macro.
(* blackbox *)
module sky130_sram_16kbyte_1rw1r_32x4096_8(
`ifdef USE_POWER_PINS
    vccd1,
    vssd1,
`endif
    clk0, csb0, web0, wmask0, addr0, din0, dout0,
    clk1, csb1, addr1, dout1
);

    parameter DATA_WIDTH = 32 ;
    parameter ADDR_WIDTH = 12 ;
    parameter WMASK_WIDTH = 4 ;

`ifdef USE_POWER_PINS
    inout vccd1;
    inout vssd1;
`endif
    input                   clk0;
    input                   csb0;
    input                   web0;
    input [WMASK_WIDTH-1:0] wmask0;
    input [ADDR_WIDTH-1:0]  addr0;
    input [DATA_WIDTH-1:0]  din0;
    output [DATA_WIDTH-1:0] dout0;

    input                   clk1;
    input                   csb1;
    input [ADDR_WIDTH-1:0]  addr1;
    output [DATA_WIDTH-1:0] dout1;

endmodule
