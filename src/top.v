// SPDX-License-Identifier: MIT

// Instantiates and wires all modules.

`timescale 1ns / 1ps

module top (
        input wire       clk_50,
        input wire       reset_n,

        output wire [4:0] vga_r,
        output wire [5:0] vga_g,
        output wire [4:0] vga_b,
        output wire	  vga_hs,
        output wire	  vga_vs,

        inout		  usbdm,
        inout		  usbdp,

        output wire       i2s_bck,
        output wire       i2s_lrck,
        output wire       i2s_din,

        output [7:0]	  seg_data,
        output [5:0]	  scan_sig
    );

    localparam [2:0]	      VRAM = 3'b000;
    localparam [2:0]	      GMODE = 3'b001;
    localparam [2:0]	      PSG = 3'b010;
    localparam [2:0]	      SMODE = 3'b011;
    localparam [2:0]	      KBD = 3'b100;
    localparam [2:0]	      IPL = 3'b101;
    localparam [2:0]	      EXT1 = 3'b110;
    localparam [2:0]	      EXT2 = 3'b111;

    // VRAM IDs, as used in the text mode:
    // TG: (0000H ~ 07FFH) Stores text char code
    // AG: (0800H - 0FFFH) Stores text attribute
    // CG: (1000H - 17FFH) Stores char pattern data
    localparam [1:0]	      TG = 2'b00;
    localparam [1:0]	      AG = 2'b01;
    localparam [1:0]	      CG = 2'b10;

    // Clocks
    wire			      clk_25;
    wire			      clk_cpu;
    wire			      clk_vdg;
    wire			      clk_psg;
    wire			      clk_usb;
    wire			      clk_seg;
    wire			      pll_locked;

    // CPU signals
    wire [15:0]		      cpu_addr;
    wire [7:0]		      cpu_data, cpu_data_in;
    wire			      m1_n;
    wire			      refresh_n;
    wire			      int_n;
    wire			      reset = ~reset_n;
    wire			      reset_cpu = reset | ~pll_locked;
    wire			      reset_vdg = reset_cpu;

    wire			      mem_rd;
    wire			      mem_wr;
    wire			      mem_en, mem_en_n;
    wire			      cpu_wr, cpu_wr_n;
    wire			      cpu_rd, cpu_rd_n;

    // Main memory
    wire [15:0]		      ram_addr;
    wire [7:0]		      ram_byte;
    wire [7:0]		      ram_din;

    // IO decoding logic signals
    wire			      io_en;
    wire			      io_rd;
    wire			      io_wr;
    wire [7:0]		      io_byte, io_dev_byte;
    wire			      vram_rd;
    wire [7:0]	                      psg_dout;
    wire [7:0]		      smode_dout = 8'h00;

    // Local regs/wire for interrupt signal generation
    reg fs_n_r = 1'b1;
    reg [2:0] int_cnt = 3'b0;
    wire	     int_en = fs_n_r && !fs_n;

    // MC6847 VDG
    reg [4:0]		      gmode;
    wire			      mc_ag;
    wire			      mc_as;
    wire [2:0]		      mc_gm;
    wire			      mc_css;
    wire			      mc_inv;
    wire			      mc_ext;
    wire [3:0]		      mc_r;
    wire [3:0]		      mc_g;
    wire [3:0]		      mc_b;
    wire			      mc_hs;
    wire			      fs_n;
    wire [1:0]		      ps; // text page

    // VRAM signals on cpu side
    wire [2:0]		      io_dev;
    wire			      vram_en;
    wire [7:0]		      vram_byte;
    wire [1:0]		      vc_id;
    wire [12:0]		      vc_addr;
    wire [10:0]		      vc_addr_tg, vc_addr_ag, vc_addr_cg;
    wire [7:0]		      vc_din;
    wire [7:0]		      vc_din_tg, vc_din_ag, vc_din_cg;
    wire [7:0]		      vc_dout;
    wire [7:0]		      vc_dout_tg, vc_dout_ag, vc_dout_cg;

    // VRAM signals on VDG side
    reg			      clk_vdg_en = 0;
    wire [1:0]		      vg_id;
    wire [12:0]		      vg_addr;
    wire [10:0]		      vg_addr_tg, vg_addr_ag, vg_addr_cg;
    wire [7:0]		      vg_data;
    wire [7:0]		      vg_data_tg, vg_data_ag, vg_data_cg;
    wire [3:0]		      attr;

    wire [10:0]		      vaddr_page;
    wire [10:0]		      vaddr_char;

    // VDG ROM/VRAM access for char pattern data(internal/external)
    wire [2:0]		      char_sel;
    wire [7:0]		      int_char_d;
    wire [6:0]  int_code;
    wire	       is_ctrl;
    wire [3:0]  char_row;
    wire [11:0]		      char_a;
    wire [7:0]		      char_d;
    wire [8:0]		      packed_char_a;
    wire [7:0]		      packed_char_d;

    // Keyboard signals
    wire [7:0]		      key1, key2, key3, key4, modifiers;
    wire[79:0] key_port;
    wire [3:0] kbd_port_n;
    wire [7:0] kbd_data;

    // PSG
    wire	       ay_bdir;
    wire	       ay_bc1;
    wire [7:0]         ay_din, ay_dout;
    wire [9:0]	       ay_sout;
    reg [3:0]	       clk_psg_div;
    wire	       clk_psg_en;
    wire	       psg_en;

    // IPL
    // Reading from 32K ROM + Writing to 64K RAM upon start.
    reg                 iplk = 1'b0;

    // Segment display
    wire [23:0] seg_num = {key2[3:0], key2[7:4], key1[3:0], key1[7:4], modifiers[3:0], modifiers[7:4]};

    clocks clock_inst(
               .clk_in(clk_50),
               .clk_25(clk_25),
               .clk_12(clk_usb),
               .clk_4(clk_cpu),
               .RESET(reset),
               .LOCKED(pll_locked)
           );
    z80_top_direct_n cpu(
                         .nMREQ(mem_en_n),
                         .nIORQ(io_en_n),
                         .nWR(cpu_wr_n),
                         .nRD(cpu_rd_n),
                         .nINT(int_n),
                         .CLK(clk_cpu),
                         .A(cpu_addr),
                         .D(cpu_data),
                         .nM1(m1_n),
                         .nRFSH(refresh_n),
                         .nHALT(),
                         .nBUSRQ(1'b1),
                         .nBUSACK(),
                         .nWAIT(1'b1),
                         .nNMI(1'b1),
                         .nRESET(~reset_cpu));

    // Access RAM for both as we do not have ROM for now -
    // just use 15 bits of the address when reading from ROM.
    wire [15:0] mem_addr = iplk | mem_wr ? ram_addr : {1'b0, ram_addr[14:0]};

    sync_ram mem(
                 .clk(clk_cpu),
                 .we(mem_wr),
                 .addr(mem_addr),
                 .din(ram_din),
                 .dout(ram_byte));

    mc6847 vdg(
               .clk        (clk_vdg),
               .clk_ena    (clk_vdg_en),
               .reset      (reset_vdg),
               .da0        (),
               .hs_n       (mc_hs),
               .fs_n       (fs_n),
               .gm         (mc_gm),
               .css        (mc_css),
               .inv        (mc_inv),
               .intn_ext   (mc_ext),
               .an_g       (mc_ag),
               .an_s       (mc_as),
               .videoaddr  (vg_addr),
               .dd         (vg_data),

               // VGA Video Outputs
               .red        (mc_r),
               .green      (mc_g),
               .blue       (mc_b),
               .hsync      (vga_hs),
               .vsync      (vga_vs),
               .artifact_en(1'b0),
               .artifact_set(1'b0),
               .artifact_phase(1'b1),
               .black_backgnd(1'b1),
               .cvbs(),
               .char_a     (char_a),
               .char_d_o   (char_d),
               .hblank(),
               .vblank()
           );

    charrom vdg_rom (
                .clk(clk_vdg),
                .address(packed_char_a),
                .dout(packed_char_d));

    vram        vram_tg(.clk_a(clk_cpu),
                        .we_a(tg_wen),
                        .addr_a(vc_addr_tg),
                        .din_a(vc_din_tg),
                        .dout_a(vc_dout_tg),
                        .addr_b(vg_addr_tg),
                        .dout_b(vg_data_tg));

    vram        vram_ag(.clk_a(clk_cpu),
                        .we_a(ag_wen),
                        .addr_a(vc_addr_ag),
                        .din_a(vc_din_ag),
                        .dout_a(vc_dout_ag),
                        .addr_b(vg_addr_ag),
                        .dout_b(vg_data_ag));

    vram        vram_cg(.clk_a(clk_cpu),
                        .we_a(cg_wen),
                        .addr_a(vc_addr_cg),
                        .din_a(vc_din_cg),
                        .dout_a(vc_dout_cg),
                        .addr_b(vg_addr_cg),
                        .dout_b(vg_data_cg));

    usb_hid_host usb (.usbclk(clk_usb), .usbrst_n(reset_n),
                      .usb_dm(usbdm), .usb_dp(usbdp),
                      .typ(), .report(),
                      .key_modifiers(modifiers),
                      .key1(key1),
                      .key2(key2),
                      .key3(key3),
                      .key4(key4),
                      .mouse_btn(), .mouse_dx(), .mouse_dy(),
                      .game_l(), .game_r(), .game_u(), .game_d(),
                      .game_a(), .game_b(), .game_x(), .game_y(),
                      .game_sel(), .game_sta(),
                      .conerr(), .dbg_hid_report()
                     );

    key_matrix key_inst(
                   .clk(clk_cpu),
                   .key_modifiers(modifiers),
                   .key1(key1),
                   .key2(key2),
                   .key3(key3),
                   .key4(key4),
                   .port(key_port));

    smg_interface seg (.CLK( clk_seg ),
                  .RSTn( reset_n ),
                  .Number_Sig( seg_num ),
                  .SMG_Data( seg_data ),
                  .Scan_Sig( scan_sig )
                                       );

    jt49_bus psg (
        .rst_n(reset_n),
        .clk(clk_psg),
        .clk_en(clk_psg_en),
        .bdir(ay_bdir),
        .bc1(ay_bc1),
        .din(ay_din),
        .sel(1'b1),
        .dout(ay_dout),
        .sound(ay_sout),
        .A(),
        .B(),
        .C(),
        .sample(),
        .IOA_in(8'h00),
        .IOA_out(),
        .IOA_oe(),
        .IOB_in(8'h00),
        .IOB_out(),
        .IOB_oe()
    );

    i2s i2s_inst(
        .clk(clk_25),
        .clk_en(clk_psg_en),
        .rst_n(reset_n),
        .din(ay_sout),
        .i2s_bclk(i2s_bck),
        .i2s_lrclk(i2s_lrck),
        .i2s_sdata(i2s_din));

    // Clock enable VDG when CVBS out is enabled.
    always @(posedge clk_vdg)
    begin
        clk_vdg_en <= !clk_vdg_en;
    end

    // Generate interrupt signal (~2us negative pulse) from VDG FS
    always @(posedge clk_cpu)
    begin
        if (reset_cpu)
        begin
            fs_n_r <= 1'b1;
            int_cnt <= 3'd0;
        end
        else
        begin
            fs_n_r <= fs_n;
            if (int_en)
            begin
                int_cnt <= 3'd7;
            end
            else if (int_cnt > 0)
            begin
                int_cnt <= int_cnt - 3'd1;
            end
        end
    end
    assign int_n = (int_cnt == 0);

    // Update GMODE (page, ascii/graphic, graphics mode)
    always @(posedge clk_cpu)
    begin
        if (io_wr && gmode_en)
        begin
            gmode <= cpu_data[5:1];
        end
    end
    assign gmode_en = io_en && io_dev == GMODE;

    always @(posedge clk_psg or negedge reset_n) begin
        if (!reset_n) clk_psg_div <= 4'd0;
        else        clk_psg_div <= clk_psg_div + 1'b1;
    end
    assign clk_psg_en = (clk_psg_div == 4'd15); // 25MHz / 16 ~= 1.56MHz

    always @(posedge clk_cpu or negedge reset_n) begin
       if (!reset_n) iplk <= 1'b0;
       else if (io_dev == IPL) iplk <= 1'b1;
    end

    // Clock definitions
    assign clk_seg = clk_25;
    assign clk_vdg = clk_25;
    assign clk_psg = clk_25;

    // Main memory/IO decoding
    assign cpu_wr = ~cpu_wr_n;
    assign cpu_rd = ~cpu_rd_n;
    assign mem_en = ~mem_en_n;
    assign mem_rd = mem_en && cpu_rd;
    assign mem_wr = mem_en && cpu_wr;
    assign io_en = ~io_en_n;
    assign io_rd = io_en && cpu_rd;
    assign io_wr = io_en && cpu_wr;
    assign vc_id = vram_en ? cpu_addr[12:11] : 2'bz;
    assign io_dev = io_en ? cpu_addr[15:13] : 3'bz;
    assign vram_en = io_en && io_dev == VRAM;
    assign vram_wr = io_wr && vram_en;
    assign vram_rd = io_rd && vram_en;
    assign io_byte = io_rd ? io_dev_byte : 8'bz;
    assign io_dev_byte = io_rd && io_dev == VRAM ? vram_byte :
           io_rd && io_dev == GMODE ? 8'b0 :
           io_rd && io_dev == PSG ? psg_dout :
           io_rd && io_dev == SMODE ? smode_dout :
           io_rd && io_dev == KBD && kbd_port_n <= 4'd9 ? kbd_data : 8'bz;

    assign ram_din = mem_wr ? cpu_data : 8'bz;
    assign ram_addr = mem_en ? cpu_addr : 16'bz;
    assign cpu_data_in = mem_rd ? ram_byte :
           io_rd ? io_byte : 8'bz;
    assign cpu_data = cpu_rd ? cpu_data_in : 8'bz;

    // Wire CPU - VRAM
    assign vc_addr = vram_en ? cpu_addr[10:0] : 11'bz;
    assign vc_addr_tg = vram_en && vc_id == TG ? vc_addr : 11'bz;
    assign vc_addr_ag = vram_en && vc_id == AG ? vc_addr : 11'bz;
    assign vc_addr_cg = vram_en && vc_id == CG ? vc_addr : 11'bz;
    assign vc_din = vram_wr ? cpu_data : 8'bz;
    assign vc_din_tg = vc_id == TG ? vc_din : 8'bz;
    assign vc_din_ag = vc_id == AG ? vc_din : 8'bz;
    assign vc_din_cg = vc_id == CG ? vc_din : 8'bz;
    assign vram_byte = vram_rd && vc_id == TG ? vc_dout_tg :
           vram_rd && vc_id == AG ? vc_dout_ag :
           vram_rd && vc_id == CG ? vc_dout_cg : 8'bz;
    assign tg_wen = vram_wr && vc_id == TG;
    assign ag_wen = vram_wr && vc_id == AG;
    assign cg_wen = vram_wr && vc_id == CG;

    // VDG - VRAM. VRAMs should be split into 2K x 3 for VDG to fetch
    // text/attr in a single cycle. addr = page * 0x200 + vg_addr (AG, TG)
    assign vaddr_page = {ps, vg_addr[8:0] };
    assign vg_id = vg_addr[12:11];
    assign vg_data = vg_id == TG ? vg_data_tg :
           vg_id == AG ? vg_data_ag :
           vg_id == CG ? vg_data_cg : 8'b0;

    assign vg_addr_tg = mc_ag ? vg_addr[10:0] : vaddr_page;
    assign vg_addr_ag = mc_ag ? vg_addr[10:0] : vaddr_page;
    assign vg_addr_cg = mc_ag ? vg_addr[10:0] : vaddr_char;

    // VDG mode from GMODE
    assign mc_gm = {1'b1, gmode[1:0]}; // GM2 is fixed to 1
    assign mc_ag = gmode[2];
    assign ps = gmode[4:3];

    // Attribute from AG
    assign mc_inv = attr[0];
    assign mc_css = attr[1];
    assign mc_as = attr[2];
    assign mc_ext = attr[3];

    // VDG signals for fetching char pattern data from VRAM CG. Data for 80 ~ DFH
    // precedes 60 ~ 7FH. Add an offset 600H for the latter.
    assign char_sel = char_a[11:9];
    assign vaddr_char = char_sel == 3'b011 ? char_a[8:0] + 12'h600 : char_a[10:0];
    assign int_code = char_a[10:4];
    assign is_ctrl = int_code < 7'd32; // Control chars always return 0's.
    assign packed_char_a[8:3] = is_ctrl ? 6'h0 : int_code - 6'd32;
    assign char_row = char_a[3:0];

    // VDG ROM stores only 8 (not 12) bytes per each char pattern data (thus 'packed_')
    // since 3 and the last 1 row are always zero.
    assign packed_char_a[2:0] = char_row - 2'b11;
    assign int_char_d = (char_row < 3 || char_row > 10 || is_ctrl) ? 8'h00 : packed_char_d;
    assign char_d = mc_ext ? vg_data_cg : int_char_d;
    assign attr = vg_data_ag[3:0];

    // Video output
    assign vga_r = {mc_r, 1'b1};
    assign vga_g = {mc_g, 2'b11};
    assign vga_b = {mc_b, 1'b1};

    assign psg_en = io_en && io_dev == PSG;

    // The schematic wires A0 to BC2, but jt49_bus does not have BC2 (always 1).
    // The chip allows an alternative wiring using redundant pin combinations
    // for INACTIVE state.
    assign ay_din = psg_en ? cpu_data : 8'bz;
    assign ay_bdir = psg_en ? io_wr | ~cpu_addr[0] : 8'b0;
    assign ay_bc1 = psg_en ? io_rd | ~cpu_addr[0] : 8'b0;
    assign psg_dout = psg_en && io_rd ? ay_dout : 8'bz;

    // Keyboard ports are 8000H ~ 8009H
    assign kbd_port_n = cpu_addr[3:0];
    assign kbd_data = kbd_port_n == 4'd0 ? key_port[7:0] :
           kbd_port_n == 4'd1 ? key_port[15:8] :
           kbd_port_n == 4'd2 ? key_port[23:16] :
           kbd_port_n == 4'd3 ? key_port[31:24] :
           kbd_port_n == 4'd4 ? key_port[39:32] :
           kbd_port_n == 4'd5 ? key_port[47:40] :
           kbd_port_n == 4'd6 ? key_port[55:48] :
           kbd_port_n == 4'd7 ? key_port[63:56] :
           kbd_port_n == 4'd8 ? key_port[71:64] :
           kbd_port_n == 4'd9 ? key_port[79:72] : 8'bz;
endmodule

module i2s(
	   input wire	    clk,
	   input wire       clk_en,
	   input wire	    rst_n,
	   input wire [9:0] din,
	   output wire	    i2s_bclk,
	   output wire	    i2s_lrclk,
	   output wire	    i2s_sdata);

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

endmodule
