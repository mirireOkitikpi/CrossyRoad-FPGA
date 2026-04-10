`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// fox_manager.v — 3 foxes with spawn timer, greedy pursuit AI, pond avoidance
//
// Foxes spawn every 10 s from 3 holes, pursue player at half speed.
// Greedy AI: close the larger of |dx| or |dy| each tick.
// Foxes die if they enter the chasm. Killed by mic blast (SW[0] stub).
////////////////////////////////////////////////////////////////////////////////
module fox_manager (
    input             clk,
    input             rst,
    input             game_active,
    input      [10:0] player_x, player_y,
    input             mic_trigger,       // SW[0] — kill foxes in radius
    // Fox outputs
    output reg [10:0] fx0, fy0, fx1, fy1, fx2, fy2,
    output reg [2:0]  fox_active         // bit per fox
);
    localparam FOX_W  = 11'd24;
    localparam FOX_H  = 11'd24;
    localparam SPEED  = 11'd2;
    // Chasm
    localparam CX0=11'd670, CY0=11'd450, CW=11'd100, CH=11'd100;
    // Ponds
    localparam P1X=11'd300, P1Y=11'd320, P1W=11'd120, P1H=11'd80;
    localparam P2X=11'd950, P2Y=11'd580, P2W=11'd120, P2H=11'd80;
    // Fox holes (spawn points)
    localparam H0X=11'd250, H0Y=11'd500;
    localparam H1X=11'd1180,H1Y=11'd350;
    localparam H2X=11'd710, H2Y=11'd680;
    // Spawn interval: 600 ticks ≈ 10 seconds at 60 Hz
    localparam SPAWN_INT = 10'd600;
    // Mic kill radius (squared, for distance comparison)
    localparam KILL_R = 11'd200;

    reg [9:0]  spawn_timer;
    reg [1:0]  next_hole;   // cycles 0,1,2
    reg        mic_prev;
    wire       mic_rise = mic_trigger & ~mic_prev;

    // AABB overlap
    function aabb;
        input [10:0] ax,ay,aw,ah,bx,by,bw,bh;
        aabb = (ax<bx+bw)&&(ax+aw>bx)&&(ay<by+bh)&&(ay+ah>by);
    endfunction

    // Fox center in chasm?
    function in_chasm;
        input [10:0] fx, fy;
        in_chasm = (fx+12>=CX0)&&(fx+12<CX0+CW)&&(fy+12>=CY0)&&(fy+12<CY0+CH);
    endfunction

    integer i;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            fx0<=H0X; fy0<=H0Y; fx1<=H1X; fy1<=H1Y; fx2<=H2X; fy2<=H2Y;
            fox_active <= 3'b000;
            spawn_timer <= 0;
            next_hole <= 0;
            mic_prev <= 0;
        end else begin
            mic_prev <= mic_trigger;

            if (game_active) begin
                // ── Spawn timer ──
                if (spawn_timer == SPAWN_INT) begin
                    spawn_timer <= 0;
                    // Spawn into first inactive fox slot
                    if (!fox_active[0]) begin
                        fox_active[0] <= 1;
                        case (next_hole)
                            2'd0: begin fx0<=H0X; fy0<=H0Y; end
                            2'd1: begin fx0<=H1X; fy0<=H1Y; end
                            default: begin fx0<=H2X; fy0<=H2Y; end
                        endcase
                        next_hole <= (next_hole == 2'd2) ? 2'd0 : next_hole + 1;
                    end else if (!fox_active[1]) begin
                        fox_active[1] <= 1;
                        case (next_hole)
                            2'd0: begin fx1<=H0X; fy1<=H0Y; end
                            2'd1: begin fx1<=H1X; fy1<=H1Y; end
                            default: begin fx1<=H2X; fy1<=H2Y; end
                        endcase
                        next_hole <= (next_hole == 2'd2) ? 2'd0 : next_hole + 1;
                    end else if (!fox_active[2]) begin
                        fox_active[2] <= 1;
                        case (next_hole)
                            2'd0: begin fx2<=H0X; fy2<=H0Y; end
                            2'd1: begin fx2<=H1X; fy2<=H1Y; end
                            default: begin fx2<=H2X; fy2<=H2Y; end
                        endcase
                        next_hole <= (next_hole == 2'd2) ? 2'd0 : next_hole + 1;
                    end
                end else
                    spawn_timer <= spawn_timer + 1;

                // ── Fox 0 AI ──
                if (fox_active[0]) begin
                    // Chasm kill
                    if (in_chasm(fx0, fy0))
                        fox_active[0] <= 0;
                    else begin
                        // Greedy pursuit
                        if ((player_x > fx0 ? player_x - fx0 : fx0 - player_x) >=
                            (player_y > fy0 ? player_y - fy0 : fy0 - player_y)) begin
                            // Move X
                            if (player_x > fx0) begin
                                if (!aabb(fx0+SPEED,fy0,FOX_W,FOX_H,P1X,P1Y,P1W,P1H) &&
                                    !aabb(fx0+SPEED,fy0,FOX_W,FOX_H,P2X,P2Y,P2W,P2H))
                                    fx0 <= fx0 + SPEED;
                                else if (player_y > fy0) fy0 <= fy0 + SPEED;
                                else if (fy0 >= SPEED)   fy0 <= fy0 - SPEED;
                            end else begin
                                if (fx0 >= SPEED &&
                                    !aabb(fx0-SPEED,fy0,FOX_W,FOX_H,P1X,P1Y,P1W,P1H) &&
                                    !aabb(fx0-SPEED,fy0,FOX_W,FOX_H,P2X,P2Y,P2W,P2H))
                                    fx0 <= fx0 - SPEED;
                                else if (player_y > fy0) fy0 <= fy0 + SPEED;
                                else if (fy0 >= SPEED)   fy0 <= fy0 - SPEED;
                            end
                        end else begin
                            // Move Y
                            if (player_y > fy0) begin
                                if (!aabb(fx0,fy0+SPEED,FOX_W,FOX_H,P1X,P1Y,P1W,P1H) &&
                                    !aabb(fx0,fy0+SPEED,FOX_W,FOX_H,P2X,P2Y,P2W,P2H))
                                    fy0 <= fy0 + SPEED;
                                else if (player_x > fx0) fx0 <= fx0 + SPEED;
                                else if (fx0 >= SPEED)   fx0 <= fx0 - SPEED;
                            end else begin
                                if (fy0 >= SPEED &&
                                    !aabb(fx0,fy0-SPEED,FOX_W,FOX_H,P1X,P1Y,P1W,P1H) &&
                                    !aabb(fx0,fy0-SPEED,FOX_W,FOX_H,P2X,P2Y,P2W,P2H))
                                    fy0 <= fy0 - SPEED;
                                else if (player_x > fx0) fx0 <= fx0 + SPEED;
                                else if (fx0 >= SPEED)   fx0 <= fx0 - SPEED;
                            end
                        end
                    end
                end

                // ── Fox 1 AI (identical logic) ──
                if (fox_active[1]) begin
                    if (in_chasm(fx1, fy1))
                        fox_active[1] <= 0;
                    else begin
                        if ((player_x > fx1 ? player_x-fx1 : fx1-player_x) >=
                            (player_y > fy1 ? player_y-fy1 : fy1-player_y)) begin
                            if (player_x > fx1) begin
                                if (!aabb(fx1+SPEED,fy1,FOX_W,FOX_H,P1X,P1Y,P1W,P1H)&&
                                    !aabb(fx1+SPEED,fy1,FOX_W,FOX_H,P2X,P2Y,P2W,P2H))
                                    fx1<=fx1+SPEED;
                                else if (player_y>fy1) fy1<=fy1+SPEED;
                                else if (fy1>=SPEED)   fy1<=fy1-SPEED;
                            end else begin
                                if (fx1>=SPEED&&
                                    !aabb(fx1-SPEED,fy1,FOX_W,FOX_H,P1X,P1Y,P1W,P1H)&&
                                    !aabb(fx1-SPEED,fy1,FOX_W,FOX_H,P2X,P2Y,P2W,P2H))
                                    fx1<=fx1-SPEED;
                                else if (player_y>fy1) fy1<=fy1+SPEED;
                                else if (fy1>=SPEED)   fy1<=fy1-SPEED;
                            end
                        end else begin
                            if (player_y > fy1) begin
                                if (!aabb(fx1,fy1+SPEED,FOX_W,FOX_H,P1X,P1Y,P1W,P1H)&&
                                    !aabb(fx1,fy1+SPEED,FOX_W,FOX_H,P2X,P2Y,P2W,P2H))
                                    fy1<=fy1+SPEED;
                                else if (player_x>fx1) fx1<=fx1+SPEED;
                                else if (fx1>=SPEED)   fx1<=fx1-SPEED;
                            end else begin
                                if (fy1>=SPEED&&
                                    !aabb(fx1,fy1-SPEED,FOX_W,FOX_H,P1X,P1Y,P1W,P1H)&&
                                    !aabb(fx1,fy1-SPEED,FOX_W,FOX_H,P2X,P2Y,P2W,P2H))
                                    fy1<=fy1-SPEED;
                                else if (player_x>fx1) fx1<=fx1+SPEED;
                                else if (fx1>=SPEED)   fx1<=fx1-SPEED;
                            end
                        end
                    end
                end

                // ── Fox 2 AI (identical logic) ──
                if (fox_active[2]) begin
                    if (in_chasm(fx2, fy2))
                        fox_active[2] <= 0;
                    else begin
                        if ((player_x > fx2 ? player_x-fx2 : fx2-player_x) >=
                            (player_y > fy2 ? player_y-fy2 : fy2-player_y)) begin
                            if (player_x > fx2) begin
                                if (!aabb(fx2+SPEED,fy2,FOX_W,FOX_H,P1X,P1Y,P1W,P1H)&&
                                    !aabb(fx2+SPEED,fy2,FOX_W,FOX_H,P2X,P2Y,P2W,P2H))
                                    fx2<=fx2+SPEED;
                                else if (player_y>fy2) fy2<=fy2+SPEED;
                                else if (fy2>=SPEED)   fy2<=fy2-SPEED;
                            end else begin
                                if (fx2>=SPEED&&
                                    !aabb(fx2-SPEED,fy2,FOX_W,FOX_H,P1X,P1Y,P1W,P1H)&&
                                    !aabb(fx2-SPEED,fy2,FOX_W,FOX_H,P2X,P2Y,P2W,P2H))
                                    fx2<=fx2-SPEED;
                                else if (player_y>fy2) fy2<=fy2+SPEED;
                                else if (fy2>=SPEED)   fy2<=fy2-SPEED;
                            end
                        end else begin
                            if (player_y > fy2) begin
                                if (!aabb(fx2,fy2+SPEED,FOX_W,FOX_H,P1X,P1Y,P1W,P1H)&&
                                    !aabb(fx2,fy2+SPEED,FOX_W,FOX_H,P2X,P2Y,P2W,P2H))
                                    fy2<=fy2+SPEED;
                                else if (player_x>fx2) fx2<=fx2+SPEED;
                                else if (fx2>=SPEED)   fx2<=fx2-SPEED;
                            end else begin
                                if (fy2>=SPEED&&
                                    !aabb(fx2,fy2-SPEED,FOX_W,FOX_H,P1X,P1Y,P1W,P1H)&&
                                    !aabb(fx2,fy2-SPEED,FOX_W,FOX_H,P2X,P2Y,P2W,P2H))
                                    fy2<=fy2-SPEED;
                                else if (player_x>fx2) fx2<=fx2+SPEED;
                                else if (fx2>=SPEED)   fx2<=fx2-SPEED;
                            end
                        end
                    end
                end

                // ── Microphone kill ──
                if (mic_rise) begin
                    if (fox_active[0] &&
                        (fx0>player_x ? fx0-player_x : player_x-fx0) < KILL_R &&
                        (fy0>player_y ? fy0-player_y : player_y-fy0) < KILL_R)
                        fox_active[0] <= 0;
                    if (fox_active[1] &&
                        (fx1>player_x ? fx1-player_x : player_x-fx1) < KILL_R &&
                        (fy1>player_y ? fy1-player_y : player_y-fy1) < KILL_R)
                        fox_active[1] <= 0;
                    if (fox_active[2] &&
                        (fx2>player_x ? fx2-player_x : player_x-fx2) < KILL_R &&
                        (fy2>player_y ? fy2-player_y : player_y-fy2) < KILL_R)
                        fox_active[2] <= 0;
                end

            end // game_active
        end
    end
endmodule
