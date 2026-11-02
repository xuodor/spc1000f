// SPDX-License-Identifier: MIT

// I2S for audio DAC

module i2s(
	   input wire	    clk,
	   input wire       clk_en,
	   input wire	    rst_n,
	   input wire [9:0] din,
	   output wire	    i2s_bclk,
	   output wire	    i2s_lrclk,
	   output wire	    i2s_sdata,
           output wire      i2s_sck);

    // Expand 10 to 16 bit
    wire [15:0] payload = { (din - 10'b1000000000), 6'h00 };
    reg [15:0] shift_reg;
    reg        sdata_out;

    reg bclk_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) bclk_reg <= 1'b0;
        else if (clk_en) bclk_reg <= ~bclk_reg;
    end
    assign i2s_bclk = bclk_reg;

    reg bclk_reg_delayed;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) bclk_reg_delayed <= 1'b0;
        else        bclk_reg_delayed <= bclk_reg;
    end
    wire bclk_rising = (bclk_reg && !bclk_reg_delayed);

    reg [4:0] bit_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt <= 5'd0;
        end else if (bclk_rising) begin
            bit_cnt <= bit_cnt + 1'b1;
        end
    end
    assign i2s_lrclk = bit_cnt[4];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 16'd0;
            sdata_out <= 1'b0;
        end else if (bclk_rising) begin
            if (bit_cnt == 5'd0 || bit_cnt == 5'd16) begin
                shift_reg <= payload;
            end else begin
                shift_reg <= {shift_reg[14:0], 1'b0};
            end

            if ((bit_cnt >= 5'd0 && bit_cnt <= 5'd15) || (bit_cnt >= 5'd16 && bit_cnt <= 5'd31)) begin
                sdata_out <= shift_reg[15];
            end else begin
                sdata_out <= 1'b0;
            end
        end
    end

    assign i2s_sdata = sdata_out;
    assign i2s_sck = 1'b0;
endmodule
