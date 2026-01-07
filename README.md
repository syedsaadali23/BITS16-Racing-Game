BITS16 Racing Game

A retro 2D racing game written entirely in x86 Assembly (16-bit real mode) for DOS.
Players navigate a car across three lanes, avoiding enemy cars and collecting bonus stars, all while enjoying smooth, flicker-free graphics.

-------------------------------------------------
Features

- Lane-based Player Movement: Responsive left/right movement using BIOS keyboard interrupts (INT 16h)
- Enemy Cars & Bonus Stars: Dynamic spawning with pseudo-random generation (LCG) and real-time collision detection
- Pixel-perfect Graphics: Cars, stars, road lines, cacti, and pebbles rendered directly to video memory (0xA000 segment)
- Flicker-Free Animation: Implemented VBlank synchronization for smooth scrolling and sprite movement
- Score Tracking & Game Over: Arcade-style score system with memory-mapped storage and clean game over screen
- Optimized Memory Management: Background buffers and sprite erasure routines prevent graphical artifacts and maintain performance

-------------------------------------------------
Technical Details

- Language: x86 Assembly (16-bit real mode)
- Environment: DOS / DOSBox
- Graphics: Mode 13h (320x200, 256 colors)
- Collision Detection: Axis-Aligned Bounding Box (AABB) for enemies and collectible stars
- Randomization: Linear Congruential Generator for dynamic enemy and star placement

-------------------------------------------------
How to Run

You can run this game in DOSBox or try it online with an assembler/emulator:

Online Assembler: https://xide.nullprime.com/

Steps in DOSBox:
1. Open DOSBox
2. Mount your project folder:
   mount C path/to/your/project
   C:
3. Assemble and link the game:
   tasm BITS16.asm
   tlink BITS16.obj
4. Run the game:
   BITS16.exe

-------------------------------------------------
Why This Project Matters

Developing BITS16 strengthened skills in:
- Low-level programming & hardware interfacing
- Time-critical algorithm design
- Real-time graphics rendering and optimization
- Embedded & performance-critical system thinking

It’s a nostalgic, retro racing experience built one CPU instruction at a time.

-------------------------------------------------
License

MIT License
