`timescale 1ns / 1ps
//=============================================================================
// fir_decim_comp.v  -  27-tap CIC droop compensator + decimate-by-4
// Digital Decimation Filter Design Challenge (Electronics Club, IIT Guwahati)
//
//  * Runs at the CIC output rate (8 kHz); one output per 4 inputs (2 kHz).
//  * Response: |H(f)| = 1/|H_CIC(f)| on 0..1000 Hz (inverse sinc^4, R=512),
//    stop band 2..4 kHz; least-squares design (firls), stop-band weight 10.
//    Combined CIC x FIR ripple 0..990 Hz = 0.043 dB, alias rejection ~59 dB.
//  * Coefficients: signed Q18 in 16-bit words. Their sum (57345 = 0.21875*2^18)
//    folds in the overall gain 3.5 and the 24-bit -> 20-bit scaling (1/16).
//  * Linear phase -> symmetric taps -> pre-adder x[i]+x[26-i]; 14 unique
//    products computed on ONE multiplier over 14 clocks (2048 clocks are
//    available per output sample).
//  * 48-bit accumulator; output round-half-up (>>>18) and saturate to 20 bits.
//=============================================================================
// 27-tap symmetric FIR CIC-droop compensator, decimate by 4, one shared multiplier
module fir_decim_comp #(
    parameter integer IN_W = 24, OUT_W = 20, COEF_W = 16, FRAC = 18, ACC_W = 48
)(
    input  wire clk, rst,
    input  wire signed [IN_W-1:0] din,
    input  wire din_valid,
    output reg  signed [OUT_W-1:0] dout,
    output reg  dout_valid,
    output reg  clip
);
    localparam integer K = 27, NU = 14, DEC = 4;

    function signed [COEF_W-1:0] coef;     // Q18 coefficients (first half)
        input [3:0] i;
        case (i)
            4'd0: coef =    75;  4'd1: coef =   165;  4'd2: coef =    14;
            4'd3: coef =  -447;  4'd4: coef =  -631;  4'd5: coef =   213;
            4'd6: coef =  1584;  4'd7: coef =  1447;  4'd8: coef = -1396;
            4'd9: coef = -4472;  4'd10: coef = -2704; 4'd11: coef = 6142;
            4'd12: coef = 17397; 4'd13: coef = 22571;   // centre tap
            default: coef = 0;
        endcase
    endfunction

    // delay line + decimation phase
    reg signed [IN_W-1:0] x [0:K-1];
    reg [1:0] ph; reg start;
    integer t;
    always @(posedge clk) begin
        if (rst) begin for (t = 0; t < K; t = t + 1) x[t] <= 0; ph <= 0; start <= 0; end
        else begin
            start <= 0;
            if (din_valid) begin
                x[0] <= din;
                for (t = 1; t < K; t = t + 1) x[t] <= x[t-1];
                if (ph == DEC-1) begin ph <= 0; start <= 1; end
                else ph <= ph + 1'b1;
            end
        end
    end

    // serial MAC with pre-adder
    reg [3:0] idx; reg busy, mvld, mlast, done;
    reg signed [IN_W:0]     pre;
    reg signed [COEF_W-1:0] cq;
    reg signed [ACC_W-1:0]  acc;
    wire [4:0] mirror = K-1 - idx;
    wire signed [IN_W:0] xa = {x[idx][IN_W-1], x[idx]};
    wire signed [IN_W:0] xb = {x[mirror][IN_W-1], x[mirror]};
    wire signed [IN_W+COEF_W:0] prodw = pre * cq;
    always @(posedge clk) begin
        if (rst) begin idx <= 0; busy <= 0; mvld <= 0; mlast <= 0; pre <= 0; cq <= 0; acc <= 0; done <= 0; end
        else begin
            done <= 0;
            if (start) begin busy <= 1; idx <= 0; end
            else if (busy) begin idx <= idx + 1'b1; if (idx == NU-1) busy <= 0; end
            mvld  <= busy;
            mlast <= busy && (idx == NU-1);
            if (busy) begin
                pre <= (idx == NU-1) ? xa : (xa + xb);
                cq  <= coef(idx);
            end
            if (start)     acc <= 0;
            else if (mvld) acc <= acc + {{(ACC_W-IN_W-COEF_W-1){prodw[IN_W+COEF_W]}}, prodw};
            if (mvld && mlast) done <= 1;
        end
    end

    // round, saturate
    wire signed [ACC_W-1:0] half = {{(ACC_W-1){1'b0}}, 1'b1} <<< (FRAC-1);
    wire signed [ACC_W-1:0] rnd  = (acc + half) >>> FRAC;
    wire signed [ACC_W-1:0] MAXV = {{(ACC_W-OUT_W+1){1'b0}}, {(OUT_W-1){1'b1}}};
    wire signed [ACC_W-1:0] MINV = ~MAXV;
    always @(posedge clk) begin
        if (rst) begin dout <= 0; dout_valid <= 0; clip <= 0; end
        else begin
            dout_valid <= done;
            clip <= 0;
            if (done) begin
                if      (rnd > MAXV) begin dout <= MAXV[OUT_W-1:0]; clip <= 1; end
                else if (rnd < MINV) begin dout <= MINV[OUT_W-1:0]; clip <= 1; end
                else                       dout <= rnd[OUT_W-1:0];
            end
        end
    end
endmodule
