// Blackbox stub for cofb_core
(* blackbox *)
module cofb_core (
`ifdef USE_POWER_PINS
    VPWR,
    VGND,
`endif
    clk, resetn,
    gc_key, gc_nonce, gc_ad, gc_data_in, gc_tag_in,
    gc_ad_length, gc_data_length, gc_decrypt_mode, gc_start,
    gc_ad_ack, gc_msg_ack,
    gc_ad_req, gc_msg_req,
    gc_data_out, gc_tag_out,
    gc_done, gc_valid
);
`ifdef USE_POWER_PINS
    inout VPWR, VGND;
`endif
    input clk, resetn, gc_decrypt_mode, gc_start, gc_ad_ack, gc_msg_ack;
    input [127:0] gc_key, gc_nonce, gc_ad, gc_data_in, gc_tag_in;
    input [7:0]   gc_ad_length, gc_data_length;
    output gc_ad_req, gc_msg_req, gc_done, gc_valid;
    output [127:0] gc_data_out, gc_tag_out;
endmodule
