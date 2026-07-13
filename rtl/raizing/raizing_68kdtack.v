// This file is a Codex-assisted refactoring and update
// based on the original work of Pramod Somashekar (pram0d)

// Raizing 68000 first-enable DTACK timing.
module raizing_68kdtack #(
    parameter W = 5,
    parameter RECOVERY = 1,
    parameter WD = 6,
    parameter MFREQ = 94500
)(
    input               rst,
    input               clk,
    output reg          cpu_cen,
    output reg          cpu_cenb,
    input               bus_cs,
    input               bus_busy,
    input               bus_legit,
    input               ASn,
    input       [1:0]   DSn,
    input       [W-2:0] num,
    input       [W-1:0] den,
    output reg          DTACKn,
    output reg [15:0]   fave,
    output reg [15:0]   fworst
);

localparam CW = W + WD;

reg [CW-1:0] cencnt = 0;
reg wait1 = 1'b1;
reg halt = 1'b0;
wire [W-1:0] num2 = {num, 1'b0};
wire over = cencnt > den - num2 && !cpu_cen && (!halt || RECOVERY == 0);
reg dsn_l = 1'b1;
reg risefall = 1'b0;
wire dsn_posedge = &DSn && !dsn_l;

always @(posedge clk) begin
    if(rst) begin
        DTACKn <= 1'b1;
        wait1 <= 1'b1;
        halt <= 1'b0;
        dsn_l <= 1'b1;
    end else begin
        dsn_l <= &DSn;
        if(ASn || dsn_posedge) begin
            DTACKn <= 1'b1;
            wait1 <= 1'b1;
            halt <= 1'b0;
        end else begin
            if(cpu_cen)
                wait1 <= 1'b0;
            if(!wait1 || cpu_cen) begin
                if(!bus_cs || !bus_busy) begin
                    DTACKn <= 1'b0;
                    halt <= 1'b0;
                end else begin
                    halt <= !bus_legit;
                end
            end
        end
    end
end

always @(posedge clk) begin
    cencnt <= over ? cencnt + num2 - den : cencnt + num2;
    if(over && !halt) begin
        cpu_cen <= risefall;
        cpu_cenb <= !risefall;
        risefall <= !risefall;
    end else begin
        cpu_cen <= 1'b0;
        cpu_cenb <= 1'b0;
    end
end

reg [15:0] freq_cnt = 0;
reg [15:0] fout_cnt = 0;

always @(posedge clk) begin
    if(rst) begin
        freq_cnt <= 0;
        fout_cnt <= 0;
        fave <= 0;
        fworst <= 16'hffff;
    end else begin
        freq_cnt <= freq_cnt + 1'b1;
        if(cpu_cen)
            fout_cnt <= fout_cnt + 1'b1;
        if(freq_cnt == MFREQ - 1) begin
            freq_cnt <= 0;
            fout_cnt <= 0;
            fave <= fout_cnt;
            if(fworst > fout_cnt)
                fworst <= fout_cnt;
        end
    end
end

endmodule
