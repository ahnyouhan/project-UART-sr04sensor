`timescale 1ns / 1ps

module sr04_top (
    input clk,
    input rst,
    input rx,
    input start,
    input echo,
    output tx,
    output trig,
    output [3:0] fnd_com,
    output [7:0] fnd_data
);
    wire tick_1us;
    wire [7:0] w_rx_fifo_popdata;
    wire [8:0] dist;
    wire [31:0] w_ascii_data;
    wire w_dist_done;
    wire w_start, cmd_start;
    wire w_rx_trigger;
    wire w_rx_fifo_pop;
    wire w_tx_fifo_full;
    wire w_tx_fifo_push;
    wire [7:0] w_tx_fifo_data;
    

    tick_gen_1us U_TICK__GEN_1US(
        .clk(clk),
        .rst(rst),
        .o_tick_1us(tick_1us)
    );
    button_debounce U_BD(
        .clk(clk),
        .rst(rst),
        .i_btn(start),
        .o_btn(w_start)
    );
    
    sr04_controller U_SR04_CTRL(
        .clk(clk),
        .rst(rst),
        .start(w_start | cmd_start),
        .echo(echo),
        .i_tick(tick_1us),
        .o_trig(trig),
        .o_dist(dist),
        .dist_done(w_dist_done)
    );

    command_control U_CMD_CTRL(
        .clk(clk),
        .rst(rst),
        .command(w_rx_fifo_popdata),
        .rx_trigger(w_rx_trigger),
        .o_start(cmd_start),
        .o_rx_fifo_pop(w_rx_fifo_pop)
    );

    data_to_ascii U_DATA_TO_ASCII(
        .i_data(dist),
        .o_data(w_ascii_data)
    );


    distance_sender U_DISTANCE_SENDER(
        .clk(clk),
        .rst(rst),
        .i_start(w_dist_done),
        .ascii_data(w_ascii_data),
        .tx_fifo_data(w_tx_fifo_data),
        .tx_fifo_push(w_tx_fifo_push),
        .tx_fifo_full(w_tx_fifo_full)
    );


    fnd_controller U_FND_CTRL(
        .clk(clk),
        .reset(rst),
        .counter(dist),
        .fnd_com(fnd_com),
        .fnd_data(fnd_data)
    );

    uart_top U_UART_TOP(
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .tx(tx),
        .rx_fifo_popdata(w_rx_fifo_popdata),
        .rx_trigger(w_rx_trigger),
        .i_rx_fifo_pop(w_rx_fifo_pop),
        .tx_fifo_data(w_tx_fifo_data),
        .tx_fifo_push(w_tx_fifo_push),
        .tx_fifo_full(w_tx_fifo_full)
    );

    

    


endmodule


module sr04_controller (
    input        clk,
    input        rst,
    input        start,
    input        echo,
    input        i_tick,
    output       o_trig,
    output [8:0] o_dist,
    output       dist_done
);  

    parameter IDLE = 2'b00, START = 2'b01, WAIT = 2'b10, DIST = 2'b11;
    reg [1:0] c_state, n_state;
    reg [14:0] tick_cnt_reg, tick_cnt_next;
    reg [8:0] dist_reg, dist_next;
    reg trigger;
    reg dist_done_reg, dist_done_next;


    assign o_trig = trigger;
    assign o_dist = dist_reg;
    assign dist_done = dist_done_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            tick_cnt_reg <= 0;
            dist_reg <= 0;
            dist_done_reg <=1'b0;
        end else begin
            c_state <= n_state;
            tick_cnt_reg <= tick_cnt_next;
            dist_reg <= dist_next;
            dist_done_reg <= dist_done_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        tick_cnt_next = tick_cnt_reg;
        dist_next = dist_reg;
        trigger = 1'b0;
        dist_done_next = 1'b0;

        case (c_state)
            IDLE: begin
                if (start) n_state = START;
            end
            START: begin
                trigger = 1'b1;
                if (i_tick) begin
                    if (tick_cnt_reg == 10) begin
                        n_state = WAIT;
                        tick_cnt_next = 0;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end else begin
                    tick_cnt_next = tick_cnt_reg;
                end
            end
            WAIT: begin
                if (i_tick && echo) begin
                    n_state = DIST;
                end 
            end
            DIST: begin
                if (i_tick) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                end
                if (!echo) begin
                    dist_next = tick_cnt_reg / 58;
                    n_state = IDLE;
                    tick_cnt_next = 0;
                    dist_done_next = 1'b1;
                end
            end
        endcase
    end

endmodule

module tick_gen_1us (
    input  clk,
    input  rst,
    output o_tick_1us
);

    parameter TICK_COUNT = 100_000_000 / 1_000_000;
    reg [$clog2(TICK_COUNT)-1:0] counter_reg;
    reg tick_1us;

    // output
    assign o_tick_1us = tick_1us;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <=0;
            tick_1us    <=1'b0;
        end else begin
            if (counter_reg == TICK_COUNT - 1) begin
                counter_reg <= 0;
                tick_1us    <= 1'b1;
            end else begin
                counter_reg <= counter_reg + 1;
                tick_1us    <= 1'b0;
            end
        end
    end

endmodule

module command_control (
    input clk,
    input rst,
    input [7:0] command,
    input rx_trigger,
    output o_start,
    output o_rx_fifo_pop
);
    localparam [1:0] IDLE = 2'b00, RECEIVE = 2'b01;

    reg [1:0] state, next;
    reg start_reg, start_next;
    reg rx_fifo_pop_reg, rx_fifo_pop_next;

    assign o_start = start_reg;
    assign o_rx_fifo_pop = rx_fifo_pop_reg;

    always @(posedge clk, posedge rst) begin
        if(rst) begin
            state <= IDLE;
            start_reg <= 0;
            rx_fifo_pop_reg <= 0;
        end else begin
            state <= next;
            start_reg <= start_next;
            rx_fifo_pop_reg <= rx_fifo_pop_next;
        end
    end

    always @(*) begin
        next = state;
        start_next = 1'b0;
        rx_fifo_pop_next = 1'b0;

        case (state)
            IDLE: begin
                if(rx_trigger) begin
                    rx_fifo_pop_next=1'b1;
                    if(command == 8'h64) begin
                        next = RECEIVE;
                    end
                end
            end
            RECEIVE: begin
                start_next = 1'b1;
                next = IDLE;
            end
            
        endcase
    end

endmodule

module data_to_ascii (
    input  [8:0] i_data,
    output [31:0] o_data
);
    assign o_data[7:0] = i_data %10 + 8'h30;
    assign o_data[15:8] = (i_data / 10) % 10 + 8'h30;
    assign o_data[23:16] = (i_data / 100) % 10 + 8'h30;
    assign o_data[31:24] = (i_data / 1000) %10 + 8'h30;
    
endmodule

module distance_sender (
    input clk,
    input rst,
    input i_start,
    input [31:0] ascii_data,
    input        tx_fifo_full,
    output [7:0] tx_fifo_data,
    output       tx_fifo_push
);

    localparam IDLE=3'b000, SEND0=3'b001, SEND1=3'b010, SEND2=3'b100, SEND3=3'b101;

    reg [2:0] state, next;
    reg [7:0] tx_fifo_data_reg, tx_fifo_data_next;
    reg tx_fifo_push_reg, tx_fifo_push_next;

    assign tx_fifo_data = tx_fifo_data_reg;
    assign tx_fifo_push = tx_fifo_push_reg;

    always @(posedge clk, posedge rst) begin
        if(rst) begin
            state <= IDLE;
            tx_fifo_data_reg <= 8'h00;
            tx_fifo_push_reg <= 1'b0;
        end else begin
            state <= next;
            tx_fifo_data_reg <= tx_fifo_data_next;
            tx_fifo_push_reg <= tx_fifo_push_next;
        end
    end

    always @(*) begin
        next = state;
        tx_fifo_data_next = tx_fifo_data_reg;
        tx_fifo_push_next = 1'b0;

        case (state)
            IDLE: begin
                if(i_start) begin
                    next = SEND0;
                end
            end
            SEND0: begin
                if(!tx_fifo_full) begin
                    next = SEND1;
                    tx_fifo_data_next = ascii_data[31:24];
                    tx_fifo_push_next = 1'b1;
                end
            end
            SEND1: begin
                if(!tx_fifo_full) begin
                    next = SEND2;
                    tx_fifo_data_next = ascii_data[23:16];
                    tx_fifo_push_next = 1'b1;
                end
            end
            SEND2: begin
                if(!tx_fifo_full) begin
                    next = SEND3;
                    tx_fifo_data_next = ascii_data[15:8];
                    tx_fifo_push_next = 1'b1;
                end
            end
            SEND3: begin
                if(!tx_fifo_full) begin
                    next = IDLE;
                    tx_fifo_data_next = ascii_data[7:0];
                    tx_fifo_push_next = 1'b1;
                end
            end
            default: begin
                next = IDLE;
            end
        endcase
    end
    
endmodule