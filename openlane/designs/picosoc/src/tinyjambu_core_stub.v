// Blackbox stub for tinyjambu_core
(* blackbox *)
module tinyjambu_core (
`ifdef USE_POWER_PINS
    VPWR,
    VGND,
`endif
    clk, resetn,
    jb_key, jb_nonce, jb_ad, jb_data_in, jb_tag_in,
    jb_ad_length, jb_data_length, jb_sel_type, jb_ena,
    jb_data_out, jb_tag_out,
    jb_done, jb_valid
);
`ifdef USE_POWER_PINS
    inout VPWR, VGND;
`endif
    input clk, resetn, jb_ena;
    input [127:0] jb_key;
    input [95:0]  jb_nonce;
    input [127:0] jb_ad, jb_data_in;
    input [63:0]  jb_tag_in;
    input [4:0]   jb_ad_length, jb_data_length;
    input [2:0]   jb_sel_type;
    output [127:0] jb_data_out;
    output [63:0]  jb_tag_out;
    output jb_done, jb_valid;
endmodule
