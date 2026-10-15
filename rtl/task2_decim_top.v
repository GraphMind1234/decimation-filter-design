`timescale 1ns / 1ps
//=============================================================================
// task2_decim_top.v  -  TASK 2: CIC + FIR droop compensator (OSR 2048)
//  din (2-bit) @ 4.096 MHz -> CIC (N=4, R=512) -> 24-bit @ 8 kHz
//                          -> 27-tap FIR, decimate by 4 -> dout 20-bit @ 2 kHz
//  Negedge input capture for the same reason as Task 1.
//=============================================================================
// TASK 2: CIC N=4, R=512 -> 24-bit -> 27-tap FIR comp, decimate 4 -> 20-bit
module task2_decim_top (
    input  wire clk, rst, en,
    input  wire signed [1:0]  din,
    output wire signed [23:0] cic_out,
    output wire cic_valid,
    output wire signed [19:0] dout,
    output wire dout_valid, clip
);
    wire clip_cic, clip_fir;
    assign clip = clip_cic | clip_fir;

    reg signed [1:0] din_q;                 // negedge capture (fixes tb race)
    always @(negedge clk) din_q <= rst ? 2'sd0 : din;

    cic_decimator #(.N(4), .R(512), .M(1), .IN_W(2), .OUT_W(24),
                    .GAIN_NUM(1), .GAIN_FRAC(0))
    u_cic (.clk(clk), .rst(rst), .en(en), .din(din_q),
           .dout(cic_out), .dout_valid(cic_valid), .clip(clip_cic));

    fir_decim_comp #(.IN_W(24), .OUT_W(20), .COEF_W(16), .FRAC(18), .ACC_W(48))
    u_fir (.clk(clk), .rst(rst), .din(cic_out), .din_valid(cic_valid),
           .dout(dout), .dout_valid(dout_valid), .clip(clip_fir));
endmodule
