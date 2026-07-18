// Adapted from MiSTer-devel/Arcade-TaitoF2_MiSTer.
// Each endpoint item occupies one 64-bit DDR word.
module raizing_ss_memory_stream_impl #(parameter COUNT = 32)
(
    input               clk,
    input               reset,
    raizing_ddr_if      ddr,

    output reg          write_req,
    output reg [63:0]   write_data,
    input               data_ack,
    output reg          read_req,
    input      [63:0]   read_data,

    input      [31:0]   start_addr,
    input      [31:0]   length,
    input               read_start,
    input               write_start,
    input               load_compatible,

    output reg          query_req,
    output reg [31:0]   chunk_address,
    output reg  [7:0]   chunk_select,
    output              busy,
    output reg          load_valid
);

    typedef enum logic [5:0] {
        IDLE,
        READ_HEADER_REQ,
        READ_HEADER_WAIT,
        SAVE_QUERY_START,
        SAVE_QUERY_WAIT,
        SAVE_DESC_REQ,
        SAVE_DESC_WAIT,
        SAVE_DEVICE_START,
        SAVE_DEVICE_WAIT,
        SAVE_DATA_REQ,
        SAVE_DATA_WAIT,
        SAVE_NEXT_CHUNK,
        SAVE_FINAL_REQ,
        SAVE_FINAL_WAIT,
        SAVE_HEADER_SIZE_REQ,
        SAVE_HEADER_SIZE_WAIT,
        SAVE_HEADER_CHANGE_REQ,
        SAVE_HEADER_CHANGE_WAIT,
        LOAD_DESC_REQ,
        LOAD_DESC_WAIT,
        LOAD_QUERY_START,
        LOAD_QUERY_WAIT,
        LOAD_SKIP,
        LOAD_DATA_REQ,
        LOAD_DATA_WAIT,
        LOAD_DEVICE_START,
        LOAD_DEVICE_WAIT,
        LOAD_VALIDATE,
        LOAD_NEXT_DESC,
        FINISH
    } state_t;

    state_t state;
    reg is_loading;
    reg metadata_validated;
    reg [7:0] chunk_index;
    reg [31:0] chunk_remaining;
    reg [31:0] current_addr;
    reg [31:0] end_addr;
    reg [63:0] buffer;
    reg [63:0] header_data;
    reg [4:0] query_delay;
    reg [7:0] device_delay;
    reg [3:0] validate_delay;

    wire [31:0] payload_length = current_addr - (start_addr + 32'd8);
    assign busy = state != IDLE;

    always @(posedge clk) begin
        if(reset) begin
            state <= IDLE;
            ddr.acquire <= 1'b0;
            ddr.addr <= 32'd0;
            ddr.wdata <= 64'd0;
            ddr.read <= 1'b0;
            ddr.write <= 1'b0;
            ddr.burstcnt <= 8'd1;
            ddr.byteenable <= 8'hff;
            write_req <= 1'b0;
            write_data <= 64'd0;
            read_req <= 1'b0;
            query_req <= 1'b0;
            chunk_address <= 32'd0;
            chunk_select <= 8'd0;
            load_valid <= 1'b0;
            is_loading <= 1'b0;
            metadata_validated <= 1'b0;
            chunk_index <= 8'd0;
            chunk_remaining <= 32'd0;
            current_addr <= 32'd0;
            end_addr <= 32'd0;
            buffer <= 64'd0;
            header_data <= 64'd0;
            query_delay <= 5'd0;
            device_delay <= 8'd0;
            validate_delay <= 4'd0;
        end else begin
            case(state)
                IDLE: begin
                    ddr.acquire <= 1'b0;
                    ddr.read <= 1'b0;
                    ddr.write <= 1'b0;
                    ddr.burstcnt <= 8'd1;
                    ddr.byteenable <= 8'hff;
                    write_req <= 1'b0;
                    read_req <= 1'b0;
                    query_req <= 1'b0;
                    chunk_address <= 32'd0;
                    chunk_select <= 8'd0;

                    if(read_start || write_start) begin
                        ddr.acquire <= 1'b1;
                        current_addr <= start_addr + 32'd8;
                        end_addr <= start_addr + length;
                        chunk_index <= 8'd0;
                        chunk_remaining <= 32'd0;
                        metadata_validated <= 1'b0;
                        load_valid <= 1'b0;
                        is_loading <= read_start;
                        state <= READ_HEADER_REQ;
                    end
                end

                READ_HEADER_REQ: begin
                    if(!ddr.busy) begin
                        ddr.addr <= start_addr;
                        ddr.read <= 1'b1;
                        state <= READ_HEADER_WAIT;
                    end
                end

                READ_HEADER_WAIT: begin
                    if(!ddr.busy) begin
                        ddr.read <= 1'b0;
                        if(ddr.rdata_ready) begin
                            header_data <= ddr.rdata;
                            if(is_loading) begin
                                if({ddr.rdata[61:32], 2'b00} == 32'd0 ||
                                   {ddr.rdata[61:32], 2'b00} > length - 32'd8) begin
                                    state <= FINISH;
                                end else begin
                                    end_addr <= start_addr + 32'd8 +
                                                {ddr.rdata[61:32], 2'b00};
                                    state <= LOAD_DESC_REQ;
                                end
                            end else begin
                                state <= SAVE_QUERY_START;
                            end
                        end
                    end
                end

                SAVE_QUERY_START: begin
                    chunk_select <= chunk_index;
                    query_delay <= 5'd0;
                    query_req <= 1'b1;
                    state <= SAVE_QUERY_WAIT;
                end

                SAVE_QUERY_WAIT: begin
                    if(data_ack) begin
                        query_req <= 1'b0;
                        chunk_remaining <= read_data[31:0];
                        buffer <= {
                            chunk_index,
                            22'd0,
                            2'd3,
                            read_data[31:0]
                        };
                        state <= SAVE_DESC_REQ;
                    end else if(&query_delay) begin
                        query_req <= 1'b0;
                        state <= SAVE_NEXT_CHUNK;
                    end else begin
                        query_delay <= query_delay + 1'b1;
                    end
                end

                SAVE_DESC_REQ: begin
                    if(current_addr > end_addr - 32'd8) begin
                        state <= FINISH;
                    end else if(!ddr.busy) begin
                        ddr.addr <= current_addr;
                        ddr.wdata <= buffer;
                        ddr.write <= 1'b1;
                        current_addr <= current_addr + 32'd8;
                        state <= SAVE_DESC_WAIT;
                    end
                end

                SAVE_DESC_WAIT: begin
                    if(!ddr.busy) begin
                        ddr.write <= 1'b0;
                        if(chunk_remaining == 0)
                            state <= SAVE_NEXT_CHUNK;
                        else
                            state <= SAVE_DEVICE_START;
                    end
                end

                SAVE_DEVICE_START: begin
                    chunk_address <= 32'd0;
                    read_req <= 1'b1;
                    device_delay <= 8'd0;
                    state <= SAVE_DEVICE_WAIT;
                end

                SAVE_DEVICE_WAIT: begin
                    if(data_ack) begin
                        buffer <= read_data;
                        read_req <= 1'b0;
                        state <= SAVE_DATA_REQ;
                    end else if(&device_delay) begin
                        read_req <= 1'b0;
                        state <= FINISH;
                    end else begin
                        device_delay <= device_delay + 1'b1;
                    end
                end

                SAVE_DATA_REQ: begin
                    if(current_addr > end_addr - 32'd8) begin
                        state <= FINISH;
                    end else if(!ddr.busy) begin
                        ddr.addr <= current_addr;
                        ddr.wdata <= buffer;
                        ddr.write <= 1'b1;
                        current_addr <= current_addr + 32'd8;
                        state <= SAVE_DATA_WAIT;
                    end
                end

                SAVE_DATA_WAIT: begin
                    if(!ddr.busy) begin
                        ddr.write <= 1'b0;
                        if(chunk_remaining == 32'd1) begin
                            chunk_remaining <= 32'd0;
                            state <= SAVE_NEXT_CHUNK;
                        end else begin
                            chunk_remaining <= chunk_remaining - 1'b1;
                            chunk_address <= chunk_address + 1'b1;
                            read_req <= 1'b1;
                            device_delay <= 8'd0;
                            state <= SAVE_DEVICE_WAIT;
                        end
                    end
                end

                SAVE_NEXT_CHUNK: begin
                    if(chunk_index + 1'b1 >= COUNT) begin
                        state <= SAVE_FINAL_REQ;
                    end else begin
                        chunk_index <= chunk_index + 1'b1;
                        state <= SAVE_QUERY_START;
                    end
                end

                SAVE_FINAL_REQ: begin
                    if(current_addr > end_addr - 32'd8) begin
                        state <= FINISH;
                    end else if(!ddr.busy) begin
                        ddr.addr <= current_addr;
                        ddr.wdata <= ~64'd0;
                        ddr.write <= 1'b1;
                        current_addr <= current_addr + 32'd8;
                        state <= SAVE_FINAL_WAIT;
                    end
                end

                SAVE_FINAL_WAIT: begin
                    if(!ddr.busy) begin
                        ddr.write <= 1'b0;
                        state <= SAVE_HEADER_SIZE_REQ;
                    end
                end

                SAVE_HEADER_SIZE_REQ: begin
                    if(!ddr.busy) begin
                        ddr.addr <= start_addr;
                        ddr.wdata <= {
                            2'b00,
                            payload_length[31:2],
                            header_data[31:0]
                        };
                        ddr.byteenable <= 8'hf0;
                        ddr.write <= 1'b1;
                        state <= SAVE_HEADER_SIZE_WAIT;
                    end
                end

                SAVE_HEADER_SIZE_WAIT: begin
                    if(!ddr.busy) begin
                        ddr.write <= 1'b0;
                        ddr.byteenable <= 8'hff;
                        state <= SAVE_HEADER_CHANGE_REQ;
                    end
                end

                SAVE_HEADER_CHANGE_REQ: begin
                    if(!ddr.busy) begin
                        ddr.addr <= start_addr;
                        ddr.wdata <= {
                            header_data[63:32],
                            header_data[31:0] + 1'b1
                        };
                        ddr.byteenable <= 8'h0f;
                        ddr.write <= 1'b1;
                        state <= SAVE_HEADER_CHANGE_WAIT;
                    end
                end

                SAVE_HEADER_CHANGE_WAIT: begin
                    if(!ddr.busy) begin
                        ddr.write <= 1'b0;
                        ddr.byteenable <= 8'hff;
                        state <= FINISH;
                    end
                end

                LOAD_DESC_REQ: begin
                    if(current_addr > end_addr - 32'd8) begin
                        state <= FINISH;
                    end else if(!ddr.busy) begin
                        ddr.addr <= current_addr;
                        ddr.read <= 1'b1;
                        current_addr <= current_addr + 32'd8;
                        state <= LOAD_DESC_WAIT;
                    end
                end

                LOAD_DESC_WAIT: begin
                    if(!ddr.busy) begin
                        ddr.read <= 1'b0;
                        if(ddr.rdata_ready) begin
                            buffer <= ddr.rdata;
                            if(&ddr.rdata[63:56]) begin
                                if(metadata_validated)
                                    load_valid <= 1'b1;
                                state <= FINISH;
                            end else if(ddr.rdata[33:32] != 2'd3) begin
                                state <= FINISH;
                            end else if(!metadata_validated &&
                                        (ddr.rdata[63:56] != 8'd0 ||
                                         ddr.rdata[31:0] != 32'd3)) begin
                                state <= FINISH;
                            end else if(metadata_validated &&
                                        ddr.rdata[63:56] == 8'd0) begin
                                state <= FINISH;
                            end else begin
                                chunk_index <= ddr.rdata[63:56];
                                chunk_select <= ddr.rdata[63:56];
                                chunk_remaining <= ddr.rdata[31:0];
                                state <= LOAD_QUERY_START;
                            end
                        end
                    end
                end

                LOAD_QUERY_START: begin
                    query_delay <= 5'd0;
                    query_req <= 1'b1;
                    state <= LOAD_QUERY_WAIT;
                end

                LOAD_QUERY_WAIT: begin
                    if(data_ack) begin
                        query_req <= 1'b0;
                        if(read_data[31:0] != chunk_remaining) begin
                            state <= FINISH;
                        end else if(chunk_remaining == 0) begin
                            state <= LOAD_NEXT_DESC;
                        end else begin
                            chunk_address <= 32'd0;
                            state <= LOAD_DATA_REQ;
                        end
                    end else if(&query_delay) begin
                        query_req <= 1'b0;
                        if(!metadata_validated)
                            state <= FINISH;
                        else
                            state <= LOAD_SKIP;
                    end else begin
                        query_delay <= query_delay + 1'b1;
                    end
                end

                LOAD_SKIP: begin
                    if(chunk_remaining > ((end_addr - current_addr) >> 3)) begin
                        state <= FINISH;
                    end else begin
                        current_addr <= current_addr + (chunk_remaining << 3);
                        chunk_remaining <= 32'd0;
                        state <= LOAD_NEXT_DESC;
                    end
                end

                LOAD_DATA_REQ: begin
                    if(current_addr > end_addr - 32'd8) begin
                        state <= FINISH;
                    end else if(!ddr.busy) begin
                        ddr.addr <= current_addr;
                        ddr.read <= 1'b1;
                        current_addr <= current_addr + 32'd8;
                        state <= LOAD_DATA_WAIT;
                    end
                end

                LOAD_DATA_WAIT: begin
                    if(!ddr.busy) begin
                        ddr.read <= 1'b0;
                        if(ddr.rdata_ready) begin
                            buffer <= ddr.rdata;
                            state <= LOAD_DEVICE_START;
                        end
                    end
                end

                LOAD_DEVICE_START: begin
                    write_data <= buffer;
                    write_req <= 1'b1;
                    device_delay <= 8'd0;
                    state <= LOAD_DEVICE_WAIT;
                end

                LOAD_DEVICE_WAIT: begin
                    if(data_ack) begin
                        write_req <= 1'b0;
                        if(chunk_remaining == 32'd1) begin
                            chunk_remaining <= 32'd0;
                            if(chunk_index == 8'd0) begin
                                validate_delay <= 4'd0;
                                state <= LOAD_VALIDATE;
                            end else begin
                                state <= LOAD_NEXT_DESC;
                            end
                        end else begin
                            chunk_remaining <= chunk_remaining - 1'b1;
                            chunk_address <= chunk_address + 1'b1;
                            state <= LOAD_DATA_REQ;
                        end
                    end else if(&device_delay) begin
                        write_req <= 1'b0;
                        state <= FINISH;
                    end else begin
                        device_delay <= device_delay + 1'b1;
                    end
                end

                LOAD_VALIDATE: begin
                    validate_delay <= validate_delay + 1'b1;
                    if(validate_delay == 4'd7) begin
                        if(load_compatible) begin
                            metadata_validated <= 1'b1;
                            state <= LOAD_NEXT_DESC;
                        end else begin
                            state <= FINISH;
                        end
                    end
                end

                LOAD_NEXT_DESC: begin
                    state <= LOAD_DESC_REQ;
                end

                FINISH: begin
                    ddr.acquire <= 1'b0;
                    ddr.read <= 1'b0;
                    ddr.write <= 1'b0;
                    ddr.byteenable <= 8'hff;
                    write_req <= 1'b0;
                    read_req <= 1'b0;
                    query_req <= 1'b0;
                    state <= IDLE;
                end

                default: state <= FINISH;
            endcase
        end
    end

endmodule

module raizing_ss_memory_stream #(
    parameter CHUNK_COUNT = 32
)(
    input clk,
    input reset,
    raizing_ddr_if ddr,
    output device_write,
    output [63:0] device_write_data,
    input device_ack,
    output device_read,
    input [63:0] device_read_data,
    input [31:0] start_addr,
    input [31:0] slot_length,
    input load_start,
    input save_start,
    input load_compatible,
    output query,
    output [31:0] chunk_addr,
    output [7:0] chunk_select,
    output busy,
    output load_valid
);

    raizing_ss_memory_stream_impl #(
        .COUNT(CHUNK_COUNT)
    ) u_stream (
        .clk(clk),
        .reset(reset),
        .ddr(ddr),
        .write_req(device_write),
        .write_data(device_write_data),
        .data_ack(device_ack),
        .read_req(device_read),
        .read_data(device_read_data),
        .start_addr(start_addr),
        .length(slot_length),
        .read_start(load_start),
        .write_start(save_start),
        .load_compatible(load_compatible),
        .query_req(query),
        .chunk_address(chunk_addr),
        .chunk_select(chunk_select),
        .busy(busy),
        .load_valid(load_valid)
    );

endmodule

module raizing_save_state_data #(
    parameter CHUNK_COUNT = 32,
    parameter [31:0] DDR_BASE = 32'h3e00_0000,
    parameter [31:0] SLOT_SIZE = 32'h0040_0000
)(
    input clk,
    input reset,
    raizing_ddr_if ddr,
    input save_start,
    input load_start,
    input load_compatible,
    input [1:0] slot,
    output busy,
    output load_valid,
    raizing_ssbus_if ssbus
);

    wire [31:0] slot_addr = DDR_BASE + (slot * SLOT_SIZE);

    raizing_ss_memory_stream #(
        .CHUNK_COUNT(CHUNK_COUNT)
    ) u_stream (
        .clk(clk),
        .reset(reset),
        .ddr(ddr),
        .device_write(ssbus.write),
        .device_write_data(ssbus.data),
        .device_ack(ssbus.ack),
        .device_read(ssbus.read),
        .device_read_data(ssbus.data_out),
        .start_addr(slot_addr),
        .slot_length(SLOT_SIZE),
        .load_start(load_start),
        .save_start(save_start),
        .load_compatible(load_compatible),
        .query(ssbus.query),
        .chunk_addr(ssbus.addr),
        .chunk_select(ssbus.select),
        .busy(busy),
        .load_valid(load_valid)
    );

endmodule
