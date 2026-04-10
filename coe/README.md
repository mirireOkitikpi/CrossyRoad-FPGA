# Sprite COE Files

Place `.coe` files for Block Memory Generator IPs here.

## Expected sprites (Phase 1.5):
- `chicken_idle.coe` — 32×32 standing chicken
- `chicken_walk1.coe` — 32×32 walk frame 1
- `chicken_walk2.coe` — 32×32 walk frame 2
- `chicken_dead.coe` — 32×32 splat sprite
- `car_red.coe` — 64×32 red car
- `car_blue.coe` — 64×32 blue car
- `truck.coe` — 96×32 truck
- `log.coe` — 96×32 log
- `fox.coe` — 32×32 fox

## COE Format
```
memory_initialization_radix=16;
memory_initialization_vector=
000, FC0, FC0, 111, ...
```
Each value is 12-bit hex RGB (4 bits per channel).
Transparency key: `000` (black = transparent).
Row-major order: pixel (0,0) first, then (1,0), ..., (W-1,0), (0,1), etc.
