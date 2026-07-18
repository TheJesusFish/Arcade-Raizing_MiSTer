module raizing_ss_ui #(
    parameter INFO_TIMEOUT_BITS = 24
)(
    input clk,
    input reset,
    input [10:0] ps2_key,
    input allow_ss,
    input busy,
    input load_rejected,
    input joy_ss,
    input joy_right,
    input joy_left,
    input joy_down,
    input joy_up,
    input [1:0] status_slot,
    input autoinc_slot,
    input [1:0] osd_save_load,
    output reg save_request,
    output reg load_request,
    output reg info_request,
    output reg [7:0] info_index,
    output reg status_update,
    output reg [1:0] selected_slot,
    output reg [1:0] request_slot
);

    localparam [7:0] INFO_INCOMPATIBLE = 8'd14;

    reg [10:0] ps2_key_d;
    reg alt_pressed;
    reg joy_ss_d;
    reg joy_right_d;
    reg joy_left_d;
    reg joy_down_d;
    reg joy_up_d;
    reg [1:0] osd_save_load_d;
    reg [1:0] status_slot_d;

    wire key_event = ps2_key[10] != ps2_key_d[10];
    wire key_pressed = ps2_key[9];

    function automatic is_slot_key(input [7:0] code);
        begin
            is_slot_key = code == 8'h05 || code == 8'h06 ||
                          code == 8'h04 || code == 8'h0c;
        end
    endfunction

    function automatic [1:0] key_slot(input [7:0] code);
        begin
            case(code)
                8'h06: key_slot = 2'd1;
                8'h04: key_slot = 2'd2;
                8'h0c: key_slot = 2'd3;
                default: key_slot = 2'd0;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        save_request <= 1'b0;
        load_request <= 1'b0;
        info_request <= 1'b0;
        status_update <= 1'b0;

        if(reset) begin
            ps2_key_d <= 11'd0;
            alt_pressed <= 1'b0;
            joy_ss_d <= 1'b0;
            joy_right_d <= 1'b0;
            joy_left_d <= 1'b0;
            joy_down_d <= 1'b0;
            joy_up_d <= 1'b0;
            osd_save_load_d <= 2'd0;
            status_slot_d <= 2'd0;
            selected_slot <= 2'd0;
            request_slot <= 2'd0;
            info_index <= 8'd0;
        end else begin
            ps2_key_d <= ps2_key;
            joy_ss_d <= joy_ss;
            joy_right_d <= joy_right;
            joy_left_d <= joy_left;
            joy_down_d <= joy_down;
            joy_up_d <= joy_up;
            osd_save_load_d <= osd_save_load;
            status_slot_d <= status_slot;

            if(status_slot != status_slot_d)
                selected_slot <= status_slot;

            if(key_event && ps2_key[7:0] == 8'h11)
                alt_pressed <= key_pressed;

            if(allow_ss && !busy && key_event && key_pressed &&
               is_slot_key(ps2_key[7:0])) begin
                request_slot <= key_slot(ps2_key[7:0]);
                selected_slot <= key_slot(ps2_key[7:0]);
                status_update <= 1'b1;
                info_request <= 1'b1;
                info_index <= 8'd6 + {key_slot(ps2_key[7:0]),
                                      !alt_pressed};
                if(alt_pressed) begin
                    save_request <= 1'b1;
                    if(autoinc_slot)
                        selected_slot <= key_slot(ps2_key[7:0]) + 1'b1;
                end else begin
                    load_request <= 1'b1;
                end
            end else if(allow_ss && !busy &&
                        osd_save_load[0] && !osd_save_load_d[0]) begin
                request_slot <= selected_slot;
                save_request <= 1'b1;
                info_request <= 1'b1;
                info_index <= 8'd6 + {selected_slot, 1'b0};
                if(autoinc_slot) begin
                    selected_slot <= selected_slot + 1'b1;
                    status_update <= 1'b1;
                end
            end else if(allow_ss && !busy &&
                        osd_save_load[1] && !osd_save_load_d[1]) begin
                request_slot <= selected_slot;
                load_request <= 1'b1;
                info_request <= 1'b1;
                info_index <= 8'd6 + {selected_slot, 1'b1};
            end else if(joy_ss && !joy_right_d && joy_right) begin
                selected_slot <= selected_slot + 1'b1;
                status_update <= 1'b1;
                info_request <= 1'b1;
                info_index <= 8'd2 + (selected_slot + 1'b1);
            end else if(joy_ss && !joy_left_d && joy_left) begin
                selected_slot <= selected_slot - 1'b1;
                status_update <= 1'b1;
                info_request <= 1'b1;
                info_index <= 8'd2 + (selected_slot - 1'b1);
            end else if(allow_ss && !busy && joy_ss &&
                        !joy_down_d && joy_down) begin
                request_slot <= selected_slot;
                save_request <= 1'b1;
                info_request <= 1'b1;
                info_index <= 8'd6 + {selected_slot, 1'b0};
                if(autoinc_slot) begin
                    selected_slot <= selected_slot + 1'b1;
                    status_update <= 1'b1;
                end
            end else if(allow_ss && !busy && joy_ss &&
                        !joy_up_d && joy_up) begin
                request_slot <= selected_slot;
                load_request <= 1'b1;
                info_request <= 1'b1;
                info_index <= 8'd6 + {selected_slot, 1'b1};
            end

            if(load_rejected) begin
                info_request <= 1'b1;
                info_index <= INFO_INCOMPATIBLE;
            end
        end
    end

endmodule
