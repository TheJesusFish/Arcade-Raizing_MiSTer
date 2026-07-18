// Adapted from MiSTer-devel/Arcade-TaitoF2_MiSTer.

interface raizing_ddr_if();
    logic acquire;
    logic [31:0] addr;
    logic [63:0] wdata;
    logic [63:0] rdata;
    logic read;
    logic write;
    logic [7:0] burstcnt;
    logic [7:0] byteenable;
    logic busy;
    logic rdata_ready;
endinterface

module raizing_ddr_mux(
    input clk,
    input reset,
    raizing_ddr_if host,
    raizing_ddr_if high_priority,
    raizing_ddr_if low_priority
);

    reg owner_valid;
    reg owner_high;
    reg read_pending;
    wire selected_high = owner_valid ? owner_high : high_priority.acquire;
    wire selected_acquire = selected_high ? high_priority.acquire :
                                                low_priority.acquire;

    always @* begin
        high_priority.rdata = host.rdata;
        low_priority.rdata = host.rdata;
        high_priority.busy = 1'b1;
        low_priority.busy = 1'b1;
        high_priority.rdata_ready = 1'b0;
        low_priority.rdata_ready = 1'b0;

        host.acquire = high_priority.acquire | low_priority.acquire;
        host.addr = 32'd0;
        host.wdata = 64'd0;
        host.read = 1'b0;
        host.write = 1'b0;
        host.burstcnt = 8'd1;
        host.byteenable = 8'hff;

        if(owner_valid || high_priority.acquire || low_priority.acquire) begin
            if(selected_high) begin
                host.addr = high_priority.addr;
                host.wdata = high_priority.wdata;
                host.read = high_priority.read;
                host.write = high_priority.write;
                host.burstcnt = high_priority.burstcnt;
                host.byteenable = high_priority.byteenable;
                high_priority.busy = host.busy;
                high_priority.rdata_ready = host.rdata_ready;
            end else begin
                host.addr = low_priority.addr;
                host.wdata = low_priority.wdata;
                host.read = low_priority.read;
                host.write = low_priority.write;
                host.burstcnt = low_priority.burstcnt;
                host.byteenable = low_priority.byteenable;
                low_priority.busy = host.busy;
                low_priority.rdata_ready = host.rdata_ready;
            end
        end
    end

    always @(posedge clk) begin
        if(reset) begin
            owner_valid <= 1'b0;
            owner_high <= 1'b0;
            read_pending <= 1'b0;
        end else begin
            if(!owner_valid) begin
                if(high_priority.acquire) begin
                    owner_valid <= 1'b1;
                    owner_high <= 1'b1;
                end else if(low_priority.acquire) begin
                    owner_valid <= 1'b1;
                    owner_high <= 1'b0;
                end
            end

            if((owner_valid || high_priority.acquire || low_priority.acquire) &&
               host.read && !host.busy)
                read_pending <= 1'b1;

            if(host.rdata_ready)
                read_pending <= 1'b0;

            if(owner_valid && !selected_acquire && !read_pending &&
               !host.busy && !host.rdata_ready)
                owner_valid <= 1'b0;
        end
    end

endmodule

module raizing_ddr_legacy_adapter(
    input clk,
    input reset,
    input block_new,
    input [31:0] addr,
    input [63:0] wdata,
    input read,
    input write,
    input [7:0] burstcnt,
    input [7:0] byteenable,
    output [63:0] rdata,
    output busy,
    output rdata_ready,
    output idle,
    raizing_ddr_if ddr
);

    reg active;
    reg issued;
    reg is_read;
    reg [31:0] saved_addr;
    reg [63:0] saved_wdata;
    reg [7:0] saved_burstcnt;
    reg [7:0] saved_byteenable;
    wire new_request = !active && !block_new && (read || write);

    assign ddr.acquire = active || new_request;
    assign ddr.addr = active ? saved_addr : addr;
    assign ddr.wdata = active ? saved_wdata : wdata;
    assign ddr.burstcnt = active ? saved_burstcnt : burstcnt;
    assign ddr.byteenable = active ? saved_byteenable : byteenable;
    assign ddr.read = (active && !issued && is_read) ||
                      (new_request && read);
    assign ddr.write = (active && !issued && !is_read) ||
                       (new_request && write && !read);

    assign rdata = ddr.rdata;
    assign rdata_ready = ddr.rdata_ready && active && is_read;
    assign busy = block_new || active || ddr.busy;
    assign idle = !active && !read && !write;

    always @(posedge clk) begin
        if(reset) begin
            active <= 1'b0;
            issued <= 1'b0;
            is_read <= 1'b0;
            saved_addr <= 32'd0;
            saved_wdata <= 64'd0;
            saved_burstcnt <= 8'd1;
            saved_byteenable <= 8'hff;
        end else begin
            if(new_request) begin
                active <= 1'b1;
                issued <= !ddr.busy;
                is_read <= read;
                saved_addr <= addr;
                saved_wdata <= wdata;
                saved_burstcnt <= burstcnt;
                saved_byteenable <= byteenable;
            end else if(active && !issued && !ddr.busy) begin
                issued <= 1'b1;
            end

            if(active && issued) begin
                if(is_read && ddr.rdata_ready) begin
                    active <= 1'b0;
                    issued <= 1'b0;
                end else if(!is_read && !ddr.busy) begin
                    active <= 1'b0;
                    issued <= 1'b0;
                end
            end
        end
    end

endmodule
