`timescale 1ns / 1ps

module top_tb;

    // Testbench Inputs
    reg clk_50;
    reg reset_n;

    // Testbench Outputs
    wire [4:0] vga_r;
    wire [5:0] vga_g;
    wire [4:0] vga_b;
    wire       vga_hs;
    wire       vga_vs;

    // Instantiate Unit Under Test (UUT)
    top uut (
        .clk_50 (clk_50),
        .reset_n   (reset_n),
        .vga_r     (vga_r),
        .vga_g     (vga_g),
        .vga_b     (vga_b),
        .vga_hs    (vga_hs),
        .vga_vs    (vga_vs)
    );

    integer hsync_cnt = 0;
    // 50 MHz Clock Generator (Period = 20 ns)
    always #10 clk_50 = ~clk_50;

    initial begin
        $dumpfile("spc1000f.vcd");
        $dumpvars(0, top_tb); // Dumps all variables in counter_tb and below

        // Initialize Inputs
        clk_50 = 1'b0;
        reset_n   = 1'b0; // Hold in reset

        // Wait 100 ns for global reset to settle
        #100;

        // Release reset
        reset_n = 1'b1;

        // Run simulation for 300us
        //#300000;

        // Run simulation for 1ms
        #1024360;

        // Run simulation for 1 full video frames (~16 ms)
        //#17024360;

        // Run simulation for 2 video frames (~33 ms)
        //#34024360;

        $display("Simulation complete.");
        $finish;
    end

    // Monitor horizontal sync toggles
    always @(posedge vga_hs) begin
       hsync_cnt = hsync_cnt + 1;
       if (hsync_cnt % 10 == 0) begin
           $display("[Hsync: %3d]", hsync_cnt);
       end
    end

endmodule
