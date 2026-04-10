`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// info_bar.v — 100px tall info bar with title, IDs, score, lives
// Uses font_rom for 2x-scale text rendering (16x32 per character).
// Unique group colours: teal background, gold border.
////////////////////////////////////////////////////////////////////////////////
module info_bar (
    input      [10:0] curr_x, curr_y,
    input      [7:0]  score,
    input      [2:0]  lives,
    input             game_over,
    output reg [3:0]  pixel_r, pixel_g, pixel_b,
    output            in_info_bar
);
    localparam BAR_H  = 11'd100;
    localparam BORDER = 11'd4;
    localparam SCALE  = 2;       // 2x font scale → 16x32 per char

    assign in_info_bar = (curr_y < BAR_H);
    wire is_border = (curr_y < BORDER) || (curr_y >= BAR_H - BORDER);

    // ── Colour palette ──
    localparam [11:0] COL_BORDER = 12'hFB0;
    localparam [11:0] COL_BG     = 12'h165;
    localparam [11:0] COL_TEXT   = 12'hFFF;
    localparam [11:0] COL_SCORE  = 12'hFF0;
    localparam [11:0] COL_HEART  = 12'hF24;

    // ── Text: "CROSSY RIVER"  (12 chars, x=40, y=10) ──
    localparam T_X=11'd40, T_Y=11'd10, T_LEN=12;
    wire [6:0] title [0:11];
    assign title[0]=7'h43; assign title[1]=7'h52; assign title[2]=7'h4F;
    assign title[3]=7'h53; assign title[4]=7'h53; assign title[5]=7'h59;
    assign title[6]=7'h20; assign title[7]=7'h52; assign title[8]=7'h49;
    assign title[9]=7'h56; assign title[10]=7'h45; assign title[11]=7'h52;

    // ── "ID:2217321" (10 chars, x=420, y=14) ──
    localparam I1_X=11'd420, I1_Y=11'd14, I1_LEN=10;
    wire [6:0] id1 [0:9];
    assign id1[0]=7'h49; assign id1[1]=7'h44; assign id1[2]=7'h3A;
    assign id1[3]=7'h32; assign id1[4]=7'h32; assign id1[5]=7'h31;
    assign id1[6]=7'h37; assign id1[7]=7'h33; assign id1[8]=7'h32;
    assign id1[9]=7'h31;

    // ── "ID:2233380" (10 chars, x=420, y=52) ──
    localparam I2_X=11'd420, I2_Y=11'd52, I2_LEN=10;
    wire [6:0] id2 [0:9];
    assign id2[0]=7'h49; assign id2[1]=7'h44; assign id2[2]=7'h3A;
    assign id2[3]=7'h32; assign id2[4]=7'h32; assign id2[5]=7'h33;
    assign id2[6]=7'h33; assign id2[7]=7'h33; assign id2[8]=7'h38;
    assign id2[9]=7'h30;

    // ── "SCORE:" (6 chars, x=800, y=14) ──
    localparam SL_X=11'd800, SL_Y=11'd14, SL_LEN=6;
    wire [6:0] scl [0:5];
    assign scl[0]=7'h53; assign scl[1]=7'h43; assign scl[2]=7'h4F;
    assign scl[3]=7'h52; assign scl[4]=7'h45; assign scl[5]=7'h3A;

    // ── Score digits (3 chars, x=896, y=14) ──
    localparam SD_X=11'd896, SD_Y=11'd14;
    wire [6:0] sd_h = 7'h30 + {3'd0, score / 8'd100};
    wire [6:0] sd_t = 7'h30 + {3'd0, (score / 8'd10) % 8'd10};
    wire [6:0] sd_o = 7'h30 + {3'd0, score % 8'd10};

    // ── "LIVES:" (6 chars, x=800, y=52) ──
    localparam LL_X=11'd800, LL_Y=11'd52, LL_LEN=6;
    wire [6:0] lvl [0:5];
    assign lvl[0]=7'h4C; assign lvl[1]=7'h49; assign lvl[2]=7'h56;
    assign lvl[3]=7'h45; assign lvl[4]=7'h53; assign lvl[5]=7'h3A;

    // ── Hearts: x=896, y=56, 24px apart, 20px wide ──
    localparam HRT_X=11'd896, HRT_Y=11'd56;
    wire in_hrt = (curr_y >= HRT_Y) && (curr_y < HRT_Y + 20) &&
                  (curr_x >= HRT_X) && (curr_x < HRT_X + 72);
    wire [1:0] hrt_idx = (curr_x - HRT_X) / 24;
    wire hrt_fill = ((curr_x - HRT_X) % 24) < 20;
    wire hrt_on = in_hrt && hrt_fill && (hrt_idx < lives);

    // ── Font ROM ──
    reg [10:0] font_addr;
    wire [7:0] font_data;
    font_rom fnt (.addr(font_addr), .font_data(font_data));

    // ── Text region helpers ──
    // For a text block at (ox,oy) with n chars at 2x scale:
    //   in_region = x in [ox, ox+n*16) && y in [oy, oy+32)
    //   char_idx  = (x-ox)/16, col = ((x-ox)/2)%8, row = ((y-oy)/2)%16

    // Title
    wire in_t = (curr_x>=T_X) && (curr_x<T_X+T_LEN*16) && (curr_y>=T_Y) && (curr_y<T_Y+32);
    wire [3:0] t_ci = (curr_x - T_X) >> 4;   // /16
    wire [2:0] t_co = ((curr_x - T_X) >> 1) & 3'h7; // /2 %8
    wire [3:0] t_ro = ((curr_y - T_Y) >> 1) & 4'hF;

    // ID1
    wire in_i1 = (curr_x>=I1_X)&&(curr_x<I1_X+I1_LEN*16)&&(curr_y>=I1_Y)&&(curr_y<I1_Y+32);
    wire [3:0] i1_ci=(curr_x-I1_X)>>4; wire [2:0] i1_co=((curr_x-I1_X)>>1)&3'h7;
    wire [3:0] i1_ro=((curr_y-I1_Y)>>1)&4'hF;

    // ID2
    wire in_i2 = (curr_x>=I2_X)&&(curr_x<I2_X+I2_LEN*16)&&(curr_y>=I2_Y)&&(curr_y<I2_Y+32);
    wire [3:0] i2_ci=(curr_x-I2_X)>>4; wire [2:0] i2_co=((curr_x-I2_X)>>1)&3'h7;
    wire [3:0] i2_ro=((curr_y-I2_Y)>>1)&4'hF;

    // Score label
    wire in_sl = (curr_x>=SL_X)&&(curr_x<SL_X+SL_LEN*16)&&(curr_y>=SL_Y)&&(curr_y<SL_Y+32);
    wire [3:0] sl_ci=(curr_x-SL_X)>>4; wire [2:0] sl_co=((curr_x-SL_X)>>1)&3'h7;
    wire [3:0] sl_ro=((curr_y-SL_Y)>>1)&4'hF;

    // Score digits (3 chars)
    wire in_sd = (curr_x>=SD_X)&&(curr_x<SD_X+48)&&(curr_y>=SD_Y)&&(curr_y<SD_Y+32);
    wire [1:0] sd_ci=(curr_x-SD_X)>>4; wire [2:0] sd_co=((curr_x-SD_X)>>1)&3'h7;
    wire [3:0] sd_ro=((curr_y-SD_Y)>>1)&4'hF;

    // Lives label
    wire in_ll = (curr_x>=LL_X)&&(curr_x<LL_X+LL_LEN*16)&&(curr_y>=LL_Y)&&(curr_y<LL_Y+32);
    wire [3:0] ll_ci=(curr_x-LL_X)>>4; wire [2:0] ll_co=((curr_x-LL_X)>>1)&3'h7;
    wire [3:0] ll_ro=((curr_y-LL_Y)>>1)&4'hF;

    // ── Priority mux ──
    reg [11:0] colour;
    always @(*) begin
        colour = COL_BG;
        font_addr = 11'd0;

        if (is_border) begin
            colour = COL_BORDER;
        end else if (in_t) begin
            font_addr = {title[t_ci], t_ro};
            if (font_data[7 - t_co]) colour = COL_TEXT;
        end else if (in_i1) begin
            font_addr = {id1[i1_ci], i1_ro};
            if (font_data[7 - i1_co]) colour = COL_TEXT;
        end else if (in_i2) begin
            font_addr = {id2[i2_ci], i2_ro};
            if (font_data[7 - i2_co]) colour = COL_TEXT;
        end else if (in_sl) begin
            font_addr = {scl[sl_ci], sl_ro};
            if (font_data[7 - sl_co]) colour = COL_TEXT;
        end else if (in_sd) begin
            case (sd_ci)
                2'd0: font_addr = {sd_h, sd_ro};
                2'd1: font_addr = {sd_t, sd_ro};
                default: font_addr = {sd_o, sd_ro};
            endcase
            if (font_data[7 - sd_co]) colour = COL_SCORE;
        end else if (in_ll) begin
            font_addr = {lvl[ll_ci], ll_ro};
            if (font_data[7 - ll_co]) colour = COL_TEXT;
        end else if (hrt_on) begin
            colour = COL_HEART;
        end
    end

    always @(*) begin
        pixel_r = colour[11:8];
        pixel_g = colour[7:4];
        pixel_b = colour[3:0];
    end
endmodule
