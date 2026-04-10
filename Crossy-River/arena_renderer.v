`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// arena_renderer.v — Pixel-level rendering of the Crossy River arena
//
// Priority (back to front):  background → logs → fox holes → foxes → player
// Info bar rendered by info_bar sub-module when curr_y < 100.
// All logic is combinational (runs at pixclk).
////////////////////////////////////////////////////////////////////////////////
module arena_renderer (
    input      [10:0] curr_x, curr_y,
    // Player
    input      [10:0] player_x, player_y,
    input      [1:0]  player_facing,
    input             player_jumping,
    // Foxes
    input      [10:0] fx0, fy0, fx1, fy1, fx2, fy2,
    input      [2:0]  fox_active,
    // Logs
    input      [10:0] lx0,ly0, lx1,ly1, lx2,ly2, lx3,ly3,
    input      [10:0] lx4,ly4, lx5,ly5, lx6,ly6, lx7,ly7,
    input      [7:0]  log_active,
    // Game state
    input      [7:0]  score,
    input      [2:0]  lives,
    input             game_over,
    input      [1:0]  game_state,
    // Output
    output reg [3:0]  draw_r, draw_g, draw_b
);
    // ── Arena geometry (duplicated — no .vh) ──
    localparam INFO_H  = 11'd100;
    localparam RIVER_W = 11'd148;
    localparam SCR_W   = 11'd1440;
    localparam SCR_H   = 11'd900;
    // River boundaries
    localparam RT_Y1 = 11'd247;   // top river bottom edge (100+148-1)
    localparam RB_Y0 = 11'd752;   // bottom river top edge (900-148)
    localparam RL_X1 = 11'd147;   // left river right edge
    localparam RR_X0 = 11'd1292;  // right river left edge (1440-148)
    localparam SAFE_X0=11'd148, SAFE_Y0=11'd248;
    localparam SAFE_X1=11'd1291, SAFE_Y1=11'd751;
    // Chasm
    localparam CX0=11'd670, CY0=11'd450, CW=11'd100, CH=11'd100;
    // Ponds
    localparam P1X=11'd300, P1Y=11'd320, P1W=11'd120, P1H=11'd80;
    localparam P2X=11'd950, P2Y=11'd580, P2W=11'd120, P2H=11'd80;
    // Fox holes
    localparam H0X=11'd250, H0Y=11'd500, HSZ=11'd24;
    localparam H1X=11'd1180,H1Y=11'd350;
    localparam H2X=11'd710, H2Y=11'd680;
    // Object sizes
    localparam PW=11'd32, PH=11'd32;
    localparam FW=11'd24, FH=11'd24;
    localparam HLW=11'd96, HLH=11'd48;  // horizontal log
    localparam VLW=11'd48, VLH=11'd96;  // vertical log

    // ── Region flags ──
    wire in_info   = (curr_y < INFO_H);
    wire in_game   = (curr_y >= INFO_H);

    // River zones
    wire in_top_r  = in_game && (curr_y <= RT_Y1);
    wire in_bot_r  = (curr_y >= RB_Y0);
    wire in_left_r = (curr_x <= RL_X1) && (curr_y > RT_Y1) && (curr_y < RB_Y0);
    wire in_right_r= (curr_x >= RR_X0) && (curr_y > RT_Y1) && (curr_y < RB_Y0);
    wire in_river  = in_top_r | in_bot_r | in_left_r | in_right_r;

    // Safe zone (inside river ring)
    wire in_safe   = (curr_x >= SAFE_X0) && (curr_x <= SAFE_X1) &&
                     (curr_y >= SAFE_Y0) && (curr_y <= SAFE_Y1);

    // Chasm
    wire in_chasm  = (curr_x >= CX0) && (curr_x < CX0+CW) &&
                     (curr_y >= CY0) && (curr_y < CY0+CH);

    // Ponds
    wire in_pond1  = (curr_x >= P1X) && (curr_x < P1X+P1W) &&
                     (curr_y >= P1Y) && (curr_y < P1Y+P1H);
    wire in_pond2  = (curr_x >= P2X) && (curr_x < P2X+P2W) &&
                     (curr_y >= P2Y) && (curr_y < P2Y+P2H);
    wire in_pond   = in_pond1 | in_pond2;

    // Fox holes
    wire in_hole0  = (curr_x>=H0X)&&(curr_x<H0X+HSZ)&&(curr_y>=H0Y)&&(curr_y<H0Y+HSZ);
    wire in_hole1  = (curr_x>=H1X)&&(curr_x<H1X+HSZ)&&(curr_y>=H1Y)&&(curr_y<H1Y+HSZ);
    wire in_hole2  = (curr_x>=H2X)&&(curr_x<H2X+HSZ)&&(curr_y>=H2Y)&&(curr_y<H2Y+HSZ);
    wire in_hole   = in_hole0 | in_hole1 | in_hole2;

    // ── Object hit tests (AABB) ──
    // Player
    wire in_player = (curr_x >= player_x) && (curr_x < player_x + PW) &&
                     (curr_y >= player_y) && (curr_y < player_y + PH);

    // Foxes
    wire in_fox0 = fox_active[0] && (curr_x>=fx0)&&(curr_x<fx0+FW)&&(curr_y>=fy0)&&(curr_y<fy0+FH);
    wire in_fox1 = fox_active[1] && (curr_x>=fx1)&&(curr_x<fx1+FW)&&(curr_y>=fy1)&&(curr_y<fy1+FH);
    wire in_fox2 = fox_active[2] && (curr_x>=fx2)&&(curr_x<fx2+FW)&&(curr_y>=fy2)&&(curr_y<fy2+FH);
    wire in_fox  = in_fox0 | in_fox1 | in_fox2;

    // Logs (horizontal: logs 0,1,4,5; vertical: logs 2,3,6,7)
    wire in_l0 = log_active[0]&&(curr_x>=lx0)&&(curr_x<lx0+HLW)&&(curr_y>=ly0)&&(curr_y<ly0+HLH);
    wire in_l1 = log_active[1]&&(curr_x>=lx1)&&(curr_x<lx1+HLW)&&(curr_y>=ly1)&&(curr_y<ly1+HLH);
    wire in_l2 = log_active[2]&&(curr_x>=lx2)&&(curr_x<lx2+VLW)&&(curr_y>=ly2)&&(curr_y<ly2+VLH);
    wire in_l3 = log_active[3]&&(curr_x>=lx3)&&(curr_x<lx3+VLW)&&(curr_y>=ly3)&&(curr_y<ly3+VLH);
    wire in_l4 = log_active[4]&&(curr_x>=lx4)&&(curr_x<lx4+HLW)&&(curr_y>=ly4)&&(curr_y<ly4+HLH);
    wire in_l5 = log_active[5]&&(curr_x>=lx5)&&(curr_x<lx5+HLW)&&(curr_y>=ly5)&&(curr_y<ly5+HLH);
    wire in_l6 = log_active[6]&&(curr_x>=lx6)&&(curr_x<lx6+VLW)&&(curr_y>=ly6)&&(curr_y<ly6+VLH);
    wire in_l7 = log_active[7]&&(curr_x>=lx7)&&(curr_x<lx7+VLW)&&(curr_y>=ly7)&&(curr_y<ly7+VLH);
    wire in_log = in_l0|in_l1|in_l2|in_l3|in_l4|in_l5|in_l6|in_l7;

    // ── Info bar sub-module ──
    wire [3:0] ib_r, ib_g, ib_b;
    wire       ib_active;
    info_bar ib_inst (
        .curr_x(curr_x), .curr_y(curr_y),
        .score(score), .lives(lives), .game_over(game_over),
        .pixel_r(ib_r), .pixel_g(ib_g), .pixel_b(ib_b),
        .in_info_bar(ib_active)
    );

    // ── Decorative patterns ──
    // River wave: alternating blue shades
    wire [11:0] river_col = (curr_x[3] ^ curr_y[2]) ? 12'h26B : 12'h37C;
    // Grass: two-tone green checkerboard
    wire [11:0] grass_col = curr_x[3] ? 12'h4A2 : 12'h3A1;
    // Log: brown with bark stripe
    wire [11:0] log_col   = (curr_x[2] ^ curr_y[2]) ? 12'h853 : 12'h742;
    // Fox: orange with dark eye
    wire fox_eye = (in_fox0 && ((curr_x-fx0)==6 ||(curr_x-fx0)==17) && ((curr_y-fy0)>=6&&(curr_y-fy0)<=9)) ||
                   (in_fox1 && ((curr_x-fx1)==6 ||(curr_x-fx1)==17) && ((curr_y-fy1)>=6&&(curr_y-fy1)<=9)) ||
                   (in_fox2 && ((curr_x-fx2)==6 ||(curr_x-fx2)==17) && ((curr_y-fy2)>=6&&(curr_y-fy2)<=9));
    wire [11:0] fox_col = fox_eye ? 12'h000 : 12'hF80;
    // Player: yellow body, orange detail
    wire [4:0] plr_lx = curr_x - player_x;
    wire [4:0] plr_ly = curr_y - player_y;
    wire plr_eye = (plr_lx >= 5'd8 && plr_lx <= 5'd23 && plr_ly >= 5'd6 && plr_ly <= 5'd10);
    wire plr_beak = (plr_lx >= 5'd12 && plr_lx <= 5'd19 && plr_ly >= 5'd14 && plr_ly <= 5'd17);
    wire [11:0] plr_col = player_jumping ? 12'hEEF :   // light blue when airborne
                           game_over     ? 12'hF44 :   // red when dead
                           plr_beak      ? 12'hF80 :   // orange beak
                           plr_eye       ? 12'h000 :   // black eye
                                           12'hFD0;    // yellow body

    // ── Priority compositing ──
    always @(*) begin
        if (in_info) begin
            // Info bar
            draw_r = ib_r; draw_g = ib_g; draw_b = ib_b;
        end else if (in_player) begin
            // Player on top
            {draw_r, draw_g, draw_b} = plr_col;
        end else if (in_fox) begin
            {draw_r, draw_g, draw_b} = fox_col;
        end else if (in_log) begin
            {draw_r, draw_g, draw_b} = log_col;
        end else if (in_hole) begin
            {draw_r, draw_g, draw_b} = 12'h321; // dark brown hole
        end else if (in_chasm) begin
            {draw_r, draw_g, draw_b} = 12'h111; // near-black chasm
        end else if (in_pond) begin
            // Pond: lighter blue than river
            {draw_r, draw_g, draw_b} = (curr_x[2] ^ curr_y[3]) ? 12'h49D : 12'h38C;
        end else if (in_river) begin
            {draw_r, draw_g, draw_b} = river_col;
        end else if (in_safe) begin
            {draw_r, draw_g, draw_b} = grass_col;
        end else begin
            {draw_r, draw_g, draw_b} = 12'h000;
        end
    end
endmodule
