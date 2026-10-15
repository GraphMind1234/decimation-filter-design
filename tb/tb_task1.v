`timescale 1ns / 1ps
`define TONE 500          // <-- change to 10 / 500 / 990
module tb_task1();
    reg data [0:4096025];
    reg clk, clk3, reset, enable;
    reg signed [1:0] bits;
    wire signed [19:0] cicout;
    wire outready, clip;

    reg [8*64:1] fin_name, fout_name;
    initial begin
        $sformat(fin_name,  "hz%0d.mem", `TONE);
        $sformat(fout_name, "cic2048_%0d.txt", `TONE);
        $readmemh(fin_name, data);
    end

    initial begin
        clk = 0; clk3 = 0; bits = 0; enable = 0; reset = 1;
        #51 reset = 0; enable = 1;
    end
    always #50     clk  = ~clk;
    always #102400 clk3 = ~clk3;     // fs/2048 output rate

    integer i = 0, fd4, nclip = 0, nout = 0;
    initial fd4 = $fopen(fout_name, "w");

    always @(posedge clk) begin
        if (i < 4096026) begin
            if (i%2 == 0) bits = {1'b0, data[i]};
            else          bits = {2{data[i]}};
            i <= i + 1;
        end else begin
            #200;
            $display("TASK1 tone=%0d Hz : %0d outputs, %0d clipped", `TONE, nout, nclip);
            $fclose(fd4);
            $finish;
        end
    end
    always @(posedge clk) begin
        if (outready) nout  = nout + 1;
        if (clip)     nclip = nclip + 1;
    end
    always @(posedge clk3) $fwrite(fd4, "%d\n", $signed(cicout));

    task1_cic_top cic (.clk(clk), .rst(reset), .en(enable), .din(bits),
                       .dout(cicout), .dout_valid(outready), .clip(clip));
endmodule
