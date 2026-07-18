module raizing_ss_controller(
    input clk,
    input reset,
    input save_request,
    input load_request,
    output pause_request,
    input paused,
    input game_quiesced,
    output reg game_save_begin,
    output reg game_save_resume,
    output reg game_restore_begin,
    output reg restore_window,
    input game_save_ready,
    input game_save_done,
    input game_restore_done,
    output reg stream_save_start,
    output reg stream_load_start,
    input stream_busy,
    input state_compatible,
    output busy,
    output reg load_rejected
);

    localparam ST_IDLE = 4'd0;
    localparam ST_WAIT_PAUSE_SAVE = 4'd1;
    localparam ST_WAIT_SAVE_READY = 4'd2;
    localparam ST_WAIT_SAVE_BUSY = 4'd3;
    localparam ST_WAIT_SAVE_STREAM = 4'd4;
    localparam ST_WAIT_SAVE_DONE = 4'd5;
    localparam ST_WAIT_PAUSE_LOAD = 4'd6;
    localparam ST_WAIT_LOAD_BUSY = 4'd7;
    localparam ST_WAIT_LOAD_STREAM = 4'd8;
    localparam ST_WAIT_RESTORE_DONE = 4'd9;
    localparam ST_REJECT_LOAD = 4'd10;

    reg [3:0] state;

    assign busy = state != ST_IDLE;
    assign pause_request = state != ST_IDLE;

    always @(posedge clk) begin
        game_save_begin <= 1'b0;
        game_save_resume <= 1'b0;
        game_restore_begin <= 1'b0;
        stream_save_start <= 1'b0;
        stream_load_start <= 1'b0;
        load_rejected <= 1'b0;

        if(reset) begin
            state <= ST_IDLE;
            restore_window <= 1'b0;
        end else begin
            case(state)
                ST_IDLE: begin
                    restore_window <= 1'b0;
                    if(save_request)
                        state <= ST_WAIT_PAUSE_SAVE;
                    else if(load_request)
                        state <= ST_WAIT_PAUSE_LOAD;
                end

                ST_WAIT_PAUSE_SAVE: begin
                    if(paused && game_quiesced) begin
                        game_save_begin <= 1'b1;
                        state <= ST_WAIT_SAVE_READY;
                    end
                end

                ST_WAIT_SAVE_READY: begin
                    if(game_save_ready) begin
                        stream_save_start <= 1'b1;
                        state <= ST_WAIT_SAVE_BUSY;
                    end
                end

                ST_WAIT_SAVE_BUSY: begin
                    if(stream_busy)
                        state <= ST_WAIT_SAVE_STREAM;
                end

                ST_WAIT_SAVE_STREAM: begin
                    if(!stream_busy) begin
                        game_save_resume <= 1'b1;
                        state <= ST_WAIT_SAVE_DONE;
                    end
                end

                ST_WAIT_SAVE_DONE: begin
                    if(game_save_done)
                        state <= ST_IDLE;
                end

                ST_WAIT_PAUSE_LOAD: begin
                    if(paused && game_quiesced) begin
                        restore_window <= 1'b1;
                        stream_load_start <= 1'b1;
                        state <= ST_WAIT_LOAD_BUSY;
                    end
                end

                ST_WAIT_LOAD_BUSY: begin
                    if(stream_busy)
                        state <= ST_WAIT_LOAD_STREAM;
                end

                ST_WAIT_LOAD_STREAM: begin
                    if(!stream_busy) begin
                        if(state_compatible) begin
                            game_restore_begin <= 1'b1;
                            state <= ST_WAIT_RESTORE_DONE;
                        end else begin
                            state <= ST_REJECT_LOAD;
                        end
                    end
                end

                ST_WAIT_RESTORE_DONE: begin
                    if(game_restore_done) begin
                        restore_window <= 1'b0;
                        state <= ST_IDLE;
                    end
                end

                default: begin
                    load_rejected <= 1'b1;
                    restore_window <= 1'b0;
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
