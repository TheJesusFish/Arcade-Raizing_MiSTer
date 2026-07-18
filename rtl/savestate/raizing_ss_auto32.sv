module raizing_ss_auto32 #(
    parameter SS_INDEX = 0,
    parameter DEVICE_COUNT = 1,
    parameter STATE_STRIDE = 64
)(
    input clk,
    input reset,
    input [63:0] ss_data,
    input [31:0] ss_addr,
    input [7:0] ss_select,
    input ss_write,
    input ss_read,
    input ss_query,
    output reg [63:0] ss_data_out,
    output reg ss_ack,
    output auto_ss_rd,
    output auto_ss_wr,
    output [31:0] auto_ss_data_in,
    output [7:0] auto_ss_device_idx,
    output [15:0] auto_ss_state_idx,
    input [31:0] auto_ss_data_out,
    input auto_ss_ack
);

    localparam WORD_COUNT = DEVICE_COUNT * STATE_STRIDE;
    wire selected = ss_select == SS_INDEX[7:0];
    wire valid_addr = ss_addr < WORD_COUNT;

    assign auto_ss_rd = selected && ss_read && valid_addr;
    assign auto_ss_wr = selected && ss_write && valid_addr;
    assign auto_ss_data_in = ss_data[31:0];
    assign auto_ss_device_idx = ss_addr / STATE_STRIDE;
    assign auto_ss_state_idx = ss_addr % STATE_STRIDE;

    always @(posedge clk) begin
        ss_ack <= 1'b0;
        ss_data_out <= 64'd0;

        if(reset) begin
            ss_ack <= 1'b0;
        end else if(selected) begin
            if(ss_query) begin
                ss_data_out <= {
                    SS_INDEX[7:0], 22'd0, 2'd2, 32'(WORD_COUNT)
                };
                ss_ack <= 1'b1;
            end else if(ss_read) begin
                if(valid_addr && auto_ss_ack)
                    ss_data_out[31:0] <= auto_ss_data_out;
                ss_ack <= 1'b1;
            end else if(ss_write) begin
                ss_ack <= 1'b1;
            end
        end
    end

endmodule

module raizing_ss_auto32_async #(
    parameter SS_INDEX = 0,
    parameter DEVICE_COUNT = 1,
    parameter STATE_STRIDE = 64,
    parameter ACK_TIMEOUT = 4
)(
    input ss_clk,
    input state_clk,
    input reset,
    input [63:0] ss_data,
    input [31:0] ss_addr,
    input [7:0] ss_select,
    input ss_write,
    input ss_read,
    input ss_query,
    output reg [63:0] ss_data_out,
    output reg ss_ack,
    output auto_ss_rd,
    output auto_ss_wr,
    output [31:0] auto_ss_data_in,
    output [7:0] auto_ss_device_idx,
    output [15:0] auto_ss_state_idx,
    input [31:0] auto_ss_data_out,
    input auto_ss_ack
);

    localparam WORD_COUNT = DEVICE_COUNT * STATE_STRIDE;
    localparam TIMEOUT_WIDTH = ACK_TIMEOUT <= 1 ? 1 : $clog2(ACK_TIMEOUT + 1);

    reg request_toggle;
    reg [31:0] request_addr;
    reg [31:0] request_data;
    reg request_write;
    reg request_pending;

    reg request_meta;
    reg request_sync;
    reg request_seen;
    reg [31:0] addr_meta;
    reg [31:0] addr_sync;
    reg [31:0] data_meta;
    reg [31:0] data_sync;
    reg write_meta;
    reg write_sync;
    reg state_active;
    reg state_write;
    reg [7:0] state_device;
    reg [15:0] state_index;
    reg [31:0] state_data;
    reg [TIMEOUT_WIDTH-1:0] timeout_count;
    reg response_toggle;
    reg [31:0] response_data;

    reg response_meta;
    reg response_sync;
    reg [31:0] response_data_meta;
    reg [31:0] response_data_sync;

    wire selected = ss_select == SS_INDEX[7:0];
    wire access = ss_read || ss_write;
    wire valid_addr = ss_addr < WORD_COUNT;

    assign auto_ss_rd = state_active && !state_write;
    assign auto_ss_wr = state_active && state_write;
    assign auto_ss_data_in = state_data;
    assign auto_ss_device_idx = state_device;
    assign auto_ss_state_idx = state_index;

    always @(posedge ss_clk) begin
        if(reset) begin
            request_toggle <= 1'b0;
            request_addr <= 32'd0;
            request_data <= 32'd0;
            request_write <= 1'b0;
            request_pending <= 1'b0;
            response_meta <= 1'b0;
            response_sync <= 1'b0;
            response_data_meta <= 32'd0;
            response_data_sync <= 32'd0;
            ss_data_out <= 64'd0;
            ss_ack <= 1'b0;
        end else begin
            response_meta <= response_toggle;
            response_sync <= response_meta;
            response_data_meta <= response_data;
            response_data_sync <= response_data_meta;

            if(ss_ack) begin
                if(!access && !ss_query) begin
                    ss_ack <= 1'b0;
                    ss_data_out <= 64'd0;
                    request_pending <= 1'b0;
                end
            end else if(selected && ss_query) begin
                ss_data_out <= {
                    SS_INDEX[7:0], 22'd0, 2'd2, 32'(WORD_COUNT)
                };
                ss_ack <= 1'b1;
            end else if(selected && access && !request_pending) begin
                if(!valid_addr) begin
                    ss_data_out <= 64'd0;
                    ss_ack <= 1'b1;
                end else begin
                    request_addr <= ss_addr;
                    request_data <= ss_data[31:0];
                    request_write <= ss_write;
                    request_toggle <= ~request_toggle;
                    request_pending <= 1'b1;
                end
            end else if(request_pending && response_sync == request_toggle) begin
                ss_data_out <= request_write ? 64'd0 : {32'd0, response_data_sync};
                ss_ack <= 1'b1;
            end
        end
    end

    always @(posedge state_clk) begin
        if(reset) begin
            request_meta <= 1'b0;
            request_sync <= 1'b0;
            request_seen <= 1'b0;
            addr_meta <= 32'd0;
            addr_sync <= 32'd0;
            data_meta <= 32'd0;
            data_sync <= 32'd0;
            write_meta <= 1'b0;
            write_sync <= 1'b0;
            state_active <= 1'b0;
            state_write <= 1'b0;
            state_device <= 8'd0;
            state_index <= 16'd0;
            state_data <= 32'd0;
            timeout_count <= {TIMEOUT_WIDTH{1'b0}};
            response_toggle <= 1'b0;
            response_data <= 32'd0;
        end else begin
            request_meta <= request_toggle;
            request_sync <= request_meta;
            addr_meta <= request_addr;
            addr_sync <= addr_meta;
            data_meta <= request_data;
            data_sync <= data_meta;
            write_meta <= request_write;
            write_sync <= write_meta;

            if(!state_active && request_sync != request_seen) begin
                request_seen <= request_sync;
                state_write <= write_sync;
                state_device <= addr_sync / STATE_STRIDE;
                state_index <= addr_sync % STATE_STRIDE;
                state_data <= data_sync;
                timeout_count <= {TIMEOUT_WIDTH{1'b0}};
                state_active <= 1'b1;
            end else if(state_active) begin
                if(auto_ss_ack) begin
                    response_data <= state_write ? 32'd0 : auto_ss_data_out;
                    response_toggle <= request_seen;
                    state_active <= 1'b0;
                end else if(ACK_TIMEOUT <= 1 || timeout_count == ACK_TIMEOUT - 1) begin
                    response_data <= 32'd0;
                    response_toggle <= request_seen;
                    state_active <= 1'b0;
                end else begin
                    timeout_count <= timeout_count + 1'b1;
                end
            end
        end
    end

endmodule
