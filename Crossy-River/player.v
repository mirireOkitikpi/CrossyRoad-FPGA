`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// player.v — Player movement, jump state, log riding, boundary/pond blocking
//
// Movement: 4 buttons, PLAYER_SPEED px per rising edge.
// Jump: btn_jump triggers JUMP_DUR ticks of airborne immunity.
// Log riding: directional flags shift position by CARRY_SPD each tick.
// Ponds block movement (AABB check against 2 static ponds).
////////////////////////////////////////////////////////////////////////////////
module player (
    input             clk,
    input             rst,
    input             game_active,
    input             respawn,
    // Buttons (debounced)
    input             btn_up, btn_down, btn_left, btn_right,
    input             btn_jump,
    // Log riding — unsigned directional flags (from game_top)
    input             carry_left, carry_right, carry_up, carry_down,
    // Outputs
    output reg [10:0] player_x, player_y,
    output reg        jumping,
    output reg [1:0]  facing
);
    localparam SPEED     = 11'd4;
    localparam CARRY_SPD = 11'd2;
    localparam PW = 11'd32, PH = 11'd32;
    localparam START_X = 11'd680, START_Y = 11'd400;
    localparam MIN_X = 11'd0, MAX_X = 11'd1408;   // 1440-32
    localparam MIN_Y = 11'd100, MAX_Y = 11'd868;   // 900-32
    // Ponds
    localparam P1X=11'd300, P1Y=11'd320, P1W=11'd120, P1H=11'd80;
    localparam P2X=11'd950, P2Y=11'd580, P2W=11'd120, P2H=11'd80;
    localparam JUMP_DUR = 8'd30;
    localparam F_UP=2'd0, F_DN=2'd1, F_LT=2'd2, F_RT=2'd3;

    // Edge detection
    reg bu_p, bd_p, bl_p, br_p, bj_p;
    wire bu_r = btn_up    & ~bu_p;
    wire bd_r = btn_down  & ~bd_p;
    wire bl_r = btn_left  & ~bl_p;
    wire br_r = btn_right & ~br_p;
    wire bj_r = btn_jump  & ~bj_p;

    reg [7:0] jump_cnt;

    // AABB overlap check (purely combinational)
    function pond_block;
        input [10:0] nx, ny;
        pond_block = ((nx < P1X+P1W) && (nx+PW > P1X) && (ny < P1Y+P1H) && (ny+PH > P1Y)) ||
                     ((nx < P2X+P2W) && (nx+PW > P2X) && (ny < P2Y+P2H) && (ny+PH > P2Y));
    endfunction

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            player_x<=START_X; player_y<=START_Y;
            jumping<=0; jump_cnt<=0; facing<=F_UP;
            bu_p<=0; bd_p<=0; bl_p<=0; br_p<=0; bj_p<=0;
        end else begin
            bu_p<=btn_up; bd_p<=btn_down;
            bl_p<=btn_left; br_p<=btn_right; bj_p<=btn_jump;

            if (respawn) begin
                player_x<=START_X; player_y<=START_Y;
                jumping<=0; jump_cnt<=0; facing<=F_UP;
            end else if (game_active) begin

                // ── Jump timer ──
                if (bj_r && !jumping) begin
                    jumping <= 1; jump_cnt <= JUMP_DUR;
                end else if (jumping) begin
                    if (jump_cnt == 0) jumping <= 0;
                    else jump_cnt <= jump_cnt - 1;
                end

                // ── Log carry (unsigned, no signed mixing) ──
                if (!jumping) begin
                    if (carry_right && (player_x + CARRY_SPD <= MAX_X)) begin
                        if (!pond_block(player_x + CARRY_SPD, player_y))
                            player_x <= player_x + CARRY_SPD;
                    end
                    if (carry_left && (player_x >= CARRY_SPD)) begin
                        if (!pond_block(player_x - CARRY_SPD, player_y))
                            player_x <= player_x - CARRY_SPD;
                    end
                    if (carry_down && (player_y + CARRY_SPD <= MAX_Y)) begin
                        if (!pond_block(player_x, player_y + CARRY_SPD))
                            player_y <= player_y + CARRY_SPD;
                    end
                    if (carry_up && (player_y >= MIN_Y + CARRY_SPD)) begin
                        if (!pond_block(player_x, player_y - CARRY_SPD))
                            player_y <= player_y - CARRY_SPD;
                    end
                end

                // ── Button hops (last-write wins, overrides carry) ──
                if (bu_r) begin
                    facing <= F_UP;
                    if (player_y >= MIN_Y + SPEED)
                        if (!pond_block(player_x, player_y - SPEED))
                            player_y <= player_y - SPEED;
                end else if (bd_r) begin
                    facing <= F_DN;
                    if (player_y + SPEED <= MAX_Y)
                        if (!pond_block(player_x, player_y + SPEED))
                            player_y <= player_y + SPEED;
                end else if (bl_r) begin
                    facing <= F_LT;
                    if (player_x >= SPEED)
                        if (!pond_block(player_x - SPEED, player_y))
                            player_x <= player_x - SPEED;
                end else if (br_r) begin
                    facing <= F_RT;
                    if (player_x + SPEED <= MAX_X)
                        if (!pond_block(player_x + SPEED, player_y))
                            player_x <= player_x + SPEED;
                end
            end
        end
    end
endmodule
