module raizing_ss_jt51_replay #(
    parameter SS_ENABLE = 1,
    parameter [7:0] SS_INDEX = 8'd20
)(
    input                clk,
    input                reset,
    input                active,
    input                cen,
    input                cen_p1,
    input                replay_cen,
    input                replay_cen_p1,
    input                cs_n,
    input                wr_n,
    input                a0,
    input          [7:0] din,
    output         [7:0] dout,
    output               irq_n,
    output               sample,
    output signed [15:0] xleft,
    output signed [15:0] xright,

    input                restore_begin,
    output               replay_busy,
    input         [63:0] ss_data,
    input         [31:0] ss_addr,
    input          [7:0] ss_select,
    input                ss_write,
    input                ss_read,
    input                ss_query,
    output reg    [63:0] ss_data_out,
    output reg           ss_ack
);

localparam [8:0] SS_COUNT = 9'd267;
localparam [2:0] RP_IDLE = 3'd0;
localparam [2:0] RP_RESET = 3'd1;
localparam [2:0] RP_FETCH = 3'd2;
localparam [2:0] RP_ADDR = 3'd3;
localparam [2:0] RP_DATA = 3'd4;
localparam [2:0] RP_WAIT = 3'd5;

wire base_reset = reset | !active;
wire selected = SS_ENABLE && active && ss_select == SS_INDEX;
wire cpu_write = !cs_n && !wr_n;
wire cpu_data_write = cpu_write && a0;

reg [2:0] replay_state;
reg [8:0] replay_step;
reg [5:0] replay_wait;
reg [7:0] register_select;
reg [6:0] saved_amd;
reg [6:0] saved_pmd;
reg [3:0] saved_keyon [0:7];

reg clear_active;
reg [7:0] clear_addr;
reg ss_read_pending;

(* ramstyle = "M10K" *) reg [7:0] shadow [0:255];
reg [7:0] shadow_q;

wire replay_uses_shadow = replay_step < 9'd256;
wire [7:0] shadow_read_addr = replay_state != RP_IDLE && replay_uses_shadow ?
                              replay_step[7:0] : ss_addr[7:0];

wire skip_step = replay_uses_shadow &&
                 (replay_step[7:0] == 8'h08 ||
                  replay_step[7:0] == 8'h19);

reg [7:0] replay_addr;
reg [7:0] replay_data;
reg replay_has_data;

always @* begin
    replay_addr = replay_step[7:0];
    replay_data = shadow_q;
    replay_has_data = 1'b1;

    if(replay_step == 9'd256) begin
        replay_addr = 8'h19;
        replay_data = {1'b0, saved_amd};
    end else if(replay_step == 9'd257) begin
        replay_addr = 8'h19;
        replay_data = {1'b1, saved_pmd};
    end else if(replay_step >= 9'd258 && replay_step <= 9'd265) begin
        replay_addr = 8'h08;
        replay_data = {
            1'b0,
            saved_keyon[replay_step[2:0]],
            replay_step[2:0]
        };
    end else if(replay_step == 9'd266) begin
        replay_addr = register_select;
        replay_data = 8'd0;
        replay_has_data = 1'b0;
    end
end

wire replay_active = replay_state != RP_IDLE;
assign replay_busy = SS_ENABLE && replay_active;

wire chip_reset = base_reset | clear_active | replay_state == RP_RESET;
wire chip_cen = replay_active ? replay_cen : (cen & active);
wire chip_cen_p1 = replay_active ? replay_cen_p1 : (cen_p1 & active);
wire chip_cs_n = replay_state == RP_ADDR || replay_state == RP_DATA ?
                 1'b0 : cs_n;
wire chip_wr_n = replay_state == RP_ADDR || replay_state == RP_DATA ?
                 1'b0 : wr_n;
wire chip_a0 = replay_state == RP_ADDR ? 1'b0 :
               replay_state == RP_DATA ? 1'b1 : a0;
wire [7:0] chip_din = replay_state == RP_ADDR ? replay_addr :
                      replay_state == RP_DATA ? replay_data : din;

always @(posedge clk) begin
    shadow_q <= shadow[shadow_read_addr];

    if(base_reset) begin
        clear_active <= SS_ENABLE;
        clear_addr <= 8'd0;
        register_select <= 8'd0;
        saved_amd <= 7'd0;
        saved_pmd <= 7'd0;
        saved_keyon[0] <= 4'd0;
        saved_keyon[1] <= 4'd0;
        saved_keyon[2] <= 4'd0;
        saved_keyon[3] <= 4'd0;
        saved_keyon[4] <= 4'd0;
        saved_keyon[5] <= 4'd0;
        saved_keyon[6] <= 4'd0;
        saved_keyon[7] <= 4'd0;
    end else if(clear_active) begin
        shadow[clear_addr] <= 8'd0;
        clear_addr <= clear_addr + 1'b1;
        if(&clear_addr)
            clear_active <= 1'b0;
    end else begin
        if(selected && ss_write && ss_addr < 32'd256)
            shadow[ss_addr[7:0]] <= ss_data[7:0];
        else if(!replay_active && cpu_data_write)
            shadow[register_select] <= din;

        if(selected && ss_write) begin
            case(ss_addr)
                32'd256: register_select <= ss_data[7:0];
                32'd257: saved_amd <= ss_data[6:0];
                32'd258: saved_pmd <= ss_data[6:0];
                32'd259: saved_keyon[0] <= ss_data[3:0];
                32'd260: saved_keyon[1] <= ss_data[3:0];
                32'd261: saved_keyon[2] <= ss_data[3:0];
                32'd262: saved_keyon[3] <= ss_data[3:0];
                32'd263: saved_keyon[4] <= ss_data[3:0];
                32'd264: saved_keyon[5] <= ss_data[3:0];
                32'd265: saved_keyon[6] <= ss_data[3:0];
                32'd266: saved_keyon[7] <= ss_data[3:0];
                default: begin end
            endcase
        end else if(!replay_active && cpu_write) begin
            if(!a0)
                register_select <= din;
            else if(register_select == 8'h19) begin
                if(din[7])
                    saved_pmd <= din[6:0];
                else
                    saved_amd <= din[6:0];
            end else if(register_select == 8'h08) begin
                saved_keyon[din[2:0]] <= din[6:3];
            end
        end
    end
end

always @(posedge clk) begin
    ss_ack <= 1'b0;

    if(base_reset) begin
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
                case(ss_addr)
                    32'd256: ss_data_out <= {56'd0, register_select};
                    32'd257: ss_data_out <= {57'd0, saved_amd};
                    32'd258: ss_data_out <= {57'd0, saved_pmd};
                    32'd259: ss_data_out <= {60'd0, saved_keyon[0]};
                    32'd260: ss_data_out <= {60'd0, saved_keyon[1]};
                    32'd261: ss_data_out <= {60'd0, saved_keyon[2]};
                    32'd262: ss_data_out <= {60'd0, saved_keyon[3]};
                    32'd263: ss_data_out <= {60'd0, saved_keyon[4]};
                    32'd264: ss_data_out <= {60'd0, saved_keyon[5]};
                    32'd265: ss_data_out <= {60'd0, saved_keyon[6]};
                    default: ss_data_out <= {60'd0, saved_keyon[7]};
                endcase
                ss_ack <= 1'b1;
            end
        end
    end
end

always @(posedge clk) begin
    if(base_reset || !SS_ENABLE) begin
        replay_state <= RP_IDLE;
        replay_step <= 9'd0;
        replay_wait <= 6'd0;
    end else if(restore_begin) begin
        replay_state <= RP_RESET;
        replay_step <= 9'd0;
        replay_wait <= 6'd0;
    end else begin
        case(replay_state)
            RP_IDLE: begin end

            RP_RESET: begin
                if(replay_cen_p1) begin
                    replay_wait <= replay_wait + 1'b1;
                    if(replay_wait == 6'd39) begin
                        replay_wait <= 6'd0;
                        replay_state <= RP_FETCH;
                    end
                end
            end

            RP_FETCH: begin
                if(skip_step) begin
                    replay_step <= replay_step + 1'b1;
                end else begin
                    replay_state <= RP_ADDR;
                end
            end

            RP_ADDR: begin
                if(replay_has_data)
                    replay_state <= RP_DATA;
                else
                    replay_state <= RP_IDLE;
            end

            RP_DATA: begin
                replay_wait <= 6'd0;
                replay_state <= RP_WAIT;
            end

            RP_WAIT: begin
                if(replay_cen_p1) begin
                    replay_wait <= replay_wait + 1'b1;
                    if(replay_wait == 6'd39) begin
                        replay_wait <= 6'd0;
                        replay_step <= replay_step + 1'b1;
                        replay_state <= RP_FETCH;
                    end
                end
            end

            default: replay_state <= RP_IDLE;
        endcase
    end
end

jt51 u_jt51(
    .rst(chip_reset),
    .clk(clk),
    .cen(chip_cen),
    .cen_p1(chip_cen_p1),
    .cs_n(chip_cs_n),
    .wr_n(chip_wr_n),
    .a0(chip_a0),
    .din(chip_din),
    .dout(dout),
    .ct1(),
    .ct2(),
    .irq_n(irq_n),
    .sample(sample),
    .left(),
    .right(),
    .xleft(xleft),
    .xright(xright)
);

endmodule
