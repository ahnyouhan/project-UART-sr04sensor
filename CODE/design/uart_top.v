`timescale 1ns / 1ps

module uart_top (
    input  clk,
    input  rst,
    input  rx,
    output tx,
    output [7:0] rx_fifo_popdata,
    output rx_trigger,
    input i_rx_fifo_pop,
    input [7:0] tx_fifo_data,
    input tx_fifo_push,
    output tx_fifo_full
    
);

    wire w_start, w_b_tick;
    wire rx_done;
    wire [7:0] w_rx_data,  w_rx_fifo_popdata, w_tx_fifo_popdata;
    wire w_rx_empty, w_tx_fifo_full, w_tx_fifo_empty, w_tx_busy;
    wire [7:0] i_tx_fifo_data;
    wire i_tx_fifo_push;

    assign rx_trigger = ~w_rx_empty;
    assign rx_fifo_popdata = w_rx_fifo_popdata;
    assign tx_fifo_data = i_tx_fifo_data;
    assign tx_fifo_push = i_tx_fifo_push;
    assign tx_fifo_full = w_tx_fifo_full;
    
   uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .start_trigger(~w_tx_fifo_empty),
        .tx_data(w_tx_fifo_popdata),
        .b_tick(w_b_tick),
        .tx(tx),
        .tx_busy(w_tx_busy)
    );
    fifo U_TX_FIFO(
        .clk(clk),
        .rst(rst),
        .push_data(i_tx_fifo_data), 
        .push(i_tx_fifo_push),      
        .pop(~w_tx_busy),                       // from uart tx
        .pop_data(w_tx_fifo_popdata),           // to uart tx
        .full(w_tx_fifo_full),   
        .empty(w_tx_fifo_empty)                 // to uart tx
    );

    uart_rx U_UART_RX (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .b_tick(w_b_tick),
        .rx_data(w_rx_data),
        .rx_done(rx_done)
    );

    fifo U_RX_FIFO(
        .clk(clk),
        .rst(rst),
        .push_data(w_rx_data),                // from uart rx
        .push(rx_done),                       // from uart rx
        .pop(i_rx_fifo_pop),                // to tx fifo
        .pop_data(w_rx_fifo_popdata),         // to tx fifo
        .full(),    
        .empty(w_rx_empty)                    // to tx fifo
    );


    baud_tick_gen U_BAUD_TICK_GEN (
        .clk(clk),
        .rst(rst),
        .b_tick(w_b_tick)
    );


endmodule

module baud_tick_gen (
    input  clk,
    input  rst,
    output b_tick
);
    // baurate
    parameter BAUDRATE = 9600 * 16;
    // State
    localparam BAUD_COUNT = 100_000_000 / BAUDRATE;
    reg [$clog2(BAUD_COUNT)-1:0] counter_reg, counter_next;
    reg tick_reg, tick_next;

    // output
    assign b_tick = tick_reg;

    //SL
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            tick_reg    <= 0;
        end else begin
            counter_reg <= counter_next;
            tick_reg    <= tick_next;
        end
    end

    // next CL
    always @(*) begin
        counter_next = counter_reg;
        tick_next    = tick_reg;
        if (counter_reg == BAUD_COUNT - 1) begin
            counter_next = 0;
            tick_next    = 1'b1;
        end else begin
            counter_next = counter_reg + 1;
            tick_next    = 1'b0;
        end
    end

endmodule


