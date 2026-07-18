// This file is a Codex-assisted refactoring and update
// based on the original work of Pramod Somashekar (pram0d)

/*
* <-- pr4m0d -->
* https://pram0d.com
* https://twitter.com/pr4m0d
* https://github.com/psomashekar
*
* Copyright (c) 2022 Pramod Somashekar
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/
module raizing_video #(
    parameter SS_ENABLE = 0
)(
    input         CLK,
    input         CLK96,
    input         PIXEL_CEN,
    input         RESET,
    input         RESET96,

    //TVRMCTL7
    output [10:0] PALRAM_ADDR,
    input  [15:0] PALRAM_DATA,
    output [13:0] TEXTROM_ADDR,
    input  [15:0] TEXTROM_DATA,
    output [11:0] TEXTVRAM_ADDR,
    input  [15:0] TEXTVRAM_DATA,
    output  [7:0] TEXTSELECT_ADDR,
    input  [15:0] TEXTSELECT_DATA,
    output  [7:0] TEXTSCROLL_ADDR,
    input  [15:0] TEXTSCROLL_DATA,
    input         SHIFT_SPRITE_PRI,
    input         FAST_OBJ_QUEUE,

    //graphics ROM
    output  [1:0] GFX_CS,
    input   [1:0] GFX_OK,
    output [21:0] GFX0_ADDR,     
    input  [31:0] GFX0_DOUT,
    output [21:0] GFX1_ADDR,     
    input  [31:0] GFX1_DOUT,

    output  [1:0] GFXSCR0_CS,
    input   [1:0] GFXSCR0_OK,
    output [21:0] GFX0SCR0_ADDR,     
    input  [31:0] GFX0SCR0_DOUT,
    output [21:0] GFX1SCR0_ADDR,     
    input  [31:0] GFX1SCR0_DOUT,

    output  [1:0] GFXSCR1_CS,
    input   [1:0] GFXSCR1_OK,
    output [21:0] GFX0SCR1_ADDR,     
    input  [31:0] GFX0SCR1_DOUT,
    output [21:0] GFX1SCR1_ADDR,     
    input  [31:0] GFX1SCR1_DOUT,

    output  [1:0] GFXSCR2_CS,
    input   [1:0] GFXSCR2_OK,
    output [21:0] GFX0SCR2_ADDR,     
    input  [31:0] GFX0SCR2_DOUT,
    output [21:0] GFX1SCR2_ADDR,     
    input  [31:0] GFX1SCR2_DOUT,

    //gp9001
    input         GP9001CS,
    output        GP9001ACK,
    output        VINT,
    input  [15:0] GP9001DIN,
    output [15:0] GP9001DOUT,
    input         GP9001_OP_SELECT_REG, 
    input         GP9001_OP_WRITE_REG, 
    input         GP9001_OP_WRITE_RAM, 
    input         GP9001_OP_READ_RAM_H, 
    input         GP9001_OP_READ_RAM_L, 
    input         GP9001_OP_SET_RAM_PTR, 
    input         GP9001_OP_OBJECTBANK_WR,
    input   [2:0] GP9001_OBJECTBANK_SLOT,
    output [10:0] GP9001OUT,

    //video signal
    output        LVBL_DLY,
    output        LHBL_DLY,
    output        LHBL,
    output        LVBL,
    output        HS,
    output        VS,
    output        CPU_HSYNC,
    output        CPU_VSYNC,
    output        CPU_FBLANK,
    output  [8:0] V,
    output  [7:0] RED,
    output  [7:0] GREEN,
    output  [7:0] BLUE,

    input   [7:0] GAME,

    input   [8:0] HS_START,
    input   [8:0] HS_END,
    input   [8:0] VS_START,
    input   [8:0] VS_END,

    input FLIP,

    input          SS_FREEZE,
    input  [63:0]  SS_DATA,
    input  [31:0]  SS_ADDR,
    input   [7:0]  SS_SELECT,
    input          SS_WRITE,
    input          SS_READ,
    input          SS_QUERY,
    output [63:0]  SS_DATA_OUT,
    output         SS_ACK,
    output         SS_QUIESCED
);

wire ACTIVE;
wire [8:0] H;
wire [8:0] VRENDER;
wire pixel_cen_run = PIXEL_CEN && !(SS_ENABLE && SS_FREEZE);

wire [43:0] ss_vtimer_state;
wire [43:0] ss_vtimer_restore;
wire ss_vtimer_restore_we;
wire [1:0] ss_response_ack;
wire [127:0] ss_response_data;
wire ss_gcu_quiesced;

wire HB = ~LHBL, VB = ~LVBL;

//pixel layers
wire [10:0] EXTRATEXT_PIXEL;
wire [14:0] OBJ_PIXEL;
wire [14:0] SCROLL0_PIXEL;
wire [14:0] SCROLL1_PIXEL;
wire [14:0] SCROLL2_PIXEL;
wire [10:0] FINAL_PIXEL;

//sync generated here is different than the GP9001 values, as those drive cpu interrupts.
hvsync_generator #(.SS_ENABLE(SS_ENABLE)) u_hvsync(
    .clk(CLK),
    .clk96(CLK96),
    .pxl_cen(pixel_cen_run),
    .reset(RESET),
    .reset96(RESET96),
    .hsync(HS),
    .vsync(VS),
    .lhbl(LHBL),
    .lvbl(LVBL),
    .display_on(ACTIVE),
    .hpos(H),
    .vpos(V),
    .vrender(VRENDER),
    .flip(FLIP),
    .ss_hold(SS_ENABLE && SS_FREEZE),
    .ss_restore(ss_vtimer_restore_we),
    .ss_state_in(ss_vtimer_restore),
    .ss_state(ss_vtimer_state)
);

raizing_pal u_pal (
    .CLK(CLK),
    .CLK96(CLK96),
    .PIXEL_CEN(pixel_cen_run),
    .RESET(RESET),
    .RESET96(RESET96),
    .LVBL(LVBL),
    .LHBL(LHBL),
    .LVBL_DLY(LVBL_DLY),
    .LHBL_DLY(LHBL_DLY),
    .PIXEL(FINAL_PIXEL),
    .PAL_ADDR(PALRAM_ADDR),
    .PAL_DATA(PALRAM_DATA),
    .RED(RED),
    .GREEN(GREEN),
    .BLUE(BLUE),
    .ACTIVE(ACTIVE)
);

raizing_colmix u_colmix(
    .CLK(CLK),
    .CLK96(CLK96),
    .RESET(RESET),
    .RESET96(RESET96),
    .PIXEL_CEN(pixel_cen_run),
    .EXTRATEXT_PIXEL(EXTRATEXT_PIXEL),
    .SCROLL0_PIXEL(SCROLL0_PIXEL),
    .SCROLL1_PIXEL(SCROLL1_PIXEL),
    .SCROLL2_PIXEL(SCROLL2_PIXEL),
    .OBJ_PIXEL(OBJ_PIXEL),
    .FINAL_PIXEL(FINAL_PIXEL),
    .ACTIVE(ACTIVE)
);

raizing_extratext u_extratext(
    .CLK(CLK),
    .CLK96(CLK96),
    .PIXEL_CEN(pixel_cen_run),
    .RESET(RESET),
    .RESET96(RESET96),
    .VRENDER(VRENDER),
    .H(H),
    .ACTIVE(ACTIVE),
    .HB(HB),
    .VB(VB),
    .FLIPX(FLIP),

    //text rom
    .TEXTROM_ADDR(TEXTROM_ADDR),
    .TEXTROM_DATA(TEXTROM_DATA),

    //text vram
    .TEXTVRAM_ADDR(TEXTVRAM_ADDR),
    .TEXTVRAM_DATA(TEXTVRAM_DATA),

    //text select ram
    .TEXTSELECT_ADDR(TEXTSELECT_ADDR),
    .TEXTSELECT_DATA(TEXTSELECT_DATA),

    //text scroll ram
    .TEXTSCROLL_ADDR(TEXTSCROLL_ADDR),
    .TEXTSCROLL_DATA(TEXTSCROLL_DATA),

    .EXTRATEXT_PIXEL(EXTRATEXT_PIXEL),
    .GAME(GAME)
);

wire  [12:0] GP9001RAM_GCU_ADDR;
wire  [15:0] GP9001RAM_GCU_DOUT;
wire  [12:0] GP9001RAM2_GCU_ADDR;
wire  [15:0] GP9001RAM2_GCU_DOUT;
wire  [12:0] SCR0_GP9001RAM_GCU_ADDR;
wire  [15:0] SCR0_GP9001RAM_GCU_DOUT;
wire  [12:0] SCR1_GP9001RAM_GCU_ADDR;
wire  [15:0] SCR1_GP9001RAM_GCU_DOUT;
wire  [12:0] SCR2_GP9001RAM_GCU_ADDR;
wire  [15:0] SCR2_GP9001RAM_GCU_DOUT;

wire [14:0] TILE_NUMBER;
wire [3:0] TILE_BANK;
wire [31:0] GFX_DATA;
wire GFX_DATA_CS;
wire GFX_DATA_OK;

wire [15:0] TILE_NUMBER_OFFS;

wire [15:0] SCR0_TILE_NUMBER_OFFS;
wire [14:0] SCR0_TILE_NUMBER;
wire [3:0] SCR0_TILE_BANK;
wire [31:0] SCR0_GFX_DATA;
wire SCR0_GFX_DATA_CS;
wire SCR0_GFX_DATA_OK;

wire [15:0] SCR1_TILE_NUMBER_OFFS;
wire [14:0] SCR1_TILE_NUMBER;
wire [3:0] SCR1_TILE_BANK;
wire [31:0] SCR1_GFX_DATA;
wire SCR1_GFX_DATA_CS;
wire SCR1_GFX_DATA_OK;

wire [15:0] SCR2_TILE_NUMBER_OFFS;
wire [14:0] SCR2_TILE_NUMBER;
wire [3:0] SCR2_TILE_BANK;
wire [31:0] SCR2_GFX_DATA;
wire SCR2_GFX_DATA_CS;
wire SCR2_GFX_DATA_OK;

wire signed [12:0] SPRITE_SCROLL_X;
wire signed [12:0] SPRITE_SCROLL_Y;
wire signed [12:0] SPRITE_SCROLL_XOFFS;
wire signed [12:0] SPRITE_SCROLL_YOFFS;
wire signed [12:0] BACKGROUND_SCROLL_X;
wire signed [12:0] BACKGROUND_SCROLL_Y;
wire signed [12:0] BACKGROUND_SCROLL_XOFFS;
wire signed [12:0] BACKGROUND_SCROLL_YOFFS;
wire signed [12:0] FOREGROUND_SCROLL_X;
wire signed [12:0] FOREGROUND_SCROLL_Y;
wire signed [12:0] FOREGROUND_SCROLL_XOFFS;
wire signed [12:0] FOREGROUND_SCROLL_YOFFS;
wire signed [12:0] TEXT_SCROLL_X;
wire signed [12:0] TEXT_SCROLL_Y;
wire signed [12:0] TEXT_SCROLL_XOFFS;
wire signed [12:0] TEXT_SCROLL_YOFFS;

raizing_obj u_obj(
    .CLK(CLK),
    .CLK96(CLK96),
    .PIXEL_CEN(pixel_cen_run),
    .RESET(RESET),
    .RESET96(RESET96),
    .VRENDER(VRENDER),
    .H(H),
    .ACTIVE(ACTIVE),
    .HB(HB),
    .VB(VB),
    .FLIPX(FLIP),
    .SHIFT_SPRITE_PRI(SHIFT_SPRITE_PRI),
    .FAST_OBJ_QUEUE(FAST_OBJ_QUEUE),

    //interface with GP9001 RAM Mirror
    .GP9001RAM_GCU_ADDR(GP9001RAM_GCU_ADDR),
    .GP9001RAM_GCU_DOUT(GP9001RAM_GCU_DOUT),
    .GP9001RAM2_GCU_ADDR(GP9001RAM2_GCU_ADDR),
    .GP9001RAM2_GCU_DOUT(GP9001RAM2_GCU_DOUT),

    //tile gfx
    .GFX_CS(GFX_DATA_CS),
    .GFX_OK(GFX_DATA_OK),
    .TILE_NUMBER(TILE_NUMBER),
    .TILE_NUMBER_OFFS(TILE_NUMBER_OFFS),
    .TILE_BANK(TILE_BANK),
    .GFX_DATA(GFX_DATA),

    //sprite scroll regs
    .SPRITE_SCROLL_X(SPRITE_SCROLL_X),
    .SPRITE_SCROLL_Y(SPRITE_SCROLL_Y),
    .SPRITE_SCROLL_XOFFS(SPRITE_SCROLL_XOFFS),
    .SPRITE_SCROLL_YOFFS(SPRITE_SCROLL_YOFFS),

    .OBJ_PIXEL(OBJ_PIXEL)
);

raizing_scroll u_scroll(
    .CLK(CLK),
    .CLK96(CLK96),
    .PIXEL_CEN(pixel_cen_run),
    .RESET(RESET),
    .RESET96(RESET96),
    .VRENDER(VRENDER),
    .H(H),
    .ACTIVE(ACTIVE),
    .HB(HB),
    .VB(VB),
    .FLIPX(FLIP),

    .SCR0_GP9001RAM_GCU_ADDR(SCR0_GP9001RAM_GCU_ADDR),
    .SCR0_GP9001RAM_GCU_DOUT(SCR0_GP9001RAM_GCU_DOUT),
    .SCR1_GP9001RAM_GCU_ADDR(SCR1_GP9001RAM_GCU_ADDR),
    .SCR1_GP9001RAM_GCU_DOUT(SCR1_GP9001RAM_GCU_DOUT),
    .SCR2_GP9001RAM_GCU_ADDR(SCR2_GP9001RAM_GCU_ADDR),
    .SCR2_GP9001RAM_GCU_DOUT(SCR2_GP9001RAM_GCU_DOUT),

    //tile gfx
    .GFXSCR0_CS(SCR0_GFX_DATA_CS),
    .GFXSCR0_OK(SCR0_GFX_DATA_OK),
    .SCR0_TILE_NUMBER(SCR0_TILE_NUMBER),
    .SCR0_TILE_NUMBER_OFFS(SCR0_TILE_NUMBER_OFFS),
    .SCR0_TILE_BANK(SCR0_TILE_BANK),
    .SCR0_GFX_DATA(SCR0_GFX_DATA),

    .GFXSCR1_CS(SCR1_GFX_DATA_CS),
    .GFXSCR1_OK(SCR1_GFX_DATA_OK),
    .SCR1_TILE_NUMBER(SCR1_TILE_NUMBER),
    .SCR1_TILE_NUMBER_OFFS(SCR1_TILE_NUMBER_OFFS),
    .SCR1_TILE_BANK(SCR1_TILE_BANK),
    .SCR1_GFX_DATA(SCR1_GFX_DATA),

    .GFXSCR2_CS(SCR2_GFX_DATA_CS),
    .GFXSCR2_OK(SCR2_GFX_DATA_OK),
    .SCR2_TILE_NUMBER(SCR2_TILE_NUMBER),
    .SCR2_TILE_NUMBER_OFFS(SCR2_TILE_NUMBER_OFFS),
    .SCR2_TILE_BANK(SCR2_TILE_BANK),
    .SCR2_GFX_DATA(SCR2_GFX_DATA),

    .BACKGROUND_SCROLL_X(BACKGROUND_SCROLL_X),
    .BACKGROUND_SCROLL_Y(BACKGROUND_SCROLL_Y),
    .BACKGROUND_SCROLL_XOFFS(BACKGROUND_SCROLL_XOFFS),
    .BACKGROUND_SCROLL_YOFFS(BACKGROUND_SCROLL_YOFFS),
    .FOREGROUND_SCROLL_X(FOREGROUND_SCROLL_X),
    .FOREGROUND_SCROLL_Y(FOREGROUND_SCROLL_Y),
    .FOREGROUND_SCROLL_XOFFS(FOREGROUND_SCROLL_XOFFS),
    .FOREGROUND_SCROLL_YOFFS(FOREGROUND_SCROLL_YOFFS),
    .TEXT_SCROLL_X(TEXT_SCROLL_X),
    .TEXT_SCROLL_Y(TEXT_SCROLL_Y),
    .TEXT_SCROLL_XOFFS(TEXT_SCROLL_XOFFS),
    .TEXT_SCROLL_YOFFS(TEXT_SCROLL_YOFFS),

    .SCROLL0_PIXEL(SCROLL0_PIXEL),
    .SCROLL1_PIXEL(SCROLL1_PIXEL),
    .SCROLL2_PIXEL(SCROLL2_PIXEL)
);

raizing_gcu #(.SS_ENABLE(SS_ENABLE)) u_gcu(
    .RESET(RESET),
    .RESET96(RESET96),
    .CLK(CLK),
    .CLK96(CLK96),
    .GFX_CLK(pixel_cen_run),
    .CS(GP9001CS),
    .ACK(GP9001ACK),
    .VINT(VINT),
    .GP9001_OP_SELECT_REG(GP9001_OP_SELECT_REG),
    .GP9001_OP_WRITE_REG(GP9001_OP_WRITE_REG),
    .GP9001_OP_WRITE_RAM(GP9001_OP_WRITE_RAM),
    .GP9001_OP_READ_RAM_H(GP9001_OP_READ_RAM_H),
    .GP9001_OP_READ_RAM_L(GP9001_OP_READ_RAM_L),
    .GP9001_OP_SET_RAM_PTR(GP9001_OP_SET_RAM_PTR),
    .GP9001_OP_OBJECTBANK_WR(GP9001_OP_OBJECTBANK_WR),
    .GP9001_OBJECTBANK_SLOT(GP9001_OBJECTBANK_SLOT),
    .GAME(GAME),
    .DIN(GP9001DIN),
    .DOUT(GP9001DOUT),
    .V(V),
    .H(H),
    .LVBL(VB),
    .HSYNC(CPU_HSYNC),
    .VSYNC(CPU_VSYNC),
    .FBLANK(CPU_FBLANK),
    .GP9001OUT(GP9001OUT),
    .FLIPX(1'b1), //for now, as I don't know how this option is used.
    .FLIPY(1'b1),

    .GP9001RAM_GCU_ADDR(GP9001RAM_GCU_ADDR),
    .GP9001RAM_GCU_DOUT(GP9001RAM_GCU_DOUT),
    .GP9001RAM2_GCU_ADDR(GP9001RAM2_GCU_ADDR),
    .GP9001RAM2_GCU_DOUT(GP9001RAM2_GCU_DOUT),

    .SCR0_GP9001RAM_GCU_ADDR(SCR0_GP9001RAM_GCU_ADDR),
    .SCR0_GP9001RAM_GCU_DOUT(SCR0_GP9001RAM_GCU_DOUT),
    .SCR1_GP9001RAM_GCU_ADDR(SCR1_GP9001RAM_GCU_ADDR),
    .SCR1_GP9001RAM_GCU_DOUT(SCR1_GP9001RAM_GCU_DOUT),
    .SCR2_GP9001RAM_GCU_ADDR(SCR2_GP9001RAM_GCU_ADDR),
    .SCR2_GP9001RAM_GCU_DOUT(SCR2_GP9001RAM_GCU_DOUT),

    .SPRITE_SCROLL_X(SPRITE_SCROLL_X),
    .SPRITE_SCROLL_Y(SPRITE_SCROLL_Y),
    .SPRITE_SCROLL_XOFFS(SPRITE_SCROLL_XOFFS),
    .SPRITE_SCROLL_YOFFS(SPRITE_SCROLL_YOFFS),
    .BACKGROUND_SCROLL_X(BACKGROUND_SCROLL_X),
    .BACKGROUND_SCROLL_Y(BACKGROUND_SCROLL_Y),
    .BACKGROUND_SCROLL_XOFFS(BACKGROUND_SCROLL_XOFFS),
    .BACKGROUND_SCROLL_YOFFS(BACKGROUND_SCROLL_YOFFS),
    .FOREGROUND_SCROLL_X(FOREGROUND_SCROLL_X),
    .FOREGROUND_SCROLL_Y(FOREGROUND_SCROLL_Y),
    .FOREGROUND_SCROLL_XOFFS(FOREGROUND_SCROLL_XOFFS),
    .FOREGROUND_SCROLL_YOFFS(FOREGROUND_SCROLL_YOFFS),
    .TEXT_SCROLL_X(TEXT_SCROLL_X),
    .TEXT_SCROLL_Y(TEXT_SCROLL_Y),
    .TEXT_SCROLL_XOFFS(TEXT_SCROLL_XOFFS),
    .TEXT_SCROLL_YOFFS(TEXT_SCROLL_YOFFS),

    .TILE_NUMBER(TILE_NUMBER),
    .TILE_BANK(TILE_BANK),
    .GFX_DATA(GFX_DATA),
    .GFX_DATA_CS(GFX_DATA_CS),
    .GFX_DATA_OK(GFX_DATA_OK),
    .TILE_NUMBER_OFFS(TILE_NUMBER_OFFS),

    .SCR0_TILE_NUMBER(SCR0_TILE_NUMBER),
    .SCR0_TILE_BANK(SCR0_TILE_BANK),
    .SCR0_GFX_DATA(SCR0_GFX_DATA),
    .SCR0_GFX_DATA_CS(SCR0_GFX_DATA_CS),
    .SCR0_GFX_DATA_OK(SCR0_GFX_DATA_OK),
    .SCR0_TILE_NUMBER_OFFS(SCR0_TILE_NUMBER_OFFS),

    .SCR1_TILE_NUMBER(SCR1_TILE_NUMBER),
    .SCR1_TILE_BANK(SCR1_TILE_BANK),
    .SCR1_GFX_DATA(SCR1_GFX_DATA),
    .SCR1_GFX_DATA_CS(SCR1_GFX_DATA_CS),
    .SCR1_GFX_DATA_OK(SCR1_GFX_DATA_OK),
    .SCR1_TILE_NUMBER_OFFS(SCR1_TILE_NUMBER_OFFS),

    .SCR2_TILE_NUMBER(SCR2_TILE_NUMBER),
    .SCR2_TILE_BANK(SCR2_TILE_BANK),
    .SCR2_GFX_DATA(SCR2_GFX_DATA),
    .SCR2_GFX_DATA_CS(SCR2_GFX_DATA_CS),
    .SCR2_GFX_DATA_OK(SCR2_GFX_DATA_OK),
    .SCR2_TILE_NUMBER_OFFS(SCR2_TILE_NUMBER_OFFS),


    //GFX ROM
    .GFX_CS(GFX_CS),
    .GFX_OK(GFX_OK),
    .GFX0_ADDR(GFX0_ADDR),     
    .GFX0_DOUT(GFX0_DOUT),
    .GFX1_ADDR(GFX1_ADDR),     
    .GFX1_DOUT(GFX1_DOUT),

    .GFXSCR0_CS(GFXSCR0_CS),
    .GFXSCR0_OK(GFXSCR0_OK),
    .GFX0SCR0_ADDR(GFX0SCR0_ADDR),     
    .GFX0SCR0_DOUT(GFX0SCR0_DOUT),
    .GFX1SCR0_ADDR(GFX1SCR0_ADDR),     
    .GFX1SCR0_DOUT(GFX1SCR0_DOUT),

    .GFXSCR1_CS(GFXSCR1_CS),
    .GFXSCR1_OK(GFXSCR1_OK),
    .GFX0SCR1_ADDR(GFX0SCR1_ADDR),     
    .GFX0SCR1_DOUT(GFX0SCR1_DOUT),
    .GFX1SCR1_ADDR(GFX1SCR1_ADDR),     
    .GFX1SCR1_DOUT(GFX1SCR1_DOUT),

    .GFXSCR2_CS(GFXSCR2_CS),
    .GFXSCR2_OK(GFXSCR2_OK),
    .GFX0SCR2_ADDR(GFX0SCR2_ADDR),     
    .GFX0SCR2_DOUT(GFX0SCR2_DOUT),
    .GFX1SCR2_ADDR(GFX1SCR2_ADDR),     
    .GFX1SCR2_DOUT(GFX1SCR2_DOUT),

    .HS_START(HS_START),
    .HS_END(HS_END),
    .VS_START(VS_START),
    .VS_END(VS_END),

    .SS_FREEZE(SS_FREEZE),
    .SS_DATA(SS_DATA),
    .SS_ADDR(SS_ADDR),
    .SS_SELECT(SS_SELECT),
    .SS_WRITE(SS_WRITE),
    .SS_READ(SS_READ),
    .SS_QUERY(SS_QUERY),
    .SS_DATA_OUT(ss_response_data[0*64 +: 64]),
    .SS_ACK(ss_response_ack[0]),
    .SS_QUIESCED(ss_gcu_quiesced)
);

raizing_ss_wide_register #(
    .WIDTH(44),
    .SS_INDEX(28)
) u_ss_vtimer(
    .clk(CLK96),
    .reset(RESET96),
    .capture_data(ss_vtimer_state),
    .restore_data(ss_vtimer_restore),
    .restore_we(ss_vtimer_restore_we),
    .ss_data(SS_DATA),
    .ss_addr(SS_ADDR),
    .ss_select(SS_SELECT),
    .ss_write(SS_WRITE),
    .ss_read(SS_READ),
    .ss_query(SS_QUERY),
    .ss_data_out(ss_response_data[1*64 +: 64]),
    .ss_ack(ss_response_ack[1])
);

raizing_ss_response_mux #(.COUNT(2)) u_ss_response(
    .ack(ss_response_ack),
    .data(ss_response_data),
    .ack_out(SS_ACK),
    .data_out(SS_DATA_OUT)
);

assign SS_QUIESCED = !SS_ENABLE ||
                     (SS_FREEZE && ss_gcu_quiesced);

endmodule
