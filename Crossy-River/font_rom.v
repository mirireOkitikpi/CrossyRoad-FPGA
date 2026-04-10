`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// font_rom.v — 8x16 ASCII bitmap font ROM
// Address: {ascii[6:0], row[3:0]} = 11 bits -> 8-bit pixel row
// MSB = leftmost pixel. Loaded from font.mem via $readmemh.
////////////////////////////////////////////////////////////////////////////////
module font_rom (
    input      [10:0] addr,
    output     [7:0]  font_data
);
    reg [7:0] rom [0:2047];
    initial $readmemh("font.mem", rom);
    assign font_data = rom[addr];
endmodule
