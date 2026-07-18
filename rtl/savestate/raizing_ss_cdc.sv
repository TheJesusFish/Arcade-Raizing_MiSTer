module raizing_ss_level_cdc(
    input dst_clk,
    input dst_reset,
    input src_level,
    output reg dst_level
);

    reg level_meta;

    always @(posedge dst_clk) begin
        if(dst_reset) begin
            level_meta <= 1'b0;
            dst_level <= 1'b0;
        end else begin
            level_meta <= src_level;
            dst_level <= level_meta;
        end
    end

endmodule

module raizing_ss_pulse_cdc(
    input src_clk,
    input src_reset,
    input src_pulse,
    input dst_clk,
    input dst_reset,
    output reg dst_pulse
);

    reg src_toggle;
    reg dst_meta;
    reg dst_toggle;
    reg dst_toggle_d;

    always @(posedge src_clk) begin
        if(src_reset)
            src_toggle <= 1'b0;
        else if(src_pulse)
            src_toggle <= ~src_toggle;
    end

    always @(posedge dst_clk) begin
        if(dst_reset) begin
            dst_meta <= 1'b0;
            dst_toggle <= 1'b0;
            dst_toggle_d <= 1'b0;
            dst_pulse <= 1'b0;
        end else begin
            dst_meta <= src_toggle;
            dst_toggle <= dst_meta;
            dst_toggle_d <= dst_toggle;
            dst_pulse <= dst_toggle ^ dst_toggle_d;
        end
    end

endmodule
