// This file is a Codex-assisted refactoring and update
// based on the original work of Pramod Somashekar (pram0d)
// SPDX-License-Identifier: GPL-3.0-or-later

module raizing_shared_jt_audio #(
    parameter SS_ENABLE = 0
)(
    input                CLK96,
    input                RESET96,
    input                ACTIVE,

    input                FM_CEN,
    input                FM_CEN_P1,
    input                FM_REPLAY_CEN,
    input                FM_REPLAY_CEN_P1,
    input                FM_CS_N,
    input                FM_WR_N,
    input                FM_A0,
    input          [7:0] FM_DIN,
    output         [7:0] FM_DOUT,
    output               FM_IRQ_N,
    output               FM_SAMPLE,
    output signed [15:0] FM_XLEFT,
    output signed [15:0] FM_XRIGHT,

    input                OKI0_CEN,
    input                OKI0_SS,
    input                OKI0_WR_N,
    input          [7:0] OKI0_DIN,
    output         [7:0] OKI0_DOUT,
    output        [17:0] OKI0_ROM_ADDR,
    input          [7:0] OKI0_ROM_DATA,
    input                OKI0_ROM_OK,
    output signed [13:0] OKI0_SOUND,
    output               OKI0_SAMPLE,

    input                OKI1_CEN,
    input                OKI1_SS,
    input                OKI1_WR_N,
    input          [7:0] OKI1_DIN,
    output         [7:0] OKI1_DOUT,
    output        [17:0] OKI1_ROM_ADDR,
    input          [7:0] OKI1_ROM_DATA,
    input                OKI1_ROM_OK,
    output signed [13:0] OKI1_SOUND,
    output               OKI1_SAMPLE,

    input                SS_RESTORE_BEGIN,
    input         [63:0] SS_DATA,
    input         [31:0] SS_ADDR,
    input          [7:0] SS_SELECT,
    input                SS_WRITE,
    input                SS_READ,
    input                SS_QUERY,
    output        [63:0] SS_DATA_OUT,
    output               SS_ACK,
    output               SS_REPLAY_BUSY
);

wire chip_reset = RESET96 | !ACTIVE;

generate
    if(SS_ENABLE) begin : gen_savestate
        wire [2:0] response_ack;
        wire [191:0] response_data;
        wire [7:0] selected_index = ACTIVE ? SS_SELECT : 8'd0;

        wire oki0_ss_rd;
        wire oki0_ss_wr;
        wire [31:0] oki0_ss_data_in;
        wire [7:0] oki0_ss_device;
        wire [15:0] oki0_ss_state;
        wire [31:0] oki0_ss_data_out;
        wire oki0_ss_ack;

        wire oki1_ss_rd;
        wire oki1_ss_wr;
        wire [31:0] oki1_ss_data_in;
        wire [7:0] oki1_ss_device;
        wire [15:0] oki1_ss_state;
        wire [31:0] oki1_ss_data_out;
        wire oki1_ss_ack;

        raizing_ss_auto32 #(
            .SS_INDEX(18),
            .DEVICE_COUNT(11),
            .STATE_STRIDE(64)
        ) u_ss_oki0(
            .clk(CLK96), .reset(RESET96),
            .ss_data(SS_DATA), .ss_addr(SS_ADDR),
            .ss_select(selected_index), .ss_write(SS_WRITE),
            .ss_read(SS_READ), .ss_query(SS_QUERY),
            .ss_data_out(response_data[0*64 +: 64]),
            .ss_ack(response_ack[0]),
            .auto_ss_rd(oki0_ss_rd), .auto_ss_wr(oki0_ss_wr),
            .auto_ss_data_in(oki0_ss_data_in),
            .auto_ss_device_idx(oki0_ss_device),
            .auto_ss_state_idx(oki0_ss_state),
            .auto_ss_data_out(oki0_ss_data_out),
            .auto_ss_ack(oki0_ss_ack)
        );

        raizing_ss_auto32 #(
            .SS_INDEX(19),
            .DEVICE_COUNT(11),
            .STATE_STRIDE(64)
        ) u_ss_oki1(
            .clk(CLK96), .reset(RESET96),
            .ss_data(SS_DATA), .ss_addr(SS_ADDR),
            .ss_select(selected_index), .ss_write(SS_WRITE),
            .ss_read(SS_READ), .ss_query(SS_QUERY),
            .ss_data_out(response_data[1*64 +: 64]),
            .ss_ack(response_ack[1]),
            .auto_ss_rd(oki1_ss_rd), .auto_ss_wr(oki1_ss_wr),
            .auto_ss_data_in(oki1_ss_data_in),
            .auto_ss_device_idx(oki1_ss_device),
            .auto_ss_state_idx(oki1_ss_state),
            .auto_ss_data_out(oki1_ss_data_out),
            .auto_ss_ack(oki1_ss_ack)
        );

        ss_jt6295 #(.INTERPOL(2)) u_adpcm_0(
            .rst(chip_reset), .filter_rst(SS_RESTORE_BEGIN),
            .clk(CLK96), .cen(OKI0_CEN & ACTIVE), .ss(OKI0_SS),
            .wrn(OKI0_WR_N), .din(OKI0_DIN), .dout(OKI0_DOUT),
            .rom_addr(OKI0_ROM_ADDR), .rom_data(OKI0_ROM_DATA),
            .rom_ok(OKI0_ROM_OK), .sound(OKI0_SOUND), .sample(OKI0_SAMPLE),
            .auto_ss_rd(oki0_ss_rd), .auto_ss_wr(oki0_ss_wr),
            .auto_ss_data_in(oki0_ss_data_in),
            .auto_ss_device_idx(oki0_ss_device),
            .auto_ss_state_idx(oki0_ss_state),
            .auto_ss_base_device_idx(8'd0),
            .auto_ss_data_out(oki0_ss_data_out), .auto_ss_ack(oki0_ss_ack)
        );

        ss_jt6295 #(.INTERPOL(2)) u_adpcm_1(
            .rst(chip_reset), .filter_rst(SS_RESTORE_BEGIN),
            .clk(CLK96), .cen(OKI1_CEN & ACTIVE), .ss(OKI1_SS),
            .wrn(OKI1_WR_N), .din(OKI1_DIN), .dout(OKI1_DOUT),
            .rom_addr(OKI1_ROM_ADDR), .rom_data(OKI1_ROM_DATA),
            .rom_ok(OKI1_ROM_OK), .sound(OKI1_SOUND), .sample(OKI1_SAMPLE),
            .auto_ss_rd(oki1_ss_rd), .auto_ss_wr(oki1_ss_wr),
            .auto_ss_data_in(oki1_ss_data_in),
            .auto_ss_device_idx(oki1_ss_device),
            .auto_ss_state_idx(oki1_ss_state),
            .auto_ss_base_device_idx(8'd0),
            .auto_ss_data_out(oki1_ss_data_out), .auto_ss_ack(oki1_ss_ack)
        );

        raizing_ss_jt51_replay #(.SS_ENABLE(1)) u_jt51(
            .clk(CLK96), .reset(RESET96), .active(ACTIVE),
            .cen(FM_CEN), .cen_p1(FM_CEN_P1),
            .replay_cen(FM_REPLAY_CEN),
            .replay_cen_p1(FM_REPLAY_CEN_P1),
            .cs_n(FM_CS_N), .wr_n(FM_WR_N), .a0(FM_A0), .din(FM_DIN),
            .dout(FM_DOUT), .irq_n(FM_IRQ_N), .sample(FM_SAMPLE),
            .xleft(FM_XLEFT), .xright(FM_XRIGHT),
            .restore_begin(SS_RESTORE_BEGIN),
            .replay_busy(SS_REPLAY_BUSY),
            .ss_data(SS_DATA), .ss_addr(SS_ADDR),
            .ss_select(selected_index), .ss_write(SS_WRITE),
            .ss_read(SS_READ), .ss_query(SS_QUERY),
            .ss_data_out(response_data[2*64 +: 64]),
            .ss_ack(response_ack[2])
        );

        raizing_ss_response_mux #(.COUNT(3)) u_ss_response(
            .ack(response_ack), .data(response_data),
            .ack_out(SS_ACK), .data_out(SS_DATA_OUT)
        );
    end else begin : gen_no_savestate
        jt6295 #(.INTERPOL(2)) u_adpcm_0(
            .rst(chip_reset), .clk(CLK96), .cen(OKI0_CEN & ACTIVE),
            .ss(OKI0_SS), .wrn(OKI0_WR_N), .din(OKI0_DIN),
            .dout(OKI0_DOUT), .rom_addr(OKI0_ROM_ADDR),
            .rom_data(OKI0_ROM_DATA), .rom_ok(OKI0_ROM_OK),
            .sound(OKI0_SOUND), .sample(OKI0_SAMPLE)
        );

        jt6295 #(.INTERPOL(2)) u_adpcm_1(
            .rst(chip_reset), .clk(CLK96), .cen(OKI1_CEN & ACTIVE),
            .ss(OKI1_SS), .wrn(OKI1_WR_N), .din(OKI1_DIN),
            .dout(OKI1_DOUT), .rom_addr(OKI1_ROM_ADDR),
            .rom_data(OKI1_ROM_DATA), .rom_ok(OKI1_ROM_OK),
            .sound(OKI1_SOUND), .sample(OKI1_SAMPLE)
        );

        jt51 u_jt51(
            .rst(chip_reset), .clk(CLK96), .cen(FM_CEN & ACTIVE),
            .cen_p1(FM_CEN_P1 & ACTIVE), .cs_n(FM_CS_N),
            .wr_n(FM_WR_N), .a0(FM_A0), .din(FM_DIN), .dout(FM_DOUT),
            .ct1(), .ct2(), .irq_n(FM_IRQ_N), .sample(FM_SAMPLE),
            .left(), .right(), .xleft(FM_XLEFT), .xright(FM_XRIGHT)
        );

        assign SS_DATA_OUT = 64'd0;
        assign SS_ACK = 1'b0;
        assign SS_REPLAY_BUSY = 1'b0;
    end
endgenerate

endmodule
