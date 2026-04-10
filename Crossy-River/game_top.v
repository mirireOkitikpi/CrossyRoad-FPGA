`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// game_top.v - Top-level for Crossy River (Lab 5 structure)
//
// Architecture:
//   clk_wiz_0 → pixclk (106.47 MHz) used for everything
//   Counter divider → game_clk (~60 Hz)
//   5× debounce → clean button signals
//   Collision engine (combinational) computes death/log riding
//   Game FSM: IDLE → PLAYING → DEAD → GAME_OVER
//
// IDs: 2217321, 2233380
////////////////////////////////////////////////////////////////////////////////
module game_top (
    input         clk,       // 100 MHz board clock
    input         rst,       // CPU_RESETN (active low)
    input         btn_c, btn_u, btn_d, btn_l, btn_r,
    input  [1:0]  sw,        // sw[0]=mic stub, sw[1]=spare
    output [3:0]  pix_r, pix_g, pix_b,
    output        hsync, vsync,
    output [6:0]  seg,
    output [7:0]  an,
    output [15:0] led
);

    // ══════════════════════════════════════════════════════════
    // 1. CLOCKING (Lab 4/5: Clocking Wizard IP - single output)
    //    pixclk (106.47 MHz) used for VGA AND all other logic.
    //    This avoids clock domain crossing issues entirely.
    // ══════════════════════════════════════════════════════════
    wire pixclk;
    clk_wiz_0 clk_inst (
        .clk_out1(pixclk),   // 106.47 MHz
        .clk_in1(clk)
    );

    // Game clock ~60 Hz (toggle every 887250 pixclk cycles)
    // 106_470_000 / (887250 * 2) = 60.0 Hz
    reg [20:0] clk_div;
    reg        game_clk;
    always @(posedge pixclk or negedge rst) begin
        if (!rst) begin clk_div <= 0; game_clk <= 0; end
        else if (clk_div == 21'd887249) begin
            clk_div <= 0; game_clk <= ~game_clk;
        end else
            clk_div <= clk_div + 1;
    end

    // ══════════════════════════════════════════════════════════
    // 2. DEBOUNCING
    // ══════════════════════════════════════════════════════════
    wire bc, bu, bd, bl, br;
    debounce db0(.clk(pixclk),.rst(rst),.btn_in(btn_c),.btn_out(bc));
    debounce db1(.clk(pixclk),.rst(rst),.btn_in(btn_u),.btn_out(bu));
    debounce db2(.clk(pixclk),.rst(rst),.btn_in(btn_d),.btn_out(bd));
    debounce db3(.clk(pixclk),.rst(rst),.btn_in(btn_l),.btn_out(bl));
    debounce db4(.clk(pixclk),.rst(rst),.btn_in(btn_r),.btn_out(br));

    // ══════════════════════════════════════════════════════════
    // 3. GAME STATE
    // ══════════════════════════════════════════════════════════
    localparam S_IDLE = 2'd0, S_PLAY = 2'd1, S_DEAD = 2'd2, S_OVER = 2'd3;
    reg [1:0]  state;
    reg [7:0]  score, high_score;
    reg [2:0]  lives;
    reg        bc_prev;
    wire       bc_rise = bc & ~bc_prev;
    wire       game_active = (state == S_PLAY);

    // Death pause counter (60 ticks = 1 second)
    reg [5:0]  dead_cnt;
    // Score timer (300 ticks = 5 seconds → +10 points)
    reg [8:0]  score_timer;
    // Respawn pulse
    reg        respawn_pulse;

    // ══════════════════════════════════════════════════════════
    // 4. PLAYER
    // ══════════════════════════════════════════════════════════
    wire [10:0] px, py;
    wire        p_jump;
    wire [1:0]  p_face;

    // Log riding signals (computed below in collision section)
    wire on_log;
    wire carry_left, carry_right, carry_up, carry_down;

    player player_inst (
        .clk(game_clk), .rst(rst),
        .game_active(game_active),
        .respawn(respawn_pulse),
        .btn_up(bu), .btn_down(bd), .btn_left(bl), .btn_right(br),
        .btn_jump(bc),
        .carry_left(carry_left), .carry_right(carry_right),
        .carry_up(carry_up), .carry_down(carry_down),
        .player_x(px), .player_y(py),
        .jumping(p_jump), .facing(p_face)
    );

    // ══════════════════════════════════════════════════════════
    // 5. LOG MANAGER
    // ══════════════════════════════════════════════════════════
    wire [10:0] lx0,ly0,lx1,ly1,lx2,ly2,lx3,ly3;
    wire [10:0] lx4,ly4,lx5,ly5,lx6,ly6,lx7,ly7;
    wire [7:0]  log_act;

    log_manager logs (
        .clk(game_clk), .rst(rst), .game_active(game_active),
        .lx0(lx0),.ly0(ly0),.lx1(lx1),.ly1(ly1),
        .lx2(lx2),.ly2(ly2),.lx3(lx3),.ly3(ly3),
        .lx4(lx4),.ly4(ly4),.lx5(lx5),.ly5(ly5),
        .lx6(lx6),.ly6(ly6),.lx7(lx7),.ly7(ly7),
        .log_active(log_act)
    );

    // ══════════════════════════════════════════════════════════
    // 6. FOX MANAGER
    // ══════════════════════════════════════════════════════════
    wire [10:0] fx0,fy0,fx1,fy1,fx2,fy2;
    wire [2:0]  fox_act;

    fox_manager foxes (
        .clk(game_clk), .rst(rst), .game_active(game_active),
        .player_x(px), .player_y(py),
        .mic_trigger(sw[0]),
        .fx0(fx0),.fy0(fy0),.fx1(fx1),.fy1(fy1),.fx2(fx2),.fy2(fy2),
        .fox_active(fox_act)
    );

    // ══════════════════════════════════════════════════════════
    // 7. COLLISION ENGINE (combinational)
    // ══════════════════════════════════════════════════════════
    localparam PW = 11'd32, PH = 11'd32;
    localparam FW = 11'd24, FH = 11'd24;
    localparam HLW=11'd96, HLH=11'd48, VLW=11'd48, VLH=11'd96;
    localparam CX0=11'd670, CY0=11'd450, CCW=11'd100, CCH=11'd100;
    // Player center
    wire [10:0] pcx = px + 11'd16;
    wire [10:0] pcy = py + 11'd16;

    // River zone (using player center)
    wire in_top_r   = (pcy >= 11'd100) && (pcy < 11'd248);
    wire in_bot_r   = (pcy >= 11'd752) && (pcy < 11'd900);
    wire in_left_r  = (pcx < 11'd148)  && (pcy >= 11'd248) && (pcy < 11'd752);
    wire in_right_r = (pcx >= 11'd1292) && (pcy >= 11'd248) && (pcy < 11'd752);
    wire in_river   = in_top_r | in_bot_r | in_left_r | in_right_r;

    // Chasm (using player center)
    wire in_chasm = (pcx >= CX0) && (pcx < CX0+CCW) && (pcy >= CY0) && (pcy < CY0+CCH);

    // Log overlap: AABB player vs each log
    wire ol0 = log_act[0]&&(px<lx0+HLW)&&(px+PW>lx0)&&(py<ly0+HLH)&&(py+PH>ly0);
    wire ol1 = log_act[1]&&(px<lx1+HLW)&&(px+PW>lx1)&&(py<ly1+HLH)&&(py+PH>ly1);
    wire ol2 = log_act[2]&&(px<lx2+VLW)&&(px+PW>lx2)&&(py<ly2+VLH)&&(py+PH>ly2);
    wire ol3 = log_act[3]&&(px<lx3+VLW)&&(px+PW>lx3)&&(py<ly3+VLH)&&(py+PH>ly3);
    wire ol4 = log_act[4]&&(px<lx4+HLW)&&(px+PW>lx4)&&(py<ly4+HLH)&&(py+PH>ly4);
    wire ol5 = log_act[5]&&(px<lx5+HLW)&&(px+PW>lx5)&&(py<ly5+HLH)&&(py+PH>ly5);
    wire ol6 = log_act[6]&&(px<lx6+VLW)&&(px+PW>lx6)&&(py<ly6+VLH)&&(py+PH>ly6);
    wire ol7 = log_act[7]&&(px<lx7+VLW)&&(px+PW>lx7)&&(py<ly7+VLH)&&(py+PH>ly7);
    assign on_log = (ol0|ol1|ol2|ol3|ol4|ol5|ol6|ol7) && in_river;

    // Carry direction: unsigned flags (anti-clockwise flow)
    assign carry_left  = on_log && in_top_r;     // top river flows left
    assign carry_right = on_log && in_bot_r;     // bottom river flows right
    assign carry_down  = on_log && in_left_r;    // left river flows down
    assign carry_up    = on_log && in_right_r;   // right river flows up

    // Fox overlap
    wire fh0 = fox_act[0]&&(px<fx0+FW)&&(px+PW>fx0)&&(py<fy0+FH)&&(py+PH>fy0);
    wire fh1 = fox_act[1]&&(px<fx1+FW)&&(px+PW>fx1)&&(py<fy1+FH)&&(py+PH>fy1);
    wire fh2 = fox_act[2]&&(px<fx2+FW)&&(px+PW>fx2)&&(py<fy2+FH)&&(py+PH>fy2);
    wire fox_hit = fh0 | fh1 | fh2;

    // Death signals
    wire river_death = in_river && !on_log && !p_jump;
    wire chasm_death = in_chasm && !p_jump;
    wire any_death   = river_death | chasm_death | fox_hit;

    // ══════════════════════════════════════════════════════════
    // 8. GAME FSM
    // ══════════════════════════════════════════════════════════
    always @(posedge game_clk or negedge rst) begin
        if (!rst) begin
            state <= S_IDLE;
            score <= 0; high_score <= 0; lives <= 3'd3;
            bc_prev <= 0; dead_cnt <= 0; score_timer <= 0;
            respawn_pulse <= 0;
        end else begin
            bc_prev <= bc;
            respawn_pulse <= 0;

            case (state)
                S_IDLE: begin
                    if (bc_rise) begin
                        state <= S_PLAY;
                        score <= 0; lives <= 3'd3;
                        score_timer <= 0;
                        respawn_pulse <= 1;
                    end
                end

                S_PLAY: begin
                    // Survival score: +10 every 5 seconds
                    if (score_timer == 9'd300) begin
                        score_timer <= 0;
                        if (score <= 8'd245) score <= score + 8'd10;
                    end else
                        score_timer <= score_timer + 1;

                    // High score tracking
                    if (score > high_score) high_score <= score;

                    // Death check
                    if (any_death) begin
                        state <= S_DEAD;
                        dead_cnt <= 6'd60;  // 1 second pause
                    end
                end

                S_DEAD: begin
                    if (dead_cnt == 0) begin
                        if (lives > 3'd1) begin
                            lives <= lives - 1;
                            state <= S_PLAY;
                            respawn_pulse <= 1;
                            score_timer <= 0;
                        end else begin
                            lives <= 0;
                            state <= S_OVER;
                        end
                    end else
                        dead_cnt <= dead_cnt - 1;
                end

                S_OVER: begin
                    if (bc_rise) state <= S_IDLE;
                end
            endcase
        end
    end

    // ══════════════════════════════════════════════════════════
    // 9. RENDERING (pixclk domain)
    // ══════════════════════════════════════════════════════════
    wire [10:0] curr_x, curr_y;
    wire [3:0]  draw_r, draw_g, draw_b;

    arena_renderer renderer (
        .curr_x(curr_x), .curr_y(curr_y),
        .player_x(px), .player_y(py),
        .player_facing(p_face), .player_jumping(p_jump),
        .fx0(fx0),.fy0(fy0),.fx1(fx1),.fy1(fy1),.fx2(fx2),.fy2(fy2),
        .fox_active(fox_act),
        .lx0(lx0),.ly0(ly0),.lx1(lx1),.ly1(ly1),
        .lx2(lx2),.ly2(ly2),.lx3(lx3),.ly3(ly3),
        .lx4(lx4),.ly4(ly4),.lx5(lx5),.ly5(ly5),
        .lx6(lx6),.ly6(ly6),.lx7(lx7),.ly7(ly7),
        .log_active(log_act),
        .score(score), .lives(lives),
        .game_over(state == S_OVER),
        .game_state(state),
        .draw_r(draw_r), .draw_g(draw_g), .draw_b(draw_b)
    );

    // ══════════════════════════════════════════════════════════
    // 10. VGA OUTPUT
    // ══════════════════════════════════════════════════════════
    vga vga_inst (
        .clk(pixclk), .rst(rst),
        .draw_r(draw_r), .draw_g(draw_g), .draw_b(draw_b),
        .curr_x(curr_x), .curr_y(curr_y),
        .pix_r(pix_r), .pix_g(pix_g), .pix_b(pix_b),
        .hsync(hsync), .vsync(vsync)
    );

    // ══════════════════════════════════════════════════════════
    // 11. SEVEN SEGMENT DISPLAY
    // ══════════════════════════════════════════════════════════
    score_display seg_inst (
        .clk(pixclk), .rst(rst),
        .score(score), .high_score(high_score),
        .seg(seg), .an(an)
    );

    // ══════════════════════════════════════════════════════════
    // 12. LED DEBUG OUTPUT
    // ══════════════════════════════════════════════════════════
    assign led[7:0]  = score;
    assign led[8]    = (lives >= 3'd1);
    assign led[9]    = (lives >= 3'd2);
    assign led[10]   = (lives >= 3'd3);
    assign led[11]   = on_log;
    assign led[12]   = in_river;
    assign led[13]   = p_jump;
    assign led[14]   = fox_hit;
    assign led[15]   = (state == S_OVER);

endmodule