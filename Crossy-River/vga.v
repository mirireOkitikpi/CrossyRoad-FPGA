`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// vga.v — VGA controller for 1440x900 @ 60 Hz (Lab 4 method)
// Pixel clock = 106.47 MHz from Clocking Wizard.
// IDs: 2217321, 2233380
////////////////////////////////////////////////////////////////////////////////
module vga (
    input             clk,
    input             rst,
    input      [3:0]  draw_r, draw_g, draw_b,
    output reg [10:0] curr_x, curr_y,
    output     [3:0]  pix_r, pix_g, pix_b,
    output            hsync, vsync
);
    localparam H_MAX = 11'd1903, H_SYNC_END = 11'd151;
    localparam H_VIS_START = 11'd384, H_VIS_END = 11'd1823;
    localparam V_MAX = 10'd931,  V_SYNC_END = 10'd2;
    localparam V_VIS_START = 10'd31,  V_VIS_END = 10'd930;

    reg [10:0] hcount;
    reg [9:0]  vcount;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            hcount <= 0; vcount <= 0;
        end else begin
            if (hcount == H_MAX) begin
                hcount <= 0;
                vcount <= (vcount == V_MAX) ? 10'd0 : vcount + 1;
            end else
                hcount <= hcount + 1;
        end
    end

    assign hsync = (hcount <= H_SYNC_END);
    assign vsync = (vcount <= V_SYNC_END);

    wire h_vis = (hcount >= H_VIS_START) && (hcount <= H_VIS_END);
    wire v_vis = (vcount >= V_VIS_START) && (vcount <= V_VIS_END);
    wire visible = h_vis && v_vis;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin curr_x <= 0; curr_y <= 0; end
        else begin
            curr_x <= h_vis ? (hcount - H_VIS_START) : 11'd0;
            curr_y <= v_vis ? (vcount - V_VIS_START) : 11'd0;
        end
    end

    assign pix_r = visible ? draw_r : 4'd0;
    assign pix_g = visible ? draw_g : 4'd0;
    assign pix_b = visible ? draw_b : 4'd0;
endmodule
