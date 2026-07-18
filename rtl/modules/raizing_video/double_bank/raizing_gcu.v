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
module raizing_gcu #(
    parameter SS_ENABLE = 0
)(
    input              CLK,
    input              CLK96,
    input              GFX_CLK,
    input              RESET,
    input              RESET96,
    input              CS,
    output             VINT,
    output reg         ACK,
    input      [15:0]  DIN,
    output reg [15:0]  DOUT,
    input       [8:0]  V,
    input       [8:0]  H,
    output     [10:0]  GP9001OUT,
    input              FLIPX,
    input              FLIPY,
    input              LVBL,

    //Register operations
    input         GP9001_OP_SELECT_REG,
    input         GP9001_OP_WRITE_REG,
    input         GP9001_OP_WRITE_RAM,
    input         GP9001_OP_READ_RAM_H,
    input         GP9001_OP_READ_RAM_L,
    input         GP9001_OP_SET_RAM_PTR,
    input         GP9001_OP_OBJECTBANK_WR,
    input [2:0]   GP9001_OBJECTBANK_SLOT,
    input [7:0]   GAME,
    output        HSYNC,
    output        VSYNC,
    output        FBLANK,

    //registers
    output signed [12:0] SPRITE_SCROLL_X,
    output signed [12:0] SPRITE_SCROLL_Y,
    output signed [12:0] SPRITE_SCROLL_XOFFS,
    output signed [12:0] SPRITE_SCROLL_YOFFS,
    output signed [12:0] BACKGROUND_SCROLL_X,
    output signed [12:0] BACKGROUND_SCROLL_Y,
    output signed [12:0] BACKGROUND_SCROLL_XOFFS,
    output signed [12:0] BACKGROUND_SCROLL_YOFFS,
    output signed [12:0] FOREGROUND_SCROLL_X,
    output signed [12:0] FOREGROUND_SCROLL_Y,
    output signed [12:0] FOREGROUND_SCROLL_XOFFS,
    output signed [12:0] FOREGROUND_SCROLL_YOFFS,
    output signed [12:0] TEXT_SCROLL_X,
    output signed [12:0] TEXT_SCROLL_Y,
    output signed [12:0] TEXT_SCROLL_XOFFS,
    output signed [12:0] TEXT_SCROLL_YOFFS,


    input  [12:0] GP9001RAM_GCU_ADDR,
    output [15:0] GP9001RAM_GCU_DOUT,
    input  [12:0] GP9001RAM2_GCU_ADDR,
    output [15:0] GP9001RAM2_GCU_DOUT,
    input  [12:0] SCR0_GP9001RAM_GCU_ADDR,
    output [15:0] SCR0_GP9001RAM_GCU_DOUT,
    input  [12:0] SCR1_GP9001RAM_GCU_ADDR,
    output [15:0] SCR1_GP9001RAM_GCU_DOUT,
    input  [12:0] SCR2_GP9001RAM_GCU_ADDR,
    output [15:0] SCR2_GP9001RAM_GCU_DOUT,

    //banking
    input [14:0] TILE_NUMBER,
    input [3:0] TILE_BANK,
    output [31:0] GFX_DATA,
    input GFX_DATA_CS,
    output GFX_DATA_OK,
    input [15:0] TILE_NUMBER_OFFS,

    input [14:0] SCR0_TILE_NUMBER,
    input [3:0] SCR0_TILE_BANK,
    output [31:0] SCR0_GFX_DATA,
    input SCR0_GFX_DATA_CS,
    output SCR0_GFX_DATA_OK,
    input [15:0] SCR0_TILE_NUMBER_OFFS,

    input [14:0] SCR1_TILE_NUMBER,
    input [3:0] SCR1_TILE_BANK,
    output [31:0] SCR1_GFX_DATA,
    input SCR1_GFX_DATA_CS,
    output SCR1_GFX_DATA_OK,
    input [15:0] SCR1_TILE_NUMBER_OFFS,

    input [14:0] SCR2_TILE_NUMBER,
    input [3:0] SCR2_TILE_BANK,
    output [31:0] SCR2_GFX_DATA,
    input SCR2_GFX_DATA_CS,
    output SCR2_GFX_DATA_OK,
    input [15:0] SCR2_TILE_NUMBER_OFFS,

    //GFX Read
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

    input   [8:0] HS_START,
    input   [8:0] HS_END,
    input   [8:0] VS_START,
    input   [8:0] VS_END,

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

localparam GAREGGA = 8'h00;
localparam KINGDMGP = 8'h02;
localparam SSTRIKER = 8'h01;

wire ss_freeze = SS_ENABLE && SS_FREEZE;
wire ss_gp_ram_active;
wire [12:0] ss_gp_ram_addr;
wire [15:0] ss_gp_ram_data;
wire ss_gp_ram_we;
wire [15:0] ss_gp_ram_q;
wire ss_sprite_ram_active;
wire [12:0] ss_sprite_ram_addr;
wire [15:0] ss_sprite_ram_data;
wire ss_sprite_ram_we;
wire [15:0] ss_sprite_ram_q;
wire [15:0] ss_sprite_ram2_q;
wire [255:0] ss_control_restore;
wire ss_control_restore_we;
reg [255:0] ss_control_capture;
wire [31:0] ss_object_banks;
wire ss_vint_state;
wire [2:0] ss_response_ack;
wire [191:0] ss_response_data;
wire ss_scroll0_active = ss_gp_ram_active && ss_gp_ram_addr < 13'h0800;
wire ss_scroll1_active = ss_gp_ram_active &&
                         ss_gp_ram_addr >= 13'h0800 && ss_gp_ram_addr < 13'h1000;
wire ss_scroll2_active = ss_gp_ram_active &&
                         ss_gp_ram_addr >= 13'h1000 && ss_gp_ram_addr < 13'h1800;
wire ss_sprite_o_active = ss_gp_ram_active &&
                          ss_gp_ram_addr >= 13'h1800 && ss_gp_ram_addr < 13'h1c00;

//debugging 
//  wire debug = 1'b1;
//  integer fd;
//  initial fd = $fopen("log_gp9001.txt", "w");

// layer offsets
wire signed [12:0] background_scroll_xoffs = GAME == SSTRIKER ? -12'h1D5 : -12'h1D6;
wire signed [12:0] background_scroll_xoffs_f = -12'h229;
wire signed [12:0] foreground_scroll_xoffs = GAME == SSTRIKER ? -12'h1D7 : -12'h1D8;
wire signed [12:0] foreground_scroll_xoffs_f = -12'h227;
wire signed [12:0] text_scroll_xoffs = GAME == SSTRIKER ? -12'h1D9 : -12'h1DA;
wire signed [12:0] text_scroll_xoffs_f = -12'h225;
wire signed [12:0] sprite_scroll_xoffs = 12'h024; //12'h1CC;
wire signed [12:0] sprite_scroll_xoffs_f = -12'h17B;

wire signed [12:0] background_scroll_yoffs = -12'h1EF;
wire signed [12:0] background_scroll_yoffs_f = -12'h210;
wire signed [12:0] foreground_scroll_yoffs = -12'h1EF;
wire signed [12:0] foreground_scroll_yoffs_f = -12'h210;
wire signed [12:0] text_scroll_yoffs = -12'h1EF;
wire signed [12:0] text_scroll_yoffs_f = -12'h210;
wire signed [12:0] sprite_scroll_yoffs = GAME == KINGDMGP || GAME == SSTRIKER ? -12'h001 : 12'h001;
wire signed [12:0] sprite_scroll_yoffs_f = -12'h108;

//blanking signal generation
assign HSYNC = H > HS_START && H < HS_END ? 0 : 1;
assign VSYNC = V >= VS_START && V <= VS_END ? 0 : 1;
assign FBLANK = !HSYNC || !VSYNC ? 0 : 1;
assign GP9001OUT = 11'd0;

//ram pointer
reg [12:0] GP9001RAM_ADDR;
wire [15:0] GP9001RAM_DOUT;
reg [15:0] GP9001RAM_DIN;
reg GP9001RAM_WE;

reg [15:0] cur_ram_ptr = 16'h0000;

//scroll registers
reg [7:0] cur_scr_reg_num = 8'hFF;
reg [15:0] voffs = 16'h0000;

reg scr_reg_background_flip_x = 0;
reg scr_reg_foreground_flip_x = 0;
reg scr_reg_text_flip_x = 0;
reg scr_reg_sprite_flip_x = 0;

reg scr_reg_background_flip_y = 0;
reg scr_reg_foreground_flip_y = 0;
reg scr_reg_text_flip_y = 0;
reg scr_reg_sprite_flip_y = 0;

reg [15:0] scr_reg_background_scroll_x = 16'd0;
reg [15:0] scr_reg_background_scroll_y = 16'd0;
reg [15:0] scr_reg_foreground_scroll_x = 16'd0;
reg [15:0] scr_reg_foreground_scroll_y = 16'd0;
reg [15:0] scr_reg_text_scroll_x = 16'd0;
reg [15:0] scr_reg_text_scroll_y = 16'd0;
reg [15:0] scr_reg_sprite_scroll_x = 16'd0;
reg [15:0] scr_reg_sprite_scroll_y = 16'd0;
reg [15:0] reg_init_v_ctrl = 16'd0;

assign SPRITE_SCROLL_X = scr_reg_sprite_scroll_x;
assign SPRITE_SCROLL_Y = scr_reg_sprite_scroll_y;
assign SPRITE_SCROLL_XOFFS = sprite_scroll_xoffs;
assign SPRITE_SCROLL_YOFFS = sprite_scroll_yoffs;

assign BACKGROUND_SCROLL_X = scr_reg_background_scroll_x;
assign BACKGROUND_SCROLL_Y = scr_reg_background_scroll_y;
assign BACKGROUND_SCROLL_XOFFS = background_scroll_xoffs;
assign BACKGROUND_SCROLL_YOFFS = background_scroll_yoffs;

assign FOREGROUND_SCROLL_X = scr_reg_foreground_scroll_x;
assign FOREGROUND_SCROLL_Y = scr_reg_foreground_scroll_y;
assign FOREGROUND_SCROLL_XOFFS = foreground_scroll_xoffs;
assign FOREGROUND_SCROLL_YOFFS =foreground_scroll_yoffs;

assign TEXT_SCROLL_X = scr_reg_text_scroll_x;
assign TEXT_SCROLL_Y = scr_reg_text_scroll_y;
assign TEXT_SCROLL_XOFFS = text_scroll_xoffs;
assign TEXT_SCROLL_YOFFS = text_scroll_yoffs;

raizing_gp9001_vint #(.SS_ENABLE(SS_ENABLE)) u_vint (
    .clk        (CLK96),
    .reset      (RESET96),
    .line_start (GFX_CLK && H == 9'd0),
    .vpos       (V),
    .reg_write  (GP9001_OP_WRITE_REG),
    .reg_index  (cur_scr_reg_num),
    .vint_n     (VINT),
    .ss_hold    (ss_freeze),
    .ss_restore (ss_control_restore_we),
    .ss_state_in(ss_control_restore[205]),
    .ss_state   (ss_vint_state)
);

reg INC_LAST_CYCLE = 1'b0;
reg READ_LAST_CYCLE = 1'b0;
reg [7:0] LAST_OP = 8'h00;

//do cpu bus tasks
reg [2:0] st=0;
always @(posedge CLK96, posedge RESET96) begin
    if(RESET96) begin
        //reset the scroll registers

        //flip x
        scr_reg_background_flip_x <= ~FLIPX;
        scr_reg_foreground_flip_x <= ~FLIPX;
        scr_reg_text_flip_x <= ~FLIPX;
        scr_reg_sprite_flip_x <= ~FLIPX;

        //flip y
        scr_reg_background_flip_y <= ~FLIPY;
        scr_reg_foreground_flip_y <= ~FLIPY;
        scr_reg_text_flip_y <= ~FLIPY;
        scr_reg_sprite_flip_y <= ~FLIPY;

        //scroll regs
        scr_reg_background_scroll_x <= 0;
        scr_reg_background_scroll_y <= 0;
        scr_reg_foreground_scroll_x <= 0;
        scr_reg_foreground_scroll_y <= 0;
        scr_reg_text_scroll_x <= 0;
        scr_reg_text_scroll_y <= 0;
        
        scr_reg_sprite_scroll_x <= 0;
        scr_reg_sprite_scroll_y <= 0;
    end else if(ss_control_restore_we) begin
        cur_ram_ptr <= ss_control_restore[15:0];
        cur_scr_reg_num <= ss_control_restore[23:16];
        LAST_OP <= ss_control_restore[31:24];
        scr_reg_background_scroll_x <= ss_control_restore[47:32];
        scr_reg_background_scroll_y <= ss_control_restore[63:48];
        scr_reg_foreground_scroll_x <= ss_control_restore[79:64];
        scr_reg_foreground_scroll_y <= ss_control_restore[95:80];
        scr_reg_text_scroll_x <= ss_control_restore[111:96];
        scr_reg_text_scroll_y <= ss_control_restore[127:112];
        scr_reg_sprite_scroll_x <= ss_control_restore[143:128];
        scr_reg_sprite_scroll_y <= ss_control_restore[159:144];
        reg_init_v_ctrl <= ss_control_restore[175:160];
        scr_reg_background_flip_x <= ss_control_restore[238];
        scr_reg_foreground_flip_x <= ss_control_restore[239];
        scr_reg_text_flip_x <= ss_control_restore[240];
        scr_reg_sprite_flip_x <= ss_control_restore[241];
        scr_reg_background_flip_y <= ss_control_restore[242];
        scr_reg_foreground_flip_y <= ss_control_restore[243];
        scr_reg_text_flip_y <= ss_control_restore[244];
        scr_reg_sprite_flip_y <= ss_control_restore[245];
        INC_LAST_CYCLE <= ss_control_restore[246];
        READ_LAST_CYCLE <= ss_control_restore[247];
        st <= ss_control_restore[250:248];
        GP9001RAM_WE <= ss_control_restore[251];
        ACK <= ss_control_restore[252];
    end else if(!ss_freeze) begin
        // if(debug && (GP9001_OP_SET_RAM_PTR || GP9001_OP_WRITE_RAM || GP9001_OP_READ_RAM_H || GP9001_OP_READ_RAM_L)) 
        //     $fwrite(fd, "time: %t, din: %h, dout: %h, cur_ram_ptr: %h, op: %h\n", $time/1000, DIN, DOUT, cur_ram_ptr, {GP9001_OP_SELECT_REG, GP9001_OP_WRITE_REG, GP9001_OP_SET_RAM_PTR, GP9001_OP_WRITE_RAM, GP9001_OP_READ_RAM_H, GP9001_OP_READ_RAM_L, GP9001_OP_OBJECTBANK_WR});

        //reset vars in transition
        if(LAST_OP != {GP9001_OP_SELECT_REG, GP9001_OP_WRITE_REG, GP9001_OP_SET_RAM_PTR, GP9001_OP_WRITE_RAM, GP9001_OP_READ_RAM_H, GP9001_OP_READ_RAM_L, GP9001_OP_OBJECTBANK_WR}) begin
            st<=0;
            INC_LAST_CYCLE <= 1'b0;
            GP9001RAM_WE<=1'b0;
            ACK<=1'b1;
        end

        if(GP9001_OP_SELECT_REG) begin
            cur_scr_reg_num <= DIN & 8'h8F;
            ACK <= 1'b1;
            LAST_OP <= {GP9001_OP_SELECT_REG, GP9001_OP_WRITE_REG, GP9001_OP_SET_RAM_PTR, GP9001_OP_WRITE_RAM, GP9001_OP_READ_RAM_H, GP9001_OP_READ_RAM_L, GP9001_OP_OBJECTBANK_WR};
        end else if(GP9001_OP_WRITE_REG) begin
            case(cur_scr_reg_num)
                8'h00, 8'h80: begin
                    scr_reg_background_scroll_x <= DIN;
                    scr_reg_background_flip_x <= cur_scr_reg_num & 8'h80 ? 
                                                    scr_reg_background_flip_x | FLIPX :
                                                    scr_reg_background_flip_x & ~FLIPX;
                end
                8'h01, 8'h81: begin
                    scr_reg_background_scroll_y <= DIN;
                    scr_reg_background_flip_y <= cur_scr_reg_num & 8'h80 ? 
                                                    scr_reg_background_flip_y | FLIPY :
                                                    scr_reg_background_flip_y & ~FLIPY;
                end
                8'h02, 8'h82: begin
                    scr_reg_foreground_scroll_x <= DIN;
                    scr_reg_foreground_flip_x <= cur_scr_reg_num & 8'h80 ? 
                                                    scr_reg_foreground_flip_x | FLIPX :
                                                    scr_reg_foreground_flip_x & ~FLIPX;
                end
                8'h03, 8'h83: begin
                    scr_reg_foreground_scroll_y <= DIN;
                    scr_reg_foreground_flip_y <= cur_scr_reg_num & 8'h80 ? 
                                                    scr_reg_foreground_flip_y | FLIPY :
                                                    scr_reg_foreground_flip_y & ~FLIPY;
                end
                8'h04, 8'h84: begin
                    scr_reg_text_scroll_x <= DIN;
                    scr_reg_text_flip_x <= cur_scr_reg_num & 8'h80 ? 
                                                    scr_reg_text_flip_x | FLIPX :
                                                    scr_reg_text_flip_x & ~FLIPX;
                end
                8'h05, 8'h85: begin
                    scr_reg_text_scroll_y <= DIN;
                    scr_reg_text_flip_y <= cur_scr_reg_num & 8'h80 ? 
                                                    scr_reg_text_flip_y | FLIPY :
                                                    scr_reg_text_flip_y & ~FLIPY;
                end
                8'h06, 8'h86: begin
                    scr_reg_sprite_scroll_x <= DIN;
                    scr_reg_sprite_flip_x <= cur_scr_reg_num & 8'h80 ? 
                                                    scr_reg_text_flip_x | FLIPX :
                                                    scr_reg_text_flip_x & ~FLIPX;
                end
                8'h07, 8'h87: begin
                    scr_reg_sprite_scroll_y <= DIN;
                    scr_reg_sprite_flip_y <= cur_scr_reg_num & 8'h80 ? 
                                                    scr_reg_sprite_flip_y | FLIPY :
                                                    scr_reg_sprite_flip_y & ~FLIPY;
                end
                8'h0e : begin
                    reg_init_v_ctrl <= DIN;
                end
            endcase
            ACK <= 1'b1;
            LAST_OP <= {GP9001_OP_SELECT_REG, GP9001_OP_WRITE_REG, GP9001_OP_SET_RAM_PTR, GP9001_OP_WRITE_RAM, GP9001_OP_READ_RAM_H, GP9001_OP_READ_RAM_L, GP9001_OP_OBJECTBANK_WR};
        end else if (GP9001_OP_SET_RAM_PTR) begin
            cur_ram_ptr <= DIN;
            ACK <= 1'b1;
            LAST_OP <= {GP9001_OP_SELECT_REG, GP9001_OP_WRITE_REG, GP9001_OP_SET_RAM_PTR, GP9001_OP_WRITE_RAM, GP9001_OP_READ_RAM_H, GP9001_OP_READ_RAM_L, GP9001_OP_OBJECTBANK_WR};
        end else if (GP9001_OP_WRITE_RAM) begin
            if(!INC_LAST_CYCLE) begin
                GP9001RAM_ADDR <= (cur_ram_ptr & 16'h1FFF);
                GP9001RAM_DIN <= DIN;
                GP9001RAM_WE <= 1'b1;
                INC_LAST_CYCLE <= 1'b1;
                ACK<=1'b0;
            end else if(!ACK) begin
                GP9001RAM_WE<=1'b0;
                cur_ram_ptr <=  cur_ram_ptr + 1;
                ACK <= 1'b1;
            end else begin
                ACK<=1'b1;
            end
            
            LAST_OP <= {GP9001_OP_SELECT_REG, GP9001_OP_WRITE_REG, GP9001_OP_SET_RAM_PTR, GP9001_OP_WRITE_RAM, GP9001_OP_READ_RAM_H, GP9001_OP_READ_RAM_L, GP9001_OP_OBJECTBANK_WR};
        end else if(GP9001_OP_READ_RAM_H || GP9001_OP_READ_RAM_L) begin
            case(st)
                0: begin
                    GP9001RAM_ADDR <= (cur_ram_ptr & 16'h1FFF) + (GP9001_OP_READ_RAM_L ? 1'b1 : 1'b0);
                    GP9001RAM_WE <=1'b0;
                    ACK<=1'b0;
                    st<=1;
                end
                1: st<=2;
                2: begin
                    DOUT <= GP9001RAM_DOUT;
                    ACK<=1'b1;
                    st<=3;
                end
            endcase
            
            LAST_OP <= {GP9001_OP_SELECT_REG, GP9001_OP_WRITE_REG, GP9001_OP_SET_RAM_PTR, GP9001_OP_WRITE_RAM, GP9001_OP_READ_RAM_H, GP9001_OP_READ_RAM_L, GP9001_OP_OBJECTBANK_WR};
        end else if(GP9001_OP_OBJECTBANK_WR) begin
            ACK <= 1'b1;
            LAST_OP <= {GP9001_OP_SELECT_REG, GP9001_OP_WRITE_REG, GP9001_OP_SET_RAM_PTR, GP9001_OP_WRITE_RAM, GP9001_OP_READ_RAM_H, GP9001_OP_READ_RAM_L, GP9001_OP_OBJECTBANK_WR};
        end else begin
            ACK <= 1'b1;
            GP9001RAM_WE <= 1'b0;
            INC_LAST_CYCLE <= 1'b0;
            st<=0;
        end
    end
end

//GP9001 RAM

raizing_dual_ram #(
    .DW(16),
    .AW(13),
    .SS_ENABLE(SS_ENABLE)
) u_gp9001ram_044_045(
    .clk0(CLK96),
    .clk1(CLK96),
    // Port 0
    .data0(GP9001RAM_DIN),
    .addr0(GP9001RAM_ADDR),
    .we0(GP9001RAM_WE && !ss_freeze),
    .q0(),
    // Port 1
    .data1(16'h0000),
    .addr1(GP9001RAM_ADDR),
    .we1(1'b0),
    .q1(GP9001RAM_DOUT),
    .ss_active(ss_gp_ram_active),
    .ss_data(ss_gp_ram_data),
    .ss_addr(ss_gp_ram_addr),
    .ss_we(ss_gp_ram_we),
    .ss_q(ss_gp_ram_q)
);

//GP9001 RAM (split out, to make rendering easier. only used internally by the GCU)
wire scroll0ram_we = GP9001RAM_WE && (GP9001RAM_ADDR>=14'h0 && GP9001RAM_ADDR<14'h800);
wire scroll1ram_we = GP9001RAM_WE && (GP9001RAM_ADDR>=14'h800 && GP9001RAM_ADDR<14'h1000);
wire scroll2ram_we = GP9001RAM_WE && (GP9001RAM_ADDR>=14'h1000 && GP9001RAM_ADDR<14'h1800);
wire spriteram_we = GP9001RAM_WE && (GP9001RAM_ADDR>=14'h1800 && GP9001RAM_ADDR<14'h1C00);

//sprite lag fix
reg [1:0] cur_buf = 0;
wire [1:0] sprite_lag = GAME == GAREGGA ? 2'd1 : 2'd0;
wire [1:0] cur_buf_rd = cur_buf - sprite_lag;
wire [12:0] spriteram_buff_offs = cur_buf==0 ? 0 :
                                  cur_buf==1 ? 14'h400 :
                                  cur_buf==2 ? 14'h800 :
                                  cur_buf==3 ? 14'h1000 :
                                  0;
wire [12:0] spriteram_clear_buff_offs = cur_buf==3 ? 0 :
                                        cur_buf==0 ? 14'h400 :
                                        cur_buf==1 ? 14'h800 :
                                        cur_buf==2 ? 14'h1000 :
                                        0;
wire [12:0] spriteram_buff_rd_offs = cur_buf_rd==0 ? 0 :
                                     cur_buf_rd==1 ? 13'h400 :
                                     cur_buf_rd==2 ? 13'h800 :
                                     cur_buf_rd==3 ? 13'h1000 :
                                     0;

reg last_vb = 0;
wire is_vb = LVBL; // start of vblank

reg clear_buff;
reg clear_buff_done;
reg [12:0] clear_buff_addr;
reg [9:0] clear_buff_counter;
wire [15:0] clear_buff_data;

always @(posedge CLK96, posedge RESET96) begin
    if(RESET96) begin
        last_vb<=0;
        cur_buf<=0;
        clear_buff<=0;
    end else if(ss_control_restore_we) begin
        cur_buf <= ss_control_restore[177:176];
        last_vb <= ss_control_restore[178];
        clear_buff <= ss_control_restore[179];
    end else if(!ss_freeze) begin
        last_vb<=is_vb;
        if(is_vb && !last_vb) begin //start of vblank, cut spriteram disable for sorcer and kingdom for now
            cur_buf<=((cur_buf+1)%4);
            clear_buff<=1;
        end

        if(clear_buff_counter=='h3FF) clear_buff<=0;
    end
end

//clear buffer ahead
reg c;

always @* begin
    ss_control_capture = 256'd0;
    ss_control_capture[15:0] = cur_ram_ptr;
    ss_control_capture[23:16] = cur_scr_reg_num;
    ss_control_capture[31:24] = LAST_OP;
    ss_control_capture[47:32] = scr_reg_background_scroll_x;
    ss_control_capture[63:48] = scr_reg_background_scroll_y;
    ss_control_capture[79:64] = scr_reg_foreground_scroll_x;
    ss_control_capture[95:80] = scr_reg_foreground_scroll_y;
    ss_control_capture[111:96] = scr_reg_text_scroll_x;
    ss_control_capture[127:112] = scr_reg_text_scroll_y;
    ss_control_capture[143:128] = scr_reg_sprite_scroll_x;
    ss_control_capture[159:144] = scr_reg_sprite_scroll_y;
    ss_control_capture[175:160] = reg_init_v_ctrl;
    ss_control_capture[177:176] = cur_buf;
    ss_control_capture[178] = last_vb;
    ss_control_capture[179] = clear_buff;
    ss_control_capture[180] = clear_buff_done;
    ss_control_capture[193:181] = clear_buff_addr;
    ss_control_capture[203:194] = clear_buff_counter;
    ss_control_capture[204] = c;
    ss_control_capture[205] = ss_vint_state;
    ss_control_capture[237:206] = ss_object_banks;
    ss_control_capture[238] = scr_reg_background_flip_x;
    ss_control_capture[239] = scr_reg_foreground_flip_x;
    ss_control_capture[240] = scr_reg_text_flip_x;
    ss_control_capture[241] = scr_reg_sprite_flip_x;
    ss_control_capture[242] = scr_reg_background_flip_y;
    ss_control_capture[243] = scr_reg_foreground_flip_y;
    ss_control_capture[244] = scr_reg_text_flip_y;
    ss_control_capture[245] = scr_reg_sprite_flip_y;
    ss_control_capture[246] = INC_LAST_CYCLE;
    ss_control_capture[247] = READ_LAST_CYCLE;
    ss_control_capture[250:248] = st;
    ss_control_capture[251] = GP9001RAM_WE;
    ss_control_capture[252] = ACK;
end

always @(posedge CLK96, posedge RESET96) begin
    if(RESET96) begin
        clear_buff_addr<=0;
        clear_buff_counter<=0;
        clear_buff_done<=0;
        c<=0;
    end else if(ss_control_restore_we) begin
        clear_buff_done <= ss_control_restore[180];
        clear_buff_addr <= ss_control_restore[193:181];
        clear_buff_counter <= ss_control_restore[203:194];
        c <= ss_control_restore[204];
    end else if(!ss_freeze) begin
        if(clear_buff) begin
            c<=c+1;
            case(c)
                0: begin
                    clear_buff_addr<=clear_buff_counter;
                    clear_buff_counter<=clear_buff_counter+1;

                    if(clear_buff_addr=='h3FF) clear_buff_done<=1;
                    else clear_buff_done<=0;
                end
                1: ; //wait state
            endcase
        end else begin
            clear_buff_counter<=0;
            clear_buff_done<=1;
            c<=0;
        end
    end
end

raizing_dual_ram #(
        .DW(16),
        .AW(10),
        .SS_ENABLE(SS_ENABLE)
    ) u_spriteram_o(
        .clk0(CLK96),
        .clk1(CLK96),
        // Port 0
        .data0(GP9001RAM_DIN),
        .addr0(GP9001RAM_ADDR[9:0]),
        .we0(spriteram_we && !ss_freeze),
        .q0(),
        // Port 1
        .data1(16'h0),
        .addr1(clear_buff_addr[9:0]),
        .we1(1'b0),
        .q1(clear_buff_data),
        .ss_active(ss_sprite_o_active),
        .ss_data(ss_gp_ram_data),
        .ss_addr(ss_gp_ram_addr[9:0]),
        .ss_we(ss_gp_ram_we),
        .ss_q()
);

raizing_dual_ram #(
        .DW(16),
        .AW(13),
        .SS_ENABLE(SS_ENABLE)
    ) u_spriteram(
        .clk0(CLK96),
        .clk1(CLK96),
        // Port 0
        .data0(clear_buff_data),
        .addr0(clear_buff_addr + spriteram_buff_offs),
        .we0(clear_buff && !clear_buff_done && !ss_freeze),
        .q0(),
        // Port 1
        .data1(16'h0),
        .addr1(GP9001RAM_GCU_ADDR[9:0] + spriteram_buff_rd_offs),
        .we1(1'b0),
        .q1(GP9001RAM_GCU_DOUT),
        .ss_active(ss_sprite_ram_active),
        .ss_data(ss_sprite_ram_data),
        .ss_addr(ss_sprite_ram_addr),
        .ss_we(ss_sprite_ram_we),
        .ss_q(ss_sprite_ram_q)
);

raizing_dual_ram #(
        .DW(16),
        .AW(13),
        .SS_ENABLE(SS_ENABLE)
    ) u_spriteram2(
        .clk0(CLK96),
        .clk1(CLK96),
        // Port 0
        .data0(clear_buff_data),
        .addr0(clear_buff_addr + spriteram_buff_offs),
        .we0(clear_buff && !clear_buff_done && !ss_freeze),
        .q0(),
        // Port 1
        .data1(16'h0),
        .addr1(GP9001RAM2_GCU_ADDR[9:0] + spriteram_buff_rd_offs),
        .we1(1'b0),
        .q1(GP9001RAM2_GCU_DOUT),
        .ss_active(ss_sprite_ram_active),
        .ss_data(ss_sprite_ram_data),
        .ss_addr(ss_sprite_ram_addr),
        .ss_we(ss_sprite_ram_we),
        .ss_q(ss_sprite_ram2_q)
);

raizing_dual_ram #(
        .DW(16),
        .AW(11),
        .SS_ENABLE(SS_ENABLE)
    ) u_scroll0ram(
        .clk0(CLK96),
        .clk1(CLK96),
        // Port 0
        .data0(GP9001RAM_DIN),
        .addr0(GP9001RAM_ADDR[10:0]),
        .we0(scroll0ram_we && !ss_freeze),
        .q0(),
        // Port 1
        .data1(16'h0000),
        .addr1(SCR0_GP9001RAM_GCU_ADDR[10:0]),
        .we1(1'b0),
        .q1(SCR0_GP9001RAM_GCU_DOUT),
        .ss_active(ss_scroll0_active),
        .ss_data(ss_gp_ram_data),
        .ss_addr(ss_gp_ram_addr[10:0]),
        .ss_we(ss_gp_ram_we),
        .ss_q()
);

raizing_dual_ram #(
        .DW(16),
        .AW(11),
        .SS_ENABLE(SS_ENABLE)
    ) u_scroll1ram(
        .clk0(CLK96),
        .clk1(CLK96),
        // Port 0
        .data0(GP9001RAM_DIN),
        .addr0(GP9001RAM_ADDR[10:0]),
        .we0(scroll1ram_we && !ss_freeze),
        .q0(),
        // Port 1
        .data1(16'h0000),
        .addr1(SCR1_GP9001RAM_GCU_ADDR[10:0]),
        .we1(1'b0),
        .q1(SCR1_GP9001RAM_GCU_DOUT),
        .ss_active(ss_scroll1_active),
        .ss_data(ss_gp_ram_data),
        .ss_addr(ss_gp_ram_addr[10:0]),
        .ss_we(ss_gp_ram_we),
        .ss_q()
);

raizing_dual_ram #(
        .DW(16),
        .AW(11),
        .SS_ENABLE(SS_ENABLE)
    ) u_scroll2ram(
        .clk0(CLK96),
        .clk1(CLK96),
        // Port 0
        .data0(GP9001RAM_DIN),
        .addr0(GP9001RAM_ADDR[10:0]),
        .we0(scroll2ram_we && !ss_freeze),
        .q0(),
        // Port 1
        .data1(16'h0000),
        .addr1(SCR2_GP9001RAM_GCU_ADDR[10:0]),
        .we1(1'b0),
        .q1(SCR2_GP9001RAM_GCU_DOUT),
        .ss_active(ss_scroll2_active),
        .ss_data(ss_gp_ram_data),
        .ss_addr(ss_gp_ram_addr[10:0]),
        .ss_we(ss_gp_ram_we),
        .ss_q()
);

//GFX interface/ banking
AFBK_CT2 #(.SS_ENABLE(SS_ENABLE)) u_afbk_ct2(
    .CLK(CLK),
    .CLK96(CLK96),
    .GFX_CLK(GFX_CLK),
    .RESET(RESET),
    .RESET96(RESET96),
    .GAME(GAME),
    //object bank
    .OBJECTBANK_SLOT(GP9001_OBJECTBANK_SLOT),
    .OBJECTBANK_DIN(DIN & 4'hF),
    .OBJECTBANK_WR(GP9001_OP_OBJECTBANK_WR),

    //tile requests
    .TILE_NUMBER(TILE_NUMBER),
    .TILE_BANK(TILE_BANK),
    .TILE_NUMBER_OFFS(TILE_NUMBER_OFFS),
    .GFX_DATA_CS(GFX_DATA_CS),
    .GFX_DATA(GFX_DATA),
    .GFX_DATA_OK(GFX_DATA_OK),

    //tile requests
    .SCR0_TILE_NUMBER(SCR0_TILE_NUMBER),
    .SCR0_TILE_BANK(SCR0_TILE_BANK),
    .SCR0_TILE_NUMBER_OFFS(SCR0_TILE_NUMBER_OFFS),
    .SCR0_GFX_DATA_CS(SCR0_GFX_DATA_CS),
    .SCR0_GFX_DATA(SCR0_GFX_DATA),
    .SCR0_GFX_DATA_OK(SCR0_GFX_DATA_OK),

    .SCR1_TILE_NUMBER(SCR1_TILE_NUMBER),
    .SCR1_TILE_BANK(SCR1_TILE_BANK),
    .SCR1_TILE_NUMBER_OFFS(SCR1_TILE_NUMBER_OFFS),
    .SCR1_GFX_DATA_CS(SCR1_GFX_DATA_CS),
    .SCR1_GFX_DATA(SCR1_GFX_DATA),
    .SCR1_GFX_DATA_OK(SCR1_GFX_DATA_OK),

    .SCR2_TILE_NUMBER(SCR2_TILE_NUMBER),
    .SCR2_TILE_BANK(SCR2_TILE_BANK),
    .SCR2_TILE_NUMBER_OFFS(SCR2_TILE_NUMBER_OFFS),
    .SCR2_GFX_DATA_CS(SCR2_GFX_DATA_CS),
    .SCR2_GFX_DATA(SCR2_GFX_DATA),
    .SCR2_GFX_DATA_OK(SCR2_GFX_DATA_OK),

    //GFX sdram interface
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
    .SS_HOLD(ss_freeze),
    .SS_RESTORE(ss_control_restore_we),
    .SS_OBJECT_BANKS_IN(ss_control_restore[237:206]),
    .SS_OBJECT_BANKS(ss_object_banks)
);

raizing_ss_ram_adapter #(
    .WIDTH(16),
    .ADDR_WIDTH(13),
    .SS_INDEX(25)
) u_ss_gp_ram(
    .clk(CLK96),
    .reset(RESET96),
    .ss_data(SS_DATA),
    .ss_addr(SS_ADDR),
    .ss_select(SS_SELECT),
    .ss_write(SS_WRITE),
    .ss_read(SS_READ),
    .ss_query(SS_QUERY),
    .ss_data_out(ss_response_data[0*64 +: 64]),
    .ss_ack(ss_response_ack[0]),
    .ram_active(ss_gp_ram_active),
    .ram_addr(ss_gp_ram_addr),
    .ram_data(ss_gp_ram_data),
    .ram_we(ss_gp_ram_we),
    .ram_q(ss_gp_ram_q)
);

raizing_ss_ram_adapter #(
    .WIDTH(16),
    .ADDR_WIDTH(13),
    .SS_INDEX(26)
) u_ss_sprite_ram(
    .clk(CLK96),
    .reset(RESET96),
    .ss_data(SS_DATA),
    .ss_addr(SS_ADDR),
    .ss_select(SS_SELECT),
    .ss_write(SS_WRITE),
    .ss_read(SS_READ),
    .ss_query(SS_QUERY),
    .ss_data_out(ss_response_data[1*64 +: 64]),
    .ss_ack(ss_response_ack[1]),
    .ram_active(ss_sprite_ram_active),
    .ram_addr(ss_sprite_ram_addr),
    .ram_data(ss_sprite_ram_data),
    .ram_we(ss_sprite_ram_we),
    .ram_q(ss_sprite_ram_q)
);

raizing_ss_wide_register #(
    .WIDTH(256),
    .SS_INDEX(27)
) u_ss_control(
    .clk(CLK96),
    .reset(RESET96),
    .capture_data(ss_control_capture),
    .restore_data(ss_control_restore),
    .restore_we(ss_control_restore_we),
    .ss_data(SS_DATA),
    .ss_addr(SS_ADDR),
    .ss_select(SS_SELECT),
    .ss_write(SS_WRITE),
    .ss_read(SS_READ),
    .ss_query(SS_QUERY),
    .ss_data_out(ss_response_data[2*64 +: 64]),
    .ss_ack(ss_response_ack[2])
);

raizing_ss_response_mux #(.COUNT(3)) u_ss_response(
    .ack(ss_response_ack),
    .data(ss_response_data),
    .ack_out(SS_ACK),
    .data_out(SS_DATA_OUT)
);

assign SS_QUIESCED = !SS_ENABLE || ss_freeze;

endmodule
