/*  This file is part of Arcade-Raizing_MiSTer.

    Arcade-Raizing_MiSTer is free software: you can redistribute it and/or
    modify it under the terms of the GNU General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Arcade-Raizing_MiSTer is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
    Public License for more details.

    You should have received a copy of the GNU General Public License along
    with Arcade-Raizing_MiSTer. If not, see <http://www.gnu.org/licenses/>.

    Local object line buffer with read-side clear. It preserves the erasing
    behavior used by the inherited Raizing object renderer without modifying
    the upstream JTFRAME line buffer.
*/

module raizing_linebuf_clear #(parameter
    DW = 8,
    AW = 9
)(
    input            clk,
    input            pxl_cen,
    input            LHBL,
    input   [AW-1:0] wr_addr,
    input   [DW-1:0] wr_data,
    input            we,
    input   [AW-1:0] rd_addr,
    output  [DW-1:0] rd_data,
    output  [DW-1:0] rd_gated
);

reg line = 1'b0;
reg last_lhbl = 1'b0;
reg [AW-1:0] last_rd_addr = {AW{1'b0}};
reg erase = 1'b0;

always @(posedge clk) begin
    last_lhbl <= LHBL;
    if(!LHBL && last_lhbl)
        line <= ~line;

    if(pxl_cen) begin
        last_rd_addr <= rd_addr;
        erase <= 1'b1;
    end else begin
        erase <= 1'b0;
    end
end

assign rd_gated = LHBL ? rd_data : {DW{1'b0}};

raizing_dual_ram #(.AW(AW+1), .DW(DW)) u_line(
    .clk0   ( clk                                   ),
    .clk1   ( clk                                   ),
    .data0  ( wr_data                               ),
    .addr0  ( {line, wr_addr}                       ),
    .we0    ( we                                    ),
    .q0     (                                       ),
    .data1  ( {DW{1'b0}}                            ),
    .addr1  ( erase ? {~line, last_rd_addr}
                    : {~line, rd_addr}              ),
    .we1    ( erase                                 ),
    .q1     ( rd_data                               )
);

endmodule
