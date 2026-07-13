// This file is a Codex-assisted refactoring and update
// based on the original work of Pramod Somashekar (pram0d)

module raizing_z80wait #(
    parameter DEVCNT = 2,
    parameter RECOVERY = 1
)(
    input                  rst_n,
    input                  clk,
    input                  cen_in,
    output reg             cen_out,
    output                 gate,
    input                  mreq_n,
    input                  iorq_n,
    input                  busak_n,
    input  [DEVCNT-1:0]    dev_busy,
    input                  rom_cs,
    input                  rom_ok
);

    reg last_rom_cs;
    reg locked;
    reg started;
    reg cen_l;
    reg [3:0] miss_cnt;

    wire rom_cs_posedge = !last_rom_cs && rom_cs;
    wire rom_bad = (rom_cs && !rom_ok) || rom_cs_posedge;
    wire dev_hold = |dev_busy;
    wire rec_en = mreq_n && iorq_n && busak_n && (RECOVERY != 0);
    wire rec = (miss_cnt != 4'd0) && !cen_in && rec_en && !cen_l;

    assign gate = !(rom_bad || dev_hold || locked);

    always @* begin
        cen_out = (cen_in && gate) || rec;
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            miss_cnt <= 4'd0;
            cen_l <= 1'b0;
        end else begin
            cen_l <= cen_out;

            if(!started) begin
                miss_cnt <= 4'd0;
            end else if(cen_in && !gate && !dev_hold) begin
                if(miss_cnt != 4'hF)
                    miss_cnt <= miss_cnt + 4'd1;
            end else if(rec && miss_cnt != 4'd0) begin
                miss_cnt <= miss_cnt - 4'd1;
            end
        end
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            last_rom_cs <= 1'b1;
            locked <= 1'b0;
            started <= 1'b0;
        end else begin
            last_rom_cs <= rom_cs;
            if(rom_bad) begin
                locked <= 1'b1;
            end else begin
                locked <= 1'b0;
                started <= 1'b1;
            end
        end
    end

endmodule

module raizing_t80 #(
    parameter CLR_INT = 0
)(
    input         rst_n,
    input         clk,
    input         cen,
    input         wait_n,
    input         int_n,
    input         nmi_n,
    input         busrq_n,
    output        m1_n,
    output        mreq_n,
    output        iorq_n,
    output        rd_n,
    output        wr_n,
    output        rfsh_n,
    output        halt_n,
    output        busak_n,
    output [15:0] A,
    input  [7:0]  din,
    output [7:0]  dout
);

    wire int_n_pin;

    generate
        if(CLR_INT) begin : gen_latched_int
            reg int_ff;
            reg int_n_d;

            always @(posedge clk) begin
                if(!rst_n) begin
                    int_ff <= 1'b0;
                    int_n_d <= 1'b0;
                end else begin
                    int_n_d <= int_n;
                    if(!m1_n && !iorq_n)
                        int_ff <= 1'b0;
                    else if(!int_n && int_n_d)
                        int_ff <= 1'b1;
                end
            end

            assign int_n_pin = ~int_ff;
        end else begin : gen_direct_int
            assign int_n_pin = int_n;
        end
    endgenerate

    T80s u_cpu (
        .RESET_n(rst_n),
        .CLK(clk),
        .CEN(cen),
        .WAIT_n(wait_n),
        .INT_n(int_n_pin),
        .NMI_n(nmi_n),
        .BUSRQ_n(busrq_n),
        .M1_n(m1_n),
        .MREQ_n(mreq_n),
        .IORQ_n(iorq_n),
        .RD_n(rd_n),
        .WR_n(wr_n),
        .RFSH_n(rfsh_n),
        .HALT_n(halt_n),
        .BUSAK_n(busak_n),
        .OUT0(1'b0),
        .A(A),
        .DI(din),
        .DO(dout)
    );

endmodule

module raizing_t80_devwait #(
    parameter M1_WAIT = 0,
    parameter RECOVERY = 1,
    parameter CLR_INT = 0
)(
    input         rst_n,
    input         clk,
    input         cen,
    output        cpu_cen,
    input         int_n,
    input         nmi_n,
    input         busrq_n,
    output        m1_n,
    output        mreq_n,
    output        iorq_n,
    output        rd_n,
    output        wr_n,
    output        rfsh_n,
    output        halt_n,
    output        busak_n,
    output [15:0] A,
    input  [7:0]  din,
    output [7:0]  dout,
    input         rom_cs,
    input         rom_ok,
    input         dev_busy
);

    wire wait_n;

    generate
        if(M1_WAIT > 0) begin : gen_m1_wait
            reg [M1_WAIT-1:0] wait_shift;
            reg m1_n_d;

            always @(posedge clk) begin
                if(!rst_n) begin
                    wait_shift <= {M1_WAIT{1'b0}};
                    m1_n_d <= 1'b1;
                end else if(cen) begin
                    m1_n_d <= m1_n;
                    if(!m1_n && m1_n_d)
                        wait_shift <= {M1_WAIT{1'b1}};
                    else
                        wait_shift <= wait_shift >> 1;
                end
            end

            assign wait_n = ~wait_shift[0];
        end else begin : gen_no_m1_wait
            assign wait_n = 1'b1;
        end
    endgenerate

    raizing_z80wait #(
        .DEVCNT(1),
        .RECOVERY(RECOVERY)
    ) u_wait (
        .rst_n(rst_n),
        .clk(clk),
        .cen_in(cen),
        .cen_out(cpu_cen),
        .gate(),
        .mreq_n(mreq_n),
        .iorq_n(iorq_n),
        .busak_n(busak_n),
        .dev_busy(dev_busy),
        .rom_cs(rom_cs),
        .rom_ok(rom_ok)
    );

    raizing_t80 #(
        .CLR_INT(CLR_INT)
    ) u_cpu (
        .rst_n(rst_n),
        .clk(clk),
        .cen(cpu_cen),
        .wait_n(wait_n),
        .int_n(int_n),
        .nmi_n(nmi_n),
        .busrq_n(busrq_n),
        .m1_n(m1_n),
        .mreq_n(mreq_n),
        .iorq_n(iorq_n),
        .rd_n(rd_n),
        .wr_n(wr_n),
        .rfsh_n(rfsh_n),
        .halt_n(halt_n),
        .busak_n(busak_n),
        .A(A),
        .din(din),
        .dout(dout)
    );

endmodule

module raizing_t80_sysz80 #(
    parameter RAM_AW = 12,
    parameter CLR_INT = 0,
    parameter M1_WAIT = 0,
    parameter RECOVERY = 1
)(
    input         rst_n,
    input         clk,
    input         cen,
    output        cpu_cen,
    input         int_n,
    input         nmi_n,
    input         busrq_n,
    output        m1_n,
    output        mreq_n,
    output        iorq_n,
    output        rd_n,
    output        wr_n,
    output        rfsh_n,
    output        halt_n,
    output        busak_n,
    output [15:0] A,
    input  [7:0]  cpu_din,
    output [7:0]  cpu_dout,
    output [7:0]  ram_dout,
    input         ram_cs,
    input         rom_cs,
    input         rom_ok
);

    wire ram_we = ram_cs && !wr_n;

    raizing_dual_ram #(
        .DW(8),
        .AW(RAM_AW)
    ) u_ram (
        .clk0(clk),
        .data0(cpu_dout),
        .addr0(A[RAM_AW-1:0]),
        .we0(ram_we),
        .q0(ram_dout),

        .clk1(clk),
        .data1(8'd0),
        .addr1({RAM_AW{1'b0}}),
        .we1(1'b0),
        .q1()
    );

    raizing_t80_devwait #(
        .M1_WAIT(M1_WAIT),
        .RECOVERY(RECOVERY),
        .CLR_INT(CLR_INT)
    ) u_cpu (
        .rst_n(rst_n),
        .clk(clk),
        .cen(cen),
        .cpu_cen(cpu_cen),
        .int_n(int_n),
        .nmi_n(nmi_n),
        .busrq_n(busrq_n),
        .m1_n(m1_n),
        .mreq_n(mreq_n),
        .iorq_n(iorq_n),
        .rd_n(rd_n),
        .wr_n(wr_n),
        .rfsh_n(rfsh_n),
        .halt_n(halt_n),
        .busak_n(busak_n),
        .A(A),
        .din(cpu_din),
        .dout(cpu_dout),
        .rom_cs(rom_cs),
        .rom_ok(rom_ok),
        .dev_busy(1'b0)
    );

endmodule
