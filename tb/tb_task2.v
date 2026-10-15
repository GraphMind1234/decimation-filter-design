`timescale 1ns / 1ps
`define TONE 500          // <-- change to 10 / 500 / 990
module tb_task2();
    reg data [0:4096025];
    reg clk, clk2, reset, enable;
    reg signed [1:0] bits;
    wire signed [23:0] cicout;
    wire signed [19:0] firout;
    wire outready, outready2, clip;

    reg [8*64:1] fin_name, fout_fir;
    initial begin
        $sformat(fin_name, "hz%0d.mem", `TONE);
        $sformat(fout_fir, "fircomp_%0d.txt", `TONE);
        $readmemh(fin_name, data);
    end

    initial begin
        clk = 0; clk2 = 0; bits = 0; enable = 0; reset = 1;
        #51 reset = 0; enable = 1;
    end
    always #50     clk  = ~clk;
    always #102400 clk2 = ~clk2;     // fs/2048 output rate

    integer i = 0, fd3, nclip = 0, nout = 0;
    initial fd3 = $fopen(fout_fir, "w");

    always @(posedge clk) begin
        if (i < 4096026) begin
            if (i%2 == 0) bits = {1'b0, data[i]};
            else          bits = {2{data[i]}};
            i <= i + 1;
        end else begin
            #200;
            $display("TASK2 tone=%0d Hz : %0d outputs, %0d clipped", `TONE, nout, nclip);
            $fclose(fd3);
            $finish;
        end
    end
    always @(posedge clk) begin
        if (outready2) nout  = nout + 1;
        if (clip)      nclip = nclip + 1;
    end
    always @(posedge clk2) $fwrite(fd3, "%d\n", $signed(firout));

    task2_decim_top dut (.clk(clk), .rst(reset), .en(enable), .din(bits),
                         .cic_out(cicout), .cic_valid(outready),
                         .dout(firout), .dout_valid(outready2), .clip(clip));
endmodule
