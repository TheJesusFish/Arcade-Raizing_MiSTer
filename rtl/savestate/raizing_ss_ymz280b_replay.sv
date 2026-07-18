module raizing_ss_ymz280b_replay #(
    parameter SS_ENABLE = 1,
    parameter [7:0] SS_INDEX = 8'd21
)(
    input         clock,
    input         reset,
    input         restore_begin,
    output        replay_busy,

    input         io_cpu_rd,
    input         io_cpu_wr,
    input         io_cpu_addr,
    input         io_cpu_mask,
    input  [7:0]  io_cpu_din,
    output [7:0]  io_cpu_dout,
    output        io_rom_rd,
    output [23:0] io_rom_addr,
    input  [7:0]  io_rom_dout,
    input         io_rom_waitReq,
    input         io_rom_valid,
    output        io_audio_valid,
    output [15:0] io_audio_bits_left,
    output [15:0] io_audio_bits_right,
    output [7:0]  keyon,
    output        keyon_enable,

    input  [63:0] ss_data,
    input  [31:0] ss_addr,
    input   [7:0] ss_select,
    input         ss_write,
    input         ss_read,
    input         ss_query,
    output reg [63:0] ss_data_out,
    output reg        ss_ack
);

localparam [8:0] SS_COUNT = 9'd257;
localparam [2:0] RP_IDLE = 3'd0;
localparam [2:0] RP_RESET = 3'd1;
localparam [2:0] RP_FETCH = 3'd2;
localparam [2:0] RP_ADDR = 3'd3;
localparam [2:0] RP_DATA = 3'd4;
localparam [2:0] RP_WAIT = 3'd5;

wire selected = SS_ENABLE && ss_select == SS_INDEX;
wire cpu_addr_write = io_cpu_wr && !io_cpu_addr;
wire cpu_data_write = io_cpu_wr && io_cpu_addr;

reg [2:0] replay_state;
reg [7:0] replay_step;
reg [3:0] reset_wait;
reg [7:0] register_select;
reg clear_active;
reg [7:0] clear_addr;
reg ss_read_pending;

(* ramstyle = "M10K" *) reg [7:0] shadow [0:255];
reg [7:0] shadow_q;

reg [7:0] replay_addr;
reg [7:0] replay_data;
reg replay_has_data;
reg [7:0] shadow_read_addr;

always @* begin
    replay_addr = replay_step;
    replay_data = shadow_q;
    replay_has_data = 1'b1;
    shadow_read_addr = ss_addr[7:0];

    if(replay_state != RP_IDLE) begin
        if(replay_step < 8'd128) begin
            replay_addr = replay_step;
            shadow_read_addr = replay_step;
            if(replay_step[6:2] < 5'd8 && replay_step[1:0] == 2'd0)
                replay_data = shadow_q & 8'h7f;
        end else if(replay_step == 8'd128) begin
            replay_addr = 8'hfe;
            shadow_read_addr = 8'hfe;
        end else if(replay_step == 8'd129) begin
            replay_addr = 8'hff;
            shadow_read_addr = 8'hff;
            replay_data = shadow_q & 8'h7f;
        end else if(replay_step >= 8'd130 && replay_step <= 8'd137) begin
            replay_addr = (replay_step - 8'd130) << 2;
            shadow_read_addr = (replay_step - 8'd130) << 2;
        end else if(replay_step == 8'd138) begin
            replay_addr = 8'hff;
            shadow_read_addr = 8'hff;
        end else begin
            replay_addr = register_select;
            replay_data = 8'd0;
            replay_has_data = 1'b0;
        end
    end
end

wire replay_active = replay_state != RP_IDLE;
assign replay_busy = SS_ENABLE && replay_active;

wire chip_reset = reset | clear_active | replay_state == RP_RESET;
wire chip_cpu_rd = replay_active ? 1'b0 : io_cpu_rd;
wire chip_cpu_wr = replay_state == RP_ADDR || replay_state == RP_DATA ?
                   1'b1 : (replay_active ? 1'b0 : io_cpu_wr);
wire chip_cpu_addr = replay_state == RP_ADDR ? 1'b0 :
                     replay_state == RP_DATA ? 1'b1 : io_cpu_addr;
wire [7:0] chip_cpu_din = replay_state == RP_ADDR ? replay_addr :
                          replay_state == RP_DATA ? replay_data : io_cpu_din;

always @(posedge clock) begin
    shadow_q <= shadow[shadow_read_addr];

    if(reset) begin
        clear_active <= SS_ENABLE;
        clear_addr <= 8'd0;
        register_select <= 8'd0;
    end else if(clear_active) begin
        shadow[clear_addr] <= 8'd0;
        clear_addr <= clear_addr + 1'b1;
        if(&clear_addr)
            clear_active <= 1'b0;
    end else begin
        if(selected && ss_write && ss_addr < 32'd256)
            shadow[ss_addr[7:0]] <= ss_data[7:0];
        else if(!replay_active && cpu_data_write)
            shadow[register_select] <= io_cpu_din;

        if(selected && ss_write && ss_addr == 32'd256)
            register_select <= ss_data[7:0];
        else if(!replay_active && cpu_addr_write)
            register_select <= io_cpu_din;
    end
end

always @(posedge clock) begin
    ss_ack <= 1'b0;

    if(reset) begin
        ss_data_out <= 64'd0;
        ss_read_pending <= 1'b0;
    end else begin
        if(!(selected && ss_read && ss_addr < 32'd256))
            ss_read_pending <= 1'b0;

        if(selected && ss_query) begin
            ss_data_out <= {SS_INDEX, 22'd0, 2'd0, 32'(SS_COUNT)};
            ss_ack <= 1'b1;
        end else if(selected && ss_write) begin
            ss_ack <= 1'b1;
        end else if(selected && ss_read) begin
            if(ss_addr < 32'd256) begin
                if(ss_read_pending) begin
                    ss_data_out <= {56'd0, shadow_q};
                    ss_ack <= 1'b1;
                end else begin
                    ss_read_pending <= 1'b1;
                end
            end else begin
                ss_data_out <= {56'd0, register_select};
                ss_ack <= 1'b1;
            end
        end
    end
end

always @(posedge clock) begin
    if(reset || !SS_ENABLE) begin
        replay_state <= RP_IDLE;
        replay_step <= 8'd0;
        reset_wait <= 4'd0;
    end else if(restore_begin) begin
        replay_state <= RP_RESET;
        replay_step <= 8'd0;
        reset_wait <= 4'd0;
    end else begin
        case(replay_state)
            RP_IDLE: begin end

            RP_RESET: begin
                reset_wait <= reset_wait + 1'b1;
                if(reset_wait == 4'd7) begin
                    reset_wait <= 4'd0;
                    replay_state <= RP_FETCH;
                end
            end

            RP_FETCH: replay_state <= RP_ADDR;

            RP_ADDR: begin
                if(replay_has_data)
                    replay_state <= RP_DATA;
                else
                    replay_state <= RP_IDLE;
            end

            RP_DATA: replay_state <= RP_WAIT;

            RP_WAIT: begin
                replay_step <= replay_step + 1'b1;
                replay_state <= RP_FETCH;
            end

            default: replay_state <= RP_IDLE;
        endcase
    end
end

YMZ280B u_ymz280b(
    .clock(clock),
    .reset(chip_reset),
    .io_cpu_rd(chip_cpu_rd),
    .io_cpu_wr(chip_cpu_wr),
    .io_cpu_addr(chip_cpu_addr),
    .io_cpu_mask(io_cpu_mask),
    .io_cpu_din(chip_cpu_din),
    .io_cpu_dout(io_cpu_dout),
    .io_rom_rd(io_rom_rd),
    .io_rom_addr(io_rom_addr),
    .io_rom_dout(io_rom_dout),
    .io_rom_waitReq(io_rom_waitReq),
    .io_rom_valid(io_rom_valid),
    .io_audio_valid(io_audio_valid),
    .io_audio_bits_left(io_audio_bits_left),
    .io_audio_bits_right(io_audio_bits_right),
    .io_irq(),
    .io_debug_channels_0_flags_keyOn(keyon[0]),
    .io_debug_channels_1_flags_keyOn(keyon[1]),
    .io_debug_channels_2_flags_keyOn(keyon[2]),
    .io_debug_channels_3_flags_keyOn(keyon[3]),
    .io_debug_channels_4_flags_keyOn(keyon[4]),
    .io_debug_channels_5_flags_keyOn(keyon[5]),
    .io_debug_channels_6_flags_keyOn(keyon[6]),
    .io_debug_channels_7_flags_keyOn(keyon[7]),
    .io_debug_utilReg_flags_keyOnEnable(keyon_enable)
);

endmodule
