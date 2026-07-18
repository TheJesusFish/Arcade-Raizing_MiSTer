module raizing_ss_68k #(
    parameter USE_DTACK = 0
)(
    input clk,
    input reset,
    input cpu_phi1,
    input save_begin,
    input save_resume,
    input restore_begin,
    input restore_window,
    input [31:0] restore_ssp,
    input [23:1] cpu_addr,
    input [15:0] cpu_data_out,
    input cpu_rw,
    input cpu_as_n,
    input cpu_uds_n,
    input cpu_lds_n,
    input cpu_dtack_n,
    input [2:0] cpu_fc,
    output cpu_run,
    output cpu_reset,
    output block_writes,
    output irq_level7,
    output override_valid,
    output reg [15:0] override_data,
    output reg [31:0] saved_ssp,
    output save_ready,
    output reg save_done,
    output reg restore_done,
    output busy
);

    localparam ST_IDLE = 3'd0;
    localparam ST_SAVE_IRQ = 3'd1;
    localparam ST_SAVE_SSP = 3'd2;
    localparam ST_SAVE_HOLD = 3'd3;
    localparam ST_SAVE_EXIT = 3'd4;
    localparam ST_RESTORE_RESET = 3'd5;
    localparam ST_RESTORE_EXIT = 3'd6;

    reg [2:0] state;
    reg [7:0] reset_count;
    reg [15:0] reset_vector [0:3];

    wire [23:0] byte_addr = {cpu_addr, 1'b0};
    wire bus_active = !cpu_as_n && (!cpu_uds_n || !cpu_lds_n);
    wire bus_ack = !USE_DTACK || !cpu_dtack_n;
    wire cpu_read = bus_active && cpu_rw;
    wire cpu_write = bus_active && !cpu_rw;
    wire iack = bus_active && cpu_fc == 3'b111;
    wire handler_cs = busy && cpu_read && byte_addr[23:8] == 16'hff00;
    wire reset_vector_cs = busy && cpu_read && byte_addr < 24'h000008;
    wire irq_vector_cs = busy && cpu_read &&
                         (byte_addr == 24'h00007c ||
                          byte_addr == 24'h00007e);
    wire program_fetch = cpu_read && bus_ack &&
                         cpu_fc == 3'b110 && !handler_cs;

    function automatic [15:0] handler_word(input [3:0] index);
        begin
            case(index)
                4'h0: handler_word = 16'h48e7;
                4'h1: handler_word = 16'hfffe;
                4'h2: handler_word = 16'h4e6e;
                4'h3: handler_word = 16'h2f0e;
                4'h4: handler_word = 16'h4df9;
                4'h5: handler_word = 16'h00ff;
                4'h6: handler_word = 16'h0000;
                4'h7: handler_word = 16'h2c8f;
                4'h8: handler_word = 16'h2c5f;
                4'h9: handler_word = 16'h4e66;
                4'ha: handler_word = 16'h4cdf;
                4'hb: handler_word = 16'h7fff;
                4'hc: handler_word = 16'h4e73;
                default: handler_word = 16'h0000;
            endcase
        end
    endfunction

    assign busy = state != ST_IDLE;
    assign irq_level7 = state == ST_SAVE_IRQ;
    assign save_ready = state == ST_SAVE_HOLD;
    assign cpu_reset = state == ST_RESTORE_RESET;
    assign block_writes = restore_window;
    assign cpu_run = state == ST_SAVE_IRQ || state == ST_SAVE_SSP ||
                     state == ST_SAVE_EXIT || state == ST_RESTORE_RESET ||
                     state == ST_RESTORE_EXIT;
    assign override_valid = handler_cs || reset_vector_cs || irq_vector_cs;

    always @* begin
        if(handler_cs)
            override_data = handler_word(byte_addr[4:1]);
        else if(reset_vector_cs)
            override_data = reset_vector[byte_addr[2:1]];
        else if(irq_vector_cs)
            override_data = byte_addr[1] ? 16'h0000 : 16'h00ff;
        else
            override_data = 16'd0;
    end

    always @(posedge clk) begin
        save_done <= 1'b0;
        restore_done <= 1'b0;

        if(reset) begin
            state <= ST_IDLE;
            reset_count <= 8'd0;
            saved_ssp <= 32'd0;
            reset_vector[0] <= 16'd0;
            reset_vector[1] <= 16'd0;
            reset_vector[2] <= 16'd0;
            reset_vector[3] <= 16'd0;
        end else begin
            case(state)
                ST_IDLE: begin
                    if(save_begin) begin
                        state <= ST_SAVE_IRQ;
                    end else if(restore_begin) begin
                        reset_vector[0] <= restore_ssp[31:16];
                        reset_vector[1] <= restore_ssp[15:0];
                        reset_vector[2] <= 16'h00ff;
                        reset_vector[3] <= 16'h0008;
                        reset_count <= 8'd0;
                        state <= ST_RESTORE_RESET;
                    end
                end

                ST_SAVE_IRQ: begin
                    if(iack && cpu_addr[3:1] == 3'b111 && !cpu_lds_n)
                        state <= ST_SAVE_SSP;
                end

                ST_SAVE_SSP: begin
                    if(cpu_write && bus_ack && byte_addr == 24'hff0000)
                        saved_ssp[31:16] <= cpu_data_out;

                    if(cpu_write && bus_ack && byte_addr == 24'hff0002) begin
                        saved_ssp[15:0] <= cpu_data_out;
                        state <= ST_SAVE_HOLD;
                    end
                end

                ST_SAVE_HOLD: begin
                    if(save_resume)
                        state <= ST_SAVE_EXIT;
                end

                ST_SAVE_EXIT: begin
                    if(program_fetch) begin
                        save_done <= 1'b1;
                        state <= ST_IDLE;
                    end
                end

                ST_RESTORE_RESET: begin
                    if(cpu_phi1) begin
                        reset_count <= reset_count + 1'b1;
                        if(&reset_count)
                            state <= ST_RESTORE_EXIT;
                    end
                end

                ST_RESTORE_EXIT: begin
                    if(program_fetch && !reset_vector_cs) begin
                        restore_done <= 1'b1;
                        state <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
