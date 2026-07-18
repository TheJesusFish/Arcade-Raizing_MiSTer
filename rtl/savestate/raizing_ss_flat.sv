module raizing_ss_response_mux #(
    parameter COUNT = 2
)(
    input [COUNT-1:0] ack,
    input [COUNT*64-1:0] data,
    output ack_out,
    output reg [63:0] data_out
);

    integer i;
    assign ack_out = |ack;

    always @* begin
        data_out = 64'd0;
        for(i = 0; i < COUNT; i = i + 1)
            data_out = data_out | (data[i*64 +: 64] & {64{ack[i]}});
    end

endmodule

module raizing_ss_register #(
    parameter WIDTH = 32,
    parameter SS_INDEX = 0
)(
    input clk,
    input reset,
    input [WIDTH-1:0] capture_data,
    output reg [WIDTH-1:0] restore_data,
    output reg restore_we,
    input [63:0] ss_data,
    input [7:0] ss_select,
    input ss_write,
    input ss_read,
    input ss_query,
    output reg [63:0] ss_data_out,
    output reg ss_ack
);

    localparam WIDTH_CODE = WIDTH <= 8 ? 0 : WIDTH <= 16 ? 1 :
                            WIDTH <= 32 ? 2 : 3;

    always @(posedge clk) begin
        ss_ack <= 1'b0;
        restore_we <= 1'b0;
        ss_data_out <= 64'd0;

        if(reset) begin
            restore_data <= {WIDTH{1'b0}};
        end else if(ss_select == SS_INDEX[7:0]) begin
            if(ss_query) begin
                ss_data_out <= {SS_INDEX[7:0], 22'd0, WIDTH_CODE[1:0], 32'd1};
                ss_ack <= 1'b1;
            end else if(ss_read) begin
                ss_data_out[WIDTH-1:0] <= capture_data;
                ss_ack <= 1'b1;
            end else if(ss_write) begin
                restore_data <= ss_data[WIDTH-1:0];
                restore_we <= 1'b1;
                ss_ack <= 1'b1;
            end
        end
    end

endmodule

module raizing_ss_wide_register #(
    parameter WIDTH = 128,
    parameter SS_INDEX = 0
)(
    input clk,
    input reset,
    input [WIDTH-1:0] capture_data,
    output reg [WIDTH-1:0] restore_data,
    output reg restore_we,
    input [63:0] ss_data,
    input [31:0] ss_addr,
    input [7:0] ss_select,
    input ss_write,
    input ss_read,
    input ss_query,
    output reg [63:0] ss_data_out,
    output reg ss_ack
);

    localparam WORD_COUNT = (WIDTH + 63) / 64;
    reg [WORD_COUNT*64-1:0] padded_restore;
    wire [WORD_COUNT*64-1:0] padded_capture =
        {{(WORD_COUNT*64-WIDTH){1'b0}}, capture_data};

    always @* restore_data = padded_restore[WIDTH-1:0];

    always @(posedge clk) begin
        ss_ack <= 1'b0;
        restore_we <= 1'b0;
        ss_data_out <= 64'd0;

        if(reset) begin
            padded_restore <= {WORD_COUNT*64{1'b0}};
        end else if(ss_select == SS_INDEX[7:0]) begin
            if(ss_query) begin
                ss_data_out <= {SS_INDEX[7:0], 22'd0, 2'd3, 32'(WORD_COUNT)};
                ss_ack <= 1'b1;
            end else if(ss_read) begin
                if(ss_addr < WORD_COUNT)
                    ss_data_out <= padded_capture[ss_addr*64 +: 64];
                ss_ack <= 1'b1;
            end else if(ss_write) begin
                if(ss_addr < WORD_COUNT) begin
                    padded_restore[ss_addr*64 +: 64] <= ss_data;
                    if(ss_addr == WORD_COUNT - 1)
                        restore_we <= 1'b1;
                end
                ss_ack <= 1'b1;
            end
        end
    end

endmodule

module raizing_ss_ram_adapter #(
    parameter WIDTH = 16,
    parameter ADDR_WIDTH = 10,
    parameter SS_INDEX = 0
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
    output reg ram_active,
    output reg [ADDR_WIDTH-1:0] ram_addr,
    output reg [WIDTH-1:0] ram_data,
    output reg ram_we,
    input [WIDTH-1:0] ram_q
);

    localparam WIDTH_CODE = WIDTH <= 8 ? 0 : WIDTH <= 16 ? 1 :
                            WIDTH <= 32 ? 2 : 3;
    localparam ST_IDLE = 2'd0;
    localparam ST_READ_WAIT = 2'd1;
    localparam ST_RESPOND = 2'd2;
    localparam ST_RELEASE = 2'd3;
    reg [1:0] state;
    reg op_read;

    always @(posedge clk) begin
        ss_ack <= 1'b0;
        ram_we <= 1'b0;

        if(reset) begin
            state <= ST_IDLE;
            ss_data_out <= 64'd0;
            ram_active <= 1'b0;
            ram_addr <= {ADDR_WIDTH{1'b0}};
            ram_data <= {WIDTH{1'b0}};
            op_read <= 1'b0;
        end else begin
            case(state)
                ST_IDLE: begin
                    ram_active <= 1'b0;
                    ss_data_out <= 64'd0;
                    if(ss_select == SS_INDEX[7:0] && ss_query) begin
                        ss_data_out <= {
                            SS_INDEX[7:0], 22'd0, WIDTH_CODE[1:0],
                            32'(1 << ADDR_WIDTH)
                        };
                        ss_ack <= 1'b1;
                        state <= ST_RELEASE;
                    end else if(ss_select == SS_INDEX[7:0] &&
                                (ss_read || ss_write)) begin
                        if(ss_addr < (1 << ADDR_WIDTH)) begin
                            ram_active <= 1'b1;
                            ram_addr <= ss_addr[ADDR_WIDTH-1:0];
                            ram_data <= ss_data[WIDTH-1:0];
                            op_read <= ss_read;
                            if(ss_write) begin
                                ram_we <= 1'b1;
                                state <= ST_RESPOND;
                            end else begin
                                state <= ST_READ_WAIT;
                            end
                        end else begin
                            ss_ack <= 1'b1;
                            state <= ST_RELEASE;
                        end
                    end
                end

                ST_READ_WAIT: begin
                    state <= ST_RESPOND;
                end

                ST_RESPOND: begin
                    if(op_read)
                        ss_data_out[WIDTH-1:0] <= ram_q;
                    ss_ack <= 1'b1;
                    state <= ST_RELEASE;
                end

                default: begin
                    ss_ack <= 1'b1;
                    if(!(ss_read || ss_write || ss_query)) begin
                        ss_ack <= 1'b0;
                        ram_active <= 1'b0;
                        state <= ST_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
