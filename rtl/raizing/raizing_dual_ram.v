// This file is a Codex-assisted refactoring and update
// based on the original work of Pramod Somashekar (pram0d)

module raizing_dual_ram #(
    parameter DW = 8,
    parameter AW = 10,
    parameter SIMFILE = "",
    parameter SIMHEXFILE = "",
    parameter SIMFILE_BYTE = 0,
    parameter FULL_DW = 8,
    parameter SYNFILE = "",
    parameter ASCII_BIN = 0
)(
    input              clk0,
    input  [DW-1:0]   data0,
    input  [AW-1:0]   addr0,
    input              we0,
    output [DW-1:0]   q0,

    input              clk1,
    input  [DW-1:0]   data1,
    input  [AW-1:0]   addr1,
    input              we1,
    output [DW-1:0]   q1
);

    reg [DW-1:0] q0_r;
    reg [DW-1:0] q1_r;
    (* ramstyle = "no_rw_check" *) reg [DW-1:0] mem [0:(1<<AW)-1];

    assign q0 = q0_r;
    assign q1 = q1_r;

    always @(posedge clk0) begin
        q0_r <= mem[addr0];
        if(we0) mem[addr0] <= data0;
    end

    always @(posedge clk1) begin
        q1_r <= mem[addr1];
        if(we1) mem[addr1] <= data1;
    end

`ifdef SIMULATION
    integer init_i;
    integer fd;
    integer readcnt;
    integer loadpos;
    integer loadcnt;
    integer full_bytes;
    reg [7:0] file_data [0:(1<<AW)*4-1];

    initial begin
        for(init_i = 0; init_i < (1<<AW); init_i = init_i + 1)
            mem[init_i] = {DW{1'b0}};

        full_bytes = FULL_DW == 32 ? 4 : (FULL_DW == 16 ? 2 : 1);

        if(SIMFILE != "") begin
            fd = $fopen(SIMFILE, "rb");
            if(fd != 0) begin
                if(FULL_DW == 8) begin
                    readcnt = $fread(mem, fd);
                end else begin
                    readcnt = $fread(file_data, fd);
                    loadcnt = 0;
                    for(loadpos = SIMFILE_BYTE; loadpos < readcnt && loadcnt < (1<<AW); loadpos = loadpos + full_bytes) begin
                        if(DW == 8)
                            mem[loadcnt] = file_data[loadpos];
                        loadcnt = loadcnt + 1;
                    end
                end
                $fclose(fd);
            end
        end else if(SIMHEXFILE != "") begin
            $readmemh(SIMHEXFILE, mem);
        end else if(SYNFILE != "") begin
            if(ASCII_BIN)
                $readmemb(SYNFILE, mem);
            else
                $readmemh(SYNFILE, mem);
        end
    end
`else
    initial begin
        if(SYNFILE != "") begin
            if(ASCII_BIN)
                $readmemb(SYNFILE, mem);
            else
                $readmemh(SYNFILE, mem);
        end
    end
`endif

endmodule
