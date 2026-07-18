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
/*
Raizing Text VRAM Controller & DMA Controller
*/
module TVRMCTL7 #(
    parameter SS_ENABLE = 0
)(
    input  CLK,
    input  CLK96,
    input  RESET,
    input  RESET96,
    input  BUSACK,
    output reg BUSREQ,

    //DMA commands
    input      BATRIDER_TEXTDATA_DMA_W,
    input      BATRIDER_PAL_TEXT_DMA_W,
    output     BUSY,

    //in/out ports to write to DMA RAM from external sources.
    input             TVRAM_CS,
    input             TVRAM_WE,
    input       [1:0] TVRAM_DS,
    input      [13:0] TVRAM_WR_ADDR,
    input      [15:0] TVRAM_DIN,

    //main ram interface for DMA copy
    output reg        DMA_RAM_CS,
    output reg [13:0] DMA_RAM_ADDR,
    input      [15:0] DMA_RAM_DATA,

    //output ports for reading
    //text rom
    input [13:0] TEXTROM_ADDR,
    output [15:0] TEXTROM_DATA,

    //text vram
    input [11:0] TEXTVRAM_ADDR,
    output [15:0] TEXTVRAM_DATA,

    //palette ram
    input [10:0] PALRAM_ADDR,
    output [15:0] PALRAM_DATA,

    //text select ram
    input [7:0] TEXTSELECT_ADDR,
    output [15:0] TEXTSELECT_DATA,

    //text scroll ram
    input [7:0] TEXTSCROLL_ADDR,
    output [15:0] TEXTSCROLL_DATA,

    //text scroll ram
    input [13:0] TEXTGFXRAM_ADDR,
    output [15:0] TEXTGFXRAM_DATA,

    //GP9001 data in
    input [10:0] GP9001OUT,

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

reg text_rom_unpacked = 1'b0;
reg [15:0] pre_wr_dma_data;
reg [13:0] pre_wr_dma_addr;
wire ss_freeze = SS_ENABLE && SS_FREEZE;
wire [127:0] control_ss_restore;
wire control_ss_restore_we;
reg [127:0] control_ss_capture;
wire [6:0] ss_response_ack;
wire [447:0] ss_response_data;

wire textrom_ss_active;
wire [13:0] textrom_ss_addr;
wire [15:0] textrom_ss_data;
wire textrom_ss_we;
wire [7:0] textrom_lo_ss_q;
wire [7:0] textrom_hi_ss_q;
wire [15:0] textrom_ss_q = {textrom_hi_ss_q, textrom_lo_ss_q};

wire textvram_ss_active;
wire [11:0] textvram_ss_addr;
wire [15:0] textvram_ss_data;
wire textvram_ss_we;
wire [15:0] textvram_ss_q;
wire palram_ss_active;
wire [10:0] palram_ss_addr;
wire [15:0] palram_ss_data;
wire palram_ss_we;
wire [15:0] palram_ss_q;
wire textselect_ss_active;
wire [7:0] textselect_ss_addr;
wire [15:0] textselect_ss_data;
wire textselect_ss_we;
wire [15:0] textselect_ss_q;
wire textscroll_ss_active;
wire [7:0] textscroll_ss_addr;
wire [15:0] textscroll_ss_data;
wire textscroll_ss_we;
wire [15:0] textscroll_ss_q;
wire textgfx_ss_active;
wire [13:0] textgfx_ss_addr;
wire [15:0] textgfx_ss_data;
wire textgfx_ss_we;
wire [15:0] textgfx_ss_q;

wire textrom_we = TVRAM_WE && !text_rom_unpacked;
wire textvram_we = pre_wr_dma_addr < 14'h1000;
wire palram_we = pre_wr_dma_addr >= 14'h1000 && pre_wr_dma_addr < 14'h1800;
wire textselect_we = pre_wr_dma_addr >= 14'h1800 && pre_wr_dma_addr < 14'h1900;
wire textscroll_we = pre_wr_dma_addr >= 14'h1900 && pre_wr_dma_addr < 14'h1A00;
wire textgfxram_we = pre_wr_dma_addr >= 14'h1A00 && pre_wr_dma_addr <= 14'h3FFF; //it may not be used.

wire [15:0] wr_dma_data = (TVRAM_CS && !text_rom_unpacked) ? TVRAM_DIN : pre_wr_dma_data;
wire [13:0] wr_dma_addr = (TVRAM_CS && !text_rom_unpacked) ? TVRAM_WR_ADDR : pre_wr_dma_addr;

initial BUSREQ = 0;
assign BUSY = BUSREQ;

//DMA commands from CPU
localparam text_pal_len = 13'h1A00;
reg [12:0] counter = 13'd0;

reg [1:0] st = 1'b0;

always @* begin
    control_ss_capture = 128'd0;
    control_ss_capture[0] = text_rom_unpacked;
    control_ss_capture[16:1] = pre_wr_dma_data;
    control_ss_capture[30:17] = pre_wr_dma_addr;
    control_ss_capture[31] = BUSREQ;
    control_ss_capture[32] = DMA_RAM_CS;
    control_ss_capture[46:33] = DMA_RAM_ADDR;
    control_ss_capture[78:47] = {19'd0, counter};
    control_ss_capture[80:79] = st;
end

always @(posedge CLK96 or posedge RESET96) begin
    if(RESET96) begin
        counter <= 0;
        DMA_RAM_CS <= 1'b0;
    end else if(control_ss_restore_we) begin
        text_rom_unpacked <= control_ss_restore[0];
        pre_wr_dma_data <= control_ss_restore[16:1];
        pre_wr_dma_addr <= control_ss_restore[30:17];
        BUSREQ <= control_ss_restore[31];
        DMA_RAM_CS <= control_ss_restore[32];
        DMA_RAM_ADDR <= control_ss_restore[46:33];
        counter <= control_ss_restore[59:47];
        st <= control_ss_restore[80:79];
    end else if(!ss_freeze && BATRIDER_TEXTDATA_DMA_W && BUSREQ && BUSACK) begin
        text_rom_unpacked <= 1'b1;
        BUSREQ <= 1'b0;
    end else if(!ss_freeze && BATRIDER_PAL_TEXT_DMA_W && BUSREQ && BUSACK) begin //called once every vblank interval. (palette and text ram)
        if(counter < text_pal_len) begin
            case(st)
                2'b00: begin
                    DMA_RAM_CS <= 1'b1;
                    DMA_RAM_ADDR <= counter;
                    pre_wr_dma_addr <= counter;
                    st <= 2'b01;
                end

                2'b01: begin
                    st <= 2'b10;
                end

                2'b10: begin
                    pre_wr_dma_data <= DMA_RAM_DATA;
                    counter <= counter + 1;
                    st <= 2'b00;
                end
            endcase
        end else begin
            counter <= 0;
            DMA_RAM_CS <= 1'b0;
            BUSREQ <= 1'b0;
        end
    end else if(!ss_freeze) begin
		if(BATRIDER_TEXTDATA_DMA_W || BATRIDER_PAL_TEXT_DMA_W) BUSREQ <= 1'b1;
		else BUSREQ <= 1'b0;
	 end
end

//text rom
raizing_dual_ram #(
    .DW(8), .AW(14), .SS_ENABLE(SS_ENABLE)
) u_textrom_lo(
    .clk0(CLK96),
    .clk1(CLK96),
    .data0  (wr_dma_data[7:0]),
    .addr0  (wr_dma_addr[13:0]),
    .we0    (textrom_we && TVRAM_CS && TVRAM_DS[1] && !ss_freeze),
    .q0     (),
    // Port 1: read
    .data1  (~8'h0),
    .addr1  (TEXTROM_ADDR),
    .we1    (1'b0),
    .q1     (TEXTROM_DATA[7:0]),
    .ss_active(textrom_ss_active),
    .ss_data(textrom_ss_data[7:0]),
    .ss_addr(textrom_ss_addr),
    .ss_we(textrom_ss_we),
    .ss_q(textrom_lo_ss_q)
);

raizing_dual_ram #(
    .DW(8), .AW(14), .SS_ENABLE(SS_ENABLE)
) u_textrom_hi(
    .clk0(CLK96),
    .clk1(CLK96),
    .data0  (wr_dma_data[15:8]),
    .addr0  (wr_dma_addr[13:0]),
    .we0    (textrom_we && TVRAM_CS && TVRAM_DS[0] && !ss_freeze),
    .q0     (),
    // Port 1: read
    .data1  (~8'h0),
    .addr1  (TEXTROM_ADDR),
    .we1    (1'b0),
    .q1     (TEXTROM_DATA[15:8]),
    .ss_active(textrom_ss_active),
    .ss_data(textrom_ss_data[15:8]),
    .ss_addr(textrom_ss_addr),
    .ss_we(textrom_ss_we),
    .ss_q(textrom_hi_ss_q)
);

raizing_dual_ram #(
    .DW(16), .AW(12), .SS_ENABLE(SS_ENABLE)
) u_textvram(
    .clk0(CLK96),
    .clk1(CLK96),
    .data0  (wr_dma_data),
    .addr0  (wr_dma_addr[11:0]),
    .we0    (textvram_we && DMA_RAM_CS && BATRIDER_PAL_TEXT_DMA_W && !ss_freeze),
    .q0     (),
    // Port 1: read
    .data1  (~16'h0),
    .addr1  (TEXTVRAM_ADDR),
    .we1    (1'b0),
    .q1     (TEXTVRAM_DATA),
    .ss_active(textvram_ss_active),
    .ss_data(textvram_ss_data),
    .ss_addr(textvram_ss_addr),
    .ss_we(textvram_ss_we),
    .ss_q(textvram_ss_q)
);

raizing_dual_ram #(
    .DW(16), .AW(11), .SS_ENABLE(SS_ENABLE)
) u_paletteram(
    .clk0(CLK96),
    .clk1(CLK96),
    .data0  (wr_dma_data),
    .addr0  (wr_dma_addr[10:0]),
    .we0    (palram_we && DMA_RAM_CS && BATRIDER_PAL_TEXT_DMA_W && !ss_freeze),
    .q0     (),
    // Port 1: read
    .data1  (~16'h0),
    .addr1  (PALRAM_ADDR),
    .we1    (1'b0),
    .q1     (PALRAM_DATA),
    .ss_active(palram_ss_active),
    .ss_data(palram_ss_data),
    .ss_addr(palram_ss_addr),
    .ss_we(palram_ss_we),
    .ss_q(palram_ss_q)
);

raizing_dual_ram #(
    .DW(16), .AW(8), .SS_ENABLE(SS_ENABLE)
) u_textselect(
    .clk0(CLK96),
    .clk1(CLK96),
    .data0  (wr_dma_data),
    .addr0  (wr_dma_addr[7:0]),
    .we0    (textselect_we && DMA_RAM_CS && BATRIDER_PAL_TEXT_DMA_W && !ss_freeze),
    .q0     (),
    // Port 1: read
    .data1  (~16'h0),
    .addr1  (TEXTSELECT_ADDR),
    .we1    (1'b0),
    .q1     (TEXTSELECT_DATA),
    .ss_active(textselect_ss_active),
    .ss_data(textselect_ss_data),
    .ss_addr(textselect_ss_addr),
    .ss_we(textselect_ss_we),
    .ss_q(textselect_ss_q)
);

raizing_dual_ram #(
    .DW(16), .AW(8), .SS_ENABLE(SS_ENABLE)
) u_textscroll(
    .clk0(CLK96),
    .clk1(CLK96),
    .data0  (wr_dma_data),
    .addr0  (wr_dma_addr[7:0]),
    .we0    (textscroll_we && DMA_RAM_CS && BATRIDER_PAL_TEXT_DMA_W && !ss_freeze),
    .q0     (),
    // Port 1: read
    .data1  (~16'h0),
    .addr1  (TEXTSCROLL_ADDR),
    .we1    (1'b0),
    .q1     (TEXTSCROLL_DATA),
    .ss_active(textscroll_ss_active),
    .ss_data(textscroll_ss_data),
    .ss_addr(textscroll_ss_addr),
    .ss_we(textscroll_ss_we),
    .ss_q(textscroll_ss_q)
);

raizing_dual_ram #(
    .DW(16), .AW(14), .SS_ENABLE(SS_ENABLE)
) u_textgfxram(
    .clk0(CLK96),
    .clk1(CLK96),
    .data0  (wr_dma_data),
    .addr0  (wr_dma_addr[13:0]),
    .we0    (textgfxram_we && DMA_RAM_CS && BATRIDER_PAL_TEXT_DMA_W && !ss_freeze),
    .q0     (),
    // Port 1: read
    .data1  (~16'h0),
    .addr1  (TEXTGFXRAM_ADDR),
    .we1    (1'b0),
    .q1     (TEXTGFXRAM_DATA),
    .ss_active(textgfx_ss_active),
    .ss_data(textgfx_ss_data),
    .ss_addr(textgfx_ss_addr),
    .ss_we(textgfx_ss_we),
    .ss_q(textgfx_ss_q)
);

raizing_ss_ram_adapter #(
    .WIDTH(16), .ADDR_WIDTH(14), .SS_INDEX(29)
) u_ss_textrom(
    .clk(CLK96), .reset(RESET96),
    .ss_data(SS_DATA), .ss_addr(SS_ADDR), .ss_select(SS_SELECT),
    .ss_write(SS_WRITE), .ss_read(SS_READ), .ss_query(SS_QUERY),
    .ss_data_out(ss_response_data[0*64 +: 64]), .ss_ack(ss_response_ack[0]),
    .ram_active(textrom_ss_active), .ram_addr(textrom_ss_addr),
    .ram_data(textrom_ss_data), .ram_we(textrom_ss_we), .ram_q(textrom_ss_q)
);

raizing_ss_ram_adapter #(
    .WIDTH(16), .ADDR_WIDTH(12), .SS_INDEX(30)
) u_ss_textvram(
    .clk(CLK96), .reset(RESET96),
    .ss_data(SS_DATA), .ss_addr(SS_ADDR), .ss_select(SS_SELECT),
    .ss_write(SS_WRITE), .ss_read(SS_READ), .ss_query(SS_QUERY),
    .ss_data_out(ss_response_data[1*64 +: 64]), .ss_ack(ss_response_ack[1]),
    .ram_active(textvram_ss_active), .ram_addr(textvram_ss_addr),
    .ram_data(textvram_ss_data), .ram_we(textvram_ss_we), .ram_q(textvram_ss_q)
);

raizing_ss_ram_adapter #(
    .WIDTH(16), .ADDR_WIDTH(11), .SS_INDEX(31)
) u_ss_palram(
    .clk(CLK96), .reset(RESET96),
    .ss_data(SS_DATA), .ss_addr(SS_ADDR), .ss_select(SS_SELECT),
    .ss_write(SS_WRITE), .ss_read(SS_READ), .ss_query(SS_QUERY),
    .ss_data_out(ss_response_data[2*64 +: 64]), .ss_ack(ss_response_ack[2]),
    .ram_active(palram_ss_active), .ram_addr(palram_ss_addr),
    .ram_data(palram_ss_data), .ram_we(palram_ss_we), .ram_q(palram_ss_q)
);

raizing_ss_ram_adapter #(
    .WIDTH(16), .ADDR_WIDTH(8), .SS_INDEX(32)
) u_ss_textselect(
    .clk(CLK96), .reset(RESET96),
    .ss_data(SS_DATA), .ss_addr(SS_ADDR), .ss_select(SS_SELECT),
    .ss_write(SS_WRITE), .ss_read(SS_READ), .ss_query(SS_QUERY),
    .ss_data_out(ss_response_data[3*64 +: 64]), .ss_ack(ss_response_ack[3]),
    .ram_active(textselect_ss_active), .ram_addr(textselect_ss_addr),
    .ram_data(textselect_ss_data), .ram_we(textselect_ss_we), .ram_q(textselect_ss_q)
);

raizing_ss_ram_adapter #(
    .WIDTH(16), .ADDR_WIDTH(8), .SS_INDEX(33)
) u_ss_textscroll(
    .clk(CLK96), .reset(RESET96),
    .ss_data(SS_DATA), .ss_addr(SS_ADDR), .ss_select(SS_SELECT),
    .ss_write(SS_WRITE), .ss_read(SS_READ), .ss_query(SS_QUERY),
    .ss_data_out(ss_response_data[4*64 +: 64]), .ss_ack(ss_response_ack[4]),
    .ram_active(textscroll_ss_active), .ram_addr(textscroll_ss_addr),
    .ram_data(textscroll_ss_data), .ram_we(textscroll_ss_we), .ram_q(textscroll_ss_q)
);

raizing_ss_ram_adapter #(
    .WIDTH(16), .ADDR_WIDTH(14), .SS_INDEX(34)
) u_ss_textgfx(
    .clk(CLK96), .reset(RESET96),
    .ss_data(SS_DATA), .ss_addr(SS_ADDR), .ss_select(SS_SELECT),
    .ss_write(SS_WRITE), .ss_read(SS_READ), .ss_query(SS_QUERY),
    .ss_data_out(ss_response_data[5*64 +: 64]), .ss_ack(ss_response_ack[5]),
    .ram_active(textgfx_ss_active), .ram_addr(textgfx_ss_addr),
    .ram_data(textgfx_ss_data), .ram_we(textgfx_ss_we), .ram_q(textgfx_ss_q)
);

raizing_ss_wide_register #(
    .WIDTH(128), .SS_INDEX(35)
) u_ss_control(
    .clk(CLK96), .reset(RESET96),
    .capture_data(control_ss_capture),
    .restore_data(control_ss_restore), .restore_we(control_ss_restore_we),
    .ss_data(SS_DATA), .ss_addr(SS_ADDR), .ss_select(SS_SELECT),
    .ss_write(SS_WRITE), .ss_read(SS_READ), .ss_query(SS_QUERY),
    .ss_data_out(ss_response_data[6*64 +: 64]), .ss_ack(ss_response_ack[6])
);

raizing_ss_response_mux #(.COUNT(7)) u_ss_response(
    .ack(ss_response_ack), .data(ss_response_data),
    .ack_out(SS_ACK), .data_out(SS_DATA_OUT)
);

assign SS_QUIESCED = !SS_ENABLE || ss_freeze;

endmodule
