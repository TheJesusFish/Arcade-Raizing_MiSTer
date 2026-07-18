// This file is a Codex-assisted refactoring and update
// based on the original work of Pramod Somashekar (pram0d)

/*
* Shared Raizing board shell for family-specific video, sound, and ROM devices.
*
* Copyright (c) 2022 Pramod Somashekar
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*/
module raizing_board #(
    parameter SS_ENABLE = 0
)(
    input [7:0] GAME_ID,
    input [7:0] TARGET_GAME_ID,

    //clock and reset
    input rst,
    input rst48,
    input rst96,
    input clk,
    input clk48,
    input clk96,
    output pxl_cen,
    output pxl2_cen,

    //video outputs
    output [7:0] red,
    output [7:0] green,
    output [7:0] blue,
    output LHBL,
    output LVBL,
    output HS,
    output VS,

    // Control I/O
    input [3:0] cab_1p,
    input [3:0] coin,
    input [9:0] joystick1,
    input [9:0] joystick2,
    input [9:0] joystick3,
    input [9:0] joystick4,
    input [15:0] joyana_l1,
    input [15:0] joyana_l2,
    input [15:0] joyana_l3,
    input [15:0] joyana_l4,
    input [15:0] joyana_r1,
    input [15:0] joyana_r2,
    input [15:0] joyana_r3,
    input [15:0] joyana_r4,
    input [1:0] dial_x,
    input [1:0] dial_y,
    input       tilt,

    // SDRAM interface
    output [21:0] ba0_addr,
    output [21:0] ba1_addr,
    output [21:0] ba2_addr,
    output [21:0] ba3_addr,
    output  [3:0] ba_rd,
    output        ba_wr,
    output [15:0] ba0_din,
    output  [1:0] ba0_dsn,
    output [15:0] ba1_din,
    output  [1:0] ba1_dsn,
    output [15:0] ba2_din,
    output  [1:0] ba2_dsn,
    output [15:0] ba3_din,
    output  [1:0] ba3_dsn,
    input   [3:0] ba_ack,
    input   [3:0] ba_dst,
    input   [3:0] ba_dok,
    input   [3:0] ba_rdy,
    input  [15:0] data_read,

    //ROM loader
    input         ioctl_rom,
    input         ioctl_cart,
    output        dwnld_busy,
    input  [25:0] ioctl_addr,
    input   [7:0] ioctl_dout,
    input         ioctl_wr,
    output  [7:0] ioctl_din,
    input         ioctl_ram,
    output [21:0] prog_addr,
    output [15:0] prog_data,
    output  [1:0] prog_mask,
    output  [1:0] prog_ba,
    output        prog_we,
    output        prog_rd,
    input         prog_ack,
    input         prog_dok,
    input         prog_dst,
    input         prog_rdy,

    //dip switches
    input [31:0] status,
    input        service,
    input        dip_pause,
    inout        dip_flip,
    input        dip_test,
    input  [1:0] dip_fxlevel,
    input [31:0] dipsw,

    //sound
    output signed [15:0] snd_left,
    output signed [15:0] snd_right,
    output               sample,
    input  [5:0]         snd_en,
    input  [7:0]         snd_vol,
    output [7:0]         snd_vu,
    output               snd_peak,

    //misc
    input                gfx_en,

    // extra clocks
    input                clk24,
    input                rst24,

    input                SS_ACTIVE,
    input                SS_FREEZE,
    input                SS_SAVE_BEGIN,
    input                SS_SAVE_RESUME,
    input                SS_RESTORE_BEGIN,
    input                SS_RESTORE_WINDOW,
    output               SS_SAVE_READY,
    output               SS_SAVE_DONE,
    output reg           SS_RESTORE_DONE,
    output               SS_GAME_QUIESCED,
    output               SS_CPU_IDLE,
    input         [63:0] SS_DATA,
    input         [31:0] SS_ADDR,
    input          [7:0] SS_SELECT,
    input                SS_WRITE,
    input                SS_READ,
    input                SS_QUERY,
    output        [63:0] SS_DATA_OUT,
    output               SS_ACK
);

localparam [7:0] RAIZING_GAREGGA  = 8'h00;
localparam [7:0] RAIZING_SSTRIKER = 8'h01;
localparam [7:0] RAIZING_KINGDMGP = 8'h02;
localparam [7:0] RAIZING_BATRIDER = 8'h03;
localparam [7:0] RAIZING_BAKRAID  = 8'h04;

wire active_is_garegga = GAME_ID == RAIZING_GAREGGA ||
                         GAME_ID == RAIZING_SSTRIKER ||
                         GAME_ID == RAIZING_KINGDMGP;
wire active_is_batrider = GAME_ID == RAIZING_BATRIDER;
wire active_is_bakraid  = GAME_ID == RAIZING_BAKRAID;
wire active_is_battle   = active_is_batrider || active_is_bakraid;

wire target_is_garegga = TARGET_GAME_ID == RAIZING_GAREGGA ||
                         TARGET_GAME_ID == RAIZING_SSTRIKER ||
                         TARGET_GAME_ID == RAIZING_KINGDMGP;
wire target_is_batrider = TARGET_GAME_ID == RAIZING_BATRIDER;
wire target_is_bakraid  = TARGET_GAME_ID == RAIZING_BAKRAID;
wire target_is_battle   = target_is_batrider || target_is_bakraid;

wire RESET   = rst48;
wire CLK     = clk48;
wire RESET96 = rst;
wire CLK96   = clk;

/* clocks */
wire g_CEN675, g_CEN675B, g_CEN4, g_CEN2, g_CEN2B, g_CEN4B, g_CEN1350, g_CEN1350B;
wire g_CEN3p375, g_CEN3p375B, g_CEN1, g_CENp7575, g_CEN1B, g_CEN1p6875, g_CEN1p6875B;
wire b_CEN2, b_CEN4, b_CEN675, b_CEN675B, b_CEN5333, b_CEN5333B, b_CEN3p2, b_CEN3p2B, b_CEN1350, b_CEN1350B;
wire k_CEN675, k_CEN675B, k_CEN5333, k_CEN5333B, k_CEN1350, k_CEN1350B, k_CEN16p9344, k_CEN16p9344B;
wire CEN16, CEN16B;

garegga_clock u_garegga_clocken (
    .CLK(CLK),
    .CLK96(CLK96),
    .CEN675(g_CEN675),
    .CEN675B(g_CEN675B),
    .CEN4(g_CEN4),
    .CEN4B(g_CEN4B),
    .CEN2(g_CEN2),
    .CEN2B(g_CEN2B),
    .CEN3p375(g_CEN3p375),
    .CEN3p375B(g_CEN3p375B),
    .CEN1(g_CEN1),
    .CENp7575(g_CENp7575),
    .CEN1B(g_CEN1B),
    .CEN1p6875(g_CEN1p6875),
    .CEN1p6875B(g_CEN1p6875B),
    .CEN1350(g_CEN1350),
    .CEN1350B(g_CEN1350B),
    .GAME(GAME_ID)
);

batrider_clock u_batrider_clocken (
    .CLK(CLK),
    .CLK96(CLK96),
    .CEN4(b_CEN4),
    .CEN2(b_CEN2),
    .CEN675(b_CEN675),
    .CEN675B(b_CEN675B),
    .CEN5333(b_CEN5333),
    .CEN5333B(b_CEN5333B),
    .CEN3p2(b_CEN3p2),
    .CEN3p2B(b_CEN3p2B),
    .CEN1350(b_CEN1350),
    .CEN1350B(b_CEN1350B)
);

bakraid_clock u_bakraid_clocken (
    .CLK(CLK),
    .CLK96(CLK96),
    .CEN675(k_CEN675),
    .CEN675B(k_CEN675B),
    .CEN5333(k_CEN5333),
    .CEN5333B(k_CEN5333B),
    .CEN1350(k_CEN1350),
    .CEN1350B(k_CEN1350B),
    .CEN16p9344(k_CEN16p9344),
    .CEN16p9344B(k_CEN16p9344B)
);

wire CEN675  = active_is_garegga ? g_CEN675  : active_is_bakraid ? k_CEN675  : b_CEN675;
wire CEN675B = active_is_garegga ? g_CEN675B : active_is_bakraid ? k_CEN675B : b_CEN675B;
wire CEN1350 = active_is_garegga ? g_CEN1350 : active_is_bakraid ? k_CEN1350 : b_CEN1350;
wire CEN1350B = active_is_garegga ? g_CEN1350B : active_is_bakraid ? k_CEN1350B : b_CEN1350B;
assign pxl_cen  = CEN675;
assign pxl2_cen = CEN1350;

/* controls and DIP switches */
wire FLIP = GAME_ID == RAIZING_GAREGGA ? dipsw[10] :
            GAME_ID == RAIZING_SSTRIKER || GAME_ID == RAIZING_KINGDMGP ? dipsw[1] :
            active_is_battle ? dipsw[16] : 1'b0;
assign dip_flip = 1'b0;

// Screen flip is handled by video; service mode is disabled.
wire [23:0] DIPSW = GAME_ID == RAIZING_GAREGGA ?
                    {dipsw[23:11], 1'b0, dipsw[9:1], 1'b0} :
                    GAME_ID == RAIZING_SSTRIKER || GAME_ID == RAIZING_KINGDMGP ?
                    {dipsw[23:3], 2'b00, dipsw[0]} :
                    active_is_battle ? {dipsw[23:17], 1'b0, dipsw[15:1], 1'b0} :
                    dipsw[23:0];
wire DIP_TEST = dip_test;

wire [7:0] DIPSW_C, DIPSW_B, DIPSW_A;
assign {DIPSW_C, DIPSW_B, DIPSW_A} = DIPSW[23:0];
wire DIP_PAUSE = dip_pause;
wire [5:0] g_sound_en = {snd_en[5:2], snd_en[1] & ~status[8], snd_en[0] & ~status[9]};
wire [5:0] b_sound_en = {snd_en[5:3], snd_en[2] & ~status[8], snd_en[1] & ~status[8], snd_en[0] & ~status[9]};

/* CPU, GP9001, and video timing bus */
wire BUSACK;
wire TVRAM_BR;
wire [19:1] CPU_ADDR;
wire [15:0] CPU_DOUT;
wire CPU_RW, CPU_RD, CPU_LDS, CPU_LDSWR;
wire ROM68K_CS, ROM68K_OK;
wire [19:0] ROM68K_ADDR;
wire [15:0] ROM68K_DOUT;
wire Z80_PRG_CS, Z80_PRG_OK;
wire [17:0] Z80_PRG_ADDR;
wire [7:0] Z80_PRG_DOUT;
wire GP9001CS, GP9001ACK, VINT;
wire GP9001_OP_SELECT_REG, GP9001_OP_WRITE_REG, GP9001_OP_WRITE_RAM;
wire GP9001_OP_READ_RAM_H, GP9001_OP_READ_RAM_L, GP9001_OP_SET_RAM_PTR;
wire GP9001_OP_OBJECTBANK_WR;
wire [2:0] GP9001_OBJECTBANK_SLOT;
wire [15:0] GCU_DOUT;
wire HSYNC, VSYNC, FBLANK;
wire CPU_LVBLL;
wire [8:0] CPU_V;
wire M68K_RESET_N;

/* Garegga direct text RAM ports */
wire [13:0] g_TEXTROM_ADDR;
wire [15:0] g_TEXTROM_DATA;
wire [11:0] g_TEXTVRAM_ADDR;
wire [15:0] g_TEXTVRAM_DATA;
wire [7:0] g_TEXTSELECT_ADDR;
wire [15:0] g_TEXTSELECT_DATA;
wire [7:0] g_TEXTSCROLL_ADDR;
wire [15:0] g_TEXTSCROLL_DATA;
wire [10:0] g_PALRAM_ADDR;
wire [15:0] g_PALRAM_DATA;

wire [11:0] g_TEXTVRAM_READ_ADDR = g_TEXTVRAM_ADDR;
wire [7:0] g_TEXTSELECT_READ_ADDR = g_TEXTSELECT_ADDR;
wire [7:0] g_TEXTSCROLL_READ_ADDR = g_TEXTSCROLL_ADDR;
wire [10:0] g_PALRAM_READ_ADDR = g_PALRAM_ADDR;

/* Batrider/Bakraid text DMA controller ports */
wire DMA_RAM_CS;
wire [13:0] DMA_RAM_ADDR;
wire [15:0] DMA_RAM_DOUT;
wire TVRAM_CS, TVRAM_WE;
wire [1:0] TVRAM_DS;
wire [13:0] TVRAM_WR_ADDR;
wire [15:0] TVRAM_DIN;
wire BATRIDER_TEXTDATA_DMA_W, BATRIDER_PAL_TEXT_DMA_W;
wire [13:0] b_TEXTROM_ADDR;
wire [15:0] b_TEXTROM_DATA;
wire [11:0] b_TEXTVRAM_ADDR;
wire [15:0] b_TEXTVRAM_DATA;
wire [7:0] b_TEXTSELECT_ADDR;
wire [15:0] b_TEXTSELECT_DATA;
wire [7:0] b_TEXTSCROLL_ADDR;
wire [15:0] b_TEXTSCROLL_DATA;
wire [10:0] b_PALRAM_ADDR;
wire [15:0] b_PALRAM_DATA;
wire [10:0] GP9001OUT;
wire [13:0] TEXTGFXRAM_ADDR = 14'd0;
wire [15:0] TEXTGFXRAM_DATA;
wire TEXTDMA_BUSY;

/* Sound latches */
wire [7:0] g_SOUNDLATCH;
wire [13:0] g_SRAM_ADDR;
wire [7:0] g_SRAM_DATA, g_SRAM_DIN;
wire g_SRAM_WE;
wire g_Z80INT, g_Z80WAIT;
wire OKI_BANK;
wire Z80CS, NMI, SNDIRQ, Z80WAIT;
wire [7:0] SOUNDLATCH, SOUNDLATCH2, SOUNDLATCH3, SOUNDLATCH4;
wire [7:0] b_SOUNDLATCH3, b_SOUNDLATCH4, k_SOUNDLATCH3, k_SOUNDLATCH4;
wire b_Z80WAIT, k_Z80WAIT, b_SNDIRQ, k_SNDIRQ;
wire [1:0] SOUNDLATCH_ACK, SOUNDLATCH_ACK_INCOMING;
assign SOUNDLATCH3 = active_is_bakraid ? k_SOUNDLATCH3 : b_SOUNDLATCH3;
assign SOUNDLATCH4 = active_is_bakraid ? k_SOUNDLATCH4 : b_SOUNDLATCH4;
assign Z80WAIT = active_is_garegga ? g_Z80WAIT : active_is_bakraid ? k_Z80WAIT : b_Z80WAIT;
assign SNDIRQ  = active_is_bakraid ? k_SNDIRQ : b_SNDIRQ;

/* Hiscore */
wire HISCORE_CS;
wire [1:0] HISCORE_WE;
wire [15:0] HISCORE_DIN;
wire [15:0] HISCORE_DOUT;
wire [8:0] HISCORE_ADDR;
wire [15:0] g_HISCORE_DOUT, b_HISCORE_DOUT;
assign HISCORE_DOUT = active_is_garegga ? g_HISCORE_DOUT : b_HISCORE_DOUT;

/* EEPROM */
wire EEPROM_SCLK, EEPROM_SCS, EEPROM_SDI, EEPROM_SDO;

wire [63:0] ss_cpu_data_out;
wire ss_cpu_ack;
wire ss_cpu_busy;
wire ss_cpu_idle;
wire ss_main_restore_done;
wire [63:0] ss_garegga_sound_data_out;
wire [63:0] ss_batrider_sound_data_out;
wire [63:0] ss_bakraid_sound_data_out;
wire ss_garegga_sound_ack, ss_batrider_sound_ack, ss_bakraid_sound_ack;
wire ss_garegga_sound_quiesced;
wire ss_batrider_sound_quiesced;
wire ss_bakraid_sound_quiesced;
wire [63:0] ss_shared_audio_data_out;
wire ss_shared_audio_ack;
wire ss_shared_audio_replay_busy;
wire ss_bakraid_audio_replay_busy;
wire [63:0] ss_video_data_out;
wire ss_video_ack, ss_video_quiesced;
wire [63:0] ss_text_data_out;
wire ss_text_ack, ss_text_quiesced;
wire [63:0] ss_garegga_storage_data_out;
wire [63:0] ss_batrider_storage_data_out;
wire [63:0] ss_bakraid_storage_data_out;
wire ss_garegga_storage_ack, ss_batrider_storage_ack;
wire ss_bakraid_storage_ack;
wire ss_garegga_storage_quiesced, ss_batrider_storage_quiesced;
wire ss_bakraid_storage_quiesced;
wire [7:0] ss_text_select = active_is_battle ? SS_SELECT : 8'hff;
wire [7:0] ss_garegga_storage_select = active_is_garegga ?
                                       SS_SELECT : 8'hff;
wire [7:0] ss_batrider_storage_select = active_is_batrider ?
                                        SS_SELECT : 8'hff;
wire [7:0] ss_bakraid_storage_select = active_is_bakraid ?
                                       SS_SELECT : 8'hff;

raizing_main_cpu #(.SS_ENABLE(SS_ENABLE)) u_cpu (
    .CLK(CLK),
    .CLK96(CLK96),
    .RESET(RESET),
    .RESET96(RESET96),
    .GAME_ID(GAME_ID),
    .CEN16(CEN16),
    .CEN16B(CEN16B),
    .BUSACK(BUSACK),
    .BR(active_is_battle ? TVRAM_BR : 1'b0),
    .DOUT(CPU_DOUT),
    .ADDR(CPU_ADDR),
    .RW(CPU_RW),
    .RD(CPU_RD),
    .LDS(CPU_LDS),
    .LDSWR(CPU_LDSWR),
    .LTABLECS(),
    .VCOUNTCS(),
    .Z80RST(),
    .M68K_RESET_N(M68K_RESET_N),
    .LVBL(CPU_LVBLL),
    .V(CPU_V),
    .FLIP(FLIP),
    .JOYMODE(2'b00),
    .JOYSTICK1(joystick1),
    .JOYSTICK2(joystick2),
    .START_BUTTON(cab_1p),
    .COIN_INPUT(coin),
    .SERVICE(service),
    .TILT(1'b0),
    .DIPSW_A(DIPSW_A),
    .DIPSW_B(DIPSW_B),
    .DIPSW_C(DIPSW_C),
    .DIP_TEST(DIP_TEST),
    .DIP_PAUSE(DIP_PAUSE),
    .CPU_PRG_CS(ROM68K_CS),
    .CPU_PRG_OK(ROM68K_OK),
    .CPU_PRG_ADDR(ROM68K_ADDR),
    .CPU_PRG_DATA(ROM68K_DOUT),
    .Z80_PRG_CS(Z80_PRG_CS),
    .Z80_PRG_OK(Z80_PRG_OK),
    .Z80_PRG_ADDR(Z80_PRG_ADDR),
    .Z80_PRG_DATA(Z80_PRG_DOUT),
    .DMA_RAM_CS(DMA_RAM_CS),
    .DMA_RAM_DOUT(DMA_RAM_DOUT),
    .DMA_RAM_ADDR(DMA_RAM_ADDR),
    .BATRIDER_TEXTDATA_DMA_W(BATRIDER_TEXTDATA_DMA_W),
    .BATRIDER_PAL_TEXT_DMA_W(BATRIDER_PAL_TEXT_DMA_W),
    .TVRAMCTL_BUSY(TVRAM_BR),
    .TVRAM_CS(TVRAM_CS),
    .TVRAM_WE(TVRAM_WE),
    .TVRAM_DS(TVRAM_DS),
    .TVRAM_WR_ADDR(TVRAM_WR_ADDR),
    .TVRAM_DIN(TVRAM_DIN),
    .GP9001CS(GP9001CS),
    .GP9001ACK(GP9001ACK),
    .VINT(VINT),
    .GP9001_OP_SELECT_REG(GP9001_OP_SELECT_REG),
    .GP9001_OP_WRITE_REG(GP9001_OP_WRITE_REG),
    .GP9001_OP_WRITE_RAM(GP9001_OP_WRITE_RAM),
    .GP9001_OP_READ_RAM_H(GP9001_OP_READ_RAM_H),
    .GP9001_OP_READ_RAM_L(GP9001_OP_READ_RAM_L),
    .GP9001_OP_SET_RAM_PTR(GP9001_OP_SET_RAM_PTR),
    .GP9001_OP_OBJECTBANK_WR(GP9001_OP_OBJECTBANK_WR),
    .GP9001_OBJECTBANK_SLOT(GP9001_OBJECTBANK_SLOT),
    .GP9001_DOUT(GCU_DOUT),
    .HSYNC(HSYNC),
    .VSYNC(VSYNC),
    .FBLANK(FBLANK),
    .TEXTVRAM_ADDR(g_TEXTVRAM_READ_ADDR),
    .TEXTVRAM_DATA(g_TEXTVRAM_DATA),
    .PALRAM_ADDR(g_PALRAM_READ_ADDR),
    .PALRAM_DATA(g_PALRAM_DATA),
    .TEXTSELECT_ADDR(g_TEXTSELECT_READ_ADDR),
    .TEXTSELECT_DATA(g_TEXTSELECT_DATA),
    .TEXTSCROLL_ADDR(g_TEXTSCROLL_READ_ADDR),
    .TEXTSCROLL_DATA(g_TEXTSCROLL_DATA),
    .GAREGGA_SOUNDLATCH(g_SOUNDLATCH),
    .GAREGGA_SRAM_ADDR(g_SRAM_ADDR),
    .GAREGGA_SRAM_DATA(g_SRAM_DATA),
    .GAREGGA_SRAM_DIN(g_SRAM_DIN),
    .GAREGGA_SRAM_WE(g_SRAM_WE),
    .GAREGGA_Z80INT(g_Z80INT),
    .OKI_BANK(OKI_BANK),
    .SOUNDLATCH3(SOUNDLATCH3),
    .SOUNDLATCH4(SOUNDLATCH4),
    .SOUNDLATCH(SOUNDLATCH),
    .SOUNDLATCH2(SOUNDLATCH2),
    .Z80WAIT(Z80WAIT),
    .Z80CS(Z80CS),
    .NMI(NMI),
    .SNDIRQ(SNDIRQ),
    .SOUNDLATCH_ACK(SOUNDLATCH_ACK),
    .SOUNDLATCH_ACK_INCOMING(SOUNDLATCH_ACK_INCOMING),
    .HISCORE_CS(HISCORE_CS),
    .HISCORE_WE(HISCORE_WE),
    .HISCORE_DIN(HISCORE_DIN),
    .HISCORE_DOUT(HISCORE_DOUT),
    .HISCORE_ADDR(HISCORE_ADDR),
    .EEPROM_SCLK(EEPROM_SCLK),
    .EEPROM_SDI(EEPROM_SDI),
    .EEPROM_SDO(EEPROM_SDO),
    .EEPROM_SCS(EEPROM_SCS),
    .SS_FREEZE(SS_FREEZE),
    .SS_SAVE_BEGIN(SS_SAVE_BEGIN),
    .SS_SAVE_RESUME(SS_SAVE_RESUME),
    .SS_RESTORE_BEGIN(SS_RESTORE_BEGIN),
    .SS_RESTORE_WINDOW(SS_RESTORE_WINDOW),
    .SS_SAVE_READY(SS_SAVE_READY),
    .SS_SAVE_DONE(SS_SAVE_DONE),
    .SS_RESTORE_DONE(ss_main_restore_done),
    .SS_BUSY(ss_cpu_busy),
    .SS_CPU_IDLE(ss_cpu_idle),
    .SS_DATA(SS_DATA),
    .SS_ADDR(SS_ADDR),
    .SS_SELECT(SS_SELECT),
    .SS_WRITE(SS_WRITE),
    .SS_READ(SS_READ),
    .SS_QUERY(SS_QUERY),
    .SS_DATA_OUT(ss_cpu_data_out),
    .SS_ACK(ss_cpu_ack)
);

/* video */
wire g_GFX_CS, g_GFX_OK, g_GFXSCR0_CS, g_GFXSCR0_OK;
wire g_GFXSCR1_CS, g_GFXSCR1_OK, g_GFXSCR2_CS, g_GFXSCR2_OK;
wire [21:0] g_GFX0_ADDR, g_GFX0SCR0_ADDR, g_GFX0SCR1_ADDR, g_GFX0SCR2_ADDR;
wire [31:0] g_GFX0_DOUT, g_GFX0SCR0_DOUT, g_GFX0SCR1_DOUT, g_GFX0SCR2_DOUT;

wire [1:0] b_GFX_CS, b_GFX_OK, b_GFXSCR0_CS, b_GFXSCR0_OK;
wire [1:0] b_GFXSCR1_CS, b_GFXSCR1_OK, b_GFXSCR2_CS, b_GFXSCR2_OK;
wire [21:0] b_GFX0_ADDR, b_GFX1_ADDR, b_GFX0SCR0_ADDR, b_GFX1SCR0_ADDR;
wire [21:0] b_GFX0SCR1_ADDR, b_GFX1SCR1_ADDR, b_GFX0SCR2_ADDR, b_GFX1SCR2_ADDR;
wire [31:0] b_GFX0_DOUT, b_GFX1_DOUT, b_GFX0SCR0_DOUT, b_GFX1SCR0_DOUT;
wire [31:0] b_GFX0SCR1_DOUT, b_GFX1SCR1_DOUT, b_GFX0SCR2_DOUT, b_GFX1SCR2_DOUT;

wire [1:0] v_GFX_CS, v_GFXSCR0_CS, v_GFXSCR1_CS, v_GFXSCR2_CS;
wire [21:0] v_GFX0_ADDR, v_GFX1_ADDR, v_GFX0SCR0_ADDR, v_GFX1SCR0_ADDR;
wire [21:0] v_GFX0SCR1_ADDR, v_GFX1SCR1_ADDR, v_GFX0SCR2_ADDR, v_GFX1SCR2_ADDR;
wire [1:0] v_GFX_OK = active_is_garegga ? {1'b0, g_GFX_OK} : b_GFX_OK;
wire [1:0] v_GFXSCR0_OK = active_is_garegga ? {1'b0, g_GFXSCR0_OK} : b_GFXSCR0_OK;
wire [1:0] v_GFXSCR1_OK = active_is_garegga ? {1'b0, g_GFXSCR1_OK} : b_GFXSCR1_OK;
wire [1:0] v_GFXSCR2_OK = active_is_garegga ? {1'b0, g_GFXSCR2_OK} : b_GFXSCR2_OK;
wire [31:0] v_GFX0_DOUT = active_is_garegga ? g_GFX0_DOUT : b_GFX0_DOUT;
wire [31:0] v_GFX0SCR0_DOUT = active_is_garegga ? g_GFX0SCR0_DOUT : b_GFX0SCR0_DOUT;
wire [31:0] v_GFX0SCR1_DOUT = active_is_garegga ? g_GFX0SCR1_DOUT : b_GFX0SCR1_DOUT;
wire [31:0] v_GFX0SCR2_DOUT = active_is_garegga ? g_GFX0SCR2_DOUT : b_GFX0SCR2_DOUT;

assign g_GFX_CS = v_GFX_CS[0] & active_is_garegga;
assign g_GFXSCR0_CS = v_GFXSCR0_CS[0] & active_is_garegga;
assign g_GFXSCR1_CS = v_GFXSCR1_CS[0] & active_is_garegga;
assign g_GFXSCR2_CS = v_GFXSCR2_CS[0] & active_is_garegga;
assign b_GFX_CS = v_GFX_CS & {2{active_is_battle}};
assign b_GFXSCR0_CS = v_GFXSCR0_CS & {2{active_is_battle}};
assign b_GFXSCR1_CS = v_GFXSCR1_CS & {2{active_is_battle}};
assign b_GFXSCR2_CS = v_GFXSCR2_CS & {2{active_is_battle}};

assign g_GFX0_ADDR = v_GFX0_ADDR;
assign g_GFX0SCR0_ADDR = v_GFX0SCR0_ADDR;
assign g_GFX0SCR1_ADDR = v_GFX0SCR1_ADDR;
assign g_GFX0SCR2_ADDR = v_GFX0SCR2_ADDR;
assign b_GFX0_ADDR = v_GFX0_ADDR;
assign b_GFX1_ADDR = v_GFX1_ADDR;
assign b_GFX0SCR0_ADDR = v_GFX0SCR0_ADDR;
assign b_GFX1SCR0_ADDR = v_GFX1SCR0_ADDR;
assign b_GFX0SCR1_ADDR = v_GFX0SCR1_ADDR;
assign b_GFX1SCR1_ADDR = v_GFX1SCR1_ADDR;
assign b_GFX0SCR2_ADDR = v_GFX0SCR2_ADDR;
assign b_GFX1SCR2_ADDR = v_GFX1SCR2_ADDR;

wire [10:0] v_PALRAM_ADDR;
wire [13:0] v_TEXTROM_ADDR;
wire [11:0] v_TEXTVRAM_ADDR;
wire [7:0] v_TEXTSELECT_ADDR, v_TEXTSCROLL_ADDR;
assign g_PALRAM_ADDR = v_PALRAM_ADDR;
assign b_PALRAM_ADDR = v_PALRAM_ADDR;
assign g_TEXTROM_ADDR = v_TEXTROM_ADDR;
assign b_TEXTROM_ADDR = v_TEXTROM_ADDR;
assign g_TEXTVRAM_ADDR = v_TEXTVRAM_ADDR;
assign b_TEXTVRAM_ADDR = v_TEXTVRAM_ADDR;
assign g_TEXTSELECT_ADDR = v_TEXTSELECT_ADDR;
assign b_TEXTSELECT_ADDR = v_TEXTSELECT_ADDR;
assign g_TEXTSCROLL_ADDR = v_TEXTSCROLL_ADDR;
assign b_TEXTSCROLL_ADDR = v_TEXTSCROLL_ADDR;

TVRMCTL7 #(.SS_ENABLE(SS_ENABLE)) u_textvramctl (
    .CLK(CLK),
    .RESET(RESET | !active_is_battle),
    .CLK96(CLK96),
    .RESET96(RESET96 | !active_is_battle),
    .BUSACK(BUSACK),
    .BUSREQ(TVRAM_BR),
    .BATRIDER_TEXTDATA_DMA_W(BATRIDER_TEXTDATA_DMA_W),
    .BATRIDER_PAL_TEXT_DMA_W(BATRIDER_PAL_TEXT_DMA_W),
    .BUSY(TEXTDMA_BUSY),
    .TVRAM_CS(TVRAM_CS),
    .TVRAM_WE(TVRAM_WE),
    .TVRAM_DS(TVRAM_DS),
    .TVRAM_WR_ADDR(TVRAM_WR_ADDR),
    .TVRAM_DIN(TVRAM_DIN),
    .DMA_RAM_CS(DMA_RAM_CS),
    .DMA_RAM_ADDR(DMA_RAM_ADDR),
    .DMA_RAM_DATA(DMA_RAM_DOUT),
    .GP9001OUT(GP9001OUT),
    .TEXTROM_ADDR(b_TEXTROM_ADDR),
    .TEXTROM_DATA(b_TEXTROM_DATA),
    .TEXTVRAM_ADDR(b_TEXTVRAM_ADDR),
    .TEXTVRAM_DATA(b_TEXTVRAM_DATA),
    .TEXTSELECT_ADDR(b_TEXTSELECT_ADDR),
    .TEXTSELECT_DATA(b_TEXTSELECT_DATA),
    .TEXTSCROLL_ADDR(b_TEXTSCROLL_ADDR),
    .TEXTSCROLL_DATA(b_TEXTSCROLL_DATA),
    .PALRAM_ADDR(b_PALRAM_ADDR),
    .PALRAM_DATA(b_PALRAM_DATA),
    .TEXTGFXRAM_ADDR(TEXTGFXRAM_ADDR),
    .TEXTGFXRAM_DATA(TEXTGFXRAM_DATA),
    .SS_FREEZE(SS_FREEZE),
    .SS_DATA(SS_DATA),
    .SS_ADDR(SS_ADDR),
    .SS_SELECT(ss_text_select),
    .SS_WRITE(SS_WRITE),
    .SS_READ(SS_READ),
    .SS_QUERY(SS_QUERY),
    .SS_DATA_OUT(ss_text_data_out),
    .SS_ACK(ss_text_ack),
    .SS_QUIESCED(ss_text_quiesced)
);

raizing_video #(.SS_ENABLE(SS_ENABLE)) u_video(
    .CLK(CLK),
    .CLK96(CLK96),
    .PIXEL_CEN(CEN675),
    .RESET(RESET),
    .RESET96(RESET96),
    .PALRAM_ADDR(v_PALRAM_ADDR),
    .PALRAM_DATA(active_is_garegga ? g_PALRAM_DATA : b_PALRAM_DATA),
    .TEXTROM_ADDR(v_TEXTROM_ADDR),
    .TEXTROM_DATA(active_is_garegga ? g_TEXTROM_DATA : b_TEXTROM_DATA),
    .TEXTVRAM_ADDR(v_TEXTVRAM_ADDR),
    .TEXTVRAM_DATA(active_is_garegga ? g_TEXTVRAM_DATA : b_TEXTVRAM_DATA),
    .TEXTSELECT_ADDR(v_TEXTSELECT_ADDR),
    .TEXTSELECT_DATA(active_is_garegga ? g_TEXTSELECT_DATA : b_TEXTSELECT_DATA),
    .TEXTSCROLL_ADDR(v_TEXTSCROLL_ADDR),
    .TEXTSCROLL_DATA(active_is_garegga ? g_TEXTSCROLL_DATA : b_TEXTSCROLL_DATA),
    .SHIFT_SPRITE_PRI(GAME_ID == RAIZING_SSTRIKER),
    .FAST_OBJ_QUEUE(GAME_ID == RAIZING_GAREGGA),
    .GFX_CS(v_GFX_CS),
    .GFX_OK(v_GFX_OK),
    .GFX0_ADDR(v_GFX0_ADDR),
    .GFX0_DOUT(v_GFX0_DOUT),
    .GFX1_ADDR(v_GFX1_ADDR),
    .GFX1_DOUT(b_GFX1_DOUT),
    .GFXSCR0_CS(v_GFXSCR0_CS),
    .GFXSCR0_OK(v_GFXSCR0_OK),
    .GFX0SCR0_ADDR(v_GFX0SCR0_ADDR),
    .GFX0SCR0_DOUT(v_GFX0SCR0_DOUT),
    .GFX1SCR0_ADDR(v_GFX1SCR0_ADDR),
    .GFX1SCR0_DOUT(b_GFX1SCR0_DOUT),
    .GFXSCR1_CS(v_GFXSCR1_CS),
    .GFXSCR1_OK(v_GFXSCR1_OK),
    .GFX0SCR1_ADDR(v_GFX0SCR1_ADDR),
    .GFX0SCR1_DOUT(v_GFX0SCR1_DOUT),
    .GFX1SCR1_ADDR(v_GFX1SCR1_ADDR),
    .GFX1SCR1_DOUT(b_GFX1SCR1_DOUT),
    .GFXSCR2_CS(v_GFXSCR2_CS),
    .GFXSCR2_OK(v_GFXSCR2_OK),
    .GFX0SCR2_ADDR(v_GFX0SCR2_ADDR),
    .GFX0SCR2_DOUT(v_GFX0SCR2_DOUT),
    .GFX1SCR2_ADDR(v_GFX1SCR2_ADDR),
    .GFX1SCR2_DOUT(b_GFX1SCR2_DOUT),
    .GP9001CS(GP9001CS),
    .GP9001ACK(GP9001ACK),
    .VINT(VINT),
    .GP9001DIN(CPU_DOUT),
    .GP9001DOUT(GCU_DOUT),
    .GP9001_OP_SELECT_REG(GP9001_OP_SELECT_REG),
    .GP9001_OP_WRITE_REG(GP9001_OP_WRITE_REG),
    .GP9001_OP_WRITE_RAM(GP9001_OP_WRITE_RAM),
    .GP9001_OP_READ_RAM_H(GP9001_OP_READ_RAM_H),
    .GP9001_OP_READ_RAM_L(GP9001_OP_READ_RAM_L),
    .GP9001_OP_SET_RAM_PTR(GP9001_OP_SET_RAM_PTR),
    .GP9001_OP_OBJECTBANK_WR(GP9001_OP_OBJECTBANK_WR),
    .GP9001_OBJECTBANK_SLOT(GP9001_OBJECTBANK_SLOT),
    .GP9001OUT(GP9001OUT),
    .LVBL_DLY(LVBL),
    .LHBL_DLY(LHBL),
    .LVBL(CPU_LVBLL),
    .LHBL(),
    .HS(HS),
    .VS(VS),
    .CPU_HSYNC(HSYNC),
    .CPU_VSYNC(VSYNC),
    .CPU_FBLANK(FBLANK),
    .V(CPU_V),
    .RED(red),
    .GREEN(green),
    .BLUE(blue),
    .GAME(GAME_ID),
    .HS_START(active_is_garegga ? 9'd325 : 9'd0),
    .HS_END(active_is_garegga ? 9'd380 : 9'd0),
    .VS_START(active_is_garegga ? 9'd232 : 9'd0),
    .VS_END(active_is_garegga ? 9'd245 : 9'd0),
    .FLIP(1'b0),
    .SS_FREEZE(SS_FREEZE),
    .SS_DATA(SS_DATA),
    .SS_ADDR(SS_ADDR),
    .SS_SELECT(SS_SELECT),
    .SS_WRITE(SS_WRITE),
    .SS_READ(SS_READ),
    .SS_QUERY(SS_QUERY),
    .SS_DATA_OUT(ss_video_data_out),
    .SS_ACK(ss_video_ack),
    .SS_QUIESCED(ss_video_quiesced)
);

/* sound */
wire signed [15:0] g_snd_left, g_snd_right, b_snd_left, b_snd_right, k_snd_left, k_snd_right;
wire g_sample, b_sample, k_sample, g_snd_peak, b_snd_peak, k_snd_peak;
wire g_ROMZ80_CS, g_ROMZ80_OK;
wire [16:0] g_ROMZ80_ADDR;
wire [7:0] g_ROMZ80_DOUT;
wire g_PCM_CS, g_PCM_OK;
wire [19:0] g_PCM_ADDR;
wire [7:0] g_PCM_DOUT;
wire b_ROMZ801_CS, b_ROMZ801_OK, k_ROMZ801_CS, k_ROMZ801_OK;
wire [17:0] b_ROMZ801_ADDR, k_ROMZ801_ADDR;
wire [7:0] b_ROMZ801_DOUT, k_ROMZ801_DOUT;
wire b_PCM_CS, b_PCM_OK, b_PCM1_CS, b_PCM1_OK;
wire [20:0] b_PCM_ADDR, b_PCM1_ADDR;
wire [7:0] b_PCM_DOUT, b_PCM1_DOUT;
wire k_PCM_CS, k_PCM_OK, k_PCM1_CS, k_PCM1_OK, k_PCM2_CS, k_PCM2_OK;
wire [21:0] k_PCM_ADDR, k_PCM1_ADDR, k_PCM2_ADDR;
wire [7:0] k_PCM_DOUT, k_PCM1_DOUT, k_PCM2_DOUT;

wire g_fm_cen_out, g_fm_cen_p1_out, g_fm_cs_n_out, g_fm_wr_n_out, g_fm_a0_out;
wire [7:0] g_fm_din_out;
wire g_oki0_cen_out, g_oki0_ss_out, g_oki0_wr_n_out;
wire [7:0] g_oki0_din_out, g_oki0_rom_data_out;
wire g_oki0_rom_ok_out;

wire b_fm_cen_out, b_fm_cen_p1_out, b_fm_cs_n_out, b_fm_wr_n_out, b_fm_a0_out;
wire [7:0] b_fm_din_out;
wire b_oki0_cen_out, b_oki0_ss_out, b_oki0_wr_n_out;
wire [7:0] b_oki0_din_out, b_oki0_rom_data_out;
wire b_oki0_rom_ok_out;
wire b_oki1_cen_out, b_oki1_ss_out, b_oki1_wr_n_out;
wire [7:0] b_oki1_din_out, b_oki1_rom_data_out;
wire b_oki1_rom_ok_out;

wire [7:0] jt_fm_dout, jt_oki0_dout, jt_oki1_dout;
wire jt_fm_irq_n, jt_fm_sample, jt_oki0_sample, jt_oki1_sample;
wire signed [15:0] jt_fm_xleft, jt_fm_xright;
wire signed [13:0] jt_oki0_sound, jt_oki1_sound;
wire [17:0] jt_oki0_rom_addr, jt_oki1_rom_addr;

garegga_sound #(
    .EXTERNAL_CHIPS(1),
    .SS_ENABLE(SS_ENABLE)
) u_garegga_sound(
    .CLK(CLK),
    .CLK96(CLK96),
    .RESET(RESET | !active_is_garegga),
    .RESET96(RESET96 | !active_is_garegga),
    .YM2151_CEN(g_CEN4),
    .YM2151_CEN2(g_CEN2),
    .OKI_CEN(g_CEN2),
    .YM2151_CEN_1(g_CEN3p375),
    .YM2151_CEN2_1(g_CEN1p6875),
    .OKI_CEN_1(g_CEN1),
    .Z80_CEN(g_CEN4),
    .ROMZ80_CS(g_ROMZ80_CS),
    .ROMZ80_OK(g_ROMZ80_OK),
    .ROMZ80_ADDR(g_ROMZ80_ADDR),
    .ROMZ80_DOUT(g_ROMZ80_DOUT),
    .PCM_CS(g_PCM_CS),
    .PCM_OK(g_PCM_OK),
    .PCM_ADDR(g_PCM_ADDR),
    .PCM_DOUT(g_PCM_DOUT),
    .left(g_snd_left),
    .right(g_snd_right),
    .sample(g_sample),
    .peak(g_snd_peak),
    .Z80INT(g_Z80INT),
    .WAIT(g_Z80WAIT),
    .M68K_RESET_N(M68K_RESET_N),
    .SOUNDLATCH(g_SOUNDLATCH),
    .SRAM_ADDR(g_SRAM_ADDR),
    .SRAM_DATA(g_SRAM_DATA),
    .SRAM_DIN(g_SRAM_DIN),
    .SRAM_WE(g_SRAM_WE),
    .OKI_BANK(OKI_BANK),
    .GAME(GAME_ID),
    .FX_LEVEL(dip_fxlevel),
    .SND_EN(g_sound_en),
    .DIP_PAUSE(DIP_PAUSE),
    .FM_CEN_OUT(g_fm_cen_out),
    .FM_CEN_P1_OUT(g_fm_cen_p1_out),
    .FM_CS_N_OUT(g_fm_cs_n_out),
    .FM_WR_N_OUT(g_fm_wr_n_out),
    .FM_A0_OUT(g_fm_a0_out),
    .FM_DIN_OUT(g_fm_din_out),
    .FM_DOUT_IN(jt_fm_dout),
    .FM_IRQ_N_IN(jt_fm_irq_n),
    .FM_SAMPLE_IN(jt_fm_sample),
    .FM_XLEFT_IN(jt_fm_xleft),
    .FM_XRIGHT_IN(jt_fm_xright),
    .OKI0_CEN_OUT(g_oki0_cen_out),
    .OKI0_SS_OUT(g_oki0_ss_out),
    .OKI0_WR_N_OUT(g_oki0_wr_n_out),
    .OKI0_DIN_OUT(g_oki0_din_out),
    .OKI0_DOUT_IN(jt_oki0_dout),
    .OKI0_ROM_ADDR_IN(jt_oki0_rom_addr),
    .OKI0_ROM_DATA_OUT(g_oki0_rom_data_out),
    .OKI0_ROM_OK_OUT(g_oki0_rom_ok_out),
    .OKI0_SOUND_IN(jt_oki0_sound),
    .OKI0_SAMPLE_IN(jt_oki0_sample),
    .SS_ACTIVE(SS_ACTIVE && active_is_garegga),
    .SS_FREEZE(SS_FREEZE),
    .SS_RESTORE_BEGIN(SS_RESTORE_BEGIN),
    .SS_DATA(SS_DATA),
    .SS_ADDR(SS_ADDR),
    .SS_SELECT(SS_SELECT),
    .SS_WRITE(SS_WRITE),
    .SS_READ(SS_READ),
    .SS_QUERY(SS_QUERY),
    .SS_DATA_OUT(ss_garegga_sound_data_out),
    .SS_ACK(ss_garegga_sound_ack),
    .SS_QUIESCED(ss_garegga_sound_quiesced)
);

batrider_sound #(
    .EXTERNAL_CHIPS(1),
    .SS_ENABLE(SS_ENABLE)
) u_batrider_sound(
    .CLK(CLK),
    .CLK96(CLK96),
    .RESET(RESET | !active_is_batrider),
    .RESET96(RESET96 | !active_is_batrider),
    .YM2151_CEN(b_CEN4),
    .YM2151_CEN2(b_CEN2),
    .Z80_CEN(b_CEN5333),
    .OKI_CEN(b_CEN3p2),
    .CS(Z80CS & active_is_batrider),
    .WAIT(b_Z80WAIT),
    .SNDIRQ(b_SNDIRQ),
    .NMI(NMI),
    .SOUNDLATCH3(b_SOUNDLATCH3),
    .SOUNDLATCH4(b_SOUNDLATCH4),
    .SOUNDLATCH(SOUNDLATCH),
    .SOUNDLATCH2(SOUNDLATCH2),
    .SND_EN(b_sound_en),
    .ROMZ80_CS(b_ROMZ801_CS),
    .ROMZ80_OK(b_ROMZ801_OK),
    .ROMZ80_ADDR(b_ROMZ801_ADDR),
    .ROMZ80_DOUT(b_ROMZ801_DOUT),
    .PCM_CS(b_PCM_CS),
    .PCM_OK(b_PCM_OK),
    .PCM_ADDR(b_PCM_ADDR),
    .PCM_DOUT(b_PCM_DOUT),
    .PCM1_CS(b_PCM1_CS),
    .PCM1_OK(b_PCM1_OK),
    .PCM1_ADDR(b_PCM1_ADDR),
    .PCM1_DOUT(b_PCM1_DOUT),
    .left(b_snd_left),
    .right(b_snd_right),
    .sample(b_sample),
    .peak(b_snd_peak),
    .FX_LEVEL(dip_fxlevel),
    .DIP_PAUSE(DIP_PAUSE),
    .FM_CEN_OUT(b_fm_cen_out),
    .FM_CEN_P1_OUT(b_fm_cen_p1_out),
    .FM_CS_N_OUT(b_fm_cs_n_out),
    .FM_WR_N_OUT(b_fm_wr_n_out),
    .FM_A0_OUT(b_fm_a0_out),
    .FM_DIN_OUT(b_fm_din_out),
    .FM_DOUT_IN(jt_fm_dout),
    .FM_IRQ_N_IN(jt_fm_irq_n),
    .FM_SAMPLE_IN(jt_fm_sample),
    .FM_XLEFT_IN(jt_fm_xleft),
    .FM_XRIGHT_IN(jt_fm_xright),
    .OKI0_CEN_OUT(b_oki0_cen_out),
    .OKI0_SS_OUT(b_oki0_ss_out),
    .OKI0_WR_N_OUT(b_oki0_wr_n_out),
    .OKI0_DIN_OUT(b_oki0_din_out),
    .OKI0_DOUT_IN(jt_oki0_dout),
    .OKI0_ROM_ADDR_IN(jt_oki0_rom_addr),
    .OKI0_ROM_DATA_OUT(b_oki0_rom_data_out),
    .OKI0_ROM_OK_OUT(b_oki0_rom_ok_out),
    .OKI0_SOUND_IN(jt_oki0_sound),
    .OKI0_SAMPLE_IN(jt_oki0_sample),
    .OKI1_CEN_OUT(b_oki1_cen_out),
    .OKI1_SS_OUT(b_oki1_ss_out),
    .OKI1_WR_N_OUT(b_oki1_wr_n_out),
    .OKI1_DIN_OUT(b_oki1_din_out),
    .OKI1_DOUT_IN(jt_oki1_dout),
    .OKI1_ROM_ADDR_IN(jt_oki1_rom_addr),
    .OKI1_ROM_DATA_OUT(b_oki1_rom_data_out),
    .OKI1_ROM_OK_OUT(b_oki1_rom_ok_out),
    .OKI1_SOUND_IN(jt_oki1_sound),
    .OKI1_SAMPLE_IN(jt_oki1_sample),
    .SS_ACTIVE(SS_ACTIVE && active_is_batrider),
    .SS_FREEZE(SS_FREEZE),
    .SS_RESTORE_BEGIN(SS_RESTORE_BEGIN),
    .SS_DATA(SS_DATA),
    .SS_ADDR(SS_ADDR),
    .SS_SELECT(SS_SELECT),
    .SS_WRITE(SS_WRITE),
    .SS_READ(SS_READ),
    .SS_QUERY(SS_QUERY),
    .SS_DATA_OUT(ss_batrider_sound_data_out),
    .SS_ACK(ss_batrider_sound_ack),
    .SS_QUIESCED(ss_batrider_sound_quiesced)
);

raizing_shared_jt_audio #(.SS_ENABLE(SS_ENABLE)) u_shared_jt_audio(
    .CLK96(CLK96),
    .RESET96(RESET96),
    .ACTIVE(active_is_garegga | active_is_batrider),
    .FM_CEN(active_is_garegga ? g_fm_cen_out : b_fm_cen_out),
    .FM_CEN_P1(active_is_garegga ? g_fm_cen_p1_out : b_fm_cen_p1_out),
    .FM_REPLAY_CEN(active_is_garegga ?
        ((GAME_ID == RAIZING_SSTRIKER || GAME_ID == RAIZING_KINGDMGP) ?
            g_CEN3p375 : g_CEN4) : b_CEN4),
    .FM_REPLAY_CEN_P1(active_is_garegga ?
        ((GAME_ID == RAIZING_SSTRIKER || GAME_ID == RAIZING_KINGDMGP) ?
            g_CEN1p6875 : g_CEN2) : b_CEN2),
    .FM_CS_N(active_is_garegga ? g_fm_cs_n_out : b_fm_cs_n_out),
    .FM_WR_N(active_is_garegga ? g_fm_wr_n_out : b_fm_wr_n_out),
    .FM_A0(active_is_garegga ? g_fm_a0_out : b_fm_a0_out),
    .FM_DIN(active_is_garegga ? g_fm_din_out : b_fm_din_out),
    .FM_DOUT(jt_fm_dout),
    .FM_IRQ_N(jt_fm_irq_n),
    .FM_SAMPLE(jt_fm_sample),
    .FM_XLEFT(jt_fm_xleft),
    .FM_XRIGHT(jt_fm_xright),
    .OKI0_CEN(active_is_garegga ? g_oki0_cen_out : b_oki0_cen_out),
    .OKI0_SS(active_is_garegga ? g_oki0_ss_out : b_oki0_ss_out),
    .OKI0_WR_N(active_is_garegga ? g_oki0_wr_n_out : b_oki0_wr_n_out),
    .OKI0_DIN(active_is_garegga ? g_oki0_din_out : b_oki0_din_out),
    .OKI0_DOUT(jt_oki0_dout),
    .OKI0_ROM_ADDR(jt_oki0_rom_addr),
    .OKI0_ROM_DATA(active_is_garegga ? g_oki0_rom_data_out : b_oki0_rom_data_out),
    .OKI0_ROM_OK(active_is_garegga ? g_oki0_rom_ok_out : b_oki0_rom_ok_out),
    .OKI0_SOUND(jt_oki0_sound),
    .OKI0_SAMPLE(jt_oki0_sample),
    .OKI1_CEN(active_is_batrider ? b_oki1_cen_out : 1'b0),
    .OKI1_SS(active_is_batrider ? b_oki1_ss_out : 1'b0),
    .OKI1_WR_N(active_is_batrider ? b_oki1_wr_n_out : 1'b1),
    .OKI1_DIN(active_is_batrider ? b_oki1_din_out : 8'd0),
    .OKI1_DOUT(jt_oki1_dout),
    .OKI1_ROM_ADDR(jt_oki1_rom_addr),
    .OKI1_ROM_DATA(active_is_batrider ? b_oki1_rom_data_out : 8'd0),
    .OKI1_ROM_OK(active_is_batrider ? b_oki1_rom_ok_out : 1'b0),
    .OKI1_SOUND(jt_oki1_sound),
    .OKI1_SAMPLE(jt_oki1_sample),
    .SS_RESTORE_BEGIN(SS_RESTORE_BEGIN),
    .SS_DATA(SS_DATA),
    .SS_ADDR(SS_ADDR),
    .SS_SELECT(SS_SELECT),
    .SS_WRITE(SS_WRITE),
    .SS_READ(SS_READ),
    .SS_QUERY(SS_QUERY),
    .SS_DATA_OUT(ss_shared_audio_data_out),
    .SS_ACK(ss_shared_audio_ack),
    .SS_REPLAY_BUSY(ss_shared_audio_replay_busy)
);

bakraid_sound #(.SS_ENABLE(SS_ENABLE)) u_bakraid_sound(
    .CLK(CLK),
    .CLK96(CLK96),
    .RESET(RESET | !active_is_bakraid),
    .RESET96(RESET96 | !active_is_bakraid),
    .Z80_CEN(k_CEN5333),
    .YMZ_CEN(k_CEN16p9344),
    .CS(Z80CS & active_is_bakraid),
    .WAIT(k_Z80WAIT),
    .SNDIRQ(k_SNDIRQ),
    .NMI(NMI),
    .SOUNDLATCH3(k_SOUNDLATCH3),
    .SOUNDLATCH4(k_SOUNDLATCH4),
    .SOUNDLATCH(SOUNDLATCH),
    .SOUNDLATCH2(SOUNDLATCH2),
    .SOUNDLATCH_ACK(SOUNDLATCH_ACK_INCOMING),
    .SOUNDLATCH_ACK_INCOMING(SOUNDLATCH_ACK),
    .ROMZ80_CS(k_ROMZ801_CS),
    .ROMZ80_OK(k_ROMZ801_OK),
    .ROMZ80_ADDR(k_ROMZ801_ADDR),
    .ROMZ80_DOUT(k_ROMZ801_DOUT),
    .PCM_CS(k_PCM_CS),
    .PCM_OK(k_PCM_OK),
    .PCM_ADDR(k_PCM_ADDR),
    .PCM_DOUT(k_PCM_DOUT),
    .PCM1_CS(k_PCM1_CS),
    .PCM1_OK(k_PCM1_OK),
    .PCM1_ADDR(k_PCM1_ADDR),
    .PCM1_DOUT(k_PCM1_DOUT),
    .PCM2_CS(k_PCM2_CS),
    .PCM2_OK(k_PCM2_OK),
    .PCM2_ADDR(k_PCM2_ADDR),
    .PCM2_DOUT(k_PCM2_DOUT),
    .left(k_snd_left),
    .right(k_snd_right),
    .sample(k_sample),
    .peak(k_snd_peak),
    .FX_LEVEL(dip_fxlevel),
    .SS_ACTIVE(SS_ACTIVE && active_is_bakraid),
    .SS_FREEZE(SS_FREEZE),
    .SS_RESTORE_BEGIN(SS_RESTORE_BEGIN),
    .SS_DATA(SS_DATA),
    .SS_ADDR(SS_ADDR),
    .SS_SELECT(SS_SELECT),
    .SS_WRITE(SS_WRITE),
    .SS_READ(SS_READ),
    .SS_QUERY(SS_QUERY),
    .SS_DATA_OUT(ss_bakraid_sound_data_out),
    .SS_ACK(ss_bakraid_sound_ack),
    .SS_QUIESCED(ss_bakraid_sound_quiesced),
    .SS_REPLAY_BUSY(ss_bakraid_audio_replay_busy)
);

assign snd_left  = active_is_garegga ? g_snd_left  : active_is_bakraid ? k_snd_left  : b_snd_left;
assign snd_right = active_is_garegga ? g_snd_right : active_is_bakraid ? k_snd_right : b_snd_right;
assign sample    = active_is_garegga ? g_sample    : active_is_bakraid ? k_sample    : b_sample;
assign snd_peak  = active_is_garegga ? g_snd_peak  : active_is_bakraid ? k_snd_peak  : b_snd_peak;
assign snd_vu    = 8'd0;

/* SDRAM */
wire [21:0] g_ba0_addr, g_ba1_addr, g_ba2_addr, g_ba3_addr;
wire [21:0] b_ba0_addr, b_ba1_addr, b_ba2_addr, b_ba3_addr;
wire [21:0] k_ba0_addr, k_ba1_addr, k_ba2_addr, k_ba3_addr;
wire [3:0] g_ba_rd, b_ba_rd, k_ba_rd;
wire g_ba_wr, b_ba_wr, k_ba_wr;
wire [15:0] g_ba0_din, b_ba0_din, k_ba0_din;
wire [1:0] g_ba0_dsn, b_ba0_dsn, k_ba0_dsn;
wire g_dwnld_busy, b_dwnld_busy, k_dwnld_busy;
wire [7:0] g_ioctl_din, b_ioctl_din, k_ioctl_din;
wire [21:0] g_prog_addr, b_prog_addr, k_prog_addr;
wire [15:0] g_prog_data, b_prog_data, k_prog_data;
wire [1:0] g_prog_mask, b_prog_mask, k_prog_mask;
wire [1:0] g_prog_ba, b_prog_ba, k_prog_ba;
wire g_prog_we, b_prog_we, k_prog_we, g_prog_rd, b_prog_rd, k_prog_rd;
wire [7:0] g_sdram_game, b_sdram_game;

wire g_ROM68K_OK, b_ROM68K_OK, k_ROM68K_OK;
wire [15:0] g_ROM68K_DOUT, b_ROM68K_DOUT, k_ROM68K_DOUT;
wire b_Z80_PRG_OK, k_Z80_PRG_OK;
wire [7:0] b_Z80_PRG_DOUT, k_Z80_PRG_DOUT;
assign ROM68K_OK   = active_is_garegga ? g_ROM68K_OK   : active_is_bakraid ? k_ROM68K_OK   : b_ROM68K_OK;
assign ROM68K_DOUT = active_is_garegga ? g_ROM68K_DOUT : active_is_bakraid ? k_ROM68K_DOUT : b_ROM68K_DOUT;
assign Z80_PRG_OK  = active_is_bakraid ? k_Z80_PRG_OK  : b_Z80_PRG_OK;
assign Z80_PRG_DOUT = active_is_bakraid ? k_Z80_PRG_DOUT : b_Z80_PRG_DOUT;

wire [1:0] btr_GFX_OK, k_GFX_OK, btr_GFXSCR0_OK, k_GFXSCR0_OK, btr_GFXSCR1_OK, k_GFXSCR1_OK, btr_GFXSCR2_OK, k_GFXSCR2_OK;
wire [31:0] btr_GFX0_DOUT, btr_GFX1_DOUT, k_GFX0_DOUT, k_GFX1_DOUT;
wire [31:0] btr_GFX0SCR0_DOUT, btr_GFX1SCR0_DOUT, k_GFX0SCR0_DOUT, k_GFX1SCR0_DOUT;
wire [31:0] btr_GFX0SCR1_DOUT, btr_GFX1SCR1_DOUT, k_GFX0SCR1_DOUT, k_GFX1SCR1_DOUT;
wire [31:0] btr_GFX0SCR2_DOUT, btr_GFX1SCR2_DOUT, k_GFX0SCR2_DOUT, k_GFX1SCR2_DOUT;
assign b_GFX_OK = active_is_bakraid ? k_GFX_OK : btr_GFX_OK;
assign b_GFX0_DOUT = active_is_bakraid ? k_GFX0_DOUT : btr_GFX0_DOUT;
assign b_GFX1_DOUT = active_is_bakraid ? k_GFX1_DOUT : btr_GFX1_DOUT;
assign b_GFXSCR0_OK = active_is_bakraid ? k_GFXSCR0_OK : btr_GFXSCR0_OK;
assign b_GFX0SCR0_DOUT = active_is_bakraid ? k_GFX0SCR0_DOUT : btr_GFX0SCR0_DOUT;
assign b_GFX1SCR0_DOUT = active_is_bakraid ? k_GFX1SCR0_DOUT : btr_GFX1SCR0_DOUT;
assign b_GFXSCR1_OK = active_is_bakraid ? k_GFXSCR1_OK : btr_GFXSCR1_OK;
assign b_GFX0SCR1_DOUT = active_is_bakraid ? k_GFX0SCR1_DOUT : btr_GFX0SCR1_DOUT;
assign b_GFX1SCR1_DOUT = active_is_bakraid ? k_GFX1SCR1_DOUT : btr_GFX1SCR1_DOUT;
assign b_GFXSCR2_OK = active_is_bakraid ? k_GFXSCR2_OK : btr_GFXSCR2_OK;
assign b_GFX0SCR2_DOUT = active_is_bakraid ? k_GFX0SCR2_DOUT : btr_GFX0SCR2_DOUT;
assign b_GFX1SCR2_DOUT = active_is_bakraid ? k_GFX1SCR2_DOUT : btr_GFX1SCR2_DOUT;

assign ba0_addr = active_is_garegga ? g_ba0_addr : active_is_bakraid ? k_ba0_addr : b_ba0_addr;
assign ba1_addr = active_is_garegga ? g_ba1_addr : active_is_bakraid ? k_ba1_addr : b_ba1_addr;
assign ba2_addr = active_is_garegga ? g_ba2_addr : active_is_bakraid ? k_ba2_addr : b_ba2_addr;
assign ba3_addr = active_is_garegga ? g_ba3_addr : active_is_bakraid ? k_ba3_addr : b_ba3_addr;
assign ba_rd    = active_is_garegga ? g_ba_rd    : active_is_bakraid ? k_ba_rd    : b_ba_rd;
assign ba_wr    = active_is_garegga ? g_ba_wr    : active_is_bakraid ? k_ba_wr    : b_ba_wr;
assign ba0_din  = active_is_garegga ? g_ba0_din  : active_is_bakraid ? k_ba0_din  : b_ba0_din;
assign ba0_dsn  = active_is_garegga ? g_ba0_dsn  : active_is_bakraid ? k_ba0_dsn  : b_ba0_dsn;
assign ba1_din  = 16'd0;
assign ba1_dsn  = 2'b11;
assign ba2_din  = 16'd0;
assign ba2_dsn  = 2'b11;
assign ba3_din  = 16'd0;
assign ba3_dsn  = 2'b11;

assign dwnld_busy = target_is_garegga ? g_dwnld_busy : target_is_bakraid ? k_dwnld_busy : target_is_batrider ? b_dwnld_busy : 1'b0;
assign ioctl_din  = target_is_garegga ? g_ioctl_din  : target_is_bakraid ? k_ioctl_din  : target_is_batrider ? b_ioctl_din  : 8'd0;
assign prog_addr  = target_is_garegga ? g_prog_addr  : target_is_bakraid ? k_prog_addr  : target_is_batrider ? b_prog_addr  : 22'd0;
assign prog_data  = target_is_garegga ? g_prog_data  : target_is_bakraid ? k_prog_data  : target_is_batrider ? b_prog_data  : 16'd0;
assign prog_mask  = target_is_garegga ? g_prog_mask  : target_is_bakraid ? k_prog_mask  : target_is_batrider ? b_prog_mask  : 2'd0;
assign prog_ba    = target_is_garegga ? g_prog_ba    : target_is_bakraid ? k_prog_ba    : target_is_batrider ? b_prog_ba    : 2'd0;
assign prog_we    = target_is_garegga ? g_prog_we    : target_is_bakraid ? k_prog_we    : target_is_batrider ? b_prog_we    : 1'b0;
assign prog_rd    = target_is_garegga ? g_prog_rd    : target_is_bakraid ? k_prog_rd    : target_is_batrider ? b_prog_rd    : 1'b0;

garegga_sdram #(.SS_ENABLE(SS_ENABLE)) u_garegga_sdram (
    .RESET(RESET96 | !active_is_garegga),
    .CLK(CLK96),
    .RESET48(RESET | !active_is_garegga),
    .CLK48(CLK),
    .CLK_GFX(g_CEN675),
    .IOCTL_ADDR(ioctl_addr),
    .IOCTL_DOUT(ioctl_dout),
    .IOCTL_DIN(g_ioctl_din),
    .IOCTL_WR(ioctl_wr & target_is_garegga),
    .IOCTL_RAM(ioctl_ram),
    .PROG_ADDR(g_prog_addr),
    .PROG_DATA(g_prog_data),
    .PROG_MASK(g_prog_mask),
    .PROG_BA(g_prog_ba),
    .PROG_WE(g_prog_we),
    .PROG_RD(g_prog_rd),
    .PROG_RDY(prog_rdy),
    .DOWNLOADING(ioctl_rom & target_is_garegga),
    .DWNLD_BUSY(g_dwnld_busy),
    .BA0_ADDR(g_ba0_addr),
    .BA1_ADDR(g_ba1_addr),
    .BA2_ADDR(g_ba2_addr),
    .BA3_ADDR(g_ba3_addr),
    .BA_RD(g_ba_rd),
    .BA_WR(g_ba_wr),
    .BA0_DIN(g_ba0_din),
    .BA0_DIN_M(g_ba0_dsn),
    .BA_ACK(ba_ack),
    .BA_DST(ba_dst),
    .BA_DOK(ba_dok),
    .BA_RDY(ba_rdy),
    .DATA_READ(data_read),
    .GFX_CS(g_GFX_CS & active_is_garegga),
    .GFX_OK(g_GFX_OK),
    .GFX0_ADDR(g_GFX0_ADDR),
    .GFX0_DOUT(g_GFX0_DOUT),
    .GFXSCR0_CS(g_GFXSCR0_CS & active_is_garegga),
    .GFXSCR0_OK(g_GFXSCR0_OK),
    .GFX0SCR0_ADDR(g_GFX0SCR0_ADDR),
    .GFX0SCR0_DOUT(g_GFX0SCR0_DOUT),
    .GFXSCR1_CS(g_GFXSCR1_CS & active_is_garegga),
    .GFXSCR1_OK(g_GFXSCR1_OK),
    .GFX0SCR1_ADDR(g_GFX0SCR1_ADDR),
    .GFX0SCR1_DOUT(g_GFX0SCR1_DOUT),
    .GFXSCR2_CS(g_GFXSCR2_CS & active_is_garegga),
    .GFXSCR2_OK(g_GFXSCR2_OK),
    .GFX0SCR2_ADDR(g_GFX0SCR2_ADDR),
    .GFX0SCR2_DOUT(g_GFX0SCR2_DOUT),
    .ROM68K_CS(ROM68K_CS & active_is_garegga),
    .ROM68K_OK(g_ROM68K_OK),
    .ROM68K_ADDR(ROM68K_ADDR[18:0]),
    .ROM68K_DOUT(g_ROM68K_DOUT),
    .ROMZ80_CS(g_ROMZ80_CS),
    .ROMZ80_OK(g_ROMZ80_OK),
    .ROMZ80_ADDR(g_ROMZ80_ADDR),
    .ROMZ80_DOUT(g_ROMZ80_DOUT),
    .PCM_CS(g_PCM_CS),
    .PCM_OK(g_PCM_OK),
    .PCM_ADDR(g_PCM_ADDR),
    .PCM_DOUT(g_PCM_DOUT),
    .TEXTROM_ADDR(g_TEXTROM_ADDR),
    .TEXTROM_DOUT(g_TEXTROM_DATA),
    .GAME(g_sdram_game),
    .HISCORE_CS(HISCORE_CS & active_is_garegga),
    .HISCORE_WE(HISCORE_WE),
    .HISCORE_DIN(HISCORE_DIN),
    .HISCORE_DOUT(g_HISCORE_DOUT),
    .HISCORE_ADDR(HISCORE_ADDR[6:0]),
    .SS_FREEZE(SS_FREEZE),
    .SS_DATA(SS_DATA),
    .SS_ADDR(SS_ADDR),
    .SS_SELECT(ss_garegga_storage_select),
    .SS_WRITE(SS_WRITE),
    .SS_READ(SS_READ),
    .SS_QUERY(SS_QUERY),
    .SS_DATA_OUT(ss_garegga_storage_data_out),
    .SS_ACK(ss_garegga_storage_ack),
    .SS_QUIESCED(ss_garegga_storage_quiesced)
);

batrider_sdram #(.SS_ENABLE(SS_ENABLE)) u_batrider_sdram (
    .RESET(RESET96 | !active_is_batrider),
    .CLK(CLK96),
    .CLK_GFX(CEN675),
    .IOCTL_ADDR(ioctl_addr),
    .IOCTL_DOUT(ioctl_dout),
    .IOCTL_DIN(b_ioctl_din),
    .IOCTL_WR(ioctl_wr & target_is_batrider),
    .IOCTL_RAM(ioctl_ram),
    .PROG_ADDR(b_prog_addr),
    .PROG_DATA(b_prog_data),
    .PROG_MASK(b_prog_mask),
    .PROG_BA(b_prog_ba),
    .PROG_WE(b_prog_we),
    .PROG_RD(b_prog_rd),
    .PROG_RDY(prog_rdy),
    .DOWNLOADING(ioctl_rom & target_is_batrider),
    .DWNLD_BUSY(b_dwnld_busy),
    .BA0_ADDR(b_ba0_addr),
    .BA1_ADDR(b_ba1_addr),
    .BA2_ADDR(b_ba2_addr),
    .BA3_ADDR(b_ba3_addr),
    .BA_RD(b_ba_rd),
    .BA_WR(b_ba_wr),
    .BA0_DIN(b_ba0_din),
    .BA0_DIN_M(b_ba0_dsn),
    .BA_ACK(ba_ack),
    .BA_DST(ba_dst),
    .BA_DOK(ba_dok),
    .BA_RDY(ba_rdy),
    .DATA_READ(data_read),
    .ROM68K_CS(ROM68K_CS & active_is_batrider),
    .ROM68K_OK(b_ROM68K_OK),
    .ROM68K_ADDR(ROM68K_ADDR),
    .ROM68K_DOUT(b_ROM68K_DOUT),
    .ROMZ80_CS(Z80_PRG_CS & active_is_batrider),
    .ROMZ80_OK(b_Z80_PRG_OK),
    .ROMZ80_ADDR(Z80_PRG_ADDR),
    .ROMZ80_DOUT(b_Z80_PRG_DOUT),
    .ROMZ801_CS(b_ROMZ801_CS),
    .ROMZ801_OK(b_ROMZ801_OK),
    .ROMZ801_ADDR(b_ROMZ801_ADDR),
    .ROMZ801_DOUT(b_ROMZ801_DOUT),
    .GFX_CS(b_GFX_CS & {2{active_is_batrider}}),
    .GFX_OK(btr_GFX_OK),
    .GFX0_ADDR(b_GFX0_ADDR),
    .GFX0_DOUT(btr_GFX0_DOUT),
    .GFX1_ADDR(b_GFX1_ADDR),
    .GFX1_DOUT(btr_GFX1_DOUT),
    .GFXSCR0_CS(b_GFXSCR0_CS & {2{active_is_batrider}}),
    .GFXSCR0_OK(btr_GFXSCR0_OK),
    .GFX0SCR0_ADDR(b_GFX0SCR0_ADDR),
    .GFX0SCR0_DOUT(btr_GFX0SCR0_DOUT),
    .GFX1SCR0_ADDR(b_GFX1SCR0_ADDR),
    .GFX1SCR0_DOUT(btr_GFX1SCR0_DOUT),
    .GFXSCR1_CS(b_GFXSCR1_CS & {2{active_is_batrider}}),
    .GFXSCR1_OK(btr_GFXSCR1_OK),
    .GFX0SCR1_ADDR(b_GFX0SCR1_ADDR),
    .GFX0SCR1_DOUT(btr_GFX0SCR1_DOUT),
    .GFX1SCR1_ADDR(b_GFX1SCR1_ADDR),
    .GFX1SCR1_DOUT(btr_GFX1SCR1_DOUT),
    .GFXSCR2_CS(b_GFXSCR2_CS & {2{active_is_batrider}}),
    .GFXSCR2_OK(btr_GFXSCR2_OK),
    .GFX0SCR2_ADDR(b_GFX0SCR2_ADDR),
    .GFX0SCR2_DOUT(btr_GFX0SCR2_DOUT),
    .GFX1SCR2_ADDR(b_GFX1SCR2_ADDR),
    .GFX1SCR2_DOUT(btr_GFX1SCR2_DOUT),
    .PCM_CS(b_PCM_CS),
    .PCM_OK(b_PCM_OK),
    .PCM_ADDR(b_PCM_ADDR),
    .PCM_DOUT(b_PCM_DOUT),
    .PCM1_CS(b_PCM1_CS),
    .PCM1_OK(b_PCM1_OK),
    .PCM1_ADDR(b_PCM1_ADDR),
    .PCM1_DOUT(b_PCM1_DOUT),
    .GAME(b_sdram_game),
    .HISCORE_CS(HISCORE_CS & active_is_batrider),
    .HISCORE_WE(HISCORE_WE),
    .HISCORE_DIN(HISCORE_DIN),
    .HISCORE_DOUT(b_HISCORE_DOUT),
    .HISCORE_ADDR(HISCORE_ADDR),
    .SS_FREEZE(SS_FREEZE),
    .SS_DATA(SS_DATA),
    .SS_ADDR(SS_ADDR),
    .SS_SELECT(ss_batrider_storage_select),
    .SS_WRITE(SS_WRITE),
    .SS_READ(SS_READ),
    .SS_QUERY(SS_QUERY),
    .SS_DATA_OUT(ss_batrider_storage_data_out),
    .SS_ACK(ss_batrider_storage_ack),
    .SS_QUIESCED(ss_batrider_storage_quiesced)
);

bakraid_sdram #(.SS_ENABLE(SS_ENABLE)) u_bakraid_sdram (
    .RESET(RESET96 | !active_is_bakraid),
    .CLK(CLK96),
    .RESET48(RESET | !active_is_bakraid),
    .CLK48(CLK),
    .CLK_GFX(CEN675),
    .IOCTL_ADDR(ioctl_addr),
    .IOCTL_DOUT(ioctl_dout),
    .IOCTL_DIN(k_ioctl_din),
    .IOCTL_WR(ioctl_wr & target_is_bakraid),
    .IOCTL_RAM(ioctl_ram),
    .PROG_ADDR(k_prog_addr),
    .PROG_DATA(k_prog_data),
    .PROG_MASK(k_prog_mask),
    .PROG_BA(k_prog_ba),
    .PROG_WE(k_prog_we),
    .PROG_RD(k_prog_rd),
    .PROG_RDY(prog_rdy),
    .DOWNLOADING(ioctl_rom & target_is_bakraid),
    .DWNLD_BUSY(k_dwnld_busy),
    .BA0_ADDR(k_ba0_addr),
    .BA1_ADDR(k_ba1_addr),
    .BA2_ADDR(k_ba2_addr),
    .BA3_ADDR(k_ba3_addr),
    .BA_RD(k_ba_rd),
    .BA_WR(k_ba_wr),
    .BA0_DIN(k_ba0_din),
    .BA0_DIN_M(k_ba0_dsn),
    .BA_ACK(ba_ack),
    .BA_DST(ba_dst),
    .BA_DOK(ba_dok),
    .BA_RDY(ba_rdy),
    .DATA_READ(data_read),
    .ROM68K_CS(ROM68K_CS & active_is_bakraid),
    .ROM68K_OK(k_ROM68K_OK),
    .ROM68K_ADDR(ROM68K_ADDR),
    .ROM68K_DOUT(k_ROM68K_DOUT),
    .ROMZ80_CS(Z80_PRG_CS & active_is_bakraid),
    .ROMZ80_OK(k_Z80_PRG_OK),
    .ROMZ80_ADDR(Z80_PRG_ADDR),
    .ROMZ80_DOUT(k_Z80_PRG_DOUT),
    .ROMZ801_CS(k_ROMZ801_CS),
    .ROMZ801_OK(k_ROMZ801_OK),
    .ROMZ801_ADDR(k_ROMZ801_ADDR),
    .ROMZ801_DOUT(k_ROMZ801_DOUT),
    .GFX_CS(b_GFX_CS & {2{active_is_bakraid}}),
    .GFX_OK(k_GFX_OK),
    .GFX0_ADDR(b_GFX0_ADDR),
    .GFX0_DOUT(k_GFX0_DOUT),
    .GFX1_ADDR(b_GFX1_ADDR),
    .GFX1_DOUT(k_GFX1_DOUT),
    .GFXSCR0_CS(b_GFXSCR0_CS & {2{active_is_bakraid}}),
    .GFXSCR0_OK(k_GFXSCR0_OK),
    .GFX0SCR0_ADDR(b_GFX0SCR0_ADDR),
    .GFX0SCR0_DOUT(k_GFX0SCR0_DOUT),
    .GFX1SCR0_ADDR(b_GFX1SCR0_ADDR),
    .GFX1SCR0_DOUT(k_GFX1SCR0_DOUT),
    .GFXSCR1_CS(b_GFXSCR1_CS & {2{active_is_bakraid}}),
    .GFXSCR1_OK(k_GFXSCR1_OK),
    .GFX0SCR1_ADDR(b_GFX0SCR1_ADDR),
    .GFX0SCR1_DOUT(k_GFX0SCR1_DOUT),
    .GFX1SCR1_ADDR(b_GFX1SCR1_ADDR),
    .GFX1SCR1_DOUT(k_GFX1SCR1_DOUT),
    .GFXSCR2_CS(b_GFXSCR2_CS & {2{active_is_bakraid}}),
    .GFXSCR2_OK(k_GFXSCR2_OK),
    .GFX0SCR2_ADDR(b_GFX0SCR2_ADDR),
    .GFX0SCR2_DOUT(k_GFX0SCR2_DOUT),
    .GFX1SCR2_ADDR(b_GFX1SCR2_ADDR),
    .GFX1SCR2_DOUT(k_GFX1SCR2_DOUT),
    .PCM_CS(k_PCM_CS),
    .PCM_OK(k_PCM_OK),
    .PCM_ADDR(k_PCM_ADDR),
    .PCM_DOUT(k_PCM_DOUT),
    .PCM1_CS(k_PCM1_CS),
    .PCM1_OK(k_PCM1_OK),
    .PCM1_ADDR(k_PCM1_ADDR),
    .PCM1_DOUT(k_PCM1_DOUT),
    .PCM2_CS(k_PCM2_CS),
    .PCM2_OK(k_PCM2_OK),
    .PCM2_ADDR(k_PCM2_ADDR),
    .PCM2_DOUT(k_PCM2_DOUT),
    .SCLK(EEPROM_SCLK),
    .SDI(EEPROM_SDI),
    .SDO(EEPROM_SDO),
    .SCS(EEPROM_SCS),
    .SS_FREEZE(SS_FREEZE),
    .SS_DATA(SS_DATA),
    .SS_ADDR(SS_ADDR),
    .SS_SELECT(ss_bakraid_storage_select),
    .SS_WRITE(SS_WRITE),
    .SS_READ(SS_READ),
    .SS_QUERY(SS_QUERY),
    .SS_DATA_OUT(ss_bakraid_storage_data_out),
    .SS_ACK(ss_bakraid_storage_ack),
    .SS_QUIESCED(ss_bakraid_storage_quiesced)
);

wire ss_sound_ack = ss_garegga_sound_ack |
                    ss_batrider_sound_ack |
                    ss_bakraid_sound_ack;
wire [63:0] ss_sound_data =
    (ss_garegga_sound_data_out & {64{ss_garegga_sound_ack}}) |
    (ss_batrider_sound_data_out & {64{ss_batrider_sound_ack}}) |
    (ss_bakraid_sound_data_out & {64{ss_bakraid_sound_ack}});
wire ss_storage_ack = ss_garegga_storage_ack |
                      ss_batrider_storage_ack |
                      ss_bakraid_storage_ack;
wire [63:0] ss_storage_data =
    (ss_garegga_storage_data_out & {64{ss_garegga_storage_ack}}) |
    (ss_batrider_storage_data_out & {64{ss_batrider_storage_ack}}) |
    (ss_bakraid_storage_data_out & {64{ss_bakraid_storage_ack}});
wire ss_sound_quiesced = active_is_garegga ? ss_garegga_sound_quiesced :
                          active_is_batrider ? ss_batrider_sound_quiesced :
                                              ss_bakraid_sound_quiesced;
wire ss_storage_quiesced = active_is_garegga ? ss_garegga_storage_quiesced :
                            active_is_batrider ? ss_batrider_storage_quiesced :
                                                ss_bakraid_storage_quiesced;
wire [5:0] ss_response_ack;

assign ss_response_ack[0] = ss_cpu_ack;
assign ss_response_ack[1] = ss_sound_ack;
assign ss_response_ack[2] = ss_shared_audio_ack;
assign ss_response_ack[3] = ss_video_ack;
assign ss_response_ack[4] = ss_text_ack;
assign ss_response_ack[5] = ss_storage_ack;

raizing_ss_response_mux #(.COUNT(6)) u_ss_response(
    .ack(ss_response_ack),
    .data({ss_storage_data,
           ss_text_data_out,
           ss_video_data_out,
           ss_shared_audio_data_out,
           ss_sound_data,
           ss_cpu_data_out}),
    .ack_out(SS_ACK),
    .data_out(SS_DATA_OUT)
);

wire ss_audio_replay_busy = active_is_bakraid ?
                            ss_bakraid_audio_replay_busy :
                            ss_shared_audio_replay_busy;
reg ss_main_restore_seen;

always @(posedge CLK96) begin
    SS_RESTORE_DONE <= 1'b0;

    if(RESET96 || !SS_ENABLE || SS_RESTORE_BEGIN) begin
        ss_main_restore_seen <= 1'b0;
    end else begin
        if(ss_main_restore_done)
            ss_main_restore_seen <= 1'b1;

        if((ss_main_restore_seen || ss_main_restore_done) &&
           !ss_audio_replay_busy) begin
            SS_RESTORE_DONE <= 1'b1;
            ss_main_restore_seen <= 1'b0;
        end
    end
end

assign SS_GAME_QUIESCED = !SS_ENABLE ||
    (SS_FREEZE && ss_cpu_idle && ss_sound_quiesced &&
     ss_video_quiesced && (!active_is_battle || ss_text_quiesced) &&
     ss_storage_quiesced);
assign SS_CPU_IDLE = !SS_ENABLE || ss_cpu_idle;

endmodule
