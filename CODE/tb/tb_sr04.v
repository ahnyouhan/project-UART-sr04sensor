`timescale 1ns / 1ps

module tb_sr04 ();

    reg clk, rst;
    reg start, echo;
    wire tick_1us;
    wire o_trig;
    wire [8:0] o_dist;
    wire [3:0] fnd_com;
    wire [7:0] fnd_data;

    tick_gen_1us dut0 (
        .clk(clk),
        .rst(rst),
        .o_tick_1us(tick_1us)
    );

    sr04_controller dut1(
        .clk(clk),
        .rst(rst),
        .start(start),
        .echo(echo),
        .i_tick(tick_1us),
        .o_trig(o_trig),
        .o_dist(o_dist)
    );
    always #5 clk = ~clk;

    initial begin
        #0;
        clk   = 0;
        rst   = 1;
        start = 0;
        echo  = 0;
        #10;
        rst = 0;

        #10;
        start = 1;
        #10;
        start = 0;
        #10;

        //wait
        start = 1;
        #10;
        start = 0;

        #10000;
        echo = 1;
        #1000000;
        echo = 0;


        #1000;
        $stop;

    end
endmodule
