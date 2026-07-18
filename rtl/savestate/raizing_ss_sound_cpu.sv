module raizing_ss_sound_cpu #(
    parameter CPU_CLOCK_ASYNC = 1,
    parameter SS_INDEX = 15
)(
    input ss_clk,
    input ss_reset,
    input cpu_clk,
    input cpu_reset,
    input ss_freeze,
    input ss_restore_begin,
    output cpu_hold,
    input cpu_quiesced,
    output cpu_restore,
    input cpu_restore_done,
    input [228:0] cpu_state,
    output [228:0] cpu_state_in,
    output quiesced,
    output restore_done,
    input [63:0] ss_data,
    input [31:0] ss_addr,
    input [7:0] ss_select,
    input ss_write,
    input ss_read,
    input ss_query,
    output [63:0] ss_data_out,
    output ss_ack
);

    wire endpoint_restore_we;

    generate
        if(CPU_CLOCK_ASYNC) begin : gen_async
            raizing_ss_level_cdc u_hold(
                .dst_clk(cpu_clk),
                .dst_reset(cpu_reset),
                .src_level(ss_freeze),
                .dst_level(cpu_hold)
            );

            raizing_ss_level_cdc u_quiesced(
                .dst_clk(ss_clk),
                .dst_reset(ss_reset),
                .src_level(cpu_quiesced),
                .dst_level(quiesced)
            );

            raizing_ss_pulse_cdc u_restore(
                .src_clk(ss_clk),
                .src_reset(ss_reset),
                .src_pulse(ss_restore_begin),
                .dst_clk(cpu_clk),
                .dst_reset(cpu_reset),
                .dst_pulse(cpu_restore)
            );

            raizing_ss_pulse_cdc u_restore_done(
                .src_clk(cpu_clk),
                .src_reset(cpu_reset),
                .src_pulse(cpu_restore_done),
                .dst_clk(ss_clk),
                .dst_reset(ss_reset),
                .dst_pulse(restore_done)
            );

            raizing_ss_async_wide_register #(
                .WIDTH(229),
                .SS_INDEX(SS_INDEX)
            ) u_state(
                .ss_clk(ss_clk),
                .ss_reset(ss_reset),
                .state_clk(cpu_clk),
                .state_reset(cpu_reset),
                .state_quiesced(cpu_quiesced),
                .capture_data(cpu_state),
                .restore_data(cpu_state_in),
                .restore_we(endpoint_restore_we),
                .ss_data(ss_data),
                .ss_addr(ss_addr),
                .ss_select(ss_select),
                .ss_write(ss_write),
                .ss_read(ss_read),
                .ss_query(ss_query),
                .ss_data_out(ss_data_out),
                .ss_ack(ss_ack)
            );
        end else begin : gen_sync
            assign cpu_hold = ss_freeze;
            assign quiesced = cpu_quiesced;
            assign cpu_restore = ss_restore_begin;
            assign restore_done = cpu_restore_done;

            raizing_ss_wide_register #(
                .WIDTH(229),
                .SS_INDEX(SS_INDEX)
            ) u_state(
                .clk(ss_clk),
                .reset(ss_reset),
                .capture_data(cpu_state),
                .restore_data(cpu_state_in),
                .restore_we(endpoint_restore_we),
                .ss_data(ss_data),
                .ss_addr(ss_addr),
                .ss_select(ss_select),
                .ss_write(ss_write),
                .ss_read(ss_read),
                .ss_query(ss_query),
                .ss_data_out(ss_data_out),
                .ss_ack(ss_ack)
            );
        end
    endgenerate

endmodule
