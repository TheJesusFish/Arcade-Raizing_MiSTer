// This file is a Codex-assisted refactoring and update
// based on the original work of Pramod Somashekar (pram0d)

/* Four-slot round-robin ROM reader for the Raizing SDRAM banks.
 * Preserves the bank request contract with local request/cache logic.
 */
`ifdef RAIZING_SDRAM_LINE64
`define RAIZING_DEFAULT_ROM_LINE_DW 64
`else
`define RAIZING_DEFAULT_ROM_LINE_DW 32
`endif

module raizing_rom_4slots_rr #(parameter
    SDRAMW = 22,
    SLOT0_DW = 8, SLOT1_DW = 8, SLOT2_DW = 8, SLOT3_DW = 8,
    SLOT0_AW = 8, SLOT1_AW = 8, SLOT2_AW = 8, SLOT3_AW = 8,

    SLOT0_LATCH  = 0,
    SLOT1_LATCH  = 0,
    SLOT2_LATCH  = 0,
    SLOT3_LATCH  = 0,

    SLOT0_DOUBLE = 0,
    SLOT1_DOUBLE = 0,
    SLOT2_DOUBLE = 0,
    SLOT3_DOUBLE = 0,

    SLOT0_OKLATCH= 1,
    SLOT1_OKLATCH= 1,
    SLOT2_OKLATCH= 1,
    SLOT3_OKLATCH= 1,

    CACHE0_SIZE = 0,
    CACHE1_SIZE = 0,
    CACHE2_SIZE = 0,
    CACHE3_SIZE = 0,
    LINE_DW = `RAIZING_DEFAULT_ROM_LINE_DW,
    LINE_CACHE0_ENTRIES = 2,
    LINE_CACHE1_ENTRIES = 2,
    LINE_CACHE2_ENTRIES = 2,
    LINE_CACHE3_ENTRIES = 2,
    DM_CACHE_BITS = 0,
/* verilator lint_off WIDTH */
    parameter [SDRAMW-1:0] SLOT0_OFFSET = 0,
    parameter [SDRAMW-1:0] SLOT1_OFFSET = 0,
    parameter [SDRAMW-1:0] SLOT2_OFFSET = 0,
    parameter [SDRAMW-1:0] SLOT3_OFFSET = 0
/* verilator lint_on WIDTH */
)(
    input               rst,
    input               clk,

    input  [SLOT0_AW-1:0] slot0_addr,
    input  [SLOT1_AW-1:0] slot1_addr,
    input  [SLOT2_AW-1:0] slot2_addr,
    input  [SLOT3_AW-1:0] slot3_addr,

    output [SLOT0_DW-1:0] slot0_dout,
    output [SLOT1_DW-1:0] slot1_dout,
    output [SLOT2_DW-1:0] slot2_dout,
    output [SLOT3_DW-1:0] slot3_dout,

    input               slot0_cs,
    input               slot1_cs,
    input               slot2_cs,
    input               slot3_cs,

    output              slot0_ok,
    output              slot1_ok,
    output              slot2_ok,
    output              slot3_ok,

    input               sdram_ack,
    output              sdram_rd,
    output [SDRAMW-1:0] sdram_addr,
    input               data_dst,
    input               data_rdy,
    input       [15:0]  data_read
);

wire [3:0] req, ok;
wire [3:0] rom_ok;
wire [3:0] slot_sel;
wire [3:0] slot_grant;
wire [SDRAMW-1:0] slot0_addr_req, slot1_addr_req, slot2_addr_req, slot3_addr_req;
wire slot0_miss_cs, slot1_miss_cs, slot2_miss_cs, slot3_miss_cs;
wire [SLOT0_DW-1:0] slot0_rom_dout;
wire [SLOT1_DW-1:0] slot1_rom_dout;
wire [SLOT2_DW-1:0] slot2_rom_dout;
wire [SLOT3_DW-1:0] slot3_rom_dout;

assign slot0_ok = ok[0];
assign slot1_ok = ok[1];
assign slot2_ok = ok[2];
assign slot3_ok = ok[3];

wire [SDRAMW-1:0] offset0 = SLOT0_OFFSET,
                  offset1 = SLOT1_OFFSET,
                  offset2 = SLOT2_OFFSET,
                  offset3 = SLOT3_OFFSET;

raizing_rom_slot_dcache #(.AW(SLOT0_AW), .DW(SLOT0_DW), .CACHE_BITS(DM_CACHE_BITS)) u_cache0(
    .rst       ( rst            ),
    .clk       ( clk            ),
    .addr      ( slot0_addr     ),
    .cs        ( slot0_cs       ),
    .ok        ( ok[0]          ),
    .dout      ( slot0_dout     ),
    .miss_cs   ( slot0_miss_cs  ),
    .miss_ok   ( rom_ok[0]      ),
    .miss_dout ( slot0_rom_dout )
);

raizing_rom_slot_dcache #(.AW(SLOT1_AW), .DW(SLOT1_DW), .CACHE_BITS(DM_CACHE_BITS)) u_cache1(
    .rst       ( rst            ),
    .clk       ( clk            ),
    .addr      ( slot1_addr     ),
    .cs        ( slot1_cs       ),
    .ok        ( ok[1]          ),
    .dout      ( slot1_dout     ),
    .miss_cs   ( slot1_miss_cs  ),
    .miss_ok   ( rom_ok[1]      ),
    .miss_dout ( slot1_rom_dout )
);

raizing_rom_slot_dcache #(.AW(SLOT2_AW), .DW(SLOT2_DW), .CACHE_BITS(DM_CACHE_BITS)) u_cache2(
    .rst       ( rst            ),
    .clk       ( clk            ),
    .addr      ( slot2_addr     ),
    .cs        ( slot2_cs       ),
    .ok        ( ok[2]          ),
    .dout      ( slot2_dout     ),
    .miss_cs   ( slot2_miss_cs  ),
    .miss_ok   ( rom_ok[2]      ),
    .miss_dout ( slot2_rom_dout )
);

raizing_rom_slot_dcache #(.AW(SLOT3_AW), .DW(SLOT3_DW), .CACHE_BITS(DM_CACHE_BITS)) u_cache3(
    .rst       ( rst            ),
    .clk       ( clk            ),
    .addr      ( slot3_addr     ),
    .cs        ( slot3_cs       ),
    .ok        ( ok[3]          ),
    .dout      ( slot3_dout     ),
    .miss_cs   ( slot3_miss_cs  ),
    .miss_ok   ( rom_ok[3]      ),
    .miss_dout ( slot3_rom_dout )
);

raizing_romrq_native #(.SDRAMW(SDRAMW),.AW(SLOT0_AW),.DW(SLOT0_DW),
    .LATCH(SLOT0_LATCH),.DOUBLE(SLOT0_DOUBLE),.OKLATCH(SLOT0_OKLATCH),
    .CACHE_SIZE(CACHE0_SIZE),.LINE_DW(LINE_DW),
    .LINE_CACHE_ENTRIES(LINE_CACHE0_ENTRIES))
u_slot0(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'd0                   ),
    .offset    ( offset0                ),
    .addr      ( slot0_addr             ),
    .addr_ok   ( slot0_miss_cs          ),
    .sdram_addr( slot0_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dst       ( data_dst               ),
    .dout      ( slot0_rom_dout         ),
    .req       ( req[0]                 ),
    .data_ok   ( rom_ok[0]              ),
    .grant     ( slot_grant[0]          ),
    .we        ( slot_sel[0]            )
);

raizing_romrq_native #(.SDRAMW(SDRAMW),.AW(SLOT1_AW),.DW(SLOT1_DW),
    .LATCH(SLOT1_LATCH),.DOUBLE(SLOT1_DOUBLE),.OKLATCH(SLOT1_OKLATCH),
    .CACHE_SIZE(CACHE1_SIZE),.LINE_DW(LINE_DW),
    .LINE_CACHE_ENTRIES(LINE_CACHE1_ENTRIES))
u_slot1(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'd0                   ),
    .offset    ( offset1                ),
    .addr      ( slot1_addr             ),
    .addr_ok   ( slot1_miss_cs          ),
    .sdram_addr( slot1_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dst       ( data_dst               ),
    .dout      ( slot1_rom_dout         ),
    .req       ( req[1]                 ),
    .data_ok   ( rom_ok[1]              ),
    .grant     ( slot_grant[1]          ),
    .we        ( slot_sel[1]            )
);

raizing_romrq_native #(.SDRAMW(SDRAMW),.AW(SLOT2_AW),.DW(SLOT2_DW),
    .LATCH(SLOT2_LATCH),.DOUBLE(SLOT2_DOUBLE),.OKLATCH(SLOT2_OKLATCH),
    .CACHE_SIZE(CACHE2_SIZE),.LINE_DW(LINE_DW),
    .LINE_CACHE_ENTRIES(LINE_CACHE2_ENTRIES))
u_slot2(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'd0                   ),
    .offset    ( offset2                ),
    .addr      ( slot2_addr             ),
    .addr_ok   ( slot2_miss_cs          ),
    .sdram_addr( slot2_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dst       ( data_dst               ),
    .dout      ( slot2_rom_dout         ),
    .req       ( req[2]                 ),
    .data_ok   ( rom_ok[2]              ),
    .grant     ( slot_grant[2]          ),
    .we        ( slot_sel[2]            )
);

raizing_romrq_native #(.SDRAMW(SDRAMW),.AW(SLOT3_AW),.DW(SLOT3_DW),
    .LATCH(SLOT3_LATCH),.DOUBLE(SLOT3_DOUBLE),.OKLATCH(SLOT3_OKLATCH),
    .CACHE_SIZE(CACHE3_SIZE),.LINE_DW(LINE_DW),
    .LINE_CACHE_ENTRIES(LINE_CACHE3_ENTRIES))
u_slot3(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'd0                   ),
    .offset    ( offset3                ),
    .addr      ( slot3_addr             ),
    .addr_ok   ( slot3_miss_cs          ),
    .sdram_addr( slot3_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dst       ( data_dst               ),
    .dout      ( slot3_rom_dout         ),
    .req       ( req[3]                 ),
    .data_ok   ( rom_ok[3]              ),
    .grant     ( slot_grant[3]          ),
    .we        ( slot_sel[3]            )
);

raizing_ramslot_ctrl_rr #(
    .SDRAMW         ( SDRAMW        )
)u_ctrl(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .req            ( req           ),
    .slot_addr_req  ({  slot3_addr_req, slot2_addr_req,
                        slot1_addr_req, slot0_addr_req }),
    .slot_sel       ( slot_sel      ),
    .slot_grant     ( slot_grant    ),
    .sdram_ack      ( sdram_ack     ),
    .sdram_rd       ( sdram_rd      ),
    .sdram_addr     ( sdram_addr    ),
    .data_rdy       ( data_rdy      )
);

endmodule

module raizing_rom_1slot #(parameter
    SDRAMW       = 22,
    SLOT0_DW     = 8,
    SLOT0_AW     = 8,
    SLOT0_LATCH  = 0,
    SLOT0_DOUBLE = 0,
    CACHE0_SIZE  = 0,
    LINE_DW      = `RAIZING_DEFAULT_ROM_LINE_DW,
    LINE_CACHE0_ENTRIES = 2,
/* verilator lint_off WIDTH */
    parameter [SDRAMW-1:0] SLOT0_OFFSET = {SDRAMW{1'b0}},
/* verilator lint_on WIDTH */
    SLOT0_OKLATCH= 1
)(
    input               rst,
    input               clk,

    input  [SLOT0_AW-1:0] slot0_addr,
    output [SLOT0_DW-1:0] slot0_dout,
    input               slot0_cs,
    output              slot0_ok,

    input               sdram_ack,
    output reg          sdram_rd,
    output reg [SDRAMW-1:0] sdram_addr,
    input               data_dst,
    input               data_rdy,
    input       [15:0]  data_read
);

wire req;
wire [SDRAMW-1:0] slot_addr_req;
reg slot_sel;
wire slot_grant = !sdram_rd && !slot_sel && req;

raizing_romrq_native #(
    .SDRAMW       (SDRAMW),
    .AW           (SLOT0_AW),
    .DW           (SLOT0_DW),
    .LATCH        (SLOT0_LATCH),
    .DOUBLE       (SLOT0_DOUBLE),
    .OKLATCH      (SLOT0_OKLATCH),
    .CACHE_SIZE   (CACHE0_SIZE),
    .LINE_DW      (LINE_DW),
    .LINE_CACHE_ENTRIES(LINE_CACHE0_ENTRIES)
) u_slot0(
    .rst          (rst),
    .clk          (clk),
    .clr          (1'b0),
    .offset       (SLOT0_OFFSET),
    .addr         (slot0_addr),
    .addr_ok      (slot0_cs),
    .sdram_addr   (slot_addr_req),
    .din          (data_read),
    .din_ok       (data_rdy),
    .dst          (data_dst),
    .dout         (slot0_dout),
    .req          (req),
    .data_ok      (slot0_ok),
    .grant        (slot_grant),
    .we           (slot_sel)
);

always @(posedge clk) begin
    if(rst) begin
        sdram_rd <= 1'b0;
        sdram_addr <= {SDRAMW{1'b0}};
        slot_sel <= 1'b0;
    end else begin
        if(sdram_ack) begin
            sdram_rd <= 1'b0;
        end

        if(data_rdy)
            slot_sel <= 1'b0;

        if(slot_grant) begin
            sdram_addr <= slot_addr_req;
            sdram_rd <= 1'b1;
            slot_sel <= 1'b1;
        end
    end
end

endmodule

module raizing_rom_2slots #(parameter
    SDRAMW   = 22,
    SLOT0_DW = 8, SLOT1_DW = 8,
    SLOT0_AW = 8, SLOT1_AW = 8,

    SLOT0_LATCH  = 0,
    SLOT1_LATCH  = 0,

    SLOT0_DOUBLE = 0,
    SLOT1_DOUBLE = 0,

    SLOT0_OKLATCH= 1,
    SLOT1_OKLATCH= 1,

    CACHE0_SIZE = 0,
    CACHE1_SIZE = 0,
    LINE_DW = `RAIZING_DEFAULT_ROM_LINE_DW,
    LINE_CACHE0_ENTRIES = 2,
    LINE_CACHE1_ENTRIES = 2,
/* verilator lint_off WIDTH */
    parameter [SDRAMW-1:0] SLOT0_OFFSET = {SDRAMW{1'b0}},
    parameter [SDRAMW-1:0] SLOT1_OFFSET = {SDRAMW{1'b0}}
/* verilator lint_on WIDTH */
)(
    input               rst,
    input               clk,

    input  [SLOT0_AW-1:0] slot0_addr,
    input  [SLOT1_AW-1:0] slot1_addr,

    output [SLOT0_DW-1:0] slot0_dout,
    output [SLOT1_DW-1:0] slot1_dout,

    input               slot0_cs,
    input               slot1_cs,

    output              slot0_ok,
    output              slot1_ok,

    input               sdram_ack,
    output reg          sdram_rd,
    output reg [SDRAMW-1:0] sdram_addr,
    input               data_dst,
    input               data_rdy,
    input       [15:0]  data_read
);

wire [1:0] req;
wire [1:0] slot_sel;
wire [1:0] slot_grant;
wire [SDRAMW-1:0] slot0_addr_req, slot1_addr_req;
reg  [1:0] slot_sel_r;

assign slot_sel = slot_sel_r;

raizing_romrq_native #(.SDRAMW(SDRAMW),.AW(SLOT0_AW),.DW(SLOT0_DW),
    .LATCH(SLOT0_LATCH),.DOUBLE(SLOT0_DOUBLE),.OKLATCH(SLOT0_OKLATCH),
    .CACHE_SIZE(CACHE0_SIZE),.LINE_DW(LINE_DW),
    .LINE_CACHE_ENTRIES(LINE_CACHE0_ENTRIES))
u_slot0(
    .rst       (rst),
    .clk       (clk),
    .clr       (1'b0),
    .offset    (SLOT0_OFFSET),
    .addr      (slot0_addr),
    .addr_ok   (slot0_cs),
    .sdram_addr(slot0_addr_req),
    .din       (data_read),
    .din_ok    (data_rdy),
    .dst       (data_dst),
    .dout      (slot0_dout),
    .req       (req[0]),
    .data_ok   (slot0_ok),
    .grant     (slot_grant[0]),
    .we        (slot_sel[0])
);

raizing_romrq_native #(.SDRAMW(SDRAMW),.AW(SLOT1_AW),.DW(SLOT1_DW),
    .LATCH(SLOT1_LATCH),.DOUBLE(SLOT1_DOUBLE),.OKLATCH(SLOT1_OKLATCH),
    .CACHE_SIZE(CACHE1_SIZE),.LINE_DW(LINE_DW),
    .LINE_CACHE_ENTRIES(LINE_CACHE1_ENTRIES))
u_slot1(
    .rst       (rst),
    .clk       (clk),
    .clr       (1'b0),
    .offset    (SLOT1_OFFSET),
    .addr      (slot1_addr),
    .addr_ok   (slot1_cs),
    .sdram_addr(slot1_addr_req),
    .din       (data_read),
    .din_ok    (data_rdy),
    .dst       (data_dst),
    .dout      (slot1_dout),
    .req       (req[1]),
    .data_ok   (slot1_ok),
    .grant     (slot_grant[1]),
    .we        (slot_sel[1])
);

wire [1:0] active = req & ~slot_sel_r;
wire grant_slot1 = !active[0] && active[1];
wire grant_any = active[0] || active[1];
wire grant_now = !sdram_rd && slot_sel_r == 2'b00 && grant_any;
assign slot_grant = grant_now ? (grant_slot1 ? 2'b10 : 2'b01) : 2'b00;

always @(posedge clk) begin
    if(rst) begin
        sdram_rd <= 1'b0;
        sdram_addr <= {SDRAMW{1'b0}};
        slot_sel_r <= 2'b00;
    end else begin
        if(sdram_ack) begin
            sdram_rd <= 1'b0;
        end

        if(data_rdy)
            slot_sel_r <= 2'b00;

        if(grant_now) begin
            sdram_addr <= grant_slot1 ? slot1_addr_req : slot0_addr_req;
            sdram_rd <= 1'b1;
            slot_sel_r <= grant_slot1 ? 2'b10 : 2'b01;
        end
    end
end

endmodule

module raizing_romrq_native #(parameter
    SDRAMW  = 22,
    AW      = 18,
    DW      = 8,
    LINE_DW = `RAIZING_DEFAULT_ROM_LINE_DW,
    LINE_CACHE_ENTRIES = 2,
    CACHE_SIZE = 0,
    OKLATCH = 1,
    DOUBLE  = 0,
    LATCH   = 0
)(
    input               rst,
    input               clk,

    input               clr,
    input [SDRAMW-1:0]  offset,

    input [15:0]        din,
    input               din_ok,
    input               dst,
    input               we,
    output              req,
    output [SDRAMW-1:0] sdram_addr,
    input               grant,

    input [AW-1:0]      addr,
    input               addr_ok,
    output              data_ok,
    output [DW-1:0]     dout
);

initial begin
    if(LINE_DW != 32 && LINE_DW != 64)
        $error("raizing_romrq_native LINE_DW must be 32 or 64");
    if(LINE_CACHE_ENTRIES < 2)
        $error("raizing_romrq_native LINE_CACHE_ENTRIES must be at least 2");
end

generate
if(LINE_DW == 64) begin : g_line64
    wire [AW-1:0] addr_req =
        (DW == 8) ? {addr[AW-1:3], 3'b000} :
                    {addr[AW-1:2], 2'b00};
    wire [SDRAMW-1:0] addr_req_ext = {{SDRAMW-AW{1'b0}}, addr_req};
    assign sdram_addr = offset + ((DW == 8) ? (addr_req_ext >> 1) : addr_req_ext);

    reg [AW-1:0] cached_addr [0:LINE_CACHE_ENTRIES-1];
    reg [63:0] cached_data [0:LINE_CACHE_ENTRIES-1];
    reg [LINE_CACHE_ENTRIES-1:0] valid = {LINE_CACHE_ENTRIES{1'b0}};
    wire [LINE_CACHE_ENTRIES-1:0] hit_vec;

    genvar hit_idx;
    for(hit_idx = 0; hit_idx < LINE_CACHE_ENTRIES; hit_idx = hit_idx + 1) begin : g_hit
        assign hit_vec[hit_idx] = valid[hit_idx] && cached_addr[hit_idx] == addr_req;
    end

    wire hit = |hit_vec;
    assign req = addr_ok && !hit;

    reg [63:0] data_mux;
    integer mux_idx;
    always @(*) begin
        data_mux = 64'd0;
        for(mux_idx = LINE_CACHE_ENTRIES-1; mux_idx >= 0; mux_idx = mux_idx - 1)
            if(hit_vec[mux_idx])
                data_mux = cached_data[mux_idx];
    end

    reg [DW-1:0] preout;

    if(DW == 8) begin : g_dout8
        always @(*) begin
            case(addr[2:0])
                3'd0: preout = data_mux[7:0];
                3'd1: preout = data_mux[15:8];
                3'd2: preout = data_mux[23:16];
                3'd3: preout = data_mux[31:24];
                3'd4: preout = data_mux[39:32];
                3'd5: preout = data_mux[47:40];
                3'd6: preout = data_mux[55:48];
                default: preout = data_mux[63:56];
            endcase
        end
    end else if(DW == 16) begin : g_dout16
        always @(*) begin
            case(addr[1:0])
                2'd0: preout = data_mux[15:0];
                2'd1: preout = data_mux[31:16];
                2'd2: preout = data_mux[47:32];
                default: preout = data_mux[63:48];
            endcase
        end
    end else begin : g_dout32
        always @(*) begin
            preout = addr[1] ? data_mux[63:32] : data_mux[31:0];
        end
    end

    reg [63:0] fill_data = 64'd0;
    reg [AW-1:0] fill_addr = {AW{1'b0}};
    reg cap_active = 1'b0;
    reg [2:0] cap_words = 3'd0;
    reg [63:0] fill_with_din;
    integer cache_idx;

    always @(*) begin
        fill_with_din = fill_data;
        if(we && dst)
            fill_with_din[15:0] = din;
        else if(we && cap_active) begin
            case(cap_words)
                3'd1: fill_with_din[31:16] = din;
                3'd2: fill_with_din[47:32] = din;
                3'd3: fill_with_din[63:48] = din;
                default: ;
            endcase
        end
    end

    always @(posedge clk) begin
        if(rst || clr) begin
            valid <= {LINE_CACHE_ENTRIES{1'b0}};
            for(cache_idx = 0; cache_idx < LINE_CACHE_ENTRIES; cache_idx = cache_idx + 1) begin
                cached_addr[cache_idx] <= {AW{1'b0}};
                cached_data[cache_idx] <= 64'd0;
            end
            fill_data <= 64'd0;
            fill_addr <= {AW{1'b0}};
            cap_active <= 1'b0;
            cap_words <= 3'd0;
        end else begin
            if(grant)
                fill_addr <= addr_req;

            if(we && dst) begin
                fill_data <= {48'd0, din};
                cap_active <= 1'b1;
                cap_words <= 3'd1;
            end else if(we && cap_active && cap_words < 3'd4) begin
                case(cap_words)
                    3'd1: fill_data[31:16] <= din;
                    3'd2: fill_data[47:32] <= din;
                    3'd3: fill_data[63:48] <= din;
                    default: ;
                endcase
                cap_words <= cap_words + 3'd1;
            end

            if(we && din_ok) begin
                for(cache_idx = LINE_CACHE_ENTRIES-1; cache_idx > 0; cache_idx = cache_idx - 1) begin
                    cached_addr[cache_idx] <= cached_addr[cache_idx-1];
                    cached_data[cache_idx] <= cached_data[cache_idx-1];
                    valid[cache_idx] <= valid[cache_idx-1];
                end
                cached_addr[0] <= fill_addr;
                cached_data[0] <= fill_with_din;
                valid[0] <= 1'b1;
                cap_active <= 1'b0;
                cap_words <= 3'd0;
            end
        end
    end

    if(LATCH != 0 || OKLATCH != 0) begin : g_registered_out
        reg data_ok_r = 1'b0;
        reg [DW-1:0] dout_r = {DW{1'b0}};
        reg [AW-1:0] out_addr = {AW{1'b0}};

        always @(posedge clk) begin
            if(rst) begin
                data_ok_r <= 1'b0;
                dout_r <= {DW{1'b0}};
                out_addr <= {AW{1'b0}};
            end else begin
                data_ok_r <= addr_ok && hit;
                dout_r <= preout;
                out_addr <= addr;
            end
        end

        assign data_ok = data_ok_r && addr_ok && addr == out_addr;
        assign dout = dout_r;
    end else begin : g_comb_out
        assign data_ok = addr_ok && hit;
        assign dout = preout;
    end
end else begin : g_line32
    wire [AW-1:0] addr_req =
        (DW == 8) ? {addr[AW-1:2], 2'b00} :
                    {addr[AW-1:1], 1'b0};

    wire [SDRAMW-1:0] addr_req_ext = {{SDRAMW-AW{1'b0}}, addr_req};
    assign sdram_addr = offset + ((DW == 8) ? (addr_req_ext >> 1) : addr_req_ext);

    reg [AW-1:0] cached_addr0 = {AW{1'b0}};
    reg [AW-1:0] cached_addr1 = {AW{1'b0}};
    reg [31:0] cached_data0 = 32'd0;
    reg [31:0] cached_data1 = 32'd0;
    reg [1:0] valid = 2'b00;

    wire hit0 = valid[0] && cached_addr0 == addr_req;
    wire hit1 = valid[1] && cached_addr1 == addr_req;
    wire hit = hit0 || hit1;
    assign req = addr_ok && !hit;

    wire [31:0] data_mux = hit0 ? cached_data0 : cached_data1;
    reg [DW-1:0] preout;

    if(DW == 8) begin : g_dout8
        always @(*) begin
            case(addr[1:0])
                2'd0: preout = data_mux[7:0];
                2'd1: preout = data_mux[15:8];
                2'd2: preout = data_mux[23:16];
                default: preout = data_mux[31:24];
            endcase
        end
    end else if(DW == 16) begin : g_dout16
        always @(*) begin
            preout = addr[0] ? data_mux[31:16] : data_mux[15:0];
        end
    end else begin : g_dout32
        always @(*) begin
            preout = data_mux[DW-1:0];
        end
    end

    reg [31:0] fill_data = 32'd0;
    reg [AW-1:0] fill_addr = {AW{1'b0}};
    reg cap_active = 1'b0;
    reg cap_second = 1'b0;

    wire [31:0] fill_with_din =
        (we && dst) ? {16'd0, din} :
        (we && cap_active && !cap_second) ? {din, fill_data[15:0]} :
        fill_data;

    always @(posedge clk) begin
        if(rst || clr) begin
            valid <= 2'b00;
            cached_addr0 <= {AW{1'b0}};
            cached_addr1 <= {AW{1'b0}};
            cached_data0 <= 32'd0;
            cached_data1 <= 32'd0;
            fill_data <= 32'd0;
            fill_addr <= {AW{1'b0}};
            cap_active <= 1'b0;
            cap_second <= 1'b0;
        end else begin
            if(grant)
                fill_addr <= addr_req;

            if(we && dst) begin
                fill_data <= {16'd0, din};
                cap_active <= 1'b1;
                cap_second <= 1'b0;
            end else if(we && cap_active && !cap_second) begin
                fill_data[31:16] <= din;
                cap_second <= 1'b1;
            end

            if(we && din_ok) begin
                cached_addr1 <= cached_addr0;
                cached_data1 <= cached_data0;
                cached_addr0 <= fill_addr;
                cached_data0 <= fill_with_din;
                valid <= {valid[0], 1'b1};
                cap_active <= 1'b0;
                cap_second <= 1'b0;
            end
        end
    end

    if(LATCH != 0 || OKLATCH != 0) begin : g_registered_out
        reg data_ok_r = 1'b0;
        reg [DW-1:0] dout_r = {DW{1'b0}};
        reg [AW-1:0] out_addr = {AW{1'b0}};

        always @(posedge clk) begin
            if(rst) begin
                data_ok_r <= 1'b0;
                dout_r <= {DW{1'b0}};
                out_addr <= {AW{1'b0}};
            end else begin
                data_ok_r <= addr_ok && hit;
                dout_r <= preout;
                out_addr <= addr;
            end
        end

        assign data_ok = data_ok_r && addr_ok && addr == out_addr;
        assign dout = dout_r;
    end else begin : g_comb_out
        assign data_ok = addr_ok && hit;
        assign dout = preout;
    end
end
endgenerate

endmodule

`undef RAIZING_DEFAULT_ROM_LINE_DW

module raizing_rom_slot_dcache #(parameter
    AW = 22,
    DW = 32,
    CACHE_BITS = 0
)(
    input              rst,
    input              clk,
    input      [AW-1:0] addr,
    input              cs,
    output             ok,
    output     [DW-1:0] dout,
    output             miss_cs,
    input              miss_ok,
    input      [DW-1:0] miss_dout
);

generate
    if(CACHE_BITS == 0) begin : no_cache
        assign miss_cs = cs;
        assign ok      = miss_ok;
        assign dout    = miss_dout;
    end else begin : dcache
        localparam LINES = 1 << CACHE_BITS;
        localparam TAGW  = AW - CACHE_BITS;

        wire [CACHE_BITS-1:0] index = addr[CACHE_BITS-1:0];
        wire [TAGW-1:0]       tag   = addr[AW-1:CACHE_BITS];

        reg [TAGW-1:0] tag_mem  [0:LINES-1];
        reg [DW-1:0]   data_mem [0:LINES-1];
        reg [LINES-1:0] valid = {LINES{1'b0}};

        reg [AW-1:0] fill_addr = {AW{1'b0}};
        reg          fill_pending = 1'b0;

        wire hit = cs && valid[index] && tag_mem[index] == tag;
        wire [AW-1:0] fill_sel_addr = fill_pending ? fill_addr : addr;
        wire [CACHE_BITS-1:0] fill_index = fill_sel_addr[CACHE_BITS-1:0];

        assign miss_cs = cs && !hit;
        assign ok      = cs && (hit || miss_ok);
        assign dout    = hit ? data_mem[index] : miss_dout;

        always @(posedge clk) begin
            if(rst) begin
                valid <= {LINES{1'b0}};
                fill_pending <= 1'b0;
                fill_addr <= {AW{1'b0}};
            end else begin
                if(miss_cs && !miss_ok && !fill_pending) begin
                    fill_addr <= addr;
                    fill_pending <= 1'b1;
                end

                if(miss_ok && (fill_pending || miss_cs)) begin
                    tag_mem[fill_index] <= fill_sel_addr[AW-1:CACHE_BITS];
                    data_mem[fill_index] <= miss_dout;
                    valid[fill_index] <= 1'b1;
                    fill_pending <= 1'b0;
                end
            end
        end
    end
endgenerate

endmodule

module raizing_ramslot_ctrl_rr #(parameter
    SDRAMW = 22
)(
    input               rst,
    input               clk,
    input       [3:0]   req,
    input [4*SDRAMW-1:0] slot_addr_req,
    output reg  [3:0]   slot_sel,
    output      [3:0]   slot_grant,

    input               sdram_ack,
    output reg          sdram_rd,
    output reg [SDRAMW-1:0] sdram_addr,
    input               data_rdy
);

wire [3:0] active = ~slot_sel & req;
reg  [3:0] acthot;
reg  [1:0] grant_idx;
reg        grant_any;
reg  [1:0] last_grant;

always @* begin
    acthot    = 4'd0;
    grant_idx = 2'd0;
    grant_any = 1'b0;

    case(last_grant)
        2'd0: begin
            if(active[1]) begin grant_idx = 2'd1; grant_any = 1'b1; end
            else if(active[2]) begin grant_idx = 2'd2; grant_any = 1'b1; end
            else if(active[3]) begin grant_idx = 2'd3; grant_any = 1'b1; end
            else if(active[0]) begin grant_idx = 2'd0; grant_any = 1'b1; end
        end
        2'd1: begin
            if(active[2]) begin grant_idx = 2'd2; grant_any = 1'b1; end
            else if(active[3]) begin grant_idx = 2'd3; grant_any = 1'b1; end
            else if(active[0]) begin grant_idx = 2'd0; grant_any = 1'b1; end
            else if(active[1]) begin grant_idx = 2'd1; grant_any = 1'b1; end
        end
        2'd2: begin
            if(active[3]) begin grant_idx = 2'd3; grant_any = 1'b1; end
            else if(active[0]) begin grant_idx = 2'd0; grant_any = 1'b1; end
            else if(active[1]) begin grant_idx = 2'd1; grant_any = 1'b1; end
            else if(active[2]) begin grant_idx = 2'd2; grant_any = 1'b1; end
        end
        2'd3: begin
            if(active[0]) begin grant_idx = 2'd0; grant_any = 1'b1; end
            else if(active[1]) begin grant_idx = 2'd1; grant_any = 1'b1; end
            else if(active[2]) begin grant_idx = 2'd2; grant_any = 1'b1; end
            else if(active[3]) begin grant_idx = 2'd3; grant_any = 1'b1; end
        end
    endcase

    if(grant_any)
        acthot[grant_idx] = 1'b1;
end

assign slot_grant = ((slot_sel == 4'd0 || data_rdy) && grant_any) ? acthot : 4'd0;

always @(posedge clk) begin
    if(rst) begin
        sdram_addr <= 0;
        sdram_rd   <= 0;
        slot_sel   <= 0;
        last_grant <= 2'd3;
    end else begin
        if(sdram_ack)
            sdram_rd <= 1'b0;

        if(slot_sel == 4'd0 || data_rdy) begin
            slot_sel <= 4'd0;
            if(grant_any) begin
                case(grant_idx)
                    2'd0: sdram_addr <= slot_addr_req[0*SDRAMW +: SDRAMW];
                    2'd1: sdram_addr <= slot_addr_req[1*SDRAMW +: SDRAMW];
                    2'd2: sdram_addr <= slot_addr_req[2*SDRAMW +: SDRAMW];
                    2'd3: sdram_addr <= slot_addr_req[3*SDRAMW +: SDRAMW];
                endcase
                sdram_rd   <= 1'b1;
                slot_sel   <= acthot;
                last_grant <= grant_idx;
            end
        end
    end
end

endmodule
