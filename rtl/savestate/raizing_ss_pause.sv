module raizing_ss_pause #(
    parameter DRAIN_CYCLES = 4
)(
    input clk,
    input reset,
    input request,
    input vblank,
    input memory_idle,
    input cpu_idle,
    output reg freeze,
    output reg paused
);

    localparam COUNT_WIDTH = DRAIN_CYCLES <= 1 ? 1 : $clog2(DRAIN_CYCLES + 1);
    reg [COUNT_WIDTH-1:0] idle_count;

    always @(posedge clk) begin
        if(reset || !request) begin
            freeze <= 1'b0;
            paused <= 1'b0;
            idle_count <= {COUNT_WIDTH{1'b0}};
        end else begin
            if(!freeze && vblank && memory_idle && cpu_idle)
                freeze <= 1'b1;

            if(freeze && !paused) begin
                if(memory_idle) begin
                    if(DRAIN_CYCLES <= 1 || idle_count == DRAIN_CYCLES - 1) begin
                        paused <= 1'b1;
                    end else begin
                        idle_count <= idle_count + 1'b1;
                    end
                end else begin
                    idle_count <= {COUNT_WIDTH{1'b0}};
                end
            end
        end
    end

endmodule
