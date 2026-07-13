// This file is a Codex-assisted refactoring and update
// based on the original work of Pramod Somashekar (pram0d)

// Read-clear object/line buffer backed by local dual-port RAM.
module raizing_obj_buffer #(
    parameter DW          = 8,
    parameter AW          = 9,
    parameter ALPHAW      = 4,
    parameter ALPHA       = 32'hF,
    parameter BLANK       = ALPHA,
    parameter BLANK_DLY   = 2,
    parameter FLIP_OFFSET = 0,
    parameter SW          = 1,
    parameter SHADOW_PEN  = ALPHA,
    parameter SHADOW      = 0,
    parameter KEEP_OLD    = 0
)(
    input           clk,
    input           LHBL,
    input           flip,
    input  [DW-1:0] wr_data,
    input  [AW-1:0] wr_addr,
    input           we,
    input  [AW-1:0] rd_addr,
    input           rd,
    output reg [DW-1:0] rd_data
);

localparam EW = SHADOW == 1 ? DW-SW : DW;

reg line = 1'b0;
reg last_LHBL = 1'b0;
reg new_we;
reg [BLANK_DLY-1:0] dly = {BLANK_DLY{1'b0}};

wire delete_we = dly[0];
wire [EW-1:0] blank_data = BLANK[EW-1:0];
wire [DW-1:0] dump_data;
wire [EW-1:0] old;
wire shade = wr_data[DW-1-:SW] != 0;
wire is_opaque = wr_data[ALPHAW-1:0] != ALPHA[ALPHAW-1:0] && we;
wire was_blank = old[ALPHAW-1:0] == ALPHA[ALPHAW-1:0];
wire is_just_a_shadow = wr_data[ALPHAW-1:0] == SHADOW_PEN[ALPHAW-1:0];
wire [AW-1:0] wr_af = flip ? ~wr_addr + FLIP_OFFSET[AW-1:0] : wr_addr;

always @* begin
    new_we = is_opaque;
    if((KEEP_OLD == 1 && !was_blank) || (SHADOW == 1 && is_just_a_shadow && shade))
        new_we = 1'b0;
end

always @(posedge clk) begin
    last_LHBL <= LHBL;
    if(!LHBL && last_LHBL)
        line <= ~line;
end

always @(posedge clk) begin
    if(rd)
        dly <= {1'b1, {BLANK_DLY-1{1'b0}}};
    else
        dly <= dly >> 1;

    if(delete_we)
        rd_data <= dump_data;
end

raizing_dual_ram #(.AW(AW+1), .DW(EW)) u_line(
    .clk0  (clk),
    .clk1  (clk),
    .data0 (wr_data[EW-1:0]),
    .addr0 ({line, wr_af}),
    .we0   (new_we),
    .q0    (old),
    .data1 (blank_data),
    .addr1 ({~line, rd_addr}),
    .we1   (delete_we),
    .q1    (dump_data[EW-1:0])
);

generate
    if(SHADOW == 1) begin : gen_shadow
        wire sh0_wemx, sh1_wemx, sh0_delmx, sh1_delmx;
        wire erase_shade, add_shade;
        reg [AW-1:0] sh_wa;
        wire [AW-1:0] sh0_rdmx, sh1_rdmx;
        wire [SW-1:0] shdout0, shdout1;
        reg [SW-1:0] shdin;
        reg sh_we;

        assign sh0_rdmx = line ? wr_af : rd_addr;
        assign sh1_rdmx = ~line ? wr_af : rd_addr;
        assign sh0_wemx = line & sh_we;
        assign sh1_wemx = ~line & sh_we;
        assign sh0_delmx = ~line & delete_we;
        assign sh1_delmx = line & delete_we;
        assign erase_shade = !shade & new_we;
        assign add_shade = shade & we && is_just_a_shadow;
        assign dump_data[DW-1-:SW] = ~line ? shdout0 : shdout1;

        always @(posedge clk) begin
            shdin <= wr_data[DW-1-:SW];
            sh_wa <= wr_af;
            sh_we <= add_shade || erase_shade;
        end

        raizing_dual_ram #(.AW(AW), .DW(SW)) u_shadow0(
            .clk0  (clk),
            .clk1  (clk),
            .data0 (shdin),
            .addr0 (sh_wa),
            .we0   (sh0_wemx),
            .q0    (),
            .data1 ({SW{1'b0}}),
            .addr1 (sh0_rdmx),
            .we1   (sh0_delmx),
            .q1    (shdout0)
        );

        raizing_dual_ram #(.AW(AW), .DW(SW)) u_shadow1(
            .clk0  (clk),
            .clk1  (clk),
            .data0 (shdin),
            .addr0 (sh_wa),
            .we0   (sh1_wemx),
            .q0    (),
            .data1 ({SW{1'b0}}),
            .addr1 (sh1_rdmx),
            .we1   (sh1_delmx),
            .q1    (shdout1)
        );
    end
endgenerate

endmodule
