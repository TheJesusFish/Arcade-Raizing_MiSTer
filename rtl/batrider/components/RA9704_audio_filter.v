// This file is a Codex-assisted refactoring and update
// based on the original work of Pramod Somashekar (pram0d)

/* RA9704 Sallen-Key stages, bilinear transformed at 192 kHz.
 * B: 10k/10k, 101pF/2.2nF; C: 10k/10k, 1nF/2.2nF.
 * Each biquad reuses one multiplier over five clocks.
 */

module ra9704_audio_filter(
    input                    rst,
    input                    clk,
    input                    sample,
    input      signed [15:0] din,
    output     signed [15:0] dout
);

wire signed [15:0] stage_b_out;
wire               stage_b_done;

ra9704_biquad #(
    .B0( 32'sd212531562), .B1( 32'sd425063124), .B2(32'sd212531562),
    .A1(-32'sd967644436), .A2( 32'sd744028860)
) u_stage_b(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .sample     ( sample       ),
    .sin        ( din          ),
    .sout       ( stage_b_out  ),
    .done       ( stage_b_done )
);

ra9704_biquad #(
    .B0( 32'sd26112195),   .B1( 32'sd52224390),
    .B2( 32'sd26112195),   .A1(-32'sd1641951548),
    .A2( 32'sd672658505)
) u_stage_c(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .sample     ( stage_b_done ),
    .sin        ( stage_b_out  ),
    .sout       ( dout         ),
    .done       (              )
);

endmodule

module ra9704_biquad #(
    parameter signed [31:0] B0 = 0,
    parameter signed [31:0] B1 = 0,
    parameter signed [31:0] B2 = 0,
    parameter signed [31:0] A1 = 0,
    parameter signed [31:0] A2 = 0
)(
    input                    rst,
    input                    clk,
    input                    sample,
    input      signed [15:0] sin,
    output reg signed [15:0] sout,
    output reg               done
);

reg signed [15:0] x0, x1, x2, y1, y2;
reg signed [15:0] operand;
reg signed [31:0] coefficient;
reg signed [50:0] accumulator;
reg        [2:0] state;
reg              busy;

wire signed [47:0] product = operand * coefficient;
wire signed [50:0] product_ext = {{3{product[47]}}, product};
wire signed [50:0] final_sum = accumulator - product_ext;

function signed [15:0] saturate_q30;
    input signed [50:0] value;
    reg   signed [50:0] scaled;
    begin
        scaled = value >>> 30;
        if(scaled > 51'sd32767)
            saturate_q30 = 16'sh7fff;
        else if(scaled < -51'sd32768)
            saturate_q30 = 16'sh8000;
        else
            saturate_q30 = scaled[15:0];
    end
endfunction

wire signed [15:0] filtered = saturate_q30(final_sum);

always @(posedge clk) begin
    done <= 1'b0;
    if(rst) begin
        x0          <= 16'sd0;
        x1          <= 16'sd0;
        x2          <= 16'sd0;
        y1          <= 16'sd0;
        y2          <= 16'sd0;
        operand     <= 16'sd0;
        coefficient <= 32'sd0;
        accumulator <= 51'sd0;
        state       <= 3'd0;
        busy        <= 1'b0;
        sout        <= 16'sd0;
    end else if(!busy) begin
        if(sample) begin
            x0          <= sin;
            operand     <= sin;
            coefficient <= B0;
            state       <= 3'd0;
            busy        <= 1'b1;
        end
    end else begin
        case(state)
            3'd0: begin
                accumulator <= product_ext;
                operand     <= x1;
                coefficient <= B1;
                state       <= 3'd1;
            end
            3'd1: begin
                accumulator <= accumulator + product_ext;
                operand     <= x2;
                coefficient <= B2;
                state       <= 3'd2;
            end
            3'd2: begin
                accumulator <= accumulator + product_ext;
                operand     <= y1;
                coefficient <= A1;
                state       <= 3'd3;
            end
            3'd3: begin
                accumulator <= accumulator - product_ext;
                operand     <= y2;
                coefficient <= A2;
                state       <= 3'd4;
            end
            default: begin
                x2   <= x1;
                x1   <= x0;
                y2   <= y1;
                y1   <= filtered;
                sout <= filtered;
                done <= 1'b1;
                busy <= 1'b0;
            end
        endcase
    end
end

endmodule
