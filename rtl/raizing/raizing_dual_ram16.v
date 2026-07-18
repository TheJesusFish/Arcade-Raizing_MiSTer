// This file is a Codex-assisted refactoring and update
// based on the original work of Pramod Somashekar (pram0d)

module raizing_dual_ram16 #(
    parameter AW = 10,
    parameter SIMFILE = "",
    parameter SIMHEXFILE_LO = "",
    parameter SIMHEXFILE_HI = "",
    parameter ENDIAN = 0,
    parameter VERBOSE = 0,
    parameter VERBOSE_OFFSET = 0,
    parameter SS_ENABLE = 0
)(
    input          clk0,
    input  [15:0] data0,
    input  [AW:1] addr0,
    input  [1:0]  we0,
    output [15:0] q0,

    input          clk1,
    input  [15:0] data1,
    input  [AW:1] addr1,
    input  [1:0]  we1,
    output [15:0] q1,

    input          ss_active,
    input  [15:0] ss_data,
    input  [AW:1] ss_addr,
    input  [1:0]  ss_we,
    output [15:0] ss_q
);

    localparam LO_BYTE = ENDIAN ? 1 : 0;
    localparam HI_BYTE = ENDIAN ? 0 : 1;

    raizing_dual_ram #(
        .DW(8),
        .AW(AW),
        .SIMFILE(SIMFILE),
        .SIMHEXFILE(SIMHEXFILE_LO),
        .SIMFILE_BYTE(LO_BYTE),
        .FULL_DW(16),
        .SS_ENABLE(SS_ENABLE)
    ) u_lo (
        .clk0(clk0),
        .data0(data0[7:0]),
        .addr0(addr0),
        .we0(we0[0]),
        .q0(q0[7:0]),

        .clk1(clk1),
        .data1(data1[7:0]),
        .addr1(addr1),
        .we1(we1[0]),
        .q1(q1[7:0]),
        .ss_active(ss_active),
        .ss_data(ss_data[7:0]),
        .ss_addr(ss_addr),
        .ss_we(ss_we[0]),
        .ss_q(ss_q[7:0])
    );

    raizing_dual_ram #(
        .DW(8),
        .AW(AW),
        .SIMFILE(SIMFILE),
        .SIMHEXFILE(SIMHEXFILE_HI),
        .SIMFILE_BYTE(HI_BYTE),
        .FULL_DW(16),
        .SS_ENABLE(SS_ENABLE)
    ) u_hi (
        .clk0(clk0),
        .data0(data0[15:8]),
        .addr0(addr0),
        .we0(we0[1]),
        .q0(q0[15:8]),

        .clk1(clk1),
        .data1(data1[15:8]),
        .addr1(addr1),
        .we1(we1[1]),
        .q1(q1[15:8]),
        .ss_active(ss_active),
        .ss_data(ss_data[15:8]),
        .ss_addr(ss_addr),
        .ss_we(ss_we[1]),
        .ss_q(ss_q[15:8])
    );

`ifdef SIMULATION
    generate
        if(VERBOSE) begin : gen_verbose
            always @(posedge clk0) begin
                if(we0[0]) $display("%m %0X=%X", {addr0, 1'b0} + VERBOSE_OFFSET, data0[7:0]);
                if(we0[1]) $display("%m %0X=%X", {addr0, 1'b1} + VERBOSE_OFFSET, data0[15:8]);
            end
        end
    endgenerate
`endif

endmodule
