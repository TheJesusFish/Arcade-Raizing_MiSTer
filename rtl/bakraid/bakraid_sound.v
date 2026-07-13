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
module bakraid_sound (
    input                CLK,
    input                CLK96,
    input                Z80_CEN,
    input                YMZ_CEN,
    input                RESET,
    input                RESET96,
    output reg           ROMZ80_CS,
	input                ROMZ80_OK,
	output        [17:0] ROMZ80_ADDR,
	input          [7:0] ROMZ80_DOUT, 
    output               PCM_CS,
    input                PCM_OK,
    output        [21:0] PCM_ADDR,
    input          [7:0] PCM_DOUT,
    output               PCM1_CS,
    input                PCM1_OK,
    output        [21:0] PCM1_ADDR,
    input          [7:0] PCM1_DOUT,
    output               PCM2_CS,
    input                PCM2_OK,
    output        [21:0] PCM2_ADDR,
    input          [7:0] PCM2_DOUT,
    output signed [15:0] left,
    output signed [15:0] right,
    output reg              sample,
    output reg           peak,

    //interface with m68k
    output               WAIT,
    output               SNDIRQ,
    input                CS,
    input                NMI,
    output reg     [7:0] SOUNDLATCH3,
    output reg     [7:0] SOUNDLATCH4,
    input          [7:0] SOUNDLATCH,
    input          [7:0] SOUNDLATCH2,
    input          [1:0] FX_LEVEL,
    output reg     [1:0] SOUNDLATCH_ACK,
    input          [1:0] SOUNDLATCH_ACK_INCOMING
);
//clock freq/88200 -1
`define YMZ280B_SAMPLE_RATE ((47250000/88200)-1)

// assign ACK = 1'b1;
wire cpu_cen;
reg int_n;
wire m1_n, iorq_n, mreq_n;
wire rd_n;
wire wr_n;
wire [15:0] A;
reg [7:0] din;
wire io_cs = !iorq_n;
wire [7:0] ram_dout, dout, fm_dout;
reg signed [15:0] fm_left, fm_right;
wire peak_l;
wire peak_r = peak_l;
assign right = left;

//clock divider for sound irq
integer c = 0, cen444 = 'd12000;
wire c_over = c==(cen444-1);

always @(posedge CLK, posedge RESET) begin
    if(RESET) begin
        int_n <= 1;
        c <= 0;
    end else if(Z80_CEN) begin 
        c <= c_over ? 0 : (c+1);
        if(!iorq_n && !m1_n) int_n <= 1;
        else if(c_over) int_n<=0;
    end
end

/*
0: pcmgain <= 8'h10 ;   // 100%
1: pcmgain <= 8'h20 ;   // 200%
2: pcmgain <= 8'h0c ;   // 75%
3: pcmgain <= 8'h08 ;   // 50%
*/

wire [7:0] fx_mult = FX_LEVEL == 2 ? 8'h10 :
                     FX_LEVEL == 3 ? 8'h20 :
                     FX_LEVEL == 1 ? 8'h0c :
                     FX_LEVEL == 0 ? 8'h08 :
                     8'h10; 
always @(posedge CLK) begin
    peak <= peak_l | peak_r;
end

jtframe_mixer #(.W0(16), .W1(16), .WOUT(16)) u_mix_left(
    .rst    ( RESET       ),
    .clk    ( CLK       ),
    .cen    ( 1'b1      ),
    // input signals
    .ch0    ( fm_left   ),
    .ch1    ( fm_right ),
    .ch2    ( 16'd0 ),
    .ch3    ( 16'd0     ),
    // gain for each channel in 4.4 fixed point format
    .gain0  ( fx_mult    ),
    .gain1  ( fx_mult   ),
    .gain2  ( 8'd0     ),
    .gain3  ( 8'd0     ),
    .mixed  ( left      ),
    .peak   ( peak_l    )
);

//io
wire nmi_n;
reg soundlatch3_wr,
    soundlatch4_wr,
    batrider_sndirq_w,
    batrider_clear_nmi_w,
    soundlatch_rd,
    soundlatch2_rd;

//address bus
reg ram_cs;
assign SNDIRQ = batrider_sndirq_w;
assign ROMZ80_ADDR = A & 16'hBFFF;
wire ymz_addr_wr_raw = io_cs && !wr_n && A[7:0] == 8'h80;
wire ymz_data_wr_raw = io_cs && !wr_n && A[7:0] == 8'h81;
wire ymzrd = io_cs && !rd_n && A[7:0] == 8'h81;
reg  ymz_addr_wr_d;
reg  ymz_data_wr_d;
reg  ymz_rd_d;
wire ymz_addr_wr_edge = ymz_addr_wr_raw && !ymz_addr_wr_d;
wire ymz_data_wr_edge = ymz_data_wr_raw && !ymz_data_wr_d;
wire ymz_rd_edge = ymzrd && !ymz_rd_d;
reg  ymz_cpu_wr;
reg  ymz_cpu_rd;
reg  ymz_cpu_addr;
reg [7:0] ymz_cpu_din;
wire ymz_keyon_enable;
wire [7:0] ymz_keyon;
wire ymz_audio_on = ymz_keyon_enable & (|ymz_keyon);

localparam signed [15:0] YMZ_RELEASE_STEP = 16'sd128;
function signed [15:0] ymz_release;
    input signed [15:0] value;
    begin
        if(value > YMZ_RELEASE_STEP)
            ymz_release = value - YMZ_RELEASE_STEP;
        else if(value < -YMZ_RELEASE_STEP)
            ymz_release = value + YMZ_RELEASE_STEP;
        else
            ymz_release = 16'sd0;
    end
endfunction

always @(posedge CLK, posedge RESET) begin
    if(RESET) begin
        soundlatch3_wr <= 0;
        soundlatch4_wr <= 0;
        batrider_sndirq_w <= 0;
        batrider_clear_nmi_w <= 0;
        soundlatch_rd <= 0;
        soundlatch2_rd <= 0;
        ram_cs <= 0; // > 0xC000 to 0xdfff
        ROMZ80_CS <= 0;
        ymz_addr_wr_d <= 0;
        ymz_data_wr_d <= 0;
        ymz_rd_d <= 0;
        ymz_cpu_wr <= 0;
        ymz_cpu_rd <= 0;
        ymz_cpu_addr <= 0;
        ymz_cpu_din <= 0;
    end else begin
        ymz_addr_wr_d <= ymz_addr_wr_raw;
        ymz_data_wr_d <= ymz_data_wr_raw;
        ymz_rd_d <= ymzrd;
        ymz_cpu_wr <= ymz_addr_wr_edge || ymz_data_wr_edge;
        ymz_cpu_rd <= ymz_rd_edge;
        if(ymz_addr_wr_edge || ymz_data_wr_edge || ymz_rd_edge) begin
            ymz_cpu_addr <= A[0];
            ymz_cpu_din <= dout;
        end

        if(io_cs) begin
            soundlatch3_wr <= !wr_n && A[7:0] == 8'h40;
            soundlatch4_wr <= !wr_n && A[7:0] == 8'h42;
            batrider_sndirq_w <= !wr_n && A[7:0] == 8'h44;
            batrider_clear_nmi_w <= !wr_n && A[7:0] == 8'h46;
            soundlatch_rd <= !rd_n && A[7:0] == 8'h48;
            soundlatch2_rd <= !rd_n && A[7:0] == 8'h4a;
        end else begin
            soundlatch3_wr <= 0;
            soundlatch4_wr <= 0;
            batrider_sndirq_w <= 0;
            batrider_clear_nmi_w <= 0;
            soundlatch_rd <= 0;
            soundlatch2_rd <= 0;
        end 
        
        if(!mreq_n) begin
            ram_cs <= A >= 'hC000 && A <= 'hFFFF;
            ROMZ80_CS <= !rd_n && (!A[15] || A[15:14]==2'b10);
        end else begin
            ram_cs<=0;
            ROMZ80_CS<=0;
        end
    end
end

always @(posedge CLK, posedge RESET) begin  
    if(RESET) begin
        SOUNDLATCH3 <= 8'h0;
        SOUNDLATCH4 <= 8'h0;
    end else begin
        //to z80
        case(1'b1)
            ROMZ80_CS: din <= ROMZ80_DOUT;
            ram_cs: din <= ram_dout;
            soundlatch_rd: din <= SOUNDLATCH;
            soundlatch2_rd: din <= SOUNDLATCH2;
            ymzrd: din<=fm_dout;
            default: din <= 8'hFF;
        endcase
        
        SOUNDLATCH_ACK<=SOUNDLATCH_ACK_INCOMING; //synchronize with 68k

        if(soundlatch3_wr) begin
            SOUNDLATCH3 <= dout;
            SOUNDLATCH_ACK[0] <= 1;
        end

        else if(soundlatch4_wr) begin
            SOUNDLATCH4 <= dout;
            SOUNDLATCH_ACK[1] <= 1;
        end
    end
end

jtframe_ff u_nmi_ff(
    .clk      ( CLK         ),
    .rst      ( RESET         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( nmi_n       ),
    .set      ( 1'b0        ),    // active high
    .clr      ( batrider_clear_nmi_w ),    // active high
    .sigedge  ( NMI ) // signal whose edge will trigger the FF
);

jtframe_ff u_m68wait_ff(
    .clk      ( CLK         ),
    .rst      ( RESET         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        ( WAIT            ),
    .qn       (        ),
    .set      ( 1'b0        ),    // active high
    .clr      ( |SOUNDLATCH_ACK ),    // release hold on 68k when all ack finished.
    .sigedge  ( CS     ) // signal whose edge will trigger the FF
);

raizing_t80_sysz80 #(.RAM_AW(14)) u_cpu(
    .rst_n      ( ~RESET    ),
    .clk        ( CLK       ),
    .cen        ( Z80_CEN     ), //5.333
    .cpu_cen    ( cpu_cen     ),
    .int_n      ( int_n       ),
    .nmi_n      ( nmi_n       ),
    .busrq_n    ( 1'b1        ),
    .m1_n       ( m1_n        ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     (             ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .cpu_din    ( din         ),
    .cpu_dout   ( dout        ),
    .ram_dout   ( ram_dout    ),
    .ram_cs     ( ram_cs      ),
    // manage access to ROM data from SDRAM
    .rom_cs     ( ROMZ80_CS   ),
    .rom_ok     ( ROMZ80_OK   )
); 

//sdram bank switch rom 7/8 or 6
wire [23:0] ymz_mem_addr;
wire ymz_io_rd;
wire [15:0] io_audio_bits_left, io_audio_bits_right;
wire signed [15:0] ymz_audio_left = io_audio_bits_left;
wire signed [15:0] ymz_audio_right = io_audio_bits_right;
wire audio_valid;
reg [23:0] ymz_mem_addr_r;
reg        ymz_io_rd_r;

assign PCM_CS=ymz_mem_addr_r<24'h400000 && ymz_io_rd_r;
assign PCM1_CS=ymz_mem_addr_r>=24'h400000 && ymz_mem_addr_r<24'h800000 && ymz_io_rd_r;
assign PCM2_CS=ymz_mem_addr_r>=24'h800000 && ymz_mem_addr_r<24'hC00000 && ymz_io_rd_r;
assign PCM_ADDR=ymz_mem_addr_r[21:0];
assign PCM1_ADDR=ymz_mem_addr_r[21:0];
assign PCM2_ADDR=ymz_mem_addr_r[21:0];
wire over_cs = ymz_mem_addr_r >= 'hC00000 && ymz_io_rd_r;

wire [7:0] io_rom_dout = PCM_CS && PCM_OK ? PCM_DOUT :
                         PCM1_CS && PCM1_OK ? PCM1_DOUT :
                         PCM2_CS && PCM2_OK ? PCM2_DOUT :
                         0;
wire io_rom_valid = (PCM_CS && PCM_OK) ||
                    (PCM1_CS && PCM1_OK) ||
                    (PCM2_CS && PCM2_OK) ||
                    over_cs;
wire io_rom_waitReq = 1;

always @(posedge CLK, posedge RESET) begin
    if(RESET) begin
        ymz_mem_addr_r <= 24'd0;
        ymz_io_rd_r <= 1'b0;
    end else begin
        ymz_mem_addr_r <= ymz_mem_addr;
        ymz_io_rd_r <= ymz_io_rd;
    end
end

always @(posedge CLK) begin
    if(RESET) begin
        fm_left <= 16'd0;
        fm_right <= 16'd0;
        sample <= 1'b0;
    end else begin
        if(audio_valid) begin
            fm_left <= ymz_audio_on ? ymz_audio_left : ymz_release(fm_left);
            fm_right <= ymz_audio_on ? ymz_audio_right : ymz_release(fm_right);
        end
        sample <= audio_valid;
    end
end

YMZ280B u_ymz280b (
    .clock(CLK), //aligned to sdram
    .reset(RESET),
    .io_cpu_rd(ymz_cpu_rd),
    .io_cpu_wr(ymz_cpu_wr),
    .io_cpu_addr(ymz_cpu_addr),
    .io_cpu_mask(1'b1),
    .io_cpu_din(ymz_cpu_din),
    .io_cpu_dout(fm_dout),
    .io_rom_rd(ymz_io_rd),
    .io_rom_addr(ymz_mem_addr),
    .io_rom_dout(io_rom_dout),
    .io_rom_valid(io_rom_valid),
    .io_rom_waitReq(io_rom_waitReq),
    .io_audio_valid(audio_valid),
    .io_audio_bits_left(io_audio_bits_left),
    .io_audio_bits_right(io_audio_bits_right),
    .io_irq(),
    .io_debug_channels_0_flags_keyOn(ymz_keyon[0]),
    .io_debug_channels_1_flags_keyOn(ymz_keyon[1]),
    .io_debug_channels_2_flags_keyOn(ymz_keyon[2]),
    .io_debug_channels_3_flags_keyOn(ymz_keyon[3]),
    .io_debug_channels_4_flags_keyOn(ymz_keyon[4]),
    .io_debug_channels_5_flags_keyOn(ymz_keyon[5]),
    .io_debug_channels_6_flags_keyOn(ymz_keyon[6]),
    .io_debug_channels_7_flags_keyOn(ymz_keyon[7]),
    .io_debug_utilReg_flags_keyOnEnable(ymz_keyon_enable)
);

endmodule
