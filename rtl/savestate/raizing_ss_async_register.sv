module raizing_ss_async_wide_register #(
    parameter WIDTH = 128,
    parameter SS_INDEX = 0
)(
    input ss_clk,
    input ss_reset,
    input state_clk,
    input state_reset,
    input state_quiesced,
    input [WIDTH-1:0] capture_data,
    output reg [WIDTH-1:0] restore_data,
    output reg restore_we,
    input [63:0] ss_data,
    input [31:0] ss_addr,
    input [7:0] ss_select,
    input ss_write,
    input ss_read,
    input ss_query,
    output [63:0] ss_data_out,
    output ss_ack
);

    reg [WIDTH-1:0] capture_hold;
    reg [WIDTH-1:0] capture_meta;
    reg [WIDTH-1:0] capture_sync;
    wire [WIDTH-1:0] restore_hold;
    wire restore_commit;
    reg [WIDTH-1:0] restore_meta;
    reg [WIDTH-1:0] restore_sync;
    wire restore_commit_state;

    always @(posedge state_clk) begin
        if(state_reset)
            capture_hold <= {WIDTH{1'b0}};
        else if(state_quiesced)
            capture_hold <= capture_data;
    end

    always @(posedge ss_clk) begin
        if(ss_reset) begin
            capture_meta <= {WIDTH{1'b0}};
            capture_sync <= {WIDTH{1'b0}};
        end else begin
            capture_meta <= capture_hold;
            capture_sync <= capture_meta;
        end
    end

    raizing_ss_wide_register #(
        .WIDTH(WIDTH),
        .SS_INDEX(SS_INDEX)
    ) u_register(
        .clk(ss_clk),
        .reset(ss_reset),
        .capture_data(capture_sync),
        .restore_data(restore_hold),
        .restore_we(restore_commit),
        .ss_data(ss_data),
        .ss_addr(ss_addr),
        .ss_select(ss_select),
        .ss_write(ss_write),
        .ss_read(ss_read),
        .ss_query(ss_query),
        .ss_data_out(ss_data_out),
        .ss_ack(ss_ack)
    );

    raizing_ss_pulse_cdc u_restore_pulse(
        .src_clk(ss_clk),
        .src_reset(ss_reset),
        .src_pulse(restore_commit),
        .dst_clk(state_clk),
        .dst_reset(state_reset),
        .dst_pulse(restore_commit_state)
    );

    always @(posedge state_clk) begin
        if(state_reset) begin
            restore_meta <= {WIDTH{1'b0}};
            restore_sync <= {WIDTH{1'b0}};
            restore_data <= {WIDTH{1'b0}};
            restore_we <= 1'b0;
        end else begin
            restore_meta <= restore_hold;
            restore_sync <= restore_meta;
            restore_we <= restore_commit_state;
            if(restore_commit_state)
                restore_data <= restore_sync;
        end
    end

endmodule
