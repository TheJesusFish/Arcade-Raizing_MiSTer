// This file is a Codex-assisted refactoring and update
// based on the original work of Pramod Somashekar (pram0d)
// SPDX-License-Identifier: GPL-3.0-or-later

module raizing_shared_jt_audio (
    input                CLK96,
    input                RESET96,
    input                ACTIVE,

    input                FM_CEN,
    input                FM_CEN_P1,
    input                FM_CS_N,
    input                FM_WR_N,
    input                FM_A0,
    input          [7:0] FM_DIN,
    output         [7:0] FM_DOUT,
    output               FM_IRQ_N,
    output               FM_SAMPLE,
    output signed [15:0] FM_XLEFT,
    output signed [15:0] FM_XRIGHT,

    input                OKI0_CEN,
    input                OKI0_SS,
    input                OKI0_WR_N,
    input          [7:0] OKI0_DIN,
    output         [7:0] OKI0_DOUT,
    output        [17:0] OKI0_ROM_ADDR,
    input          [7:0] OKI0_ROM_DATA,
    input                OKI0_ROM_OK,
    output signed [13:0] OKI0_SOUND,
    output               OKI0_SAMPLE,

    input                OKI1_CEN,
    input                OKI1_SS,
    input                OKI1_WR_N,
    input          [7:0] OKI1_DIN,
    output         [7:0] OKI1_DOUT,
    output        [17:0] OKI1_ROM_ADDR,
    input          [7:0] OKI1_ROM_DATA,
    input                OKI1_ROM_OK,
    output signed [13:0] OKI1_SOUND,
    output               OKI1_SAMPLE
);

wire chip_reset = RESET96 | !ACTIVE;

jt6295 #(.INTERPOL(2)) u_adpcm_0(
    .rst      ( chip_reset        ),
    .clk      ( CLK96             ),
    .cen      ( OKI0_CEN & ACTIVE ),
    .ss       ( OKI0_SS           ),
    .wrn      ( OKI0_WR_N         ),
    .din      ( OKI0_DIN          ),
    .dout     ( OKI0_DOUT         ),
    .rom_addr ( OKI0_ROM_ADDR     ),
    .rom_data ( OKI0_ROM_DATA     ),
    .rom_ok   ( OKI0_ROM_OK       ),
    .sound    ( OKI0_SOUND        ),
    .sample   ( OKI0_SAMPLE       )
);

jt6295 #(.INTERPOL(2)) u_adpcm_1(
    .rst      ( chip_reset        ),
    .clk      ( CLK96             ),
    .cen      ( OKI1_CEN & ACTIVE ),
    .ss       ( OKI1_SS           ),
    .wrn      ( OKI1_WR_N         ),
    .din      ( OKI1_DIN          ),
    .dout     ( OKI1_DOUT         ),
    .rom_addr ( OKI1_ROM_ADDR     ),
    .rom_data ( OKI1_ROM_DATA     ),
    .rom_ok   ( OKI1_ROM_OK       ),
    .sound    ( OKI1_SOUND        ),
    .sample   ( OKI1_SAMPLE       )
);

jt51 u_jt51(
    .rst      ( chip_reset        ),
    .clk      ( CLK96             ),
    .cen      ( FM_CEN & ACTIVE   ),
    .cen_p1   ( FM_CEN_P1 & ACTIVE ),
    .cs_n     ( FM_CS_N           ),
    .wr_n     ( FM_WR_N           ),
    .a0       ( FM_A0             ),
    .din      ( FM_DIN            ),
    .dout     ( FM_DOUT           ),
    .ct1      (                   ),
    .ct2      (                   ),
    .irq_n    ( FM_IRQ_N          ),
    .sample   ( FM_SAMPLE         ),
    .left     (                   ),
    .right    (                   ),
    .xleft    ( FM_XLEFT          ),
    .xright   ( FM_XRIGHT         )
);

endmodule
