# CrossyRoad-FPGA

Crossy Road hardware clone implemented in Verilog on the **Nexys 4DDR** (xc7a100tcsg324-1) FPGA development board.

**Module:** ES3B2 Digital Systems Design — University of Warwick

## Game Overview

A top-down scrolling game where the player controls a chicken navigating through lanes of traffic (cars, trucks), rivers (logs), and grass (safe zones with foxes). The player hops upward through lanes while avoiding obstacles and staying on logs over rivers.

## Project Structure

```
CrossyRoad-FPGA/
├── src/                        # Verilog source modules
│   ├── game_top.v              # Top-level: FSM, clocks, integration
│   ├── vga.v                   # VGA controller (1440×900 @ 60Hz)
│   ├── drawcon.v               # Pixel rendering engine (priority mux)
│   ├── player_ctrl.v           # Chicken movement & boundary logic
│   ├── score_display.v         # 7-segment multiplexed score display
│   └── debounce.v              # Button debounce (2-FF sync + counter)
├── constraints/
│   └── crossy_road.xdc         # Pin assignments for Nexys 4DDR
├── testbench/
│   └── tb_vga.v                # VGA timing verification testbench
├── coe/                        # Sprite data (COE files for Block RAM)
├── docs/                       # Architecture diagrams & planning docs
└── README.md
```

## Hardware Requirements

- Nexys 4DDR (Digilent) with Artix-7 xc7a100tcsg324-1
- VGA monitor + VGA cable (or HDMI-to-VGA adapter)
- Vivado 2024.1

## Vivado Setup

1. Create new RTL project targeting `xc7a100tcsg324-1`
2. Add all `.v` files from `src/` as design sources
3. Add `constraints/crossy_road.xdc` as constraints
4. Add `testbench/tb_vga.v` as simulation source
5. **IP Catalog → Clocking Wizard:**
   - Output clock `clk_out1` = **106.47 MHz**
   - Uncheck *reset* and *locked*
   - Click Generate
6. Set `game_top.v` as the top module
7. Run Synthesis → Implementation → Generate Bitstream
8. Program device via Hardware Manager

## Controls

| Input | Function |
|-------|----------|
| BTNU | Hop up (one lane) |
| BTND | Hop down |
| BTNL | Hop left |
| BTNR | Hop right |
| BTNC | Start / Restart |
| SW[0:2] | Difficulty (future) |
| CPU_RESETN | Hardware reset |

## VGA Timing (1440×900 @ 60Hz)

| Parameter | Value |
|-----------|-------|
| Pixel clock | 106.47 MHz |
| H total | 1904 clocks |
| H visible | 1440 pixels (hcount 384–1823) |
| V total | 932 lines |
| V visible | 900 lines (vcount 31–930) |

## Module Hierarchy

```
game_top
├── clk_wiz_0           (IP: 100→106.47 MHz PLL)
├── debounce × 5        (button cleaning)
├── player_ctrl          (movement + boundaries)
├── drawcon              (pixel rendering)
│   └── [sprite ROMs]   (BRAM IPs from COE files — Phase 1.5)
├── vga                  (sync generation + RGB gating)
└── score_display        (7-segment mux)
```

## Development Phases

**Phase 1 (current):** Core MVP — VGA output, info bar, coloured-rectangle sprites, button movement, static lane map, AABB collision, scoring.

**Phase 1.5:** Replace rectangles with BRAM sprite ROMs (`.coe` files), add `lane_manager` with LFSR-based procedural generation, walking animations.

**Phase 2:** Accelerometer integration (SPI/ADXL362 — jump mechanic), microphone input (PDM — "call a taxi" to remove foxes), PWM audio, dynamic sprite swapping.
