// Blackbox stub for xoodyakcore
(* blackbox *)
module xoodyakcore (
`ifdef USE_POWER_PINS
    VPWR,
    VGND,
`endif
    clk, resetn,
    xd_key, xd_nonce, xd_ad, xd_data_in, xd_tag_in,
    xd_ad_length, xd_data_length, xd_sel_type, xd_ena,
    xd_data_out, xd_tag_out,
    xd_done, xd_valid
);
`ifdef USE_POWER_PINS
    inout VPWR, VGND;
`endif
    input clk, resetn, xd_ena;
    input [127:0] xd_key, xd_nonce, xd_ad, xd_data_in, xd_tag_in;
    input [4:0]   xd_ad_length, xd_data_length;
    input [1:0]   xd_sel_type;
    output [127:0] xd_data_out, xd_tag_out;
    output xd_done, xd_valid;
endmodule
