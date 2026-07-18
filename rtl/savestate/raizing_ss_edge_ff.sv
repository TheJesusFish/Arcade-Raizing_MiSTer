module raizing_ss_edge_ff(
    input clk,
    input reset,
    input hold,
    input cen,
    input din,
    output reg q,
    output reg qn,
    input set,
    input clr,
    input sigedge,
    input restore_we,
    input [1:0] restore_state,
    output [1:0] capture_state
);

    reg last_edge;

    assign capture_state = {q, last_edge};

    always @(posedge clk) begin
        if(reset) begin
            q <= 1'b0;
            qn <= 1'b1;
            last_edge <= 1'b0;
        end else if(restore_we) begin
            q <= restore_state[1];
            qn <= ~restore_state[1];
            last_edge <= restore_state[0];
        end else if(!hold) begin
            last_edge <= sigedge;
            if(cen && clr) begin
                q <= 1'b0;
                qn <= 1'b1;
            end else if(cen && set) begin
                q <= 1'b1;
                qn <= 1'b0;
            end else if(sigedge && !last_edge) begin
                q <= din;
                qn <= ~din;
            end
        end
    end

endmodule
