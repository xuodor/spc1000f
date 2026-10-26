# SPC-1000F
SPC-1000F is a near-complete FPGA implementation of [SPC-1000](https://en.wikipedia.org/wiki/SPC-1000), 8-bit computer popular in South Korea back in 80's.

![SPC-1000 on FPGA](spc1000f.jpg)

* Dev board: Alinx AX309 (Spartan 6, XC6SLX16)
  * Available on [AliExpress](https://www.aliexpress.com/w/wholesale-ax309-fpga.html?spm=a2g0o.home.search.0)
  * Resources (specs/docs, Verilog examples) on [Github](https://github.com/alinxalinx/AX309)
* Open-source modules (all the credits go to the authors) adopted in the project are:
  * Z80 - https://github.com/gdevic/A-Z80
  * MC6847 - https://github.com/hoglet67/Ice40Atom/blob/master/src/mc6847.v
  * USB HID Host (for keyboard) - https://github.com/nand2mario/usb_hid_host
  * AY-3-8910(YM2149) - https://github.com/jotego/jt49

## How to use it
 * Use the .mcs PROM file in the repo. Follow the guideline ["Programming SPI Flash"](https://docs.amd.com/r/en-US/xapp586-spi-flash/Programming-the-SPI-Flash-In-System)
 * The board will reboot to the initial screen once the flashing is done.
 * If you want to build it from source, unzip the archive(xilinx.zip), import the project, and follow [the instruction](https://dejazzer.com/ee478/labs/lab2_ise_tutorial.pdf) (from section 3.4 "Add Existing Source Files to Project").

## Connecting a keyboard
   The board does not come with USB or PS/2 connector. I chose to use a simple [USB 2.0 A female receptacle](https://www.google.com/search?q=USB+A+female+receptacle) + 15K resistors x 2 as instructed in [usb-hid-host](https://github.com/nand2mario/usb_hid_host/blob/main/doc/usb_hid_host.md) project.
```
+---------+
|         |           +-----+           +----------------+
|         +----+------+     |           |                |
|  FPGA   |    |      | USB +-----------+    Keyboard    |
|  board  +----|---+--+ con.|           |                |
|         |    |   |  +-----+           +----------------+
+---------+    8   8
               |   |  15K
              /// ///
```
(VCC,GND pins are not shown here for brevity's sake but they need wiring too)

## Connecting a sound chip

A [DAC breakout board](https://www.google.com/search?q=I2s++dac+module)(PCM5012 or MAX93857, to name a few) via I2S protocol (`bclk/lrclk/din`) works.

## TODO
 * Fix bugs (plenty of them alive...)
 * Tape loading/saving
 * Support more boards (Tang Nano 9K, iCESugar are planned)
 * Upgrade USB HID host from low- to full-speed one
 * Scanline effect