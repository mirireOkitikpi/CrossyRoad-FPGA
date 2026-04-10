`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// score_display.v — Multiplexed 7-segment display (Lab 1/2 method)
// Displays score on right 4 digits, high score on left 4 digits.
// Uses a fast scan clock from sys_clk to multiplex 8 anodes.
////////////////////////////////////////////////////////////////////////////////
module score_display (
    input        clk,
    input        rst,
    input  [7:0] score,
    input  [7:0] high_score,
    output [6:0] seg,
    output [7:0] an
);
    // Scan counter — bits [17:15] select which digit is active
    reg [17:0] scan_cnt;
    always @(posedge clk or negedge rst) begin
        if (!rst) scan_cnt <= 0;
        else      scan_cnt <= scan_cnt + 1;
    end
    wire [2:0] digit_sel = scan_cnt[17:15];

    // BCD extraction (simple for 0–255)
    wire [3:0] sc_hund = score / 100;
    wire [3:0] sc_tens = (score / 10) % 10;
    wire [3:0] sc_ones = score % 10;
    wire [3:0] hs_hund = high_score / 100;
    wire [3:0] hs_tens = (high_score / 10) % 10;
    wire [3:0] hs_ones = high_score % 10;

    // Digit mux: AN[7..4]=high_score, AN[3..0]=score
    reg [3:0] hex_digit;
    reg [7:0] an_reg;
    always @(*) begin
        an_reg = 8'hFF;
        hex_digit = 4'd0;
        case (digit_sel)
            3'd0: begin an_reg = 8'hFE; hex_digit = sc_ones; end
            3'd1: begin an_reg = 8'hFD; hex_digit = sc_tens; end
            3'd2: begin an_reg = 8'hFB; hex_digit = sc_hund; end
            3'd3: begin an_reg = 8'hF7; hex_digit = 4'd0;    end
            3'd4: begin an_reg = 8'hEF; hex_digit = hs_ones; end
            3'd5: begin an_reg = 8'hDF; hex_digit = hs_tens; end
            3'd6: begin an_reg = 8'hBF; hex_digit = hs_hund; end
            3'd7: begin an_reg = 8'h7F; hex_digit = 4'd0;    end
        endcase
    end
    assign an = an_reg;

    // Seven-segment decoder (active low, Lab 1 method)
    reg [6:0] seg_reg;
    always @(*) begin
        case (hex_digit)
            4'd0: seg_reg = 7'b1000000;
            4'd1: seg_reg = 7'b1111001;
            4'd2: seg_reg = 7'b0100100;
            4'd3: seg_reg = 7'b0110000;
            4'd4: seg_reg = 7'b0011001;
            4'd5: seg_reg = 7'b0010010;
            4'd6: seg_reg = 7'b0000010;
            4'd7: seg_reg = 7'b1111000;
            4'd8: seg_reg = 7'b0000000;
            4'd9: seg_reg = 7'b0010000;
            default: seg_reg = 7'b1111111;
        endcase
    end
    assign seg = seg_reg;
endmodule
