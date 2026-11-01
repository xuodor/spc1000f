// SPDX-License-Identifier: MIT

// SDRAM Controller
module sdram
    #(
         parameter MEM_DATA_BITS = 8,
         parameter ADDR_BITS = 16,
         parameter BURST_BITS = 8,
         parameter BURST_SIZE = 1
     )
     (
         input rst,
         input mem_clk,

         input wire wr,
         input wire rd,
         input wire [15: 0] addr,
         input wire [7: 0] din,
         output wire [7: 0] dout,

         output reg rd_burst_req,
         output reg wr_burst_req,
         output reg [7: 0] rd_burst_len,
         output reg [7: 0] wr_burst_len,
         output reg [15: 0] rd_burst_addr,
         output reg [15: 0] wr_burst_addr,
         input rd_burst_data_valid,
         input wr_burst_data_req,
         input [7: 0] rd_burst_data,
         output reg [7: 0] wr_burst_data,
         input rd_burst_finish,
         input wr_burst_finish
     );

    localparam IDLE = 3'd0;
    localparam MEM_READ = 3'd1;
    localparam MEM_WRITE = 3'd2;
    localparam END = 3'd3;

    reg[2: 0] state;
    reg[2: 0] rd_cnt;
    reg [7: 0] dout_r;
    assign dout = dout_r;

    always@(posedge mem_clk or posedge rst)begin
        if (rst == 1'b1)
            wr_burst_data <= 8'h0;
        else if (wr_burst_data_req == 1'b1)
            wr_burst_data <= din;
    end

    always@(posedge mem_clk or posedge rst)begin
        if (rst == 1'b1)begin
            state <= IDLE;
            wr_burst_req <= 1'b0;
            rd_burst_req <= 1'b0;
            rd_burst_len <= BURST_SIZE[7: 0];
            wr_burst_len <= BURST_SIZE[7: 0];
            rd_burst_addr <= 16'h0;
            wr_burst_addr <= 16'h0;
        end
        else
        case (state)
            IDLE:begin
                if (wr) begin
                    state <= MEM_WRITE;
                    wr_burst_req <= 1'b1;
                    wr_burst_len <= BURST_SIZE[7: 0];
                    wr_burst_addr <= addr;
                    rd_burst_req <= 1'b0;
                end
                else if (rd) begin
                    state <= MEM_READ;
                    rd_burst_req <= 1'b1;
                    rd_burst_addr <= addr;
                    rd_burst_len <= BURST_SIZE[7: 0];
                    rd_cnt <= 3'd1;
                end
            end
            MEM_WRITE:begin
                if (wr_burst_finish == 1'b1)begin
                    wr_burst_req <= 1'b0;
                    state <= END;
                end
            end

            MEM_READ:begin
                if (rd_burst_data_valid == 1'b1) begin
                    rd_burst_req <= 1'b0;
                    dout_r <= rd_burst_data;
                    state <= END;
                end

                if (rd_burst_finish == 1'b1)begin
                    state <= END;
                end
            end

            default:
                if (!wr && !rd) begin
                    state <= IDLE;
                end
        endcase
    end

endmodule
