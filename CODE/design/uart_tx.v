`timescale 1ns / 1ps

module uart_tx (
    input clk,
    input rst,
    input start_trigger,
    input [7:0] tx_data,
    input b_tick,
    output tx,
    output tx_busy
);

    //fsm state
    localparam [2:0] IDLE = 3'h0, WAIT = 3'h1, START = 3'h2, DATA = 3'h3, STOP = 3'h4;

    // state
    reg [2:0] state, next;
    // bit control reg
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    // tick count
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    // tx internal buffer
    reg [7:0] data_reg, data_next;
    // output
    reg tx_reg, tx_next;
    reg tx_busy_reg, tx_busy_next;
    // output tx
    assign tx = tx_reg;
    assign tx_busy = tx_busy_reg;


    // state register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state <= IDLE;
            tx_reg <= 1'b1;  // idle output high
            bit_cnt_reg <= 0;
            data_reg <= 0;
            tx_busy_reg <= 0;
            b_tick_cnt_reg <= 0;
        end else begin
            state       <= next;
            tx_reg      <= tx_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg <= bit_cnt_next;
            data_reg    <= data_next;
            tx_busy_reg <= tx_busy_next;
        end
    end

    always @(*) begin
        next            = state;  // Latch X
        tx_next         = tx_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        data_next       = data_reg;
        tx_busy_next    = tx_busy_reg;
        case (state)
            IDLE: begin
                tx_next = 1'b1;
                
                tx_busy_next = 1'b0;
                if (start_trigger == 1'b1) begin
                    tx_busy_next = 1'b1;
                    data_next = tx_data;
                    next = WAIT;
                end
            end
            WAIT: begin
                if (b_tick) begin
                    b_tick_cnt_next = 0;
                    next = START;
                end

            end
            START: begin
                tx_next = 1'b0;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        bit_cnt_next = 0;
                        next = DATA;
                    end
                    else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end 
            end
            
            DATA: begin
                tx_next = data_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        if (bit_cnt_reg == 7) begin
                            next = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                            data_next = data_reg >> 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end


            STOP: begin
                tx_next = 1'b1;
                if (b_tick) begin
                    if(b_tick_cnt_reg == 15) begin
                        tx_busy_next = 1'b0;    
                        next = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                    
                end
            end
        endcase
    end


endmodule
