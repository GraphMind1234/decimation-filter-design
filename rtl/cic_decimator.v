`timescale 1ns / 1ps
//=============================================================================
// cic_decimator.v  -  Parameterised N-stage CIC decimator
// Digital Decimation Filter Design Challenge (Electronics Club, IIT Guwahati)
//
//  H(z) = [ (1 - z^-(R*M)) / (1 - z^-1) ]^N
//  * N integrators at the input rate, N combs at the decimated rate
//    (Hogenauer structure) - no multipliers in the filter path.
//  * All registers are BMAX = N*log2(R*M) + IN_W bits wide; two's-complement
//    wrap-around in the integrators is harmless because the combs only take
//    differences (result is exact modulo 2^BMAX).
//  * Combs are sequenced one stage per clock after each decimation tick.
//  * Output: constant gain GAIN_NUM/2^GAIN_FRAC, round-half-up to OUT_W bits,
//    saturate; 'clip' pulses if a sample saturated.
//  Used as  Task 1: N=3, R=2048, OUT_W=20, gain 7/2   (BMAX = 35)
//           Task 2: N=4, R=512,  OUT_W=24, gain 1     (BMAX = 38)
//=============================================================================
// N-stage CIC decimator, wrap-around arithmetic, round + saturate output
module cic_decimator #(
    parameter integer N = 4, R = 512, M = 1, IN_W = 2, OUT_W = 20,
    parameter integer GAIN_NUM = 1, GAIN_FRAC = 0   // gain = GAIN_NUM / 2^GAIN_FRAC
)(
    input  wire clk, rst, en,
    input  wire signed [IN_W-1:0]  din,
    output reg  signed [OUT_W-1:0] dout,
    output reg  dout_valid,
    output reg  clip
);
    localparam integer LOG2RM = $clog2(R*M);
    localparam integer BMAX   = N*LOG2RM + IN_W;           // Hogenauer bound
    localparam integer CNT_W  = (R > 1) ? $clog2(R) : 1;
    localparam integer GW     = BMAX + 9;
    localparam integer SH     = N*LOG2RM - (OUT_W-1) + GAIN_FRAC;

    // integrators
    reg signed [BMAX-1:0] integ [0:N-1];
    integer k;
    always @(posedge clk) begin
        if (rst) for (k = 0; k < N; k = k + 1) integ[k] <= 0;
        else if (en) begin
            integ[0] <= integ[0] + {{(BMAX-IN_W){din[IN_W-1]}}, din};
            for (k = 1; k < N; k = k + 1) integ[k] <= integ[k] + integ[k-1];
        end
    end

    // downsampler
    reg [CNT_W-1:0] cnt; reg tick;
    always @(posedge clk) begin
        if (rst) begin cnt <= 0; tick <= 0; end
        else begin
            tick <= 0;
            if (en) begin
                if (cnt == R-1) begin cnt <= 0; tick <= 1; end
                else cnt <= cnt + 1'b1;
            end
        end
    end

    // combs (one stage per clock after each tick)
    reg signed [BMAX-1:0] cval [0:N];
    reg signed [BMAX-1:0] dl   [0:N*M-1];
    reg [N:0] vs;
    integer s, j;
    always @(posedge clk) begin
        if (rst) begin
            vs <= 0;
            for (s = 0; s <= N; s = s + 1)   cval[s] <= 0;
            for (s = 0; s <  N*M; s = s + 1) dl[s]   <= 0;
        end else begin
            vs <= {vs[N-1:0], tick};
            if (tick) cval[0] <= integ[N-1];
            for (s = 1; s <= N; s = s + 1)
                if (vs[s-1]) begin
                    cval[s] <= cval[s-1] - dl[(s-1)*M + M-1];
                    for (j = M-1; j > 0; j = j - 1) dl[(s-1)*M + j] <= dl[(s-1)*M + j-1];
                    dl[(s-1)*M] <= cval[s-1];
                end
        end
    end

    // gain, round, saturate
    wire signed [GW-1:0] cext = {{(GW-BMAX){cval[N][BMAX-1]}}, cval[N]};
    wire signed [GW-1:0] prod = cext * GAIN_NUM;
    wire signed [GW-1:0] half = {{(GW-1){1'b0}}, 1'b1} <<< (SH-1);
    wire signed [GW-1:0] rnd  = (prod + half) >>> SH;
    wire signed [GW-1:0] MAXV = {{(GW-OUT_W+1){1'b0}}, {(OUT_W-1){1'b1}}};
    wire signed [GW-1:0] MINV = ~MAXV;
    always @(posedge clk) begin
        if (rst) begin dout <= 0; dout_valid <= 0; clip <= 0; end
        else begin
            dout_valid <= vs[N];
            clip <= 0;
            if (vs[N]) begin
                if      (rnd > MAXV) begin dout <= MAXV[OUT_W-1:0]; clip <= 1; end
                else if (rnd < MINV) begin dout <= MINV[OUT_W-1:0]; clip <= 1; end
                else                       dout <= rnd[OUT_W-1:0];
            end
        end
    end
endmodule
