// This file is a Codex-assisted refactoring and update
// based on the original work of Pramod Somashekar (pram0d)

module raizing_z80wait #(
    parameter DEVCNT = 2,
    parameter RECOVERY = 1,
    parameter SS_ENABLE = 0
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
    input                  rom_ok,
    input                  ss_hold,
    input                  ss_restore,
    input            [7:0] ss_state_in,
    output           [7:0] ss_state
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
    wire state_hold = SS_ENABLE && ss_hold;
    wire state_restore = SS_ENABLE && ss_restore;

    assign gate = !(rom_bad || dev_hold || locked);
    assign ss_state = {last_rom_cs, locked, started, cen_l, miss_cnt};

    always @* begin
        cen_out = (cen_in && gate) || rec;
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            miss_cnt <= 4'd0;
            cen_l <= 1'b0;
        end else if(state_restore) begin
            cen_l <= ss_state_in[4];
            miss_cnt <= ss_state_in[3:0];
        end else if(!state_hold) begin
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
        end else if(state_restore) begin
            last_rom_cs <= ss_state_in[7];
            locked <= ss_state_in[6];
            started <= ss_state_in[5];
        end else if(!state_hold) begin
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
    parameter CLR_INT = 0,
    parameter SS_ENABLE = 0
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
    output [7:0]  dout,
    input         ss_hold,
    output        ss_quiesced,
    input         ss_restore,
    output reg    ss_restore_done,
    output [228:0] ss_state,
    input  [228:0] ss_state_in
);

    wire int_n_pin;
    wire cpu_cen;
    wire [211:0] state_reg;
    wire [16:0] state_ext;
    wire state_boundary;

    assign cpu_cen = cen && !(SS_ENABLE && ss_hold && state_boundary);
    assign ss_quiesced = SS_ENABLE && ss_hold && state_boundary;
    assign ss_state = SS_ENABLE ? {state_ext, state_reg} : 229'd0;

    always @(posedge clk) begin
        if(!rst_n)
            ss_restore_done <= 1'b0;
        else
            ss_restore_done <= SS_ENABLE && ss_restore;
    end

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

    raizing_t80s_ss u_cpu (
        .RESET_n(rst_n),
        .CLK(clk),
        .CEN(cpu_cen),
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
        .DO(dout),
        .STATE_REG(state_reg),
        .STATE_SET(SS_ENABLE && ss_restore),
        .STATE_DIR(SS_ENABLE ? ss_state_in[211:0] : 212'd0),
        .STATE_EXT(state_ext),
        .STATE_EXT_DIR(SS_ENABLE ? ss_state_in[228:212] : 17'd0),
        .STATE_BOUNDARY(state_boundary),
        .MC_OUT(),
        .TS_OUT()
    );

endmodule

module raizing_t80_devwait #(
    parameter M1_WAIT = 0,
    parameter RECOVERY = 1,
    parameter CLR_INT = 0,
    parameter SS_ENABLE = 0
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
    input         dev_busy,
    input         ss_hold,
    output        ss_quiesced,
    input         ss_restore,
    output        ss_restore_done,
    output [228:0] ss_state,
    input  [228:0] ss_state_in,
    output   [7:0] ss_wait_state,
    input    [7:0] ss_wait_state_in
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
        .RECOVERY(RECOVERY),
        .SS_ENABLE(SS_ENABLE)
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
        .rom_ok(rom_ok),
        .ss_hold(ss_hold && ss_quiesced),
        .ss_restore(ss_restore),
        .ss_state_in(ss_wait_state_in),
        .ss_state(ss_wait_state)
    );

    raizing_t80 #(
        .CLR_INT(CLR_INT),
        .SS_ENABLE(SS_ENABLE)
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
        .dout(dout),
        .ss_hold(ss_hold),
        .ss_quiesced(ss_quiesced),
        .ss_restore(ss_restore),
        .ss_restore_done(ss_restore_done),
        .ss_state(ss_state),
        .ss_state_in(ss_state_in)
    );

endmodule

module raizing_t80_sysz80 #(
    parameter RAM_AW = 12,
    parameter CLR_INT = 0,
    parameter M1_WAIT = 0,
    parameter RECOVERY = 1,
    parameter SS_ENABLE = 0
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
    input         rom_ok,
    input         ss_ram_clk,
    input         ss_hold,
    output        ss_quiesced,
    input         ss_restore,
    output        ss_restore_done,
    output [228:0] ss_state,
    input  [228:0] ss_state_in,
    output   [7:0] ss_wait_state,
    input    [7:0] ss_wait_state_in,
    input         ss_ram_active,
    input  [RAM_AW-1:0] ss_ram_addr,
    input  [7:0]  ss_ram_data,
    input         ss_ram_we,
    output [7:0]  ss_ram_q
);

    wire ram_we = ram_cs && !wr_n;

    generate
        if(SS_ENABLE) begin : gen_ss_ram
            raizing_dual_ram #(
                .DW(8),
                .AW(RAM_AW)
            ) u_ram (
                .clk0(clk),
                .data0(cpu_dout),
                .addr0(A[RAM_AW-1:0]),
                .we0(ram_we),
                .q0(ram_dout),

                .clk1(ss_ram_clk),
                .data1(ss_ram_data),
                .addr1(ss_ram_addr),
                .we1(ss_ram_active && ss_ram_we),
                .q1(ss_ram_q)
            );
        end else begin : gen_no_ss_ram
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

            assign ss_ram_q = 8'd0;
        end
    endgenerate

    raizing_t80_devwait #(
        .M1_WAIT(M1_WAIT),
        .RECOVERY(RECOVERY),
        .CLR_INT(CLR_INT),
        .SS_ENABLE(SS_ENABLE)
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
        .dev_busy(1'b0),
        .ss_hold(ss_hold),
        .ss_quiesced(ss_quiesced),
        .ss_restore(ss_restore),
        .ss_restore_done(ss_restore_done),
        .ss_state(ss_state),
        .ss_state_in(ss_state_in),
        .ss_wait_state(ss_wait_state),
        .ss_wait_state_in(ss_wait_state_in)
    );

endmodule
