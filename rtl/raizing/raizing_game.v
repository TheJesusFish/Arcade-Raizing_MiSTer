// This file is a Codex-assisted refactoring and update
// based on the original work of Pramod Somashekar (pram0d)

/*
* Combined Raizing game dispatcher.
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*/
module raizing_game(
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
    input  [7:0]         debug_bus,
    output [7:0]         debug_view,

    // extra clocks
    input                clk24,
    input                rst24,

    input                ss_do_save,
    input                ss_do_restore,
    input                ss_stream_busy,
    input                ss_format_valid,
    output               ss_stream_save,
    output               ss_stream_load,
    output               ss_active,
    output               ss_load_rejected,
    output        [7:0]  ss_game_id,
    input         [63:0] ss_data,
    input         [31:0] ss_addr,
    input          [7:0] ss_select,
    input                ss_write,
    input                ss_read,
    input                ss_query,
    output        [63:0] ss_data_out,
    output               ss_ack
);

localparam [7:0] RAIZING_GAREGGA  = 8'h00;
localparam [7:0] RAIZING_SSTRIKER = 8'h01;
localparam [7:0] RAIZING_KINGDMGP = 8'h02;
localparam [7:0] RAIZING_BATRIDER = 8'h03;
localparam [7:0] RAIZING_BAKRAID  = 8'h04;

assign debug_view = 8'd0;

reg [7:0] game_id = RAIZING_BATRIDER;

wire        core_ioctl_rom;
wire        core_ioctl_cart;
wire        core_ioctl_wr;
wire [25:0] core_ioctl_addr;
wire  [7:0] core_ioctl_dout;
wire        core_ioctl_ram;
wire [31:0] core_dipsw;
wire        core_dip_pause;
wire        core_dip_flip;
wire        core_dip_test;

assign core_ioctl_rom  = ioctl_rom;
assign core_ioctl_cart = ioctl_cart;
assign core_ioctl_wr   = ioctl_wr;
assign core_ioctl_addr = ioctl_addr;
assign core_ioctl_dout = ioctl_dout;
assign core_ioctl_ram  = ioctl_ram;
assign core_dipsw      = dipsw;
assign core_dip_pause  = dip_pause;
assign core_dip_flip   = dip_flip;
assign core_dip_test   = dip_test;
wire [3:0] core_cab_1p = cab_1p;
wire [3:0] core_coin = coin;
wire [9:0] core_joystick1 = joystick1;
wire [9:0] core_joystick2 = joystick2;
wire [9:0] core_joystick3 = joystick3;
wire [9:0] core_joystick4 = joystick4;
wire       core_service = service;
wire core_rst   = rst;
wire core_rst48 = rst48;
wire core_rst96 = rst96;
wire core_rst24 = rst24;

wire selector_cycle = core_ioctl_wr && !core_ioctl_ram && core_ioctl_addr == 26'd0;
wire [7:0] target_game_id = selector_cycle ? core_ioctl_dout : game_id;

always @(posedge clk96) begin
    if(selector_cycle)
        game_id <= core_ioctl_dout;
end

wire ss_pause_request;
wire ss_freeze;
wire ss_paused;
wire ss_game_quiesced;
wire ss_cpu_idle;
wire ss_save_begin;
wire ss_save_resume;
wire ss_restore_begin;
wire ss_restore_window;
wire ss_save_ready;
wire ss_save_done;
wire ss_restore_done;
wire ss_do_save_96;
wire ss_do_restore_96;
wire ss_stream_busy_96;
wire ss_format_valid_96;
wire ss_stream_save_96;
wire ss_stream_load_96;
wire ss_active_96;
wire ss_load_rejected_96;
wire ss_sdram_idle = !(|ba_rd) && !ba_wr &&
                     !(|ba_ack) && !(|ba_dst) &&
                     !(|ba_dok) && !(|ba_rdy);

assign ss_game_id = game_id;

raizing_ss_pulse_cdc u_ss_save_request_cdc(
    .src_clk(clk),
    .src_reset(core_rst),
    .src_pulse(ss_do_save),
    .dst_clk(clk96),
    .dst_reset(core_rst96),
    .dst_pulse(ss_do_save_96)
);

raizing_ss_pulse_cdc u_ss_load_request_cdc(
    .src_clk(clk),
    .src_reset(core_rst),
    .src_pulse(ss_do_restore),
    .dst_clk(clk96),
    .dst_reset(core_rst96),
    .dst_pulse(ss_do_restore_96)
);

raizing_ss_level_cdc u_ss_stream_busy_cdc(
    .dst_clk(clk96),
    .dst_reset(core_rst96),
    .src_level(ss_stream_busy),
    .dst_level(ss_stream_busy_96)
);

raizing_ss_level_cdc u_ss_format_valid_cdc(
    .dst_clk(clk96),
    .dst_reset(core_rst96),
    .src_level(ss_format_valid),
    .dst_level(ss_format_valid_96)
);

raizing_ss_pulse_cdc u_ss_stream_save_cdc(
    .src_clk(clk96),
    .src_reset(core_rst96),
    .src_pulse(ss_stream_save_96),
    .dst_clk(clk),
    .dst_reset(core_rst),
    .dst_pulse(ss_stream_save)
);

raizing_ss_pulse_cdc u_ss_stream_load_cdc(
    .src_clk(clk96),
    .src_reset(core_rst96),
    .src_pulse(ss_stream_load_96),
    .dst_clk(clk),
    .dst_reset(core_rst),
    .dst_pulse(ss_stream_load)
);

raizing_ss_level_cdc u_ss_active_cdc(
    .dst_clk(clk),
    .dst_reset(core_rst),
    .src_level(ss_active_96),
    .dst_level(ss_active)
);

raizing_ss_pulse_cdc u_ss_rejected_cdc(
    .src_clk(clk96),
    .src_reset(core_rst96),
    .src_pulse(ss_load_rejected_96),
    .dst_clk(clk),
    .dst_reset(core_rst),
    .dst_pulse(ss_load_rejected)
);

raizing_ss_pause #(.DRAIN_CYCLES(8)) u_ss_pause(
    .clk(clk96),
    .reset(core_rst96),
    .request(ss_pause_request),
    .vblank(!LVBL),
    .memory_idle(ss_sdram_idle),
    .cpu_idle(ss_cpu_idle),
    .freeze(ss_freeze),
    .paused(ss_paused)
);

raizing_ss_controller u_ss_controller(
    .clk(clk96),
    .reset(core_rst96),
    .save_request(ss_do_save_96),
    .load_request(ss_do_restore_96),
    .pause_request(ss_pause_request),
    .paused(ss_paused),
    .game_quiesced(ss_game_quiesced),
    .game_save_begin(ss_save_begin),
    .game_save_resume(ss_save_resume),
    .game_restore_begin(ss_restore_begin),
    .restore_window(ss_restore_window),
    .game_save_ready(ss_save_ready),
    .game_save_done(ss_save_done),
    .game_restore_done(ss_restore_done),
    .stream_save_start(ss_stream_save_96),
    .stream_load_start(ss_stream_load_96),
    .stream_busy(ss_stream_busy_96),
    .state_compatible(ss_format_valid_96),
    .busy(ss_active_96),
    .load_rejected(ss_load_rejected_96)
);

raizing_board #(.SS_ENABLE(1)) u_board (
    .GAME_ID(game_id),
    .TARGET_GAME_ID(target_game_id),
    .rst(core_rst),
    .rst48(core_rst48),
    .rst96(core_rst96),
    .clk(clk),
    .clk48(clk48),
    .clk96(clk96),
    .pxl_cen(pxl_cen),
    .pxl2_cen(pxl2_cen),
    .red(red),
    .green(green),
    .blue(blue),
    .LHBL(LHBL),
    .LVBL(LVBL),
    .HS(HS),
    .VS(VS),
    .cab_1p(core_cab_1p),
    .coin(core_coin),
    .joystick1(core_joystick1),
    .joystick2(core_joystick2),
    .joystick3(core_joystick3),
    .joystick4(core_joystick4),
    .joyana_l1(joyana_l1),
    .joyana_l2(joyana_l2),
    .joyana_l3(joyana_l3),
    .joyana_l4(joyana_l4),
    .joyana_r1(joyana_r1),
    .joyana_r2(joyana_r2),
    .joyana_r3(joyana_r3),
    .joyana_r4(joyana_r4),
    .dial_x(dial_x),
    .dial_y(dial_y),
    .tilt(tilt),
    .ba0_addr(ba0_addr),
    .ba1_addr(ba1_addr),
    .ba2_addr(ba2_addr),
    .ba3_addr(ba3_addr),
    .ba_rd(ba_rd),
    .ba_wr(ba_wr),
    .ba0_din(ba0_din),
    .ba0_dsn(ba0_dsn),
    .ba1_din(ba1_din),
    .ba1_dsn(ba1_dsn),
    .ba2_din(ba2_din),
    .ba2_dsn(ba2_dsn),
    .ba3_din(ba3_din),
    .ba3_dsn(ba3_dsn),
    .ba_ack(ba_ack),
    .ba_dst(ba_dst),
    .ba_dok(ba_dok),
    .ba_rdy(ba_rdy),
    .data_read(data_read),
    .ioctl_rom(core_ioctl_rom),
    .ioctl_cart(core_ioctl_cart),
    .dwnld_busy(dwnld_busy),
    .ioctl_addr(core_ioctl_addr),
    .ioctl_dout(core_ioctl_dout),
    .ioctl_wr(core_ioctl_wr),
    .ioctl_din(ioctl_din),
    .ioctl_ram(core_ioctl_ram),
    .prog_addr(prog_addr),
    .prog_data(prog_data),
    .prog_mask(prog_mask),
    .prog_ba(prog_ba),
    .prog_we(prog_we),
    .prog_rd(prog_rd),
    .prog_ack(prog_ack),
    .prog_dok(prog_dok),
    .prog_dst(prog_dst),
    .prog_rdy(prog_rdy),
    .status(status),
    .service(core_service),
    .dip_pause(core_dip_pause),
    .dip_flip(core_dip_flip),
    .dip_test(core_dip_test),
    .dip_fxlevel(dip_fxlevel),
    .dipsw(core_dipsw),
    .snd_left(snd_left),
    .snd_right(snd_right),
    .sample(sample),
    .snd_en(snd_en),
    .snd_vol(snd_vol),
    .snd_vu(snd_vu),
    .snd_peak(snd_peak),
    .gfx_en(gfx_en),
    .clk24(clk24),
    .rst24(core_rst24),
    .SS_ACTIVE(ss_active_96),
    .SS_FREEZE(ss_freeze),
    .SS_SAVE_BEGIN(ss_save_begin),
    .SS_SAVE_RESUME(ss_save_resume),
    .SS_RESTORE_BEGIN(ss_restore_begin),
    .SS_RESTORE_WINDOW(ss_restore_window),
    .SS_SAVE_READY(ss_save_ready),
    .SS_SAVE_DONE(ss_save_done),
    .SS_RESTORE_DONE(ss_restore_done),
    .SS_GAME_QUIESCED(ss_game_quiesced),
    .SS_CPU_IDLE(ss_cpu_idle),
    .SS_DATA(ss_data),
    .SS_ADDR(ss_addr),
    .SS_SELECT(ss_select),
    .SS_WRITE(ss_write),
    .SS_READ(ss_read),
    .SS_QUERY(ss_query),
    .SS_DATA_OUT(ss_data_out),
    .SS_ACK(ss_ack)
);

endmodule
