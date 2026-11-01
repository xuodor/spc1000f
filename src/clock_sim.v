`timescale 1ns / 1ps

module clocks (
    input  wire clk_in,   // 50 MHz input clock
    output reg  clk_25,   // 25 MHz generated clock
    output reg  clk_12,   // 12 MHz generated clock
    output reg  clk_4,    //  4 MHz generated clock
    output reg  clk_100,  // SDRAM
    output reg  clk_100p, // SDRAM controller
    input  wire RESET,     // Active-high RESET input
    output reg  LOCKED     // PLL Lock indicator
);

   initial begin
      clk_25 = 1'b0;
      clk_12 = 1'b0;

      clk_4 = 1'b0;
      clk_100 = 1'b0;
      clk_100p = 1'b0;
      LOCKED = 1'b0;
   end

   reg [5:0] acc;

   always @(posedge clk_in or posedge RESET) begin
      if (RESET) begin
	 acc <= 0;
         clk_25 <= 1'b0;
         clk_12 = 1'b0;
         LOCKED <= 1'b0;
      end else begin
	 clk_25 <= ~clk_25;
	 LOCKED <= 1'b1; // Simulate immediate PLL lock
      end
   end

    realtime last_edge;
    realtime current_edge;
    realtime in_period;
    realtime out_half_period;
    realtime phase_shift_delay;

    integer edge_count;

    reg sdram_clk;
    reg sdram_clk_ref;
    // --- PLL Stabilization Simulation ---
    // Simulates the time a real analog PLL circuit takes to achieve lock stability
    always begin
         #125 clk_4 = ~clk_4;
    end

    initial begin
        LOCKED = 1'b0;
        sdram_clk = 1'b0;
        sdram_clk_ref = 1'b0;
        clk_4 = 0;

        last_edge = 0;
        in_period = 0;
        out_half_period = 0;
        phase_shift_delay = 0;
        edge_count = 0;
    end

    always @(posedge clk_in) begin
            // Simulates locking onto the input frequency after a brief startup window
            if (!LOCKED) begin
                #100; // 100ns stabilization delay guard
                LOCKED <= 1'b1;
            end
    end

    // Measure the incoming clock period dynamically
    always @(posedge clk_in) begin
            current_edge = $realtime;

            if (last_edge > 0) begin
                in_period = current_edge - last_edge;
                out_half_period = in_period / 4.0; // 100MHz half-period is 1/4 of 50MHz full-period
                phase_shift_delay = in_period / 8.0;  // 2.5ns shift (one-quarter of 100MHz period)

                // Simulate a locking delay (e.g., requires 3 consecutive stable cycles)
                if (edge_count < 3) begin
                    edge_count <= edge_count + 1;
                    LOCKED     <= 0;
                end else begin
                    LOCKED     <= 1;
                end
            end

            last_edge = current_edge;
    end

    // Generate the 100 MHz clock based on the measured input period
    always begin
        // If LOCKED and period is valid, oscillate at 2x the frequency (100 MHz)
        if (LOCKED && out_half_period > 0) begin
            #(out_half_period) clk_100 = ~clk_100;
        end else begin
            // Default safe state or tracking mode before lock
            clk_100 = 0;
            #1;
        end
    end

    // Generate the 90-degree phase-shifted clock
    // Directly shadows the base clock, offset by the phase_shift_delay
    always @(clk_100 or LOCKED) begin
        if (LOCKED && phase_shift_delay > 0) begin
            clk_100p <= #(phase_shift_delay) clk_100;
        end else begin
            clk_100p <= 0;
        end
    end

endmodule

module ODDR2
    #(
        parameter DDR_ALIGNMENT = "NONE",
        parameter INIT = 1'b0,
        parameter SRTYPE = "SYNC"
    )
    (
        output wire Q,
        input wire C0,
        input wire C1,
        input wire CE,
        input wire D0,
        input wire D1,
        input wire R,
        input wire S
    );

    assign Q = C0;
endmodule
