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
module bakraid_sound #(
    parameter SS_ENABLE = 0
)(
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
    input          [1:0] SOUNDLATCH_ACK_INCOMING,

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
    output               SS_QUIESCED,
    output               SS_REPLAY_BUSY
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

wire ss_cpu_hold;
wire ss_cpu_quiesced;
wire ss_cpu_restore;
wire ss_cpu_restore_done;
wire ss_quiesced_sync;
wire [228:0] ss_cpu_state;
wire [228:0] ss_cpu_state_in;
wire [7:0] ss_wait_state;
wire [7:0] ss_wait_state_in;
wire ss_sound_frozen = SS_ENABLE && SS_ACTIVE && ss_cpu_quiesced;
wire [7:0] ss_select_active = SS_ENABLE && SS_ACTIVE ? SS_SELECT : 8'hff;
wire [1:0] ss_nmi_state, ss_wait_ff_state;
wire [191:0] ss_control_restore;
wire ss_control_restore_we;
reg [191:0] ss_control_capture;
wire ss_ram_active;
wire [13:0] ss_ram_addr;
wire [7:0] ss_ram_data;
wire ss_ram_we;
wire [7:0] ss_ram_q;
wire [3:0] ss_response_ack;
wire [255:0] ss_response_data;

//clock divider for sound irq
localparam [13:0] CEN444 = 14'd12000;
reg [13:0] c = 14'd0;
wire c_over = c == CEN444 - 1'b1;

always @(posedge CLK, posedge RESET) begin
    if(RESET) begin
        int_n <= 1;
        c <= 0;
    end else if(ss_control_restore_we) begin
        int_n <= ss_control_restore[0];
        c <= ss_control_restore[14:1];
    end else if(!ss_sound_frozen && Z80_CEN) begin
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
    if(ss_control_restore_we)
        peak <= ss_control_restore[15];
    else if(!ss_sound_frozen)
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
    end else if(ss_control_restore_we) begin
        ROMZ80_CS <= ss_control_restore[16];
        ram_cs <= ss_control_restore[17];
        ymz_addr_wr_d <= ss_control_restore[18];
        ymz_data_wr_d <= ss_control_restore[19];
        ymz_rd_d <= ss_control_restore[20];
        ymz_cpu_wr <= ss_control_restore[21];
        ymz_cpu_rd <= ss_control_restore[22];
        ymz_cpu_addr <= ss_control_restore[23];
        ymz_cpu_din <= ss_control_restore[31:24];
        soundlatch3_wr <= ss_control_restore[32];
        soundlatch4_wr <= ss_control_restore[33];
        batrider_sndirq_w <= ss_control_restore[34];
        batrider_clear_nmi_w <= ss_control_restore[35];
        soundlatch_rd <= ss_control_restore[36];
        soundlatch2_rd <= ss_control_restore[37];
    end else if(!ss_sound_frozen) begin
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
    end else if(ss_control_restore_we) begin
        din <= ss_control_restore[45:38];
        SOUNDLATCH3 <= ss_control_restore[53:46];
        SOUNDLATCH4 <= ss_control_restore[61:54];
        SOUNDLATCH_ACK <= ss_control_restore[63:62];
    end else if(!ss_sound_frozen) begin
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

raizing_ss_edge_ff u_nmi_ff(
    .clk      ( CLK         ),
    .reset    ( RESET         ),
    .hold     ( ss_sound_frozen ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( nmi_n       ),
    .set      ( 1'b0        ),    // active high
    .clr      ( batrider_clear_nmi_w ),    // active high
    .sigedge  ( NMI ), // signal whose edge will trigger the FF
    .restore_we(ss_cpu_restore),
    .restore_state(ss_control_restore[65:64]),
    .capture_state(ss_nmi_state)
);

raizing_ss_edge_ff u_m68wait_ff(
    .clk      ( CLK         ),
    .reset    ( RESET         ),
    .hold     ( ss_sound_frozen ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        ( WAIT            ),
    .qn       (        ),
    .set      ( 1'b0        ),    // active high
    .clr      ( |SOUNDLATCH_ACK ),    // release hold on 68k when all ack finished.
    .sigedge  ( CS     ), // signal whose edge will trigger the FF
    .restore_we(ss_cpu_restore),
    .restore_state(ss_control_restore[67:66]),
    .capture_state(ss_wait_ff_state)
);

raizing_t80_sysz80 #(
    .RAM_AW(14),
    .SS_ENABLE(SS_ENABLE)
) u_cpu(
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
    .CPU_CLOCK_ASYNC(1),
    .SS_INDEX(15)
) u_ss_cpu(
    .ss_clk(CLK96),
    .ss_reset(RESET96),
    .cpu_clk(CLK),
    .cpu_reset(RESET),
    .ss_freeze(SS_ENABLE && SS_ACTIVE && SS_FREEZE),
    .ss_restore_begin(SS_ENABLE && SS_ACTIVE && SS_RESTORE_BEGIN),
    .cpu_hold(ss_cpu_hold),
    .cpu_quiesced(ss_cpu_quiesced),
    .cpu_restore(ss_cpu_restore),
    .cpu_restore_done(ss_cpu_restore_done),
    .cpu_state(ss_cpu_state),
    .cpu_state_in(ss_cpu_state_in),
    .quiesced(ss_quiesced_sync),
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
    .ADDR_WIDTH(14),
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

raizing_ss_async_wide_register #(
    .WIDTH(192),
    .SS_INDEX(17)
) u_ss_control(
    .ss_clk(CLK96),
    .ss_reset(RESET96),
    .state_clk(CLK),
    .state_reset(RESET),
    .state_quiesced(ss_cpu_quiesced),
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

raizing_ss_response_mux #(.COUNT(4)) u_ss_response(
    .ack(ss_response_ack),
    .data(ss_response_data),
    .ack_out(SS_ACK),
    .data_out(SS_DATA_OUT)
);

assign ss_wait_state_in = ss_control_restore[75:68];
assign SS_QUIESCED = !SS_ENABLE || !SS_ACTIVE || ss_quiesced_sync;

//sdram bank switch rom 7/8 or 6
wire [23:0] ymz_mem_addr;
wire ymz_io_rd;
wire [15:0] io_audio_bits_left, io_audio_bits_right;
wire signed [15:0] ymz_audio_left = io_audio_bits_left;
wire signed [15:0] ymz_audio_right = io_audio_bits_right;
wire audio_valid;
reg [23:0] ymz_mem_addr_r;
reg        ymz_io_rd_r;

always @* begin
    ss_control_capture = 192'd0;
    ss_control_capture[0] = int_n;
    ss_control_capture[14:1] = c;
    ss_control_capture[15] = peak;
    ss_control_capture[16] = ROMZ80_CS;
    ss_control_capture[17] = ram_cs;
    ss_control_capture[18] = ymz_addr_wr_d;
    ss_control_capture[19] = ymz_data_wr_d;
    ss_control_capture[20] = ymz_rd_d;
    ss_control_capture[21] = ymz_cpu_wr;
    ss_control_capture[22] = ymz_cpu_rd;
    ss_control_capture[23] = ymz_cpu_addr;
    ss_control_capture[31:24] = ymz_cpu_din;
    ss_control_capture[32] = soundlatch3_wr;
    ss_control_capture[33] = soundlatch4_wr;
    ss_control_capture[34] = batrider_sndirq_w;
    ss_control_capture[35] = batrider_clear_nmi_w;
    ss_control_capture[36] = soundlatch_rd;
    ss_control_capture[37] = soundlatch2_rd;
    ss_control_capture[45:38] = din;
    ss_control_capture[53:46] = SOUNDLATCH3;
    ss_control_capture[61:54] = SOUNDLATCH4;
    ss_control_capture[63:62] = SOUNDLATCH_ACK;
    ss_control_capture[65:64] = ss_nmi_state;
    ss_control_capture[67:66] = ss_wait_ff_state;
    ss_control_capture[75:68] = ss_wait_state;
    ss_control_capture[99:76] = ymz_mem_addr_r;
    ss_control_capture[100] = ymz_io_rd_r;
    ss_control_capture[116:101] = fm_left;
    ss_control_capture[132:117] = fm_right;
    ss_control_capture[133] = sample;
end

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
    end else if(ss_control_restore_we) begin
        ymz_mem_addr_r <= ss_control_restore[99:76];
        ymz_io_rd_r <= ss_control_restore[100];
    end else if(!ss_sound_frozen) begin
        ymz_mem_addr_r <= ymz_mem_addr;
        ymz_io_rd_r <= ymz_io_rd;
    end
end

always @(posedge CLK) begin
    if(RESET) begin
        fm_left <= 16'd0;
        fm_right <= 16'd0;
        sample <= 1'b0;
    end else if(ss_control_restore_we) begin
        fm_left <= ss_control_restore[116:101];
        fm_right <= ss_control_restore[132:117];
        sample <= ss_control_restore[133];
    end else if(!ss_sound_frozen) begin
        if(audio_valid) begin
            fm_left <= ymz_audio_on ? ymz_audio_left : ymz_release(fm_left);
            fm_right <= ymz_audio_on ? ymz_audio_right : ymz_release(fm_right);
        end
        sample <= audio_valid;
    end
end

raizing_ss_ymz280b_replay #(.SS_ENABLE(SS_ENABLE)) u_ymz280b(
    .clock(CLK),
    .reset(RESET),
    .restore_begin(SS_ACTIVE && SS_RESTORE_BEGIN),
    .replay_busy(SS_REPLAY_BUSY),
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
    .keyon(ymz_keyon),
    .keyon_enable(ymz_keyon_enable),
    .ss_data(SS_DATA),
    .ss_addr(SS_ADDR),
    .ss_select(ss_select_active),
    .ss_write(SS_WRITE),
    .ss_read(SS_READ),
    .ss_query(SS_QUERY),
    .ss_data_out(ss_response_data[3*64 +: 64]),
    .ss_ack(ss_response_ack[3])
);

endmodule
