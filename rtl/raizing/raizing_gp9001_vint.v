// This file is a Codex-assisted refactoring and update
// based on the original work of Pramod Somashekar (pram0d)

// GP9001 vertical interrupt latch. The pin is active low in this core.
module raizing_gp9001_vint #(
    parameter SS_ENABLE = 0
)(
    input            clk,
    input            reset,
    input            line_start,
    input      [8:0] vpos,
    input            reg_write,
    input      [7:0] reg_index,
    output reg       vint_n,
    input            ss_hold,
    input            ss_restore,
    input            ss_state_in,
    output           ss_state
);

wire vint_clear = reg_write &&
                  (reg_index[3:0] == 4'he || reg_index[3:0] == 4'hf);
assign ss_state = vint_n;

always @(posedge clk or posedge reset) begin
    if(reset)
        vint_n <= 1'b1;
    else if(SS_ENABLE && ss_restore)
        vint_n <= ss_state_in;
    else if(SS_ENABLE && ss_hold)
        vint_n <= vint_n;
    else if(vint_clear)
        vint_n <= 1'b1;
    else if(line_start && vpos == 9'h0e6)
        vint_n <= 1'b0;
end

endmodule
