`timescale 1ns / 1ps
//=============================================================================
// task1_cic_top.v  -  TASK 1: standalone CIC decimator (OSR 2048)
//  din (2-bit, {-1,0,+1}) @ 4.096 MHz  ->  dout (20-bit signed) @ 2 kHz
//  CIC N=3, R=2048, M=1, output gain 3.5 (=7/2).
//  The input is captured on the falling clock edge: the provided testbench
//  updates 'bits' with a blocking assignment on posedge clk, which would
//  race with posedge-sampled logic.
//=============================================================================
// TASK 1: CIC N=3, R=2048, M=1, gain 3.5, 20-bit output
module task1_cic_top (
    input  wire clk, rst, en,
    input  wire signed [1:0]  din,
    output wire signed [19:0] dout,
    output wire dout_valid, clip
);
    reg signed [1:0] din_q;                 // negedge capture (fixes tb race)
    always @(negedge clk) din_q <= rst ? 2'sd0 : din;

    cic_decimator #(.N(3), .R(2048), .M(1), .IN_W(2), .OUT_W(20),
                    .GAIN_NUM(7), .GAIN_FRAC(1))
    u_cic (.clk(clk), .rst(rst), .en(en), .din(din_q),
           .dout(dout), .dout_valid(dout_valid), .clip(clip));
endmodule
