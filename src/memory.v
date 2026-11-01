// SPDX-License-Identifier: MIT

// Single-port, synchronous read/write RAM
module sync_ram(
		input wire	  clk,
		input wire	  we,
		input wire [14:0] addr,
		input wire [7:0]  din,
		output reg [7:0] dout);
   parameter			 MEM_INIT_FILE = "main.mem";
   (* ram_style = "block" *) reg [7:0]                     ram [0:32767];

   initial
     if (MEM_INIT_FILE != "")
       $readmemh(MEM_INIT_FILE, ram);

   always @(posedge clk) begin
      if (we) ram[addr] <= din;
      dout <= ram[addr];
   end

endmodule // ram_sync

// Dual-port, synchronous read/write + async read-only RAM.
// When the same address is written to/read from each port,
// the latest written value is returned.
module vram (
                // Port A (CPU)
                input            clk_a,
                input            we_a,
                input [10:0]     addr_a,
                input [7:0]      din_a,
                output reg [7:0] dout_a,
                // Port B (VDG)
                input            clk_b,
                input [10:0]     addr_b,
                output reg [7:0] dout_b
            );

   (* ram_style = "block" *) reg [7:0] ram [0:2047];

   always @(posedge clk_a)
     begin
        if (we_a) begin
          ram[addr_a] <= din_a;
        end
        dout_a <= ram[addr_a];
     end

   always @(posedge clk_a)
     begin
         dout_b <= ram[addr_b];
     end

endmodule
