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
module batrider_sound #(
    parameter EXTERNAL_CHIPS = 0,
    parameter SS_ENABLE = 0
)(
    input                CLK,
    input                CLK96,
    input                YM2151_CEN,
    input                YM2151_CEN2,
    input                Z80_CEN,
    input                OKI_CEN,
    input                RESET,
    input                RESET96,
    output reg           ROMZ80_CS,
	input                ROMZ80_OK,
	output reg    [17:0] ROMZ80_ADDR,
	input          [7:0] ROMZ80_DOUT,
    output               PCM_CS,
    input                PCM_OK,
    output        [20:0] PCM_ADDR,
    input          [7:0] PCM_DOUT,
    output               PCM1_CS,
    input                PCM1_OK,
    output        [20:0] PCM1_ADDR,
    input          [7:0] PCM1_DOUT,
    output signed [15:0] left,
    output signed [15:0] right,
    output               sample,
    output reg           peak,

    //interface with m68k
    output               WAIT,
    output reg           SNDIRQ,
    input                CS,
    input                NMI,
    output reg     [7:0] SOUNDLATCH3,
    output reg     [7:0] SOUNDLATCH4,
    input          [7:0] SOUNDLATCH,
    input          [7:0] SOUNDLATCH2,
    input          [1:0] FX_LEVEL,
    input          [5:0] SND_EN,
	input		 DIP_PAUSE,

    output               FM_CEN_OUT,
    output               FM_CEN_P1_OUT,
    output               FM_CS_N_OUT,
    output               FM_WR_N_OUT,
    output               FM_A0_OUT,
    output         [7:0] FM_DIN_OUT,
    input          [7:0] FM_DOUT_IN,
    input                FM_IRQ_N_IN,
    input                FM_SAMPLE_IN,
    input signed  [15:0] FM_XLEFT_IN,
    input signed  [15:0] FM_XRIGHT_IN,

    output               OKI0_CEN_OUT,
    output               OKI0_SS_OUT,
    output               OKI0_WR_N_OUT,
    output         [7:0] OKI0_DIN_OUT,
    input          [7:0] OKI0_DOUT_IN,
    input         [17:0] OKI0_ROM_ADDR_IN,
    output         [7:0] OKI0_ROM_DATA_OUT,
    output               OKI0_ROM_OK_OUT,
    input signed  [13:0] OKI0_SOUND_IN,
    input                OKI0_SAMPLE_IN,

    output               OKI1_CEN_OUT,
    output               OKI1_SS_OUT,
    output               OKI1_WR_N_OUT,
    output         [7:0] OKI1_DIN_OUT,
    input          [7:0] OKI1_DOUT_IN,
    input         [17:0] OKI1_ROM_ADDR_IN,
    output         [7:0] OKI1_ROM_DATA_OUT,
    output               OKI1_ROM_OK_OUT,
    input signed  [13:0] OKI1_SOUND_IN,
    input                OKI1_SAMPLE_IN,

    input                SS_ACTIVE,
    input                SS_FREEZE,
    input                SS_RESTORE_BEGIN,
    input         [63:0] SS_DATA,
    input         [31:0] SS_ADDR,
    input          [7:0] SS_SELECT,
    input                SS_WRITE,
    input                SS_READ,
    input                SS_QUERY,
    output        [63:0] SS_DATA_OUT,
    output               SS_ACK,
    output               SS_QUIESCED
);

// assign ACK = 1'b1;
wire cpu_cen;
wire int_n;
wire m1_n, iorq_n, mreq_n;
wire rd_n;
wire wr_n;
wire [15:0] A;
reg [7:0] din, oki0_din, oki1_din;
wire io_cs = !iorq_n;
wire oki0_wr_dec = io_cs && !wr_n && A[7:0] == 8'h82;
wire oki1_wr_dec = io_cs && !wr_n && A[7:0] == 8'h84;
wire z80_bank_wr_dec = io_cs && !wr_n && A[7:0] == 8'h88;
wire oki_bank_wr_dec = io_cs && !wr_n && A[7:0] >= 8'hC0 && A[7:0] <= 8'hC6;
wire oki0_bank_wr = oki_bank_wr_dec && !A[2];
wire oki1_bank_wr = oki_bank_wr_dec &&  A[2];
wire [2:0] oki_bank_offset = A[2:0] & 3'b110;
reg [3:0] bank = 2; // init bank to 2
reg ram_cs, fm_cs;
wire [7:0] ram_dout, dout, fm_dout, oki0_dout, oki1_dout;
wire signed [15:0] fm_left, fm_right;
wire signed [16:0] fm_mix_sum = {fm_left[15], fm_left} + {fm_right[15], fm_right};
wire signed [15:0] fm_mono = fm_mix_sum[16:1];
wire peak_l, peak_r, peak_oki;

wire signed [13:0] oki0_pre, oki1_pre;
wire signed [15:0] oki_mono, oki_filtered;
wire oki0_sample, oki1_sample;
wire [17:0] oki0_pcm_addr, oki1_pcm_addr;
reg oki0_bank_wr_q, oki1_bank_wr_q;
reg [2:0] oki_bank_offset_q;
reg [7:0] oki_bank_din;
reg oki0_wr_l, oki1_wr_l;
reg oki0_bank_wr_l, oki1_bank_wr_l;
wire z80_cen_eff = Z80_CEN;
// Direct Z80-to-JT51 write path.
wire fm_chip_select = fm_cs;
wire fm_write_n = wr_n;
wire fm_a0 = A[0];
wire [7:0] fm_din = dout;
wire oki0_wr_pulse = !oki0_wr_dec && oki0_wr_l;
wire oki1_wr_pulse = !oki1_wr_dec && oki1_wr_l;
wire oki0_bank_wr_pulse = !oki0_bank_wr && oki0_bank_wr_l;
wire oki1_bank_wr_pulse = !oki1_bank_wr && oki1_bank_wr_l;
wire nmi_n;
wire ss_cpu_hold;
wire ss_cpu_quiesced;
wire ss_cpu_restore;
wire ss_cpu_restore_done;
wire [228:0] ss_cpu_state;
wire [228:0] ss_cpu_state_in;
wire [7:0] ss_wait_state;
wire [7:0] ss_wait_state_in;
wire ss_sound_frozen = SS_ENABLE && SS_ACTIVE && ss_cpu_quiesced;
wire [7:0] ss_select_active = SS_ENABLE && SS_ACTIVE ? SS_SELECT : 8'hff;
wire [1:0] ss_nmi_state, ss_wait_ff_state;
wire [31:0] ss_nmk0_state, ss_nmk1_state;
wire [191:0] ss_control_restore;
wire ss_control_restore_we;
reg [191:0] ss_control_capture;
wire ss_ram_active;
wire [12:0] ss_ram_addr;
wire [7:0] ss_ram_data;
wire ss_ram_we;
wire [7:0] ss_ram_q;
wire [2:0] ss_response_ack;
wire [191:0] ss_response_data;
reg soundlatch3_wr,
    soundlatch4_wr,
    batrider_sndirq_w,
    batrider_clear_nmi_w,
    soundlatch_rd,
    soundlatch2_rd,
    ymsnd_rd,
    okim6295_device_0_rd,
    okim6295_device_0_wr_q,
    okim6295_device_1_rd,
    okim6295_device_1_wr_q;

always @* begin
    ss_control_capture = 192'd0;
    ss_control_capture[3:0] = bank;
    ss_control_capture[4] = ram_cs;
    ss_control_capture[5] = fm_cs;
    ss_control_capture[6] = ROMZ80_CS;
    ss_control_capture[24:7] = ROMZ80_ADDR;
    ss_control_capture[25] = SNDIRQ;
    ss_control_capture[26] = soundlatch3_wr;
    ss_control_capture[27] = soundlatch4_wr;
    ss_control_capture[28] = batrider_sndirq_w;
    ss_control_capture[29] = batrider_clear_nmi_w;
    ss_control_capture[30] = soundlatch_rd;
    ss_control_capture[31] = soundlatch2_rd;
    ss_control_capture[32] = ymsnd_rd;
    ss_control_capture[33] = okim6295_device_0_rd;
    ss_control_capture[34] = okim6295_device_1_rd;
    ss_control_capture[42:35] = din;
    ss_control_capture[50:43] = SOUNDLATCH3;
    ss_control_capture[58:51] = SOUNDLATCH4;
    ss_control_capture[66:59] = oki0_din;
    ss_control_capture[74:67] = oki1_din;
    ss_control_capture[75] = okim6295_device_0_wr_q;
    ss_control_capture[76] = okim6295_device_1_wr_q;
    ss_control_capture[77] = oki0_bank_wr_q;
    ss_control_capture[78] = oki1_bank_wr_q;
    ss_control_capture[81:79] = oki_bank_offset_q;
    ss_control_capture[89:82] = oki_bank_din;
    ss_control_capture[90] = oki0_wr_l;
    ss_control_capture[91] = oki1_wr_l;
    ss_control_capture[92] = oki0_bank_wr_l;
    ss_control_capture[93] = oki1_bank_wr_l;
    ss_control_capture[125:94] = ss_nmk0_state;
    ss_control_capture[157:126] = ss_nmk1_state;
    ss_control_capture[159:158] = ss_nmi_state;
    ss_control_capture[161:160] = ss_wait_ff_state;
    ss_control_capture[169:162] = ss_wait_state;
end

assign FM_CEN_OUT = YM2151_CEN & DIP_PAUSE & ~ss_sound_frozen;
assign FM_CEN_P1_OUT = YM2151_CEN2 & DIP_PAUSE & ~ss_sound_frozen;
assign FM_CS_N_OUT = !fm_chip_select;
assign FM_WR_N_OUT = fm_write_n;
assign FM_A0_OUT = fm_a0;
assign FM_DIN_OUT = fm_din;

assign OKI0_CEN_OUT = OKI_CEN & DIP_PAUSE & ~ss_sound_frozen;
assign OKI0_SS_OUT = 1'b1;
assign OKI0_WR_N_OUT = ~okim6295_device_0_wr_q;
assign OKI0_DIN_OUT = oki0_din;
assign OKI0_ROM_DATA_OUT = PCM_DOUT;
assign OKI0_ROM_OK_OUT = PCM_OK;

assign OKI1_CEN_OUT = OKI_CEN & DIP_PAUSE & ~ss_sound_frozen;
assign OKI1_SS_OUT = 1'b0;
assign OKI1_WR_N_OUT = ~okim6295_device_1_wr_q;
assign OKI1_DIN_OUT = oki1_din;
assign OKI1_ROM_DATA_OUT = PCM1_DOUT;
assign OKI1_ROM_OK_OUT = PCM1_OK;

//debugging
`ifdef SIMULATION
wire debug = 1'b1;
integer fd;
initial fd = $fopen("logsound.txt", "w");
`endif

/*
FX_LEVEL is status[7:6] after jtframe_dip's 2'b10 XOR.
OSD order: High, Very High, Very Low, Low.
*/

wire [7:0] fx_mult = FX_LEVEL == 2 ? 8'h10 :
                     FX_LEVEL == 3 ? 8'h20 :
                     FX_LEVEL == 0 ? 8'h08 :
                     FX_LEVEL == 1 ? 8'h0c :
                     8'h10;

localparam [7:0] FM_MIX_GAIN = 8'h07;
always @(posedge CLK96) begin
    if(!ss_sound_frozen)
        peak <= peak_l | peak_r | peak_oki;
end

reg [7:0] gain1;
reg signed [15:0] final_left;
reg signed [13:0] final_oki0, final_oki1;
reg signed [15:0] final_oki;
wire [7:0] fm_gain   = SND_EN[0] ? FM_MIX_GAIN : 8'd0;
wire [7:0] oki0_gain = SND_EN[1] ? gain1  : 8'd0;
wire [7:0] oki1_gain = SND_EN[2] ? gain1  : 8'd0;
wire [7:0] oki_gain  = (SND_EN[1] | SND_EN[2]) ? 8'h12 : 8'd0;

always @(posedge CLK96) begin
    if(!ss_sound_frozen) begin
        // Fold YM2151 stereo into the board's mono path.
        final_left<=fm_mono;
        final_oki0<=oki0_pre;
        final_oki1<=oki1_pre;
        final_oki<=oki_filtered;
        gain1<=fx_mult;
    end
end

// Sum both M6295 channels before filtering.
jtframe_mixer #(.W0(14), .W1(14), .WOUT(16)) u_mix_oki(
    .rst    ( RESET96       ),
    .clk    ( CLK96       ),
    .cen    ( 1'b1      ),
    // input signals
    .ch0    ( final_oki0 ),
    .ch1    ( final_oki1 ),
    .ch2    ( 16'd0     ),
    .ch3    ( 16'd0     ),
    // gain for each channel in 4.4 fixed point format
    .gain0  ( oki0_gain ),
    .gain1  ( oki1_gain ),
    .gain2  ( 8'd0      ),
    .gain3  ( 8'd0      ),
    .mixed  ( oki_mono  ),
    .peak   ( peak_oki  )
);

// Two RA9704 Sallen-Key sections, bilinear transformed at 192 kHz.
// Digital gains remain calibrated to JT51/JT6295 full scale.
wire [1:0] ra9704_filter_cen;
jtframe_frac_cen #(.W(2), .WC(15)) u_ra9704_filter_cen(
    .clk  ( CLK96              ),
    .n    ( 15'd64             ),
    .m    ( 15'd31500          ),
    .cen  ( ra9704_filter_cen  ),
    .cenb (                     )
);

ra9704_audio_filter u_ra9704_audio_filter(
    .rst        ( RESET96 | (SS_ENABLE && SS_ACTIVE && SS_RESTORE_BEGIN) ),
    .clk        ( CLK96                 ),
    .sample     ( ra9704_filter_cen[0] & ~ss_sound_frozen ),
    .din        ( oki_mono              ),
    .dout       ( oki_filtered          )
);

assign right = left;
assign peak_r = peak_l;

jtframe_mixer #(.W0(16), .W1(16), .WOUT(16)) u_mix_left(
    .rst    ( RESET96       ),
    .clk    ( CLK96       ),
    .cen    ( 1'b1      ),
    // input signals
    .ch0    ( final_left   ),
    .ch1    ( final_oki  ),
    .ch2    ( 16'd0     ),
    .ch3    ( 16'd0     ),
    // gain for each channel in 4.4 fixed point format
    .gain0  ( fm_gain   ),
    .gain1  ( oki_gain  ),
    .gain2  ( 8'd0      ),
    .gain3  ( 8'd0     ),
    .mixed  ( left      ),
    .peak   ( peak_l    )
);

//address bus
always @(posedge CLK96) begin
    if(RESET96) begin
        soundlatch3_wr <= 0;
        soundlatch4_wr <= 0;
        batrider_sndirq_w <= 0;
        batrider_clear_nmi_w <= 0;
        soundlatch_rd <= 0;
        soundlatch2_rd <= 0;
        ymsnd_rd <= 0;
        okim6295_device_0_rd <= 0;
        okim6295_device_1_rd <= 0;
        bank <= 4'd2;
        ram_cs <= 0; // > 0xC000 to 0xdfff
        fm_cs <= 0;
        ROMZ80_CS <= 0;
        ROMZ80_ADDR<=0;
        SNDIRQ<=0;
    end else if(ss_control_restore_we) begin
        bank <= ss_control_restore[3:0];
        ram_cs <= ss_control_restore[4];
        fm_cs <= ss_control_restore[5];
        ROMZ80_CS <= ss_control_restore[6];
        ROMZ80_ADDR <= ss_control_restore[24:7];
        SNDIRQ <= ss_control_restore[25];
        soundlatch3_wr <= ss_control_restore[26];
        soundlatch4_wr <= ss_control_restore[27];
        batrider_sndirq_w <= ss_control_restore[28];
        batrider_clear_nmi_w <= ss_control_restore[29];
        soundlatch_rd <= ss_control_restore[30];
        soundlatch2_rd <= ss_control_restore[31];
        ymsnd_rd <= ss_control_restore[32];
        okim6295_device_0_rd <= ss_control_restore[33];
        okim6295_device_1_rd <= ss_control_restore[34];
    end else if(!ss_sound_frozen) begin
            // if(debug) $display("address:%h, op:%b", A, {rd_n, wr_n, iorq_n, mreq_n, m1_n});
        soundlatch3_wr <= io_cs && !wr_n && A[7:0] == 8'h40;
        soundlatch4_wr <= io_cs && !wr_n && A[7:0] == 8'h42;
        batrider_sndirq_w <= io_cs && !wr_n && A[7:0] == 8'h44;
        batrider_clear_nmi_w <= io_cs && !wr_n && A[7:0] == 8'h46;
        soundlatch_rd <= io_cs && !rd_n && A[7:0] == 8'h48;
        soundlatch2_rd <= io_cs && !rd_n && A[7:0] == 8'h4a;
        ymsnd_rd <= io_cs && !rd_n && A[7:0] == 8'h81;
        okim6295_device_0_rd <= io_cs && !rd_n && A[7:0] == 8'h82;
        okim6295_device_1_rd <= io_cs && !rd_n && A[7:0] == 8'h84;
        ram_cs <= !mreq_n && A[15:13] == 4'b110; // > 0xC000 to 0xdfff
        fm_cs <= io_cs && (A[7:0] == 8'h80 || A[7:0] == 8'h81);
        ROMZ80_CS <= !mreq_n && !rd_n && (!A[15] || A[15:14]==2'b10);
        ROMZ80_ADDR <= A[15:14] == 2'b10 ? {bank, A[13:0]} : {2'b00, A};
        if(z80_bank_wr_dec) begin
            bank <= dout[3:0];
        end
        SNDIRQ<=io_cs && A[7:0] == 8'h44;
    end
end

//io switch
always @(posedge CLK96) begin
    if(RESET96) begin
        SOUNDLATCH3 <= 8'h0;
        SOUNDLATCH4 <= 8'h0;
        oki0_din <= 8'h0;
        oki1_din <= 8'h0;
        okim6295_device_0_wr_q <= 1'b0;
        okim6295_device_1_wr_q <= 1'b0;
        oki0_bank_wr_q <= 1'b0;
        oki1_bank_wr_q <= 1'b0;
        oki_bank_offset_q <= 3'd0;
        oki_bank_din <= 8'h0;
        oki0_wr_l <= 1'b0;
        oki1_wr_l <= 1'b0;
        oki0_bank_wr_l <= 1'b0;
        oki1_bank_wr_l <= 1'b0;
    end else if(ss_control_restore_we) begin
        din <= ss_control_restore[42:35];
        SOUNDLATCH3 <= ss_control_restore[50:43];
        SOUNDLATCH4 <= ss_control_restore[58:51];
        oki0_din <= ss_control_restore[66:59];
        oki1_din <= ss_control_restore[74:67];
        okim6295_device_0_wr_q <= ss_control_restore[75];
        okim6295_device_1_wr_q <= ss_control_restore[76];
        oki0_bank_wr_q <= ss_control_restore[77];
        oki1_bank_wr_q <= ss_control_restore[78];
        oki_bank_offset_q <= ss_control_restore[81:79];
        oki_bank_din <= ss_control_restore[89:82];
        oki0_wr_l <= ss_control_restore[90];
        oki1_wr_l <= ss_control_restore[91];
        oki0_bank_wr_l <= ss_control_restore[92];
        oki1_bank_wr_l <= ss_control_restore[93];
    end else if(!ss_sound_frozen) begin
        oki0_wr_l <= oki0_wr_dec;
        oki1_wr_l <= oki1_wr_dec;
        oki0_bank_wr_l <= oki0_bank_wr;
        oki1_bank_wr_l <= oki1_bank_wr;
        okim6295_device_0_wr_q <= oki0_wr_pulse;
        okim6295_device_1_wr_q <= oki1_wr_pulse;
        oki0_bank_wr_q <= oki0_bank_wr_pulse;
        oki1_bank_wr_q <= oki1_bank_wr_pulse;

        if(oki_bank_wr_dec) begin
            oki_bank_offset_q <= oki_bank_offset;
            oki_bank_din <= dout;
        end

        //to z80
        case(1'b1)
            ROMZ80_CS: din <= ROMZ80_DOUT;
            ram_cs: din <= ram_dout;
            soundlatch_rd: din <= SOUNDLATCH;
            soundlatch2_rd: din <= SOUNDLATCH2;
            ymsnd_rd: din <= fm_dout;
            okim6295_device_0_rd: din <= oki0_dout;
            okim6295_device_1_rd: din <= oki1_dout;
            default: din <= 8'hFF;
        endcase

`ifdef SIMULATION
        if(debug) begin
            if(soundlatch_rd) $display("soundlatch_rd:%h", SOUNDLATCH);
            if(soundlatch2_rd) $display("soundlatch2_rd:%h", SOUNDLATCH2);
            // if(ymsnd_rd) $display("ymsnd_rd:%h", fm_dout);
            if(soundlatch3_wr) $display("soundlatch3_wr:%h", dout);
            if(soundlatch4_wr) $display("soundlatch4_wr:%h", dout);
            if(batrider_sndirq_w) $display("sndirq_w:%h", dout);
            if(batrider_clear_nmi_w) $display("clear_nmi:%h", dout);
        end
`endif

        if(soundlatch3_wr) begin
            SOUNDLATCH3 <= dout;
        end

        else if(soundlatch4_wr) begin
            SOUNDLATCH4 <= dout;
        end

        else if(oki0_wr_dec) begin
            oki0_din <= dout;
        end

        else if(oki1_wr_dec) begin
            oki1_din <= dout;
        end
    end
end

NMK112 u_nmk112_0(
    .CLK(CLK96),
    .RESET(RESET96),
    .WE(oki0_bank_wr_q),
    .OFFSET(oki_bank_offset_q),
    .DATA(oki_bank_din),
    .REQ_ADDR(oki0_pcm_addr & 'h3FFFF),
    .REQ_DATA_ADDR(PCM_ADDR),
    .SS_HOLD(ss_sound_frozen),
    .SS_RESTORE(ss_cpu_restore),
    .SS_STATE_IN(ss_control_restore[125:94]),
    .SS_STATE(ss_nmk0_state)
);

NMK112 #(.ROM_OFFS('h100000)) u_nmk112_1(
    .CLK(CLK96),
    .RESET(RESET96),
    .WE(oki1_bank_wr_q),
    .OFFSET(oki_bank_offset_q),
    .DATA(oki_bank_din),
    .REQ_ADDR(oki1_pcm_addr & 'h3FFFF),
    .REQ_DATA_ADDR(PCM1_ADDR),
    .SS_HOLD(ss_sound_frozen),
    .SS_RESTORE(ss_cpu_restore),
    .SS_STATE_IN(ss_control_restore[157:126]),
    .SS_STATE(ss_nmk1_state)
);

raizing_ss_edge_ff u_nmi_ff(
    .clk      ( CLK96         ),
    .reset    ( RESET96         ),
    .hold     ( ss_sound_frozen ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( nmi_n       ),
    .set      ( 1'b0        ),    // active high
    .clr      ( batrider_clear_nmi_w ),    // active high
    .sigedge  ( CS ), // signal whose edge will trigger the FF
    .restore_we(ss_cpu_restore),
    .restore_state(ss_control_restore[159:158]),
    .capture_state(ss_nmi_state)
);

raizing_ss_edge_ff u_m68wait_ff(
    .clk      ( CLK96         ),
    .reset    ( RESET96         ),
    .hold     ( ss_sound_frozen ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        ( WAIT            ),
    .qn       (        ),
    .set      ( 1'b0        ),    // active high
    .clr      ( batrider_clear_nmi_w),    // active high
    .sigedge  ( CS     ), // signal whose edge will trigger the FF
    .restore_we(ss_cpu_restore),
    .restore_state(ss_control_restore[161:160]),
    .capture_state(ss_wait_ff_state)
);

raizing_t80_sysz80 #(
    .RAM_AW(13),
    .RECOVERY(0),
    .SS_ENABLE(SS_ENABLE)
) u_cpu(
    .rst_n      ( ~RESET96      ),
    .clk        ( CLK96         ),
    .cen        ( z80_cen_eff ), // 5.333 MHz
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
    .rom_ok     ( ROMZ80_OK   ),
    .ss_ram_clk ( CLK96       ),
    .ss_hold    ( ss_cpu_hold ),
    .ss_quiesced(ss_cpu_quiesced),
    .ss_restore ( ss_cpu_restore),
    .ss_restore_done(ss_cpu_restore_done),
    .ss_state   ( ss_cpu_state),
    .ss_state_in(ss_cpu_state_in),
    .ss_wait_state(ss_wait_state),
    .ss_wait_state_in(ss_wait_state_in),
    .ss_ram_active(ss_ram_active),
    .ss_ram_addr(ss_ram_addr),
    .ss_ram_data(ss_ram_data),
    .ss_ram_we  (ss_ram_we),
    .ss_ram_q   (ss_ram_q)
);

raizing_ss_sound_cpu #(
    .CPU_CLOCK_ASYNC(0),
    .SS_INDEX(15)
) u_ss_cpu(
    .ss_clk(CLK96),
    .ss_reset(RESET96),
    .cpu_clk(CLK96),
    .cpu_reset(RESET96),
    .ss_freeze(SS_ENABLE && SS_ACTIVE && SS_FREEZE),
    .ss_restore_begin(SS_ENABLE && SS_ACTIVE && SS_RESTORE_BEGIN),
    .cpu_hold(ss_cpu_hold),
    .cpu_quiesced(ss_cpu_quiesced),
    .cpu_restore(ss_cpu_restore),
    .cpu_restore_done(ss_cpu_restore_done),
    .cpu_state(ss_cpu_state),
    .cpu_state_in(ss_cpu_state_in),
    .quiesced(),
    .restore_done(),
    .ss_data(SS_DATA),
    .ss_addr(SS_ADDR),
    .ss_select(ss_select_active),
    .ss_write(SS_WRITE),
    .ss_read(SS_READ),
    .ss_query(SS_QUERY),
    .ss_data_out(ss_response_data[0*64 +: 64]),
    .ss_ack(ss_response_ack[0])
);

raizing_ss_ram_adapter #(
    .WIDTH(8),
    .ADDR_WIDTH(13),
    .SS_INDEX(16)
) u_ss_ram(
    .clk(CLK96),
    .reset(RESET96),
    .ss_data(SS_DATA),
    .ss_addr(SS_ADDR),
    .ss_select(ss_select_active),
    .ss_write(SS_WRITE),
    .ss_read(SS_READ),
    .ss_query(SS_QUERY),
    .ss_data_out(ss_response_data[1*64 +: 64]),
    .ss_ack(ss_response_ack[1]),
    .ram_active(ss_ram_active),
    .ram_addr(ss_ram_addr),
    .ram_data(ss_ram_data),
    .ram_we(ss_ram_we),
    .ram_q(ss_ram_q)
);

raizing_ss_wide_register #(
    .WIDTH(192),
    .SS_INDEX(17)
) u_ss_control(
    .clk(CLK96),
    .reset(RESET96),
    .capture_data(ss_control_capture),
    .restore_data(ss_control_restore),
    .restore_we(ss_control_restore_we),
    .ss_data(SS_DATA),
    .ss_addr(SS_ADDR),
    .ss_select(ss_select_active),
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

assign ss_wait_state_in = ss_control_restore[169:162];
assign SS_QUIESCED = !SS_ENABLE || !SS_ACTIVE || ss_cpu_quiesced;

assign PCM_CS = 1'b1;
assign PCM1_CS = 1'b1;

generate
if(!EXTERNAL_CHIPS) begin : gen_internal_chips
jt6295 #(.INTERPOL(2)) u_adpcm_0(
    .rst        ( RESET96       ),
    .clk        ( CLK96       ),
    .cen        ( OKI_CEN & DIP_PAUSE   ),
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

jt6295 #(.INTERPOL(2)) u_adpcm_1(
    .rst        ( RESET96       ),
    .clk        ( CLK96       ),
    .cen        ( OKI_CEN & DIP_PAUSE   ),
    .ss         ( 1'b0      ),
    // CPU interface
    .wrn        ( ~okim6295_device_1_wr_q ),  // active low
    .din        ( oki1_din      ),
    .dout       ( oki1_dout  ),
    // ROM interface
    .rom_addr   ( oki1_pcm_addr ),
    .rom_data   ( PCM1_DOUT ),
    .rom_ok     ( PCM1_OK   ),
    // Sound output
    .sound      ( oki1_pre   ),
    .sample     ( oki1_sample)   // ~26kHz
);

jt51 u_jt51(
    .rst        ( RESET96       ), // reset
    .clk        ( CLK96       ), // main clock
    .cen        ( YM2151_CEN & DIP_PAUSE    ),
    .cen_p1     ( YM2151_CEN2 & DIP_PAUSE   ),
    .cs_n       ( !fm_chip_select ), // chip select
    .wr_n       ( fm_write_n      ), // write
    .a0         ( fm_a0           ),
    .din        ( fm_din          ), // data in
    .dout       ( fm_dout   ), // data out
    .ct1        (           ),
    .ct2        (           ),
    .irq_n      ( int_n     ),  // I do not synchronize this signal
    // Low resolution output (same as real chip)
    .sample     ( sample    ), // marks new output sample
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_left   ),
    .xright     ( fm_right  )
);
end else begin : gen_external_chips
    assign fm_dout = FM_DOUT_IN;
    assign int_n = FM_IRQ_N_IN;
    assign sample = FM_SAMPLE_IN;
    assign fm_left = FM_XLEFT_IN;
    assign fm_right = FM_XRIGHT_IN;
    assign oki0_dout = OKI0_DOUT_IN;
    assign oki0_pcm_addr = OKI0_ROM_ADDR_IN;
    assign oki0_pre = OKI0_SOUND_IN;
    assign oki0_sample = OKI0_SAMPLE_IN;
    assign oki1_dout = OKI1_DOUT_IN;
    assign oki1_pcm_addr = OKI1_ROM_ADDR_IN;
    assign oki1_pre = OKI1_SOUND_IN;
    assign oki1_sample = OKI1_SAMPLE_IN;
end
endgenerate

endmodule
