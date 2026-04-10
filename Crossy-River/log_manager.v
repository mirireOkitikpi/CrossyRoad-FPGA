`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// log_manager.v — Manages 8 logs across 4 river lanes (anti-clockwise flow)
//
// Lane 0 (top):    horizontal, flow LEFT,  y fixed at 150
// Lane 1 (left):   vertical,   flow DOWN,  x fixed at 50
// Lane 2 (bottom): horizontal, flow RIGHT, y fixed at 802
// Lane 3 (right):  vertical,   flow UP,    x fixed at 1342
//
// Logs 0-1: lane 0,  Logs 2-3: lane 1,  Logs 4-5: lane 2,  Logs 6-7: lane 3
// Horizontal logs: 96 x 48.   Vertical logs: 48 x 96.
////////////////////////////////////////////////////////////////////////////////
module log_manager (
    input             clk,
    input             rst,
    input             game_active,
    // Log screen positions (11-bit, may be >1440 when off-screen)
    output reg [10:0] lx0, ly0, lx1, ly1,
    output reg [10:0] lx2, ly2, lx3, ly3,
    output reg [10:0] lx4, ly4, lx5, ly5,
    output reg [10:0] lx6, ly6, lx7, ly7,
    output reg [7:0]  log_active   // 1 bit per log: visible on screen
);
    // ── Arena geometry ──
    localparam LOG_SPEED   = 11'd2;
    // Horizontal logs (top/bottom lanes)
    localparam H_LOG_W     = 11'd96;
    localparam H_LOG_H     = 11'd48;
    // Vertical logs (left/right lanes)
    localparam V_LOG_W     = 11'd48;
    localparam V_LOG_H     = 11'd96;
    // Fixed perpendicular positions (centered in 148px river band)
    localparam TOP_Y       = 11'd150;   // 100 + (148-48)/2
    localparam BOT_Y       = 11'd802;   // 752 + (148-48)/2
    localparam LEFT_X      = 11'd50;    // (148-48)/2
    localparam RIGHT_X     = 11'd1342;  // 1292 + (148-48)/2
    // Flow ranges
    localparam SCREEN_W    = 11'd1440;
    localparam V_FLOW_TOP  = 11'd200;   // vertical logs enter here
    localparam V_FLOW_BOT  = 11'd750;   // vertical logs exit here
    // Wrap thresholds (unsigned: use large values for "off left/top")
    localparam WRAP_MAX    = 11'd1600;

    // ── Initial positions: evenly spaced ──
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            // Lane 0 (top, flow left): logs start spread across screen
            lx0 <= 11'd200;   ly0 <= TOP_Y;
            lx1 <= 11'd920;   ly1 <= TOP_Y;
            // Lane 1 (left, flow down)
            lx2 <= LEFT_X;    ly2 <= 11'd280;
            lx3 <= LEFT_X;    ly3 <= 11'd520;
            // Lane 2 (bottom, flow right)
            lx4 <= 11'd100;   ly4 <= BOT_Y;
            lx5 <= 11'd820;   ly5 <= BOT_Y;
            // Lane 3 (right, flow up)
            lx6 <= RIGHT_X;   ly6 <= 11'd680;
            lx7 <= RIGHT_X;   ly7 <= 11'd400;
            log_active <= 8'hFF;
        end else if (game_active) begin
            // ── Lane 0: flow LEFT (x decreases) ──
            if (lx0 < LOG_SPEED || lx0 > WRAP_MAX)
                begin lx0 <= SCREEN_W; log_active[0] <= 1'b1; end
            else begin
                lx0 <= lx0 - LOG_SPEED;
                log_active[0] <= (lx0 > LOG_SPEED) && (lx0 <= SCREEN_W);
            end

            if (lx1 < LOG_SPEED || lx1 > WRAP_MAX)
                begin lx1 <= SCREEN_W; log_active[1] <= 1'b1; end
            else begin
                lx1 <= lx1 - LOG_SPEED;
                log_active[1] <= (lx1 > LOG_SPEED) && (lx1 <= SCREEN_W);
            end

            // ── Lane 1: flow DOWN (y increases) ──
            if (ly2 > V_FLOW_BOT + V_LOG_H)
                begin ly2 <= V_FLOW_TOP; log_active[2] <= 1'b1; end
            else begin
                ly2 <= ly2 + LOG_SPEED;
                log_active[2] <= (ly2 >= V_FLOW_TOP) && (ly2 <= V_FLOW_BOT);
            end

            if (ly3 > V_FLOW_BOT + V_LOG_H)
                begin ly3 <= V_FLOW_TOP; log_active[3] <= 1'b1; end
            else begin
                ly3 <= ly3 + LOG_SPEED;
                log_active[3] <= (ly3 >= V_FLOW_TOP) && (ly3 <= V_FLOW_BOT);
            end

            // ── Lane 2: flow RIGHT (x increases) ──
            if (lx4 > SCREEN_W)
                begin lx4 <= 11'd0; log_active[4] <= 1'b1; end
            else begin
                lx4 <= lx4 + LOG_SPEED;
                log_active[4] <= (lx4 <= SCREEN_W);
            end

            if (lx5 > SCREEN_W)
                begin lx5 <= 11'd0; log_active[5] <= 1'b1; end
            else begin
                lx5 <= lx5 + LOG_SPEED;
                log_active[5] <= (lx5 <= SCREEN_W);
            end

            // ── Lane 3: flow UP (y decreases) ──
            if (ly6 < V_FLOW_TOP || ly6 > WRAP_MAX)
                begin ly6 <= V_FLOW_BOT; log_active[6] <= 1'b1; end
            else begin
                ly6 <= ly6 - LOG_SPEED;
                log_active[6] <= (ly6 >= V_FLOW_TOP) && (ly6 <= V_FLOW_BOT);
            end

            if (ly7 < V_FLOW_TOP || ly7 > WRAP_MAX)
                begin ly7 <= V_FLOW_BOT; log_active[7] <= 1'b1; end
            else begin
                ly7 <= ly7 - LOG_SPEED;
                log_active[7] <= (ly7 >= V_FLOW_TOP) && (ly7 <= V_FLOW_BOT);
            end

            // Fixed perpendicular coords stay constant
            ly0 <= TOP_Y;  ly1 <= TOP_Y;
            lx2 <= LEFT_X; lx3 <= LEFT_X;
            ly4 <= BOT_Y;  ly5 <= BOT_Y;
            lx6 <= RIGHT_X; lx7 <= RIGHT_X;
        end
    end
endmodule
