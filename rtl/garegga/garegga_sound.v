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
module garegga_sound (
    input                CLK,
    input                CLK96,
    input                RESET,
    input                RESET96,
    input                YM2151_CEN,
    input                YM2151_CEN2,
    input                YM2151_CEN_1,
    input                YM2151_CEN2_1,
    input                Z80_CEN,
    input                OKI_CEN,
    input                OKI_CEN_1,
    
    output reg           ROMZ80_CS,
	input                ROMZ80_OK,
	output reg    [16:0] ROMZ80_ADDR,
	input          [7:0] ROMZ80_DOUT, 
    output               PCM_CS,
    input                PCM_OK,
    output        [19:0] PCM_ADDR,
    input          [7:0] PCM_DOUT,
    output signed [15:0] left,
    output signed [15:0] right,
    output               sample,
    output reg           peak,

    //interface with m68k
    output               WAIT,
    input                M68K_RESET_N,
    input                Z80INT,
    input          [7:0] SOUNDLATCH,
    output        [13:0] SRAM_ADDR,
    input          [7:0] SRAM_DATA,
    output         [7:0] SRAM_DIN,
    output               SRAM_WE,

    input                OKI_BANK,
    input          [7:0] GAME,
    input          [1:0] FX_LEVEL,
    input          [5:0] SND_EN,
    input		 DIP_PAUSE
);

localparam GAREGGA = 'h0, KINGDMGP = 'h2, SSTRIKER = 'h1;
wire is_sorcer_kingdom = GAME == KINGDMGP || GAME == SSTRIKER;
wire audio_cpu_reset = RESET96 | (is_sorcer_kingdom && ~M68K_RESET_N);
// assign ACK = 1'b1;
wire cpu_cen;
wire int_n;
wire ym_irq_n;
wire m1_n, iorq_n, mreq_n;
wire rd_n;
wire wr_n;
wire [15:0] A;
reg [7:0] din, oki0_din, oki1_din;
reg [3:0] bank = 2; // init bank to 2
wire [7:0] dout, fm0_dout, oki0_dout, fm1_dout, oki1_dout;
wire signed [15:0] fm0_left, fm0_right, fm1_left, fm1_right;
wire signed [16:0] fm0_mono_sum, fm1_mono_sum;
wire signed [15:0] fm0_mono, fm1_mono;
wire peak_l, peak_r;
wire sample_0, sample_1;
assign sample = GAME == GAREGGA ? sample_0 : sample_1;

wire signed [13:0] oki0_pre, oki1_pre;
wire oki0_sample, oki1_sample;

reg [7:0] nmk112_data_0a;
reg [2:0] nmk112_offset_0a;
reg nmk112_we_q;
reg okim6295_device_0_wr_q;
wire [17:0] oki0_pcm_addr, oki1_pcm_addr;
wire [20:0] nmk_pcm_addr;

//debugging
`ifdef SIMULATION
wire debug = 1'b1;
integer fd;
initial fd = $fopen("logsound.txt", "w");
`endif
/*
JTFrame maps the OSD FX level as:
0: Very Low, 1: Low, 2: High/default, 3: Very High.
Sorcer Striker/Kingdom Grandprix use the louder standalone mix; Garegga
retains its smaller OKI boost.
*/
wire [7:0] fx_mult_sorcer_kingdom = FX_LEVEL == 2 ? 8'h24 :
                                     FX_LEVEL == 3 ? 8'h30 :
                                     FX_LEVEL == 1 ? 8'h18 :
                                     FX_LEVEL == 0 ? 8'h0c :
                                     8'h24;
wire [7:0] fx_mult_garegga = FX_LEVEL == 2 ? 8'h12 :
                              FX_LEVEL == 3 ? 8'h23 :
                              FX_LEVEL == 1 ? 8'h0d :
                              FX_LEVEL == 0 ? 8'h09 :
                              8'h12;
wire [7:0] fmgain = GAME == GAREGGA ? 8'h08 : 8'h0c;

assign fm0_mono_sum = {fm0_left[15], fm0_left} + {fm0_right[15], fm0_right};
assign fm1_mono_sum = {fm1_left[15], fm1_left} + {fm1_right[15], fm1_right};
assign fm0_mono = fm0_mono_sum[16:1];
assign fm1_mono = fm1_mono_sum[16:1];

always @(posedge CLK96) begin
    peak <= peak_l | peak_r;
end

reg [7:0] gain1;
reg signed [15:0] final_left;
reg signed [13:0] final_oki0;
wire [7:0] fm_gain  = SND_EN[0] ? fmgain : 8'd0;
wire [7:0] oki_gain = SND_EN[1] ? gain1  : 8'd0;
always @(posedge CLK96) begin
    final_left<=GAME==GAREGGA ? fm0_mono : fm1_mono;
    final_oki0<=GAME==GAREGGA ? oki0_pre : oki1_pre;
    gain1<=GAME==GAREGGA ? fx_mult_garegga : fx_mult_sorcer_kingdom;
end

assign right = left;
assign peak_r = peak_l;
jtframe_mixer #(.W0(16), .W1(14), .WOUT(16)) u_mix_left(
    .rst    ( RESET96       ),
    .clk    ( CLK96       ),
    .cen    ( 1'b1),
    // input signals
    .ch0    ( final_left   ),
    .ch1    ( final_oki0 ),
    .ch2    ( 16'd0 ),
    .ch3    ( 16'd0     ),
    // gain for each channel in 4.4 fixed point format
    .gain0  ( fm_gain   ),
    .gain1  ( oki_gain  ),
    .gain2  ( 8'd0     ),
    .gain3  ( 8'd0     ),
    .mixed  ( left      ),
    .peak   ( peak_l    )
);

//io
wire nmi_n = 1'b1;
reg soundlatch_rd,
    soundlatch_ack,
    ymsnd_rd,
    okim6295_device_0_rd,
    raizing_z80_bankswitch_w,
    e01d_rd;

wire z80_mem_rd = !mreq_n && !rd_n;
wire z80_mem_wr = !mreq_n && !wr_n;
wire snd_rd_qual = is_sorcer_kingdom ? z80_mem_rd : !rd_n;
wire snd_wr_qual = is_sorcer_kingdom ? z80_mem_wr : !wr_n;
wire ym_access = (is_sorcer_kingdom ? !mreq_n : 1'b1) && (A == 16'hE000 || A == 16'hE001);
wire okim6295_device_0_wr_dec = snd_wr_qual && A == 16'hE004;
wire raizing_oki_bankswitch_w_dec = snd_wr_qual && (A == 16'hE006 || A == 16'hE008);

//address bus
reg ram_cs, fm_cs;
always @(posedge CLK96) begin
    if(audio_cpu_reset) begin
        soundlatch_rd <= 0;
        soundlatch_ack <= 0;
        ymsnd_rd <= 0;
        okim6295_device_0_rd <= 0;
        raizing_z80_bankswitch_w <= 0;
        e01d_rd<=0;
        ram_cs <= 0; // > 0xC000 to 0xdfff
        fm_cs <= 0;
        ROMZ80_CS <= 0;
        ROMZ80_ADDR<=0;
    end else begin
`ifdef SIMULATION
        if(debug)
            $fwrite(fd, "time: %t, addr: %h, int_n: %h, m1_n: %h, iorq_n: %h, dout: %h, din: %h\n", $time/1000, A, int_n, m1_n, iorq_n, dout, din);
`endif
        soundlatch_rd <= snd_rd_qual && A == 16'hE01C;
        soundlatch_ack <= snd_wr_qual && A == 16'hE00C;
        ymsnd_rd <= snd_rd_qual && A == 16'hE001;
        okim6295_device_0_rd <= snd_rd_qual && A == 16'hE004;
        raizing_z80_bankswitch_w <= snd_wr_qual && A == 16'hE00A;
        e01d_rd <= snd_rd_qual && A == 16'hE01D;

        ram_cs <= !mreq_n && A[15:13] == 3'b110; // > 0xC000 to 0xdfff
        fm_cs <= ym_access;
        ROMZ80_CS <= z80_mem_rd && (is_sorcer_kingdom ? A < 16'hC000 : (!A[15] || A[15:14] == 2'b10));
        ROMZ80_ADDR <= is_sorcer_kingdom ? {1'b0, A} :
                       (A[15:14] == 2'b10 ? ({bank[2:0], 14'd0} + {3'b000, A[13:0]}) : {1'b0, A});
    end
end

//io switch

//ram
assign SRAM_WE = ram_cs && !wr_n;
assign SRAM_DIN = dout;
assign SRAM_ADDR = {1'b0,A[12:0]};

always @(posedge CLK96) begin  
    if(audio_cpu_reset) begin
        oki0_din <= 8'h0;
        oki1_din <= 8'h0;
        okim6295_device_0_wr_q <= 1'b0;
        nmk112_we_q <= 1'b0;
        nmk112_offset_0a <= 3'd0;
        nmk112_data_0a <= 8'h0;
    end else begin
        okim6295_device_0_wr_q <= okim6295_device_0_wr_dec;
        nmk112_we_q <= raizing_oki_bankswitch_w_dec;

        //to z80
        case(1'b1)
            ROMZ80_CS: din <= ROMZ80_DOUT;
            (ram_cs && !rd_n): din <= SRAM_DATA;
            soundlatch_rd: din <= SOUNDLATCH;
            ymsnd_rd: din <= GAME == GAREGGA ? fm0_dout : fm1_dout;
            okim6295_device_0_rd: din <= GAME == GAREGGA ? oki0_dout : oki1_dout;
            e01d_rd : din<=8'h00;
            default: din <= 8'hFF;
        endcase

        if(okim6295_device_0_wr_dec) begin
            oki0_din <= dout;
            oki1_din <= dout;
        end

        if(raizing_oki_bankswitch_w_dec) begin
            nmk112_offset_0a <= A[3] ? 3'd2 : 3'd0;
            nmk112_data_0a <= dout;
        end

        if(raizing_z80_bankswitch_w) begin
            bank<=dout[3:0];  
        end
    end
end
assign PCM_ADDR = GAME == KINGDMGP ? ({1'b0, OKI_BANK, 18'd0} + {2'b00, oki1_pcm_addr}) :
                  GAME == SSTRIKER ? {2'b00, oki1_pcm_addr} :
                  nmk_pcm_addr[19:0];


NMK112 u_nmk112_0(
    .CLK(CLK96),
    .RESET(RESET96),
    .WE(nmk112_we_q),
    .OFFSET(nmk112_offset_0a),
    .DATA(nmk112_data_0a),
    .REQ_ADDR(oki0_pcm_addr),
    .REQ_DATA_ADDR(nmk_pcm_addr)
);

jtframe_ff u_int_ff(
    .clk      ( CLK96         ),
    .rst      ( RESET96         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( int_n       ),
    .set      ( 1'b0 ),    // active high
    .clr      ( !iorq_n && !m1_n ),    // active high
    .sigedge  ( Z80INT ) // signal whose edge will trigger the FF
);

jtframe_ff u_m68wait_ff(
    .clk      ( CLK96         ),
    .rst      ( RESET96         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        ( WAIT            ),
    .qn       (        ),
    .set      ( 1'b0        ),    // active high
    .clr      ( soundlatch_ack ),    // active high
    .sigedge  ( Z80INT     ) // signal whose edge will trigger the FF
);
wire z80int_n = GAME == GAREGGA ? int_n : ym_irq_n;

wire busak_n;
wire wait_n = 1'b1;

raizing_z80wait #(1) u_wait(
    .rst_n      ( ~audio_cpu_reset ),
    .clk        ( CLK96       ),
    .cen_in     ( Z80_CEN       ),
    .cen_out    ( cpu_cen   ),
    .gate       (           ),
    .iorq_n     ( iorq_n    ),
    .mreq_n     ( mreq_n    ),
    .busak_n    ( busak_n   ),
    // manage access to shared memory
    .dev_busy   ( 1'b0      ),
    // manage access to ROM data from SDRAM
    .rom_cs     ( ROMZ80_CS    ),
    .rom_ok     ( ROMZ80_OK    )
);

raizing_t80 u_cpu(
    .rst_n    ( ~audio_cpu_reset ),
    .clk      ( CLK96       ),
    .cen      ( cpu_cen   ),
    .wait_n   ( wait_n    ),
    .int_n    ( z80int_n  ),
    .nmi_n    ( nmi_n     ),
    .busrq_n  ( 1'b1   ),
    .m1_n     ( m1_n      ),
    .mreq_n   ( mreq_n    ),
    .iorq_n   ( iorq_n    ),
    .rd_n     ( rd_n      ),
    .wr_n     ( wr_n      ),
    .rfsh_n   (     ),
    .halt_n   (     ),
    .busak_n  (    ),
    .A        ( A         ),
    .din      ( din       ),
    .dout     ( dout      )
);

// jtframe_z80_romwait #(.M1_WAIT(1)) u_cpu(
//     .rst_n      ( ~RESET96      ),
//     .clk        ( CLK96         ),
//     .cen        ( Z80_CEN     ), //4
//     .cpu_cen    ( cpu_cen     ),
//     .int_n      ( z80int_n      ),
//     .nmi_n      ( nmi_n       ),
//     .busrq_n    ( 1'b1        ),
//     .m1_n       ( m1_n        ),
//     .mreq_n     ( mreq_n      ),
//     .iorq_n     ( iorq_n      ),
//     .rd_n       ( rd_n        ),
//     .wr_n       ( wr_n        ),
//     .rfsh_n     (             ),
//     .halt_n     (             ),
//     .busak_n    (             ),
//     .A          ( A           ),
//     .din    ( din         ),
//     .dout   ( dout        ),
//     // .ram_cs     ( ram_cs      ),
//     // manage access to ROM data from SDRAM
//     .rom_cs     ( ROMZ80_CS   ),
//     .rom_ok     ( ROMZ80_OK   )
// ); 

assign PCM_CS = 1'b1;

// Use the softer/brighter JT6295 4x interpolator that fixed the low-brightness
// OKI character in Batrider/Cave while leaving the drop-in module untouched.
//for garegga
jt6295 #(.INTERPOL(2)) u_adpcm_0(
    .rst        ( RESET96       ),
    .clk        ( CLK96       ),
    .cen        ( OKI_CEN & DIP_PAUSE ),
    .ss         ( 1'b1      ),
    // CPU interface
    .wrn        ( ~okim6295_device_0_wr_q ),  // active low
    .din        ( oki0_din      ),
    .dout       ( oki0_dout  ),
    // ROM interface
    .rom_addr   ( oki0_pcm_addr ),
    .rom_data   ( PCM_DOUT),
    .rom_ok     ( PCM_OK  ),
    // Sound output
    .sound      ( oki0_pre   ),
    .sample     ( oki0_sample)   // ~26kHz
);

jt51 u_jt51_0(
    .rst        ( RESET96       ), // reset
    .clk        ( CLK96       ), // main clock
    .cen        ( YM2151_CEN & DIP_PAUSE    ), // 4mhz
    .cen_p1     ( YM2151_CEN2 & DIP_PAUSE   ), //2mhz, half clock
    .cs_n       ( !fm_cs    ), // chip select
    .wr_n       ( wr_n      ), // write
    .a0         ( A[0]     ),
    .din        ( dout    ), // data in
    .dout       ( fm0_dout   ), // data out
    .ct1        (           ),
    .ct2        (           ),
    .irq_n      (      ),  // I do not synchronize this signal
    // Low resolution output (same as real chip)
    .sample     ( sample_0    ), // marks new output sample
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm0_left   ),
    .xright     ( fm0_right  )
);

//for sorcer & kingdom
jt51 u_jt51_1(
    .rst        ( RESET96       ), // reset
    .clk        ( CLK96       ), // main clock
    .cen        ( YM2151_CEN_1 & DIP_PAUSE    ), // 4mhz
    .cen_p1     ( YM2151_CEN2_1 & DIP_PAUSE   ), //2mhz, half clock
    .cs_n       ( !fm_cs    ), // chip select
    .wr_n       ( wr_n      ), // write
    .a0         ( A[0]     ),
    .din        ( dout    ), // data in
    .dout       ( fm1_dout   ), // data out
    .ct1        (           ),
    .ct2        (           ),
    .irq_n      ( ym_irq_n     ),  // I do not synchronize this signal
    // Low resolution output (same as real chip)
    .sample     ( sample_1    ), // marks new output sample
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm1_left   ),
    .xright     ( fm1_right  )
);

jt6295 #(.INTERPOL(2)) u_adpcm_1(
    .rst        ( RESET96       ),
    .clk        ( CLK96       ),
    .cen        ( OKI_CEN_1 & DIP_PAUSE ),
    .ss         ( 1'b1      ),
    // CPU interface
    .wrn        ( ~okim6295_device_0_wr_q ),  // active low
    .din        ( oki1_din      ),
    .dout       ( oki1_dout  ),
    // ROM interface
    .rom_addr   ( oki1_pcm_addr ),
    .rom_data   ( PCM_DOUT),
    .rom_ok     ( PCM_OK  ),
    // Sound output
    .sound      ( oki1_pre   ),
    .sample     ( oki1_sample)   // ~26kHz
);

endmodule
