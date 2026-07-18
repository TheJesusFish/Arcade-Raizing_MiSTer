// This file is a Codex-assisted refactoring and update
// based on the original work of Pramod Somashekar (pram0d)

/*
* Shared Raizing 68K CPU/bus block.
*
* Derived from GPLv3+ Raizing/Batrider/Garegga CPU modules in this tree.
*
* Copyright (c) 2022 Pramod Somashekar
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*/
module raizing_main_cpu #(
    parameter SS_ENABLE = 0
)(
    input CLK,
    input CLK96,
    input RESET96,
    input RESET,
    input [7:0] GAME_ID,
    input GP9001ACK,
    input VINT,
    input BR,
    input [8:0] V,
    output BUSACK,
    input LVBL,
    input FLIP,

    output [19:1] ADDR,
    output [15:0] DOUT,
    output RW,
    output RD,
    output LDS,
    output LDSWR,
    output GP9001CS,
    output LTABLECS,
    output VCOUNTCS,
    output Z80RST,
    output M68K_RESET_N,
    output CEN16,
    output CEN16B,

    // cabinet I/O
    input [1:0]  JOYMODE,
    input [9:0]  JOYSTICK1,
    input [9:0]  JOYSTICK2,
    input [3:0]  START_BUTTON,
    input [3:0]  COIN_INPUT,
    input        SERVICE,
    input        TILT,

    // DIP switches
    input        DIP_TEST,
    input        DIP_PAUSE,
    input [7:0]  DIPSW_A,
    input [7:0]  DIPSW_B,
    input [7:0]  DIPSW_C,

    // 68k ROM interface
    output            CPU_PRG_CS,
    input             CPU_PRG_OK,
    output reg [19:0] CPU_PRG_ADDR,
    input      [15:0] CPU_PRG_DATA,

    // 68k-visible Z80 ROM window, used by Batrider/Bakraid
    output            Z80_PRG_CS,
    input             Z80_PRG_OK,
    output reg [17:0] Z80_PRG_ADDR,
    input      [7:0]  Z80_PRG_DATA,

    // Batrider/Bakraid text DMA RAM interface
    input         DMA_RAM_CS,
    output [15:0] DMA_RAM_DOUT,
    input  [13:0] DMA_RAM_ADDR,
    output reg    BATRIDER_TEXTDATA_DMA_W,
    output reg    BATRIDER_PAL_TEXT_DMA_W,
    input         TVRAMCTL_BUSY,
    output        TVRAM_CS,
    output        TVRAM_WE,
    output [1:0]  TVRAM_DS,
    output [13:0] TVRAM_WR_ADDR,
    output [15:0] TVRAM_DIN,

    // GP9001/GCU interface
    output reg       GP9001_OP_SELECT_REG,
    output reg       GP9001_OP_WRITE_REG,
    output reg       GP9001_OP_WRITE_RAM,
    output reg       GP9001_OP_READ_RAM_H,
    output reg       GP9001_OP_READ_RAM_L,
    output reg       GP9001_OP_SET_RAM_PTR,
    output reg       GP9001_OP_OBJECTBANK_WR,
    output reg [2:0] GP9001_OBJECTBANK_SLOT,
    input     [15:0] GP9001_DOUT,
    input            HSYNC,
    input            VSYNC,
    input            FBLANK,

    // Garegga-family direct text/palette RAM read ports
    input  [11:0] TEXTVRAM_ADDR,
    output [15:0] TEXTVRAM_DATA,
    input  [10:0] PALRAM_ADDR,
    output [15:0] PALRAM_DATA,
    input   [7:0] TEXTSELECT_ADDR,
    output [15:0] TEXTSELECT_DATA,
    input   [7:0] TEXTSCROLL_ADDR,
    output [15:0] TEXTSCROLL_DATA,

    // Garegga-family shared sound RAM and interrupt path
    output reg [7:0] GAREGGA_SOUNDLATCH,
    input  [13:0] GAREGGA_SRAM_ADDR,
    output  [7:0] GAREGGA_SRAM_DATA,
    input   [7:0] GAREGGA_SRAM_DIN,
    input         GAREGGA_SRAM_WE,
    output reg    GAREGGA_Z80INT,
    output reg    OKI_BANK,

    // Batrider/Bakraid sound command path
    input  [7:0] SOUNDLATCH3,
    input  [7:0] SOUNDLATCH4,
    output reg [7:0] SOUNDLATCH,
    output reg [7:0] SOUNDLATCH2,
    input            Z80WAIT,
    output           Z80CS,
    output           NMI,
    input            SNDIRQ,
    output reg [1:0] SOUNDLATCH_ACK,
    input      [1:0] SOUNDLATCH_ACK_INCOMING,

    // Hiscore interface. Garegga uses ADDR[6:0], Batrider uses ADDR[8:0].
    output          HISCORE_CS,
    output   [1:0] HISCORE_WE,
    output  [15:0] HISCORE_DIN,
    input   [15:0] HISCORE_DOUT,
    output   [8:0] HISCORE_ADDR,

    // Bakraid EEPROM interface
    output reg EEPROM_SCLK,
    output reg EEPROM_SDI,
    input      EEPROM_SDO,
    output reg EEPROM_SCS,

    input         SS_FREEZE,
    input         SS_SAVE_BEGIN,
    input         SS_SAVE_RESUME,
    input         SS_RESTORE_BEGIN,
    input         SS_RESTORE_WINDOW,
    output        SS_SAVE_READY,
    output        SS_SAVE_DONE,
    output        SS_RESTORE_DONE,
    output        SS_BUSY,
    output        SS_CPU_IDLE,
    input  [63:0] SS_DATA,
    input  [31:0] SS_ADDR,
    input   [7:0] SS_SELECT,
    input         SS_WRITE,
    input         SS_READ,
    input         SS_QUERY,
    output [63:0] SS_DATA_OUT,
    output        SS_ACK
);

localparam [7:0] RAIZING_GAREGGA  = 8'h00;
localparam [7:0] RAIZING_SSTRIKER = 8'h01;
localparam [7:0] RAIZING_KINGDMGP = 8'h02;
localparam [7:0] RAIZING_BATRIDER = 8'h03;
localparam [7:0] RAIZING_BAKRAID  = 8'h04;

wire is_garegga_family = GAME_ID == RAIZING_GAREGGA ||
                         GAME_ID == RAIZING_SSTRIKER ||
                         GAME_ID == RAIZING_KINGDMGP;
wire is_bakraid  = GAME_ID == RAIZING_BAKRAID;
wire is_battle   = GAME_ID == RAIZING_BATRIDER || is_bakraid;

wire [3:0] start_button_live = START_BUTTON;
wire [3:0] coin_input_live   = COIN_INPUT;

// Board-derived 68K cadence: 94.5 MHz * 32 / 189 = 16.000 MHz.
localparam [6:0] RAIZING_CPU_CEN_NUM = 7'd32;
localparam [7:0] RAIZING_CPU_CEN_DEN = 8'd189;

// Address bus
wire [23:1] A;
wire BUSn, UDSn, LDSn, ASn, LDSWn, UDSWn;
wire BRn, BGACKn, BGn, DTACKn;
wire FC0, FC1, FC2;
wire int1, int2;
wire [23:0] addr_8 = {A[23:1], 1'b0};
wire [23:0] addr_8_plus = {A[23:1], UDSn && !LDSn};
wire [15:0] cpu_dout;
reg  [15:0] cpu_din;
reg nmi_r;
reg text_rom_unpacked = 1'b0;
wire cpu_phi1_raw;
wire cpu_phi2_raw;
wire cpu_phi1;
wire cpu_phi2;
reg cpu_expect_phi1;
wire ss_cpu_run;
wire ss_cpu_reset;
wire ss_block_writes;
wire ss_irq_level7;
wire ss_override_valid;
wire [15:0] ss_override_data;
wire ss_active_freeze = SS_ENABLE && SS_FREEZE;
wire ss_write_blocked = SS_ENABLE && ss_block_writes;
wire cpu_write_ok = !RW && !ss_write_blocked;
wire [31:0] ss_saved_ssp;
wire [31:0] ss_restore_ssp;
wire [7:0] ss_control0_capture;
wire [63:0] ss_control1_capture;
wire [31:0] ss_control2_capture;
wire [7:0] ss_control0_restore;
wire [63:0] ss_control1_restore;
wire [31:0] ss_control2_restore;
wire ss_control0_restore_we;
wire ss_control1_restore_we;
wire ss_control2_restore_we;
wire [5:0] ss_irq_state;
wire [1:0] ss_snd_irq_state;
wire ss_ram_active;
wire [14:0] ss_ram_addr;
wire [15:0] ss_ram_data;
wire ss_ram_we;
wire [15:0] ss_ram_q;
wire ss_garegga_ram_active;
wire [13:0] ss_garegga_ram_addr;
wire [7:0] ss_garegga_ram_data;
wire ss_garegga_ram_we;
wire [7:0] ss_garegga_ram_q;
wire [7:0] ss_garegga_select = is_garegga_family ? SS_SELECT : 8'hff;
wire ss_palram_active;
wire [10:0] ss_palram_addr;
wire [15:0] ss_palram_data;
wire ss_palram_we;
wire [15:0] ss_palram_q;
wire ss_txvram_active;
wire [11:0] ss_txvram_addr;
wire [15:0] ss_txvram_data;
wire ss_txvram_we;
wire [15:0] ss_txvram_q;
wire ss_txselect_active;
wire [10:0] ss_txselect_addr;
wire [15:0] ss_txselect_data;
wire ss_txselect_we;
wire [15:0] ss_txselect_q;
wire ss_txscroll_active;
wire [10:0] ss_txscroll_addr;
wire [15:0] ss_txscroll_data;
wire ss_txscroll_we;
wire [15:0] ss_txscroll_q;
wire ss_txram_active;
wire [10:0] ss_txram_addr;
wire [15:0] ss_txram_data;
wire ss_txram_we;
wire [15:0] ss_txram_q;
wire ss_ram2_active;
wire [9:0] ss_ram2_addr;
wire [15:0] ss_ram2_data;
wire ss_ram2_we;
wire [15:0] ss_ram2_q;

wire ss_cpu_clock_open = !ss_active_freeze || ss_cpu_run;
assign cpu_phi1 = cpu_phi1_raw && ss_cpu_clock_open &&
                  (!SS_ENABLE || cpu_expect_phi1);
assign cpu_phi2 = cpu_phi2_raw && ss_cpu_clock_open &&
                  (!SS_ENABLE || !cpu_expect_phi1);
assign SS_CPU_IDLE = !SS_ENABLE ||
                     (ASn && BGACKn && !cpu_phi1 && !cpu_phi2);

always @(posedge CLK96 or posedge RESET96) begin
    if(RESET96) begin
        cpu_expect_phi1 <= 1'b0;
    end else if(cpu_phi1) begin
        cpu_expect_phi1 <= 1'b0;
    end else if(cpu_phi2) begin
        cpu_expect_phi1 <= 1'b1;
    end
end

// Registered family bus selects feed the shared 68K bus.
reg pre_sel_rom, pre_sel_local_ram, pre_sel_zrom;
reg pre_sel_sram, pre_sel_palram, pre_sel_txvram, pre_sel_txlineselect, pre_sel_txlinescroll, pre_sel_txram, pre_sel_ram2;
reg reg_sel_rom;
reg sel_gp9001, sel_io, sel_z80, sel_hiscore;
reg dsn_dly;

wire sel_rom            = ~BUSn & (dsn_dly ? reg_sel_rom       : pre_sel_rom);
wire sel_local_ram      = pre_sel_local_ram;
wire sel_zrom           = pre_sel_zrom;
wire sel_sram           = pre_sel_sram;
wire sel_palram         = pre_sel_palram;
wire sel_txvram         = pre_sel_txvram;
wire sel_txlineselect   = pre_sel_txlineselect;
wire sel_txlinescroll   = pre_sel_txlinescroll;
wire sel_txram          = pre_sel_txram;
wire sel_ram2           = pre_sel_ram2;
wire ram_ok             = 1'b1;

wire cpu_prg_ok = CPU_PRG_OK;
wire [15:0] cpu_prg_data = CPU_PRG_DATA;

assign CPU_PRG_CS = sel_rom && !ss_override_valid;
assign Z80_PRG_CS = is_battle && sel_zrom && !ss_override_valid;
assign ADDR[19:1] = A[19:1];
assign DOUT       = cpu_dout;
assign GP9001CS   = sel_gp9001 && !ss_override_valid;
assign RD         = RW;
assign LTABLECS   = 1'b0;
assign VCOUNTCS   = 1'b0;
assign Z80RST     = 1'b0;

assign LDS   = LDSn;
assign LDSWR = LDSWn;
assign BUSn  = ASn | (UDSn & LDSn);
assign UDSWn = RW | UDSn | ss_write_blocked;
assign LDSWn = RW | LDSn | ss_write_blocked;
assign TVRAM_DS = {~UDSn, ~LDSn};

always @(posedge CLK96 or posedge RESET96) begin
    if(RESET96) begin
        reg_sel_rom       <= 1'b0;
        dsn_dly           <= 1'b1;
    end else if(CEN16) begin
        reg_sel_rom       <= pre_sel_rom;
        dsn_dly           <= &{UDSWn, LDSWn};
    end
end

wire cpu_space_cycle = FC0 & FC1 & FC2;
wire cpu_addr_space = !cpu_space_cycle;
wire cpu_mem_cycle = !ASn && BGACKn && (GAME_ID != RAIZING_SSTRIKER || cpu_addr_space);
wire VPAn = ~&{FC0, FC1, FC2, ~ASn};

wire soundlatch_w_live = !ASn && BGACKn && !RW && !LDSn &&
                         !ss_write_blocked &&
                         addr_8[23:20] == 4'b0101 &&
                         ((GAME_ID == RAIZING_BATRIDER && addr_8[7:0] == 8'h20) ||
                          (is_bakraid                 && addr_8[7:0] == 8'h14));
wire soundlatch2_w_live = !ASn && BGACKn && !RW && !LDSn &&
                          !ss_write_blocked &&
                          addr_8[23:20] == 4'b0101 &&
                          ((GAME_ID == RAIZING_BATRIDER && addr_8[7:0] == 8'h22) ||
                           (is_bakraid                 && addr_8[7:0] == 8'h16));
wire garegga_soundlatch_w = is_garegga_family &&
                            addr_8[23:20] == 4'b0110 && cpu_write_ok;

// I/O chip selects
reg gp9001_vdp_device_r_cs, gp9001_vdp_device_w_cs;
reg read_port_in1_r_cs, read_port_in2_r_cs, read_port_sys_r_cs, read_port_dswa_r_cs;
reg read_port_dswb_r_cs, read_port_jmpr_r_cs, toaplan2_coinword_w_cs, video_count_r_cs;
reg read_port_in_r_cs, read_port_sys_dsw_r_cs, read_port_dsw_r_cs;
reg soundlatch3_r_cs, soundlatch4_r_cs, batrider_z80_busack_r_cs;
reg batrider_unk_sound_w_cs;
reg batrider_clr_sndirq_w_cs, batrider_z80_busreq_w, batrider_textdata_dma_w_cs;
reg batrider_unk_dma_w, batrider_objectbank_w_cs, bakraid_eeprom_r, bakraid_eeprom_w;

wire g_hiscore_hit = GAME_ID == RAIZING_GAREGGA && addr_8 >= 24'h10CA4C && addr_8 < (24'h10CA4C + 24'h0000EC);
wire b_hiscore_hit = GAME_ID == RAIZING_BATRIDER && addr_8 >= 24'h20FA20 && addr_8 < 24'h20FD30;
wire [23:0] g_hiscore_off = addr_8 - 24'h10CA4C;
wire [23:0] b_hiscore_off = addr_8 - 24'h20FA20;
assign HISCORE_ADDR = is_garegga_family ? {2'b00, g_hiscore_off[7:1]} : b_hiscore_off[9:1];
assign HISCORE_CS   = sel_hiscore && !ss_override_valid;
assign HISCORE_DIN  = cpu_dout;

wire g_hiscore_init_end = GAME_ID == RAIZING_GAREGGA && addr_8_plus == 24'h10CB36 && cpu_dout[15:8] == 8'h2A;
wire b_hiscore_init_end = addr_8 == 24'h20FD2E && UDSn && !LDSn && cpu_dout[7:0] == 8'h30;
reg g_hiscore_init = 1'b0;
reg b_hiscore_init = 1'b0;
reg last_g_hiscore_init_end = 1'b0;
reg last_b_hiscore_init_end = 1'b0;
wire hiscore_init = is_garegga_family ? g_hiscore_init : b_hiscore_init;
assign HISCORE_WE = {
    sel_hiscore && cpu_write_ok && !UDSn,
    sel_hiscore && cpu_write_ok && !LDSn
} & {2{hiscore_init}};

always @(posedge CLK96 or posedge RESET96) begin
    if(RESET96) begin
        pre_sel_rom          <= 1'b0;
        pre_sel_local_ram    <= 1'b0;
        pre_sel_zrom         <= 1'b0;
        pre_sel_sram         <= 1'b0;
        pre_sel_palram       <= 1'b0;
        pre_sel_txvram       <= 1'b0;
        pre_sel_txlineselect <= 1'b0;
        pre_sel_txlinescroll <= 1'b0;
        pre_sel_txram        <= 1'b0;
        pre_sel_ram2         <= 1'b0;
        sel_gp9001           <= 1'b0;
        sel_io               <= 1'b0;
        sel_z80              <= 1'b0;
        sel_hiscore          <= 1'b0;
        CPU_PRG_ADDR         <= 20'd0;
        Z80_PRG_ADDR         <= 18'd0;
        last_g_hiscore_init_end <= 1'b0;
        last_b_hiscore_init_end <= 1'b0;
        g_hiscore_init       <= 1'b0;
        b_hiscore_init       <= 1'b0;
        nmi_r                <= 1'b0;
    end else if(ss_active_freeze && !ss_cpu_run) begin
        pre_sel_rom          <= 1'b0;
        pre_sel_local_ram    <= 1'b0;
        pre_sel_zrom         <= 1'b0;
        pre_sel_sram         <= 1'b0;
        pre_sel_palram       <= 1'b0;
        pre_sel_txvram       <= 1'b0;
        pre_sel_txlineselect <= 1'b0;
        pre_sel_txlinescroll <= 1'b0;
        pre_sel_txram        <= 1'b0;
        pre_sel_ram2         <= 1'b0;
        sel_gp9001           <= 1'b0;
        sel_io               <= 1'b0;
        sel_z80              <= 1'b0;
        sel_hiscore          <= 1'b0;

        if(ss_control0_restore_we) begin
            nmi_r <= ss_control0_restore[0];
            g_hiscore_init <= ss_control0_restore[1];
            b_hiscore_init <= ss_control0_restore[2];
            last_g_hiscore_init_end <= ss_control0_restore[3];
            last_b_hiscore_init_end <= ss_control0_restore[4];
        end
    end else begin
        if(cpu_mem_cycle) begin
            last_g_hiscore_init_end <= g_hiscore_init_end;
            last_b_hiscore_init_end <= b_hiscore_init_end;

            if(is_garegga_family) begin
                pre_sel_rom       <= GAME_ID == RAIZING_SSTRIKER ? addr_8 <= 24'h07FFFF : addr_8 <= 24'h0FFFFF;
                CPU_PRG_ADDR      <= {1'b0, A[19:1]};
                pre_sel_local_ram <= addr_8[23:16] == 8'h10;
                pre_sel_zrom      <= 1'b0;
                Z80_PRG_ADDR      <= 18'd0;

                pre_sel_sram         <= addr_8[23:14] == 10'b0010_0001_10;
                pre_sel_palram       <= GAME_ID == RAIZING_SSTRIKER ? (addr_8 >= 24'h400000 && addr_8 <= 24'h400FFF) :
                                                                    addr_8[23:20] == 4'b0100;
                pre_sel_txvram       <= addr_8 >= 24'h500000 && addr_8 <= 24'h501FFF;
                pre_sel_txlineselect <= addr_8 >= 24'h502000 && addr_8 <= 24'h502FFF;
                pre_sel_txlinescroll <= addr_8 >= 24'h503000 && addr_8 <= 24'h5031FF;
                pre_sel_txram        <= addr_8 >= 24'h503200 && addr_8 <= 24'h503FFF;
                pre_sel_ram2         <= GAME_ID == RAIZING_SSTRIKER ? (addr_8 >= 24'h401000 && addr_8 <= 24'h4017FF) :
                                                                    addr_8[23:12] == 12'b0100_0000_0001;
                sel_gp9001           <= GAME_ID == RAIZING_SSTRIKER ? (addr_8[23:4] == 20'h30000) :
                                                                    addr_8[23:20] == 4'b0011;
                sel_io               <= addr_8[23:12] == 12'b0010_0001_1100;
                sel_z80              <= garegga_soundlatch_w;
                sel_hiscore          <= g_hiscore_hit;
                if(!g_hiscore_init && !g_hiscore_init_end && last_g_hiscore_init_end)
                    g_hiscore_init <= 1'b1;
            end else begin
                pre_sel_rom          <= addr_8[23:21] == 3'b000;
                CPU_PRG_ADDR         <= A[20:1];
                pre_sel_local_ram    <= addr_8[23:15] == 9'b0010_0000_0 || addr_8[23:15] == 9'b0010_0000_1;
                pre_sel_zrom         <= addr_8[23:20] == 4'b0011;
                Z80_PRG_ADDR         <= addr_8[18:1];
                pre_sel_sram         <= 1'b0;
                pre_sel_palram       <= 1'b0;
                pre_sel_txvram       <= 1'b0;
                pre_sel_txlineselect <= 1'b0;
                pre_sel_txlinescroll <= 1'b0;
                pre_sel_txram        <= 1'b0;
                pre_sel_ram2         <= 1'b0;
                sel_gp9001           <= addr_8[23:20] == 4'b0100;
                sel_io               <= addr_8[23:20] == 4'b0101;
                sel_hiscore          <= b_hiscore_hit;
                if(GAME_ID == RAIZING_BATRIDER && !b_hiscore_init && !b_hiscore_init_end && last_b_hiscore_init_end)
                    b_hiscore_init <= 1'b1;

                if(GAME_ID == RAIZING_BATRIDER)
                    sel_z80 <= soundlatch2_w_live || (soundlatch_w_live && cpu_dout[7:0] == 8'h55);
                else
                    sel_z80 <= 1'b0;
            end
        end else begin
            pre_sel_rom          <= 1'b0;
            pre_sel_local_ram    <= 1'b0;
            pre_sel_zrom         <= 1'b0;
            pre_sel_sram         <= 1'b0;
            pre_sel_palram       <= 1'b0;
            pre_sel_txvram       <= 1'b0;
            pre_sel_txlineselect <= 1'b0;
            pre_sel_txlinescroll <= 1'b0;
            pre_sel_txram        <= 1'b0;
            pre_sel_ram2         <= 1'b0;
            sel_gp9001           <= 1'b0;
            sel_io               <= 1'b0;
            sel_z80              <= 1'b0;
            sel_hiscore          <= 1'b0;
            nmi_r                <= 1'b0;
        end
    end
end

always @(*) begin
    gp9001_vdp_device_r_cs = sel_gp9001 && RW;
    gp9001_vdp_device_w_cs = sel_gp9001 && cpu_write_ok;

    read_port_in1_r_cs = is_garegga_family && sel_io && addr_8[11:0] == 12'h020 && RW;
    read_port_in2_r_cs = is_garegga_family && sel_io && addr_8[11:0] == 12'h024 && RW;
    read_port_sys_r_cs = is_garegga_family && sel_io && addr_8[11:0] == 12'h028 && RW;
    read_port_dswa_r_cs = is_garegga_family && sel_io && addr_8[11:0] == 12'h02C && RW;
    read_port_dswb_r_cs = is_garegga_family && sel_io && addr_8[11:0] == 12'h030 && RW;
    read_port_jmpr_r_cs = is_garegga_family && sel_io && addr_8[11:0] == 12'h034 && RW;
    video_count_r_cs = is_garegga_family ?
        (sel_io && addr_8[11:0] == 12'h03C && RW) :
        (sel_io && addr_8[7:0] == 8'h06);
    toaplan2_coinword_w_cs = is_garegga_family ?
        (sel_io && addr_8[11:0] == 12'h01C && cpu_write_ok) :
        (sel_io && cpu_write_ok &&
         (is_bakraid ? addr_8[7:0] == 8'h08 : addr_8[7:0] == 8'h10));

    read_port_in_r_cs = is_battle && sel_io && addr_8[7:0] == 8'h00;
    read_port_sys_dsw_r_cs = is_battle && sel_io && addr_8[7:0] == 8'h02;
    read_port_dsw_r_cs = is_battle && sel_io && addr_8[7:0] == 8'h04;
    soundlatch3_r_cs = is_battle && sel_io && (is_bakraid ? addr_8[7:0] == 8'h10 : addr_8[7:0] == 8'h08);
    soundlatch4_r_cs = is_battle && sel_io && (is_bakraid ? addr_8[7:0] == 8'h12 : addr_8[7:0] == 8'h0A);
    batrider_z80_busack_r_cs = GAME_ID == RAIZING_BATRIDER && sel_io && addr_8[7:0] == 8'h0C;
    bakraid_eeprom_r = is_bakraid && sel_io && addr_8[7:0] == 8'h18 && RW;
    batrider_unk_sound_w_cs = is_battle && sel_io && cpu_write_ok &&
                              (is_bakraid ? addr_8[7:0] == 8'h1A : addr_8[7:0] == 8'h24);
    batrider_clr_sndirq_w_cs = is_battle && sel_io && cpu_write_ok &&
                               (is_bakraid ? addr_8[7:0] == 8'h1C : addr_8[7:0] == 8'h26);
    bakraid_eeprom_w = is_bakraid && sel_io &&
                       addr_8[7:0] == 8'h1E && cpu_write_ok;
    batrider_z80_busreq_w = GAME_ID == RAIZING_BATRIDER && sel_io &&
                            addr_8[7:0] == 8'h60 && cpu_write_ok;
    batrider_textdata_dma_w_cs = is_battle && sel_io &&
                                 addr_8[7:0] == 8'h80 && cpu_write_ok;
    batrider_unk_dma_w = is_battle && sel_io &&
                         addr_8[7:0] == 8'h82 && cpu_write_ok;
    batrider_objectbank_w_cs = is_battle && sel_io &&
                               addr_8[7:4] == 4'hC && cpu_write_ok;
end

reg [15:0] z80_bus_request;
reg [3:0] sound_nmi_pulse;
reg [3:0] sound_ack_pulse;
reg       sound_ack_wr_d;
reg [7:0] soundlatch_live;

assign ss_control0_capture = {
    GAREGGA_Z80INT,
    OKI_BANK,
    text_rom_unpacked,
    last_b_hiscore_init_end,
    last_g_hiscore_init_end,
    b_hiscore_init,
    g_hiscore_init,
    nmi_r
};

assign ss_control1_capture = {
    BATRIDER_PAL_TEXT_DMA_W,
    BATRIDER_TEXTDATA_DMA_W,
    EEPROM_SDI,
    EEPROM_SCS,
    EEPROM_SCLK,
    sound_ack_wr_d,
    SOUNDLATCH_ACK,
    sound_ack_pulse,
    sound_nmi_pulse,
    z80_bus_request,
    soundlatch_live,
    GAREGGA_SOUNDLATCH,
    SOUNDLATCH2,
    SOUNDLATCH
};

assign ss_control2_capture = {
    13'd0,
    GP9001_OBJECTBANK_SLOT,
    GP9001_OP_OBJECTBANK_WR,
    GP9001_OP_SET_RAM_PTR,
    GP9001_OP_READ_RAM_L,
    GP9001_OP_READ_RAM_H,
    GP9001_OP_WRITE_RAM,
    GP9001_OP_WRITE_REG,
    GP9001_OP_SELECT_REG,
    sound_ack_wr_d,
    ss_snd_irq_state,
    ss_irq_state
};

wire sound_ack_wr = is_bakraid && batrider_unk_sound_w_cs;
wire sound_ack_edge = sound_ack_wr && !sound_ack_wr_d;
wire bakraid_z80_cs = sound_ack_wr || (|sound_ack_pulse);
wire active_z80_cs = is_bakraid ? bakraid_z80_cs : sel_z80;
assign Z80CS = is_battle ? active_z80_cs : 1'b0;
assign NMI = is_bakraid ? (|sound_nmi_pulse) : nmi_r;

wire bus_cs = ss_override_valid || |{pre_sel_rom, pre_sel_local_ram, pre_sel_zrom, pre_sel_sram, pre_sel_palram,
                pre_sel_txvram, pre_sel_txlineselect, pre_sel_txlinescroll, pre_sel_txram, pre_sel_ram2,
                sel_gp9001, sel_io, active_z80_cs};
wire bus_busy = !ss_override_valid &&
                 |{sel_local_ram & ~ram_ok, sel_sram & ~ram_ok, sel_palram & ~ram_ok,
                   sel_txvram & ~ram_ok, sel_txlineselect & ~ram_ok, sel_txlinescroll & ~ram_ok,
                   sel_txram & ~ram_ok, sel_ram2 & ~ram_ok, sel_rom & ~cpu_prg_ok, sel_zrom & ~Z80_PRG_OK,
                   sel_gp9001 & ~GP9001ACK, active_z80_cs & Z80WAIT};

localparam [3:0] SOUND_NMI_PULSE_LEN = 4'd8;
localparam [3:0] SOUND_ACK_PULSE_LEN = 4'd8;

wire [9:0] gp9001_vstatus_sum = {1'b0, V} + 10'd15;
wire [9:0] gp9001_vstatus_v = gp9001_vstatus_sum >= 10'd262 ? gp9001_vstatus_sum - 10'd262 :
                                                                    gp9001_vstatus_sum;
wire [8:0] video_count_v = GAME_ID == RAIZING_GAREGGA ? gp9001_vstatus_v[8:0] : V;
wire [15:0] video_status_hs = (16'hFF00 & (!HSYNC ? ~16'h8000 : 16'hFFFF));
wire [15:0] video_status_vs = (16'hFF00 & (!VSYNC ? ~16'h4000 : 16'hFFFF));
wire [15:0] video_status_fb = (16'hFF00 & (!FBLANK ? ~16'h0100 : 16'hFFFF));
wire [15:0] video_status = video_count_v < 9'd256 ? (video_status_hs & video_status_vs & video_status_fb) | {8'h00, video_count_v[7:0]} :
                                                   (video_status_hs & video_status_vs & video_status_fb) | 16'h00FF;
wire gp9001_irq_status_r = (GAME_ID == RAIZING_KINGDMGP || GAME_ID == RAIZING_SSTRIKER) &&
                           gp9001_vdp_device_r_cs && addr_8[3:0] == 4'hC;
wire gp9001_vdp_status_bit = gp9001_vstatus_v >= 10'd245;
wire gp9001_status_bit = gp9001_vdp_status_bit;

wire [7:0] p1_ctrl = {1'b0, ~JOYSTICK1[6], ~JOYSTICK1[5], ~JOYSTICK1[4], ~JOYSTICK1[0], ~JOYSTICK1[1], ~JOYSTICK1[2], ~JOYSTICK1[3]};
wire [7:0] p2_ctrl = {1'b0, ~JOYSTICK2[6], ~JOYSTICK2[5], ~JOYSTICK2[4], ~JOYSTICK2[0], ~JOYSTICK2[1], ~JOYSTICK2[2], ~JOYSTICK2[3]};

wire [15:0] local_ram_q0;
wire [15:0] local_ram_dma_q;
wire [7:0]  main_sram_q0;
wire [15:0] main_palram_q0;
wire [15:0] main_txvram_q0;
wire [15:0] main_txlineselect_q0;
wire [15:0] main_txlinescroll_q0;
wire [15:0] main_txram_q0;
wire [15:0] main_ram2_q0;
wire [15:0] wram_cpu_data = !RW && (sel_local_ram || sel_sram || sel_palram || sel_txvram ||
                                    sel_txlineselect || sel_txlinescroll || sel_txram || sel_ram2) ? cpu_dout : 16'h0000;

always @(posedge CLK96) begin
    if(RESET96) begin
        cpu_din <= 16'h0000;
    end else begin
        cpu_din <= ss_override_valid ? ss_override_data :
                   gp9001_irq_status_r ? {15'b0, gp9001_status_bit} :
                   sel_gp9001 && RW ? GP9001_DOUT :
                   sel_rom ? cpu_prg_data :
                   sel_hiscore && hiscore_init ? HISCORE_DOUT :
                   sel_local_ram ? local_ram_q0 :
                   is_garegga_family && sel_sram ? (GAME_ID == RAIZING_GAREGGA ? {8'h00, main_sram_q0} : {2{main_sram_q0}}) :
                   is_garegga_family && sel_palram ? main_palram_q0 :
                   is_garegga_family && sel_txvram ? main_txvram_q0 :
                   is_garegga_family && sel_txlineselect ? main_txlineselect_q0 :
                   is_garegga_family && sel_txlinescroll ? main_txlinescroll_q0 :
                   is_garegga_family && sel_txram ? main_txram_q0 :
                   is_garegga_family && sel_ram2 ? main_ram2_q0 :
                   is_battle && sel_zrom ? {8'h00, Z80_PRG_DATA} :
                   read_port_in1_r_cs ? {2{p1_ctrl}} :
                   read_port_in2_r_cs ? {2{p2_ctrl}} :
                   read_port_sys_r_cs ? {DIPSW_C, 1'b0, ~start_button_live[1], ~start_button_live[0], ~coin_input_live[1], ~coin_input_live[0], ~DIP_TEST, 1'b0, ~SERVICE} :
                   read_port_dswa_r_cs ? {2{DIPSW_A}} :
                   read_port_dswb_r_cs ? {2{DIPSW_B}} :
                   read_port_jmpr_r_cs ? {2{DIPSW_C}} :
                   read_port_in_r_cs ? {p2_ctrl, p1_ctrl} :
                   read_port_sys_dsw_r_cs ? {DIPSW_C, 1'b0, ~start_button_live[1], ~start_button_live[0], ~coin_input_live[1], ~coin_input_live[0], ~DIP_TEST, 1'b0, ~SERVICE} :
                   read_port_dsw_r_cs ? {DIPSW_B, DIPSW_A} :
                   video_count_r_cs ? video_status :
                   soundlatch3_r_cs ? {8'h00, SOUNDLATCH3} :
                   soundlatch4_r_cs ? {8'h00, SOUNDLATCH4} :
                   batrider_z80_busack_r_cs ? z80_bus_request :
                   bakraid_eeprom_r ? {11'h000, EEPROM_SDO, 3'b000, z80_bus_request[0]} :
                   toaplan2_coinword_w_cs ? 16'h0000 :
                   16'h0000;
    end
end

wire inta_n = ~&{FC0, FC1, FC2, ~ASn};
wire snd_irq_ack;

raizing_ss_edge_ff u_nmi_ff(
    .clk           (CLK96),
    .reset         (RESET96),
    .hold          (ss_active_freeze),
    .cen           (1'b1),
    .din           (1'b1),
    .q             (snd_irq_ack),
    .qn            (),
    .set           (1'b0),
    .clr           (batrider_clr_sndirq_w_cs),
    .sigedge       (SNDIRQ),
    .restore_we    (SS_ENABLE && ss_control2_restore_we),
    .restore_state (ss_control2_restore[7:6]),
    .capture_state (ss_snd_irq_state)
);

always @(posedge CLK96) begin
    if(RESET96) begin
        SOUNDLATCH <= 8'h00;
        SOUNDLATCH2 <= 8'h00;
        GAREGGA_SOUNDLATCH <= 8'h00;
        GAREGGA_Z80INT <= 1'b0;
        OKI_BANK <= 1'b0;
        soundlatch_live <= 8'h00;
        sound_nmi_pulse <= 4'd0;
        sound_ack_pulse <= 4'd0;
        sound_ack_wr_d <= 1'b0;
        SOUNDLATCH_ACK <= 2'b11;
        EEPROM_SCLK <= 1'b0;
        EEPROM_SCS <= 1'b0;
        EEPROM_SDI <= 1'b0;
        z80_bus_request <= 16'd0;
        BATRIDER_TEXTDATA_DMA_W <= 1'b0;
        BATRIDER_PAL_TEXT_DMA_W <= 1'b0;
        text_rom_unpacked <= 1'b0;
        GP9001_OP_SELECT_REG <= 1'b0;
        GP9001_OP_WRITE_REG <= 1'b0;
        GP9001_OP_WRITE_RAM <= 1'b0;
        GP9001_OP_READ_RAM_H <= 1'b0;
        GP9001_OP_READ_RAM_L <= 1'b0;
        GP9001_OP_SET_RAM_PTR <= 1'b0;
        GP9001_OP_OBJECTBANK_WR <= 1'b0;
        GP9001_OBJECTBANK_SLOT <= 3'd0;
    end else if(ss_active_freeze && !ss_cpu_run) begin
        if(ss_control0_restore_we) begin
            text_rom_unpacked <= ss_control0_restore[5];
            OKI_BANK <= ss_control0_restore[6];
            GAREGGA_Z80INT <= ss_control0_restore[7];
        end

        if(ss_control1_restore_we) begin
            SOUNDLATCH <= ss_control1_restore[7:0];
            SOUNDLATCH2 <= ss_control1_restore[15:8];
            GAREGGA_SOUNDLATCH <= ss_control1_restore[23:16];
            soundlatch_live <= ss_control1_restore[31:24];
            z80_bus_request <= ss_control1_restore[47:32];
            sound_nmi_pulse <= ss_control1_restore[51:48];
            sound_ack_pulse <= ss_control1_restore[55:52];
            SOUNDLATCH_ACK <= ss_control1_restore[57:56];
            EEPROM_SCLK <= ss_control1_restore[59];
            EEPROM_SCS <= ss_control1_restore[60];
            EEPROM_SDI <= ss_control1_restore[61];
            BATRIDER_TEXTDATA_DMA_W <= ss_control1_restore[62];
            BATRIDER_PAL_TEXT_DMA_W <= ss_control1_restore[63];
        end

        if(ss_control2_restore_we) begin
            sound_ack_wr_d <= ss_control2_restore[8];
            GP9001_OP_SELECT_REG <= ss_control2_restore[9];
            GP9001_OP_WRITE_REG <= ss_control2_restore[10];
            GP9001_OP_WRITE_RAM <= ss_control2_restore[11];
            GP9001_OP_READ_RAM_H <= ss_control2_restore[12];
            GP9001_OP_READ_RAM_L <= ss_control2_restore[13];
            GP9001_OP_SET_RAM_PTR <= ss_control2_restore[14];
            GP9001_OP_OBJECTBANK_WR <= ss_control2_restore[15];
            GP9001_OBJECTBANK_SLOT <= ss_control2_restore[18:16];
        end
    end else begin
        sound_ack_wr_d <= sound_ack_wr;

        if(is_garegga_family) begin
            if(GAME_ID == RAIZING_KINGDMGP && toaplan2_coinword_w_cs &&
               cpu_write_ok && !LDSn)
                OKI_BANK <= cpu_dout[4];

            if(GAME_ID == RAIZING_GAREGGA && garegga_soundlatch_w) begin
                GAREGGA_SOUNDLATCH <= cpu_dout[7:0];
                GAREGGA_Z80INT <= 1'b1;
            end else if(gp9001_vdp_device_r_cs) begin
                case(addr_8[3:0])
                    4'h4: GP9001_OP_READ_RAM_H <= 1'b1;
                    4'h6: GP9001_OP_READ_RAM_L <= 1'b1;
                endcase
            end else if(gp9001_vdp_device_w_cs) begin
                case(addr_8[3:0])
                    4'hC: GP9001_OP_WRITE_REG <= 1'b1;
                    4'h8: GP9001_OP_SELECT_REG <= 1'b1;
                    4'h4, 4'h6: GP9001_OP_WRITE_RAM <= 1'b1;
                    4'h0: GP9001_OP_SET_RAM_PTR <= 1'b1;
                endcase
            end else begin
                GAREGGA_Z80INT <= 1'b0;
                if(GP9001ACK) begin
                    GP9001_OP_SELECT_REG <= 1'b0;
                    GP9001_OP_WRITE_REG <= 1'b0;
                    GP9001_OP_WRITE_RAM <= 1'b0;
                    GP9001_OP_READ_RAM_H <= 1'b0;
                    GP9001_OP_READ_RAM_L <= 1'b0;
                    GP9001_OP_SET_RAM_PTR <= 1'b0;
                    GP9001_OP_OBJECTBANK_WR <= 1'b0;
                end
            end
        end else begin
            if(is_bakraid) begin
                if(CEN16 && bakraid_eeprom_w && !LDSWn) begin
                    z80_bus_request[0] <= cpu_dout[4];
                    EEPROM_SCLK <= cpu_dout[3];
                    EEPROM_SDI <= cpu_dout[2];
                    EEPROM_SCS <= cpu_dout[0];
                end

                if(sound_ack_edge) begin
                    sound_ack_pulse <= SOUND_ACK_PULSE_LEN;
                    sound_nmi_pulse <= SOUND_NMI_PULSE_LEN;
                end else begin
                    if(sound_ack_pulse != 4'd0)
                        sound_ack_pulse <= sound_ack_pulse - 4'd1;
                    if(sound_nmi_pulse != 4'd0)
                        sound_nmi_pulse <= sound_nmi_pulse - 4'd1;
                end

                SOUNDLATCH_ACK <= SOUNDLATCH_ACK_INCOMING;
            end

            if(soundlatch_w_live) begin
                soundlatch_live <= cpu_dout[7:0];
                SOUNDLATCH <= cpu_dout[7:0];
                if(is_bakraid)
                    SOUNDLATCH_ACK[0] <= 1'b0;
            end else if(soundlatch2_w_live) begin
                SOUNDLATCH2 <= cpu_dout[7:0];
                if(is_bakraid)
                    SOUNDLATCH_ACK[1] <= 1'b0;
            end else if(GAME_ID == RAIZING_BATRIDER && batrider_z80_busreq_w) begin
                z80_bus_request <= cpu_dout;
            end else if(batrider_textdata_dma_w_cs) begin
                BATRIDER_TEXTDATA_DMA_W <= 1'b1;
                text_rom_unpacked <= 1'b1;
            end else if(batrider_unk_dma_w) begin
                BATRIDER_PAL_TEXT_DMA_W <= 1'b1;
            end else if(batrider_objectbank_w_cs) begin
                GP9001_OBJECTBANK_SLOT <= addr_8[3:1];
                GP9001_OP_OBJECTBANK_WR <= 1'b1;
            end else if(gp9001_vdp_device_r_cs) begin
                case(addr_8[3:0])
                    4'h8: GP9001_OP_READ_RAM_H <= 1'b1;
                    4'hA: GP9001_OP_READ_RAM_L <= 1'b1;
                endcase
            end else if(gp9001_vdp_device_w_cs) begin
                case(addr_8[3:0])
                    4'h0: GP9001_OP_WRITE_REG <= 1'b1;
                    4'h4: GP9001_OP_SELECT_REG <= 1'b1;
                    4'h8, 4'hA: GP9001_OP_WRITE_RAM <= 1'b1;
                    4'hC: GP9001_OP_SET_RAM_PTR <= 1'b1;
                endcase
            end else begin
                if(!TVRAMCTL_BUSY) begin
                    BATRIDER_TEXTDATA_DMA_W <= 1'b0;
                    BATRIDER_PAL_TEXT_DMA_W <= 1'b0;
                end

                if(GP9001ACK) begin
                    GP9001_OP_SELECT_REG <= 1'b0;
                    GP9001_OP_WRITE_REG <= 1'b0;
                    GP9001_OP_WRITE_RAM <= 1'b0;
                    GP9001_OP_READ_RAM_H <= 1'b0;
                    GP9001_OP_READ_RAM_L <= 1'b0;
                    GP9001_OP_SET_RAM_PTR <= 1'b0;
                    GP9001_OP_OBJECTBANK_WR <= 1'b0;
                end
            end
        end
    end
end

assign {TVRAM_WE, TVRAM_CS} = {2{
    is_battle && !text_rom_unpacked && sel_local_ram &&
    addr_8[15] == 1'b0 && !ss_override_valid && !ss_write_blocked
}};
assign TVRAM_DIN = cpu_dout;
assign TVRAM_WR_ADDR = addr_8[14:1];
assign DMA_RAM_DOUT = local_ram_dma_q;

// Garegga uses GP9001 VINT for IRQ4; early games retain LVBL IRQ.
wire early_irq4_n = GAME_ID == RAIZING_GAREGGA ? VINT : int1;

jtframe_virq #(.SS_ENABLE(SS_ENABLE)) u_virq(
    .rst        (RESET96),
    .clk        (CLK96),
    .LVBL       (LVBL),
    .dip_pause  (DIP_PAUSE),
    .skip_en    (),
    .skip_but   (),
    .clr        (~inta_n),
    .custom_in  (is_battle ? snd_irq_ack : 1'b0),
    .blin_n     (int1),
    .blout_n    (),
    .custom_n   (int2),
    .ss_hold    (ss_active_freeze),
    .ss_restore (SS_ENABLE && ss_control2_restore_we),
    .ss_state_in(ss_control2_restore[5:0]),
    .ss_state   (ss_irq_state)
);

generate
    if(SS_ENABLE) begin : gen_savestate
        wire [11:0] response_ack;
        wire [767:0] response_data;

        raizing_ss_68k #(.USE_DTACK(1)) u_ss_68k(
            .clk(CLK96),
            .reset(RESET96),
            .cpu_phi1(cpu_phi1),
            .save_begin(SS_SAVE_BEGIN),
            .save_resume(SS_SAVE_RESUME),
            .restore_begin(SS_RESTORE_BEGIN),
            .restore_window(SS_RESTORE_WINDOW),
            .restore_ssp(ss_restore_ssp),
            .cpu_addr(A),
            .cpu_data_out(cpu_dout),
            .cpu_rw(RW),
            .cpu_as_n(ASn),
            .cpu_uds_n(UDSn),
            .cpu_lds_n(LDSn),
            .cpu_dtack_n(DTACKn),
            .cpu_fc({FC2, FC1, FC0}),
            .cpu_run(ss_cpu_run),
            .cpu_reset(ss_cpu_reset),
            .block_writes(ss_block_writes),
            .irq_level7(ss_irq_level7),
            .override_valid(ss_override_valid),
            .override_data(ss_override_data),
            .saved_ssp(ss_saved_ssp),
            .save_ready(SS_SAVE_READY),
            .save_done(SS_SAVE_DONE),
            .restore_done(SS_RESTORE_DONE),
            .busy(SS_BUSY)
        );

        raizing_ss_register #(
            .WIDTH(32),
            .SS_INDEX(1)
        ) u_ss_ssp(
            .clk(CLK96),
            .reset(RESET96),
            .capture_data(ss_saved_ssp),
            .restore_data(ss_restore_ssp),
            .restore_we(),
            .ss_data(SS_DATA),
            .ss_select(SS_SELECT),
            .ss_write(SS_WRITE),
            .ss_read(SS_READ),
            .ss_query(SS_QUERY),
            .ss_data_out(response_data[0*64 +: 64]),
            .ss_ack(response_ack[0])
        );

        raizing_ss_ram_adapter #(
            .WIDTH(16),
            .ADDR_WIDTH(15),
            .SS_INDEX(2)
        ) u_ss_ram(
            .clk(CLK96),
            .reset(RESET96),
            .ss_data(SS_DATA),
            .ss_addr(SS_ADDR),
            .ss_select(SS_SELECT),
            .ss_write(SS_WRITE),
            .ss_read(SS_READ),
            .ss_query(SS_QUERY),
            .ss_data_out(response_data[1*64 +: 64]),
            .ss_ack(response_ack[1]),
            .ram_active(ss_ram_active),
            .ram_addr(ss_ram_addr),
            .ram_data(ss_ram_data),
            .ram_we(ss_ram_we),
            .ram_q(ss_ram_q)
        );

        raizing_ss_ram_adapter #(
            .WIDTH(8),
            .ADDR_WIDTH(14),
            .SS_INDEX(16)
        ) u_ss_garegga_ram(
            .clk(CLK96),
            .reset(RESET96),
            .ss_data(SS_DATA),
            .ss_addr(SS_ADDR),
            .ss_select(ss_garegga_select),
            .ss_write(SS_WRITE),
            .ss_read(SS_READ),
            .ss_query(SS_QUERY),
            .ss_data_out(response_data[2*64 +: 64]),
            .ss_ack(response_ack[2]),
            .ram_active(ss_garegga_ram_active),
            .ram_addr(ss_garegga_ram_addr),
            .ram_data(ss_garegga_ram_data),
            .ram_we(ss_garegga_ram_we),
            .ram_q(ss_garegga_ram_q)
        );

        raizing_ss_register #(
            .WIDTH(8),
            .SS_INDEX(10)
        ) u_ss_control0(
            .clk(CLK96),
            .reset(RESET96),
            .capture_data(ss_control0_capture),
            .restore_data(ss_control0_restore),
            .restore_we(ss_control0_restore_we),
            .ss_data(SS_DATA),
            .ss_select(SS_SELECT),
            .ss_write(SS_WRITE),
            .ss_read(SS_READ),
            .ss_query(SS_QUERY),
            .ss_data_out(response_data[3*64 +: 64]),
            .ss_ack(response_ack[3])
        );

        raizing_ss_register #(
            .WIDTH(64),
            .SS_INDEX(11)
        ) u_ss_control1(
            .clk(CLK96),
            .reset(RESET96),
            .capture_data(ss_control1_capture),
            .restore_data(ss_control1_restore),
            .restore_we(ss_control1_restore_we),
            .ss_data(SS_DATA),
            .ss_select(SS_SELECT),
            .ss_write(SS_WRITE),
            .ss_read(SS_READ),
            .ss_query(SS_QUERY),
            .ss_data_out(response_data[4*64 +: 64]),
            .ss_ack(response_ack[4])
        );

        raizing_ss_register #(
            .WIDTH(32),
            .SS_INDEX(12)
        ) u_ss_control2(
            .clk(CLK96),
            .reset(RESET96),
            .capture_data(ss_control2_capture),
            .restore_data(ss_control2_restore),
            .restore_we(ss_control2_restore_we),
            .ss_data(SS_DATA),
            .ss_select(SS_SELECT),
            .ss_write(SS_WRITE),
            .ss_read(SS_READ),
            .ss_query(SS_QUERY),
            .ss_data_out(response_data[5*64 +: 64]),
            .ss_ack(response_ack[5])
        );

        raizing_ss_ram_adapter #(
            .WIDTH(16),
            .ADDR_WIDTH(11),
            .SS_INDEX(38)
        ) u_ss_palram(
            .clk(CLK96), .reset(RESET96),
            .ss_data(SS_DATA), .ss_addr(SS_ADDR),
            .ss_select(ss_garegga_select), .ss_write(SS_WRITE),
            .ss_read(SS_READ), .ss_query(SS_QUERY),
            .ss_data_out(response_data[6*64 +: 64]),
            .ss_ack(response_ack[6]),
            .ram_active(ss_palram_active), .ram_addr(ss_palram_addr),
            .ram_data(ss_palram_data), .ram_we(ss_palram_we),
            .ram_q(ss_palram_q)
        );

        raizing_ss_ram_adapter #(
            .WIDTH(16),
            .ADDR_WIDTH(12),
            .SS_INDEX(39)
        ) u_ss_txvram(
            .clk(CLK96), .reset(RESET96),
            .ss_data(SS_DATA), .ss_addr(SS_ADDR),
            .ss_select(ss_garegga_select), .ss_write(SS_WRITE),
            .ss_read(SS_READ), .ss_query(SS_QUERY),
            .ss_data_out(response_data[7*64 +: 64]),
            .ss_ack(response_ack[7]),
            .ram_active(ss_txvram_active), .ram_addr(ss_txvram_addr),
            .ram_data(ss_txvram_data), .ram_we(ss_txvram_we),
            .ram_q(ss_txvram_q)
        );

        raizing_ss_ram_adapter #(
            .WIDTH(16),
            .ADDR_WIDTH(11),
            .SS_INDEX(40)
        ) u_ss_txselect(
            .clk(CLK96), .reset(RESET96),
            .ss_data(SS_DATA), .ss_addr(SS_ADDR),
            .ss_select(ss_garegga_select), .ss_write(SS_WRITE),
            .ss_read(SS_READ), .ss_query(SS_QUERY),
            .ss_data_out(response_data[8*64 +: 64]),
            .ss_ack(response_ack[8]),
            .ram_active(ss_txselect_active), .ram_addr(ss_txselect_addr),
            .ram_data(ss_txselect_data), .ram_we(ss_txselect_we),
            .ram_q(ss_txselect_q)
        );

        raizing_ss_ram_adapter #(
            .WIDTH(16),
            .ADDR_WIDTH(11),
            .SS_INDEX(41)
        ) u_ss_txscroll(
            .clk(CLK96), .reset(RESET96),
            .ss_data(SS_DATA), .ss_addr(SS_ADDR),
            .ss_select(ss_garegga_select), .ss_write(SS_WRITE),
            .ss_read(SS_READ), .ss_query(SS_QUERY),
            .ss_data_out(response_data[9*64 +: 64]),
            .ss_ack(response_ack[9]),
            .ram_active(ss_txscroll_active), .ram_addr(ss_txscroll_addr),
            .ram_data(ss_txscroll_data), .ram_we(ss_txscroll_we),
            .ram_q(ss_txscroll_q)
        );

        raizing_ss_ram_adapter #(
            .WIDTH(16),
            .ADDR_WIDTH(11),
            .SS_INDEX(42)
        ) u_ss_txram(
            .clk(CLK96), .reset(RESET96),
            .ss_data(SS_DATA), .ss_addr(SS_ADDR),
            .ss_select(ss_garegga_select), .ss_write(SS_WRITE),
            .ss_read(SS_READ), .ss_query(SS_QUERY),
            .ss_data_out(response_data[10*64 +: 64]),
            .ss_ack(response_ack[10]),
            .ram_active(ss_txram_active), .ram_addr(ss_txram_addr),
            .ram_data(ss_txram_data), .ram_we(ss_txram_we),
            .ram_q(ss_txram_q)
        );

        raizing_ss_ram_adapter #(
            .WIDTH(16),
            .ADDR_WIDTH(10),
            .SS_INDEX(43)
        ) u_ss_ram2(
            .clk(CLK96), .reset(RESET96),
            .ss_data(SS_DATA), .ss_addr(SS_ADDR),
            .ss_select(ss_garegga_select), .ss_write(SS_WRITE),
            .ss_read(SS_READ), .ss_query(SS_QUERY),
            .ss_data_out(response_data[11*64 +: 64]),
            .ss_ack(response_ack[11]),
            .ram_active(ss_ram2_active), .ram_addr(ss_ram2_addr),
            .ram_data(ss_ram2_data), .ram_we(ss_ram2_we),
            .ram_q(ss_ram2_q)
        );

        raizing_ss_response_mux #(.COUNT(12)) u_ss_response(
            .ack(response_ack),
            .data(response_data),
            .ack_out(SS_ACK),
            .data_out(SS_DATA_OUT)
        );
    end else begin : gen_no_savestate
        assign ss_cpu_run = 1'b0;
        assign ss_cpu_reset = 1'b0;
        assign ss_block_writes = 1'b0;
        assign ss_irq_level7 = 1'b0;
        assign ss_override_valid = 1'b0;
        assign ss_override_data = 16'd0;
        assign ss_saved_ssp = 32'd0;
        assign ss_restore_ssp = 32'd0;
        assign ss_control0_restore = 8'd0;
        assign ss_control1_restore = 64'd0;
        assign ss_control2_restore = 32'd0;
        assign ss_control0_restore_we = 1'b0;
        assign ss_control1_restore_we = 1'b0;
        assign ss_control2_restore_we = 1'b0;
        assign ss_ram_active = 1'b0;
        assign ss_ram_addr = 15'd0;
        assign ss_ram_data = 16'd0;
        assign ss_ram_we = 1'b0;
        assign ss_garegga_ram_active = 1'b0;
        assign ss_garegga_ram_addr = 14'd0;
        assign ss_garegga_ram_data = 8'd0;
        assign ss_garegga_ram_we = 1'b0;
        assign ss_palram_active = 1'b0;
        assign ss_palram_addr = 11'd0;
        assign ss_palram_data = 16'd0;
        assign ss_palram_we = 1'b0;
        assign ss_txvram_active = 1'b0;
        assign ss_txvram_addr = 12'd0;
        assign ss_txvram_data = 16'd0;
        assign ss_txvram_we = 1'b0;
        assign ss_txselect_active = 1'b0;
        assign ss_txselect_addr = 11'd0;
        assign ss_txselect_data = 16'd0;
        assign ss_txselect_we = 1'b0;
        assign ss_txscroll_active = 1'b0;
        assign ss_txscroll_addr = 11'd0;
        assign ss_txscroll_data = 16'd0;
        assign ss_txscroll_we = 1'b0;
        assign ss_txram_active = 1'b0;
        assign ss_txram_addr = 11'd0;
        assign ss_txram_data = 16'd0;
        assign ss_txram_we = 1'b0;
        assign ss_ram2_active = 1'b0;
        assign ss_ram2_addr = 10'd0;
        assign ss_ram2_data = 16'd0;
        assign ss_ram2_we = 1'b0;
        assign SS_SAVE_READY = 1'b0;
        assign SS_SAVE_DONE = 1'b0;
        assign SS_RESTORE_DONE = 1'b0;
        assign SS_BUSY = 1'b0;
        assign SS_DATA_OUT = 64'd0;
        assign SS_ACK = 1'b0;
    end
endgenerate

raizing_68kdtack #(.W(8), .MFREQ(94500)) u_dtack(
    .rst        (RESET96),
    .clk        (CLK96),
    .cpu_cen    (cpu_phi1_raw),
    .cpu_cenb   (cpu_phi2_raw),
    .bus_cs     (bus_cs),
    .bus_busy   (bus_busy),
    .bus_legit  (1'b0),
    .ASn        (is_bakraid ? (ASn | (active_z80_cs & Z80WAIT)) : ASn),
    .DSn        ({UDSn, LDSn}),
    .num        (RAIZING_CPU_CEN_NUM),
    .den        (RAIZING_CPU_CEN_DEN),
    .DTACKn     (DTACKn),
    .fave       (),
    .fworst     ()
);

assign BUSACK = ~BGACKn;

jtframe_68kdma #(.BW(1)) u_arbitration(
    .clk        (CLK96),
    .cen        (cpu_phi2_raw),
    .rst        (RESET96),
    .cpu_BRn    (BRn),
    .cpu_BGACKn (BGACKn),
    .cpu_BGn    (BGn),
    .cpu_ASn    (ASn),
    .cpu_DTACKn (DTACKn),
    .dev_br     (BR)
);

fx68k u_011 (
    .clk        (CLK96),
    .extReset   (RESET96 || ss_cpu_reset),
    .pwrUp      (RESET96 || ss_cpu_reset),
    .enPhi1     (cpu_phi1),
    .enPhi2     (cpu_phi2),
    .eab        (A),
    .iEdb       (cpu_din),
    .oEdb       (cpu_dout),
    .eRWn       (RW),
    .LDSn       (LDSn),
    .UDSn       (UDSn),
    .ASn        (ASn),
    .VPAn       (VPAn),
    .FC0        (FC0),
    .FC1        (FC1),
    .FC2        (FC2),
    .BERRn      (1'b1),
    .HALTn      (DIP_PAUSE && (!ss_active_freeze || ss_cpu_run)),
    .BRn        (BRn),
    .BGACKn     (BGACKn),
    .BGn        (BGn),
    .DTACKn     (DTACKn),
    .IPL0n      (ss_irq_level7 ? 1'b0 : (is_bakraid ? int1 : 1'b1)),
    .IPL1n      (ss_irq_level7 ? 1'b0 : (is_bakraid ? int2 : (is_battle ? int1 : 1'b1))),
    .IPL2n      (ss_irq_level7 ? 1'b0 : (is_bakraid ? 1'b1 : (is_battle ? int2 : early_irq4_n))),
    .oRESETn    (M68K_RESET_N),
    .oHALTEDn   (),
    .VMAn       (),
    .E          ()
);

assign CEN16 = cpu_phi1_raw;
assign CEN16B = cpu_phi2_raw;

// 64 KB local CPU RAM. Garegga uses it as 0x100000-0x10FFFF. Batrider/Bakraid
// use the lower 32 KB as text DMA source VRAM and upper 32 KB as work RAM.
raizing_dual_ram16 #(
    .AW(15),
    .SS_ENABLE(SS_ENABLE)
) u_cpu_local_ram(
    .clk0(CLK96),
    .clk1(CLK96),
    .data0(wram_cpu_data),
    .addr0(A[15:1]),
    .we0({sel_local_ram && cpu_write_ok && !UDSn,
          sel_local_ram && cpu_write_ok && !LDSn}),
    .q0(local_ram_q0),
    .data1(16'h0000),
    .addr1({1'b0, DMA_RAM_ADDR}),
    .we1(2'b00),
    .q1(local_ram_dma_q),
    .ss_active(ss_ram_active),
    .ss_data(ss_ram_data),
    .ss_addr(ss_ram_addr),
    .ss_we({2{ss_ram_we}}),
    .ss_q(ss_ram_q)
);

raizing_dual_ram #(
    .DW(8),
    .AW(14),
    .SS_ENABLE(SS_ENABLE)
) u_garegga_sram_ram(
    .clk0(CLK96),
    .clk1(CLK96),
    .data0(wram_cpu_data[7:0]),
    .addr0((addr_8 >> 1) & 14'h3FFF),
    .we0(sel_sram && cpu_write_ok &&
         (GAME_ID == RAIZING_GAREGGA || !LDSn)),
    .q0(main_sram_q0),
    .data1(GAREGGA_SRAM_DIN),
    .addr1(GAREGGA_SRAM_ADDR),
    .we1(GAREGGA_SRAM_WE),
    .q1(GAREGGA_SRAM_DATA),
    .ss_active(ss_garegga_ram_active),
    .ss_data(ss_garegga_ram_data),
    .ss_addr(ss_garegga_ram_addr),
    .ss_we(ss_garegga_ram_we),
    .ss_q(ss_garegga_ram_q)
);

raizing_dual_ram16 #(.AW(11), .SS_ENABLE(SS_ENABLE)) u_garegga_palram_ram(
    .clk0(CLK96),
    .clk1(CLK96),
    .data0(wram_cpu_data),
    .addr0(A[11:1]),
    .we0({sel_palram && cpu_write_ok && !UDSn,
          sel_palram && cpu_write_ok && !LDSn}),
    .q0(main_palram_q0),
    .data1(16'h0000),
    .addr1(PALRAM_ADDR),
    .we1(2'b00),
    .q1(PALRAM_DATA),
    .ss_active(ss_palram_active),
    .ss_data(ss_palram_data),
    .ss_addr(ss_palram_addr),
    .ss_we({2{ss_palram_we}}),
    .ss_q(ss_palram_q)
);

raizing_dual_ram16 #(.AW(12), .SS_ENABLE(SS_ENABLE)) u_garegga_txvram_ram(
    .clk0(CLK96),
    .clk1(CLK96),
    .data0(wram_cpu_data),
    .addr0(A[12:1]),
    .we0({sel_txvram && cpu_write_ok && !UDSn,
          sel_txvram && cpu_write_ok && !LDSn}),
    .q0(main_txvram_q0),
    .data1(16'h0000),
    .addr1(TEXTVRAM_ADDR),
    .we1(2'b00),
    .q1(TEXTVRAM_DATA),
    .ss_active(ss_txvram_active),
    .ss_data(ss_txvram_data),
    .ss_addr(ss_txvram_addr),
    .ss_we({2{ss_txvram_we}}),
    .ss_q(ss_txvram_q)
);

raizing_dual_ram16 #(.AW(11), .SS_ENABLE(SS_ENABLE)) u_garegga_txlineselect_ram(
    .clk0(CLK96),
    .clk1(CLK96),
    .data0(wram_cpu_data),
    .addr0(A[11:1]),
    .we0({sel_txlineselect && cpu_write_ok && !UDSn,
          sel_txlineselect && cpu_write_ok && !LDSn}),
    .q0(main_txlineselect_q0),
    .data1(16'h0000),
    .addr1(TEXTSELECT_ADDR),
    .we1(2'b00),
    .q1(TEXTSELECT_DATA),
    .ss_active(ss_txselect_active),
    .ss_data(ss_txselect_data),
    .ss_addr(ss_txselect_addr),
    .ss_we({2{ss_txselect_we}}),
    .ss_q(ss_txselect_q)
);

raizing_dual_ram16 #(.AW(11), .SS_ENABLE(SS_ENABLE)) u_garegga_txlinescroll_ram(
    .clk0(CLK96),
    .clk1(CLK96),
    .data0(wram_cpu_data),
    .addr0(A[11:1]),
    .we0({sel_txlinescroll && cpu_write_ok && !UDSn,
          sel_txlinescroll && cpu_write_ok && !LDSn}),
    .q0(main_txlinescroll_q0),
    .data1(16'h0000),
    .addr1(TEXTSCROLL_ADDR),
    .we1(2'b00),
    .q1(TEXTSCROLL_DATA),
    .ss_active(ss_txscroll_active),
    .ss_data(ss_txscroll_data),
    .ss_addr(ss_txscroll_addr),
    .ss_we({2{ss_txscroll_we}}),
    .ss_q(ss_txscroll_q)
);

raizing_dual_ram16 #(.AW(11), .SS_ENABLE(SS_ENABLE)) u_sstriker_txram_ram(
    .clk0(CLK96),
    .clk1(CLK96),
    .data0(wram_cpu_data),
    .addr0(A[11:1]),
    .we0({sel_txram && cpu_write_ok && !UDSn,
          sel_txram && cpu_write_ok && !LDSn}),
    .q0(main_txram_q0),
    .data1(16'h0000),
    .addr1(11'd0),
    .we1(2'b00),
    .q1(),
    .ss_active(ss_txram_active),
    .ss_data(ss_txram_data),
    .ss_addr(ss_txram_addr),
    .ss_we({2{ss_txram_we}}),
    .ss_q(ss_txram_q)
);

raizing_dual_ram16 #(.AW(10), .SS_ENABLE(SS_ENABLE)) u_garegga_cpu_wram2(
    .clk0(CLK96),
    .clk1(CLK96),
    .data0(wram_cpu_data),
    .addr0(A[10:1]),
    .we0({sel_ram2 && cpu_write_ok && !UDSn,
          sel_ram2 && cpu_write_ok && !LDSn}),
    .q0(main_ram2_q0),
    .data1(16'h0000),
    .addr1(10'd0),
    .we1(2'b00),
    .q1(),
    .ss_active(ss_ram2_active),
    .ss_data(ss_ram2_data),
    .ss_addr(ss_ram2_addr),
    .ss_we({2{ss_ram2_we}}),
    .ss_q(ss_ram2_q)
);

endmodule
