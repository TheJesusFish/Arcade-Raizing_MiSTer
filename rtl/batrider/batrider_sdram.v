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
module batrider_sdram #(
    //8 bit addressing
    parameter ROM01_PRG_LEN = 25'h200000,
			  ROMZ80_PRG_LEN = 25'h40000,
			  GP9001_TILE_LEN = 25'h1000000,
			  PCM_DATA_LEN = 25'h200000,
              SS_ENABLE = 0
)(
    input RESET,
    input CLK,
    input CLK_GFX,

    //ROM loader
	input  [25:0] IOCTL_ADDR,
	input  [7:0]  IOCTL_DOUT,
	output [7:0]  IOCTL_DIN,
	input 		  IOCTL_WR,
	input 		  IOCTL_RAM,
	output [21:0] PROG_ADDR,
	output [15:0] PROG_DATA,
	output [1:0]  PROG_MASK,
	output [1:0]  PROG_BA,
	output reg	  PROG_WE,
	output 		  PROG_RD,
	input 		  PROG_RDY,
    input         DOWNLOADING,
    output        DWNLD_BUSY,

    // Bank 0: allows R/W
    output [21:0] BA0_ADDR,
    output [21:0] BA1_ADDR,
    output [21:0] BA2_ADDR,
    output [21:0] BA3_ADDR,
    output [ 3:0] BA_RD,
    output        BA_WR,
    output [15:0] BA0_DIN,
    output [ 1:0] BA0_DIN_M,  // write mask
    input  [ 3:0] BA_ACK,
    input  [ 3:0] BA_DST,
    input  [ 3:0] BA_DOK,
    input  [ 3:0] BA_RDY,
	input  [15:0] DATA_READ,

    //main cpu prg (Read)
	input 		  ROM68K_CS,
	output 		  ROM68K_OK,
	input  [19:0] ROM68K_ADDR,
	output [15:0] ROM68K_DOUT,
	
	//snd prg (Read)
	input 		  ROMZ80_CS,
	output 		  ROMZ80_OK,
	input  [17:0] ROMZ80_ADDR,
	output  [7:0] ROMZ80_DOUT,

	//snd prg (Read, mirror for z80)
	input 		  ROMZ801_CS,
	output 		  ROMZ801_OK,
	input  [17:0] ROMZ801_ADDR,
	output  [7:0] ROMZ801_DOUT,
	
	//tile data (Read) (it is split across 2 banks)
	input 	[1:0] GFX_CS,
	output 	[1:0] GFX_OK,
	input  [21:0] GFX0_ADDR,
	output [31:0] GFX0_DOUT,
	input  [21:0] GFX1_ADDR,
	output [31:0] GFX1_DOUT,

	//extra port for scroll0
	input 	[1:0] GFXSCR0_CS,
	output 	[1:0] GFXSCR0_OK,
	input  [21:0] GFX0SCR0_ADDR,
	output [31:0] GFX0SCR0_DOUT,
	input  [21:0] GFX1SCR0_ADDR,
	output [31:0] GFX1SCR0_DOUT,

	//extra port for scroll1
	input 	[1:0] GFXSCR1_CS,
	output 	[1:0] GFXSCR1_OK,
	input  [21:0] GFX0SCR1_ADDR,
	output [31:0] GFX0SCR1_DOUT,
	input  [21:0] GFX1SCR1_ADDR,
	output [31:0] GFX1SCR1_DOUT,

	//extra port for scroll2
	input 	[1:0] GFXSCR2_CS,
	output 	[1:0] GFXSCR2_OK,
	input  [21:0] GFX0SCR2_ADDR,
	output [31:0] GFX0SCR2_DOUT,
	input  [21:0] GFX1SCR2_ADDR,
	output [31:0] GFX1SCR2_DOUT,
	
	//PCM data (Read)
	input 		  PCM_CS,
	output 		  PCM_OK,
	input  [20:0] PCM_ADDR,
	output [7:0]  PCM_DOUT,

	//PCM data (Read, mirror for adpcm)
	input 		  PCM1_CS,
	output 		  PCM1_OK,
	input  [20:0] PCM1_ADDR,
	output [7:0]  PCM1_DOUT,

	output reg [7:0] GAME,

	//hiscores
	input		  HISCORE_CS,
	input   [1:0] HISCORE_WE,
	input  [15:0] HISCORE_DIN,
	output [15:0] HISCORE_DOUT,
	input   [8:0] HISCORE_ADDR,

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

//loader
assign DWNLD_BUSY = DOWNLOADING;

localparam [7:0] RAIZING_BATRIDER = 8'h03;

initial GAME = RAIZING_BATRIDER;

localparam ROM_BASE = 26'h1,
		   SND_BASE = ROM_BASE + ROM01_PRG_LEN,
		   TILE_BASE = SND_BASE + ROMZ80_PRG_LEN,
		   PCM_BASE = TILE_BASE + GP9001_TILE_LEN,
		   ROM_END = PCM_BASE + PCM_DATA_LEN;

wire is_cpu = IOCTL_ADDR >= ROM_BASE && IOCTL_ADDR < SND_BASE;
wire is_snd = IOCTL_ADDR >= SND_BASE && IOCTL_ADDR < TILE_BASE;
wire is_tile = IOCTL_ADDR >= TILE_BASE && IOCTL_ADDR < PCM_BASE;
wire is_pcm = IOCTL_ADDR >= PCM_BASE && IOCTL_ADDR < ROM_END;
wire is_game = IOCTL_ADDR == 0;
wire is_rom = is_cpu | is_snd | is_tile | is_pcm;

reg [7:0] pre_data;
reg [1:0] pre_mask;
reg [21:0] pre_addr;
reg [1:0] pre_ba;

wire [25:0] bulk_addr = IOCTL_ADDR;
wire [25:0] cpu_addr = bulk_addr - ROM_BASE;
wire [25:0] snd_load_addr = bulk_addr - SND_BASE;
wire [25:0] snd_addr = (bulk_addr - SND_BASE) + PCM_DATA_LEN; //sound program follows PCM on BA3.
wire [25:0] pcm_addr = (bulk_addr - PCM_BASE); 
wire [25:0] tile_addr = bulk_addr - TILE_BASE;
wire [25:0] load_addr = is_cpu ? cpu_addr :
						is_snd ? snd_load_addr :
						is_pcm ? pcm_addr :
						tile_addr;

assign PROG_DATA = {2{pre_data}};
assign PROG_MASK = pre_mask;
assign PROG_BA = pre_ba;
assign PROG_ADDR = pre_addr;
assign PROG_RD = 0;

// main loader for ROM data

always @(posedge CLK) begin
    if(IOCTL_WR && !IOCTL_RAM) begin
		if(is_game) begin
			PROG_WE <= 1'b0;
			GAME <= IOCTL_DOUT;
		end else if(is_rom) begin
			PROG_WE<=1'b1;
			pre_data <= IOCTL_DOUT;
			pre_mask <= load_addr[0] ? 2'b10 : 2'b01;
			pre_addr <= is_cpu ? cpu_addr>>1 :
						is_snd ? snd_addr>>1 :
						is_pcm ? pcm_addr>>1 :
						(tile_addr & 'h7FFFFF)>>1;
			pre_ba <=  is_cpu ? 2'h0 : //cpu program
					   is_snd ? 2'h3 : //snd program
					   is_pcm ? 2'h3 : //pcm data
					   tile_addr[23] ? 2'h2 : 2'h1; //tiles/gfx first/second half
			// $display("%h, %h, %h", pre_addr, IOCTL_ADDR, IOCTL_DOUT);
		end
    end else begin
		if(!DOWNLOADING || PROG_RDY) PROG_WE<=1'b0;
	end
end

//PROMS
assign BA_WR = 1'b0;

`ifdef SIMULATION

//the snd rom
reg  [7:0] z80prg [0:2**18-1];
`ifndef BATRIDER_LOADER_SIM
initial $readmemh("rom/z80prg.hex",  z80prg, 0, 262143);
`endif

//the 68k rom
reg  [7:0] prg [0:2**22-1];
`ifndef BATRIDER_LOADER_SIM
initial $readmemh("rom/68kprg.hex",  prg, 0, 2097151);
`endif

assign ROM68K_OK=1'b1;
assign ROM68K_DOUT={prg[ROM68K_ADDR<<1], prg[(ROM68K_ADDR<<1)+1]};
assign ROMZ80_OK=1'b1;
assign ROMZ80_DOUT = z80prg[ROMZ80_ADDR];
assign ROMZ801_OK=1'b1;
assign ROMZ801_DOUT = z80prg[ROMZ801_ADDR];

`else
raizing_rom_1slot #(
	.SDRAMW      (22),
	.SLOT0_AW    (20), // 68k ROM (16 bit addressing)
	.SLOT0_DW    (16),
	.SLOT0_LATCH (1),
	.SLOT0_DOUBLE(1),
	.LINE_CACHE0_ENTRIES(4),
	.SLOT0_OFFSET(0)
) u_bank0 (
	.rst         (RESET),
	.clk         (CLK),

	.slot0_cs    (ROM68K_CS),
	.slot0_ok    (ROM68K_OK),
	.slot0_addr  (ROM68K_ADDR),
	.slot0_dout  (ROM68K_DOUT),

	.sdram_addr  (BA0_ADDR),
	.sdram_rd    (BA_RD[0]),
	.sdram_ack   (BA_ACK[0]),
	.data_dst    (BA_DST[0]),
	.data_rdy    (BA_RDY[0]),
	.data_read   (DATA_READ)
);
`endif

raizing_rom_4slots_rr #(
    .SDRAMW      (22),
	.SLOT0_AW    (22), //first half of gfx (8MB) (16 bit addressing, but the words are swapped.)
	.SLOT0_DW    (32),
	.SLOT0_DOUBLE(1),
	.SLOT0_LATCH (0),

	.SLOT1_AW    (22), //first half of gfx (8MB) (16 bit addressing, but the words are swapped.)
	.SLOT1_DW    (32),
	.SLOT1_DOUBLE(1),
	.SLOT1_LATCH (0),

	.SLOT2_AW    (22), //first half of gfx (8MB) (16 bit addressing, but the words are swapped.)
	.SLOT2_DW    (32),
	.SLOT2_DOUBLE(1),
	.SLOT2_LATCH (0),

	.SLOT3_AW    (22), //first half of gfx (8MB) (16 bit addressing, but the words are swapped.)
	.SLOT3_DW    (32),
	.SLOT3_DOUBLE(1),
	.SLOT3_LATCH (0)
) u_bank1 (
    .rst         (RESET),
	.clk         (CLK),

	.slot0_cs    (GFX_CS[0]),
	.slot0_ok    (GFX_OK[0]),
	.slot0_addr  (GFX0_ADDR),
	.slot0_dout  (GFX0_DOUT),

	.slot1_cs    (GFXSCR0_CS[0]),
	.slot1_ok    (GFXSCR0_OK[0]),
	.slot1_addr  (GFX0SCR0_ADDR),
	.slot1_dout  (GFX0SCR0_DOUT),

	.slot2_cs    (GFXSCR1_CS[0]),
	.slot2_ok    (GFXSCR1_OK[0]),
	.slot2_addr  (GFX0SCR1_ADDR),
	.slot2_dout  (GFX0SCR1_DOUT),

	.slot3_cs    (GFXSCR2_CS[0]),
	.slot3_ok    (GFXSCR2_OK[0]),
	.slot3_addr  (GFX0SCR2_ADDR),
	.slot3_dout  (GFX0SCR2_DOUT),

		.sdram_addr  (BA1_ADDR),
		.sdram_rd    (BA_RD[1]),
	.sdram_ack   (BA_ACK[1]),
	.data_dst    (BA_DST[1]),
	.data_rdy    (BA_RDY[1]),
	.data_read   (DATA_READ)
);

raizing_rom_4slots_rr #(
    .SDRAMW      (22),
	.SLOT0_AW    (22), //second half of gfx (8MB) (16 bit addressing, but the words are swapped.)
	.SLOT0_DW    (32),
	.SLOT0_DOUBLE(1),
	.SLOT0_LATCH (0),

	.SLOT1_AW    (22), //first half of gfx (8MB) (16 bit addressing, but the words are swapped.)
	.SLOT1_DW    (32),
	.SLOT1_DOUBLE(1),
	.SLOT1_LATCH (0),

	.SLOT2_AW    (22), //first half of gfx (8MB) (16 bit addressing, but the words are swapped.)
	.SLOT2_DW    (32),
	.SLOT2_DOUBLE(1),
	.SLOT2_LATCH (0),
	
	.SLOT3_AW    (22), //first half of gfx (8MB) (16 bit addressing, but the words are swapped.)
	.SLOT3_DW    (32),
	.SLOT3_DOUBLE(1),
	.SLOT3_LATCH (0)
) u_bank2 (
    .rst         (RESET),
	.clk         (CLK),

	.slot0_cs    (GFX_CS[1]),
	.slot0_ok    (GFX_OK[1]),
	.slot0_addr  (GFX1_ADDR),
	.slot0_dout  (GFX1_DOUT),

	.slot1_cs    (GFXSCR0_CS[1]),
	.slot1_ok    (GFXSCR0_OK[1]),
	.slot1_addr  (GFX1SCR0_ADDR),
	.slot1_dout  (GFX1SCR0_DOUT),

	.slot2_cs    (GFXSCR1_CS[1]),
	.slot2_ok    (GFXSCR1_OK[1]),
	.slot2_addr  (GFX1SCR1_ADDR),
	.slot2_dout  (GFX1SCR1_DOUT),

	.slot3_cs    (GFXSCR2_CS[1]),
	.slot3_ok    (GFXSCR2_OK[1]),
	.slot3_addr  (GFX1SCR2_ADDR),
	.slot3_dout  (GFX1SCR2_DOUT),

		.sdram_addr  (BA2_ADDR),
		.sdram_rd    (BA_RD[2]),
	.sdram_ack   (BA_ACK[2]),
	.data_dst    (BA_DST[2]),
	.data_rdy    (BA_RDY[2]),
	.data_read   (DATA_READ)
);

//pcm data
raizing_rom_4slots_rr #(
    .SDRAMW      (22),
	.SLOT0_AW    (21), //PCM rom (8 bit addressing)
	.SLOT0_DW    (8),
	.SLOT0_LATCH (0),
	.SLOT0_DOUBLE(1),

	.SLOT1_AW    (21), //PCM rom mirror (8 bit addressing)
	.SLOT1_DW    (8),
	.SLOT1_LATCH (0),
	.SLOT1_DOUBLE(1),

	.SLOT2_AW    (18), //sound Z80 ROM (8 bit addressing)
	.SLOT2_DW    (8),
	.SLOT2_LATCH (1),
	.SLOT2_DOUBLE(1),

	.SLOT3_AW    (18), //68k-side Z80 ROM mirror (8 bit addressing)
	.SLOT3_DW    (8),
	.SLOT3_LATCH (1),
	.SLOT3_DOUBLE(1),

	.SLOT2_OFFSET(PCM_DATA_LEN>>1),
	.SLOT3_OFFSET(PCM_DATA_LEN>>1)
) u_bank3 (
    .rst         (RESET),
	.clk         (CLK),

	.slot0_cs    (PCM_CS),
	.slot0_ok    (PCM_OK),
	.slot0_addr  (PCM_ADDR ^ 21'd1),
	.slot0_dout  (PCM_DOUT),

	.slot1_cs    (PCM1_CS),
	.slot1_ok    (PCM1_OK),
	.slot1_addr  (PCM1_ADDR ^ 21'd1),
	.slot1_dout  (PCM1_DOUT),

	.slot2_cs    (ROMZ80_CS),
	.slot2_ok    (ROMZ80_OK),
	.slot2_addr  (ROMZ80_ADDR ^ 18'd1),
	.slot2_dout  (ROMZ80_DOUT),

	.slot3_cs    (ROMZ801_CS),
	.slot3_ok    (ROMZ801_OK),
	.slot3_addr  (ROMZ801_ADDR ^ 18'd1),
	.slot3_dout  (ROMZ801_DOUT),

		.sdram_addr  (BA3_ADDR),
		.sdram_rd    (BA_RD[3]),
	.sdram_ack   (BA_ACK[3]),
	.data_dst    (BA_DST[3]),
	.data_rdy    (BA_RDY[3]),
	.data_read   (DATA_READ)
);

//hiscore table
//20fa20-20fD2F mainram
wire dump_we = IOCTL_WR & IOCTL_RAM;
wire [15:0] hiscore_q1;
assign IOCTL_DIN = IOCTL_ADDR[0] ? hiscore_q1[7:0] : hiscore_q1[15:8];
wire ss_freeze = SS_ENABLE && SS_FREEZE;
wire ss_hiscore_active;
wire [8:0] ss_hiscore_addr;
wire [15:0] ss_hiscore_data;
wire ss_hiscore_we;
wire [8:0] hiscore_dump_addr = ss_hiscore_active ?
                               ss_hiscore_addr : IOCTL_ADDR[9:1];
wire [15:0] hiscore_dump_data = ss_hiscore_active ?
                                ss_hiscore_data : {2{IOCTL_DOUT}};
wire [1:0] hiscore_dump_we = ss_hiscore_active ?
                             {2{ss_hiscore_we}} :
                             {dump_we && !IOCTL_ADDR[0],
                              dump_we && IOCTL_ADDR[0]};

raizing_dual_ram16 #(.AW(9), .SS_ENABLE(SS_ENABLE)) u_hiscore_table(
    .clk0   ( CLK  ),
    .clk1   ( CLK  ),
    // First port: internal use
    .addr0  ( HISCORE_ADDR  ),
    .data0  ( HISCORE_DIN   ),
    .we0    ( HISCORE_WE & {2{!ss_freeze}} ),
    .q0     ( HISCORE_DOUT  ),
    // Second port: dump
    .addr1  ( hiscore_dump_addr ),
    .data1  ( hiscore_dump_data ),
    .we1    ( hiscore_dump_we ),
    .q1     ( hiscore_q1 ),
    .ss_active(ss_hiscore_active),
    .ss_data(ss_hiscore_data),
    .ss_addr(ss_hiscore_addr),
    .ss_we({2{ss_hiscore_we}}),
    .ss_q()
);

raizing_ss_ram_adapter #(
    .WIDTH(16),
    .ADDR_WIDTH(9),
    .SS_INDEX(44)
) u_ss_hiscore(
    .clk(CLK), .reset(RESET),
    .ss_data(SS_DATA), .ss_addr(SS_ADDR),
    .ss_select(SS_SELECT), .ss_write(SS_WRITE),
    .ss_read(SS_READ), .ss_query(SS_QUERY),
    .ss_data_out(SS_DATA_OUT), .ss_ack(SS_ACK),
    .ram_active(ss_hiscore_active), .ram_addr(ss_hiscore_addr),
    .ram_data(ss_hiscore_data), .ram_we(ss_hiscore_we),
    .ram_q(hiscore_q1)
);

assign SS_QUIESCED = !SS_ENABLE || ss_freeze;

endmodule
