# Battlestar-Galatica
A horizontal scrolling space game made using MIPS assembly. This is the course project for CSC258H1, at the University of Toronto.<br />
The goal of this game is to gather as much coins as you can while avoiding obstacles including asteroids and lasers.

## Software Requirements
* **MARS (MIPS Assembler and Runtime Simulator)** Download here: http://courses.missouristate.edu/KenVollmar/mars/

## Setting Up the Game
* Open *game.asm* under File -> Open
* Assemble the file under Run -> Assemble
* Under Tools, select "Keyboard and Display MMIO Simulator"; Select "Connect to MIPS"
* Under Tools, select "Bitmap Display"; Select "Connect to MIPS"; Configure the settings to the following:
  * Unit Width: 2
  * Unit Height: 2
  * Display Width: 512
  * Display Height: 512
  * Base address for display: 0x10008000 ($gp)
* Select Run -> Go to play the game

## Game Controls
(please make sure that Caps Lock is OFF)
* w/a/s/d: moves the plane in the up/left/down/right direction respectively 
* p: restarts the game
* q: exits the game

## Academic Integrity
Files in this repository were submitted to the University of Toronto and are not intended to be reused for academic purposes.
