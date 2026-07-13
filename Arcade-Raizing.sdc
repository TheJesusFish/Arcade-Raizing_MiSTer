derive_pll_clocks
derive_clock_uncertainty

# SDRAM_CLK uses the -5026 ps PLL tap; the controller uses general[4].
create_generated_clock -name SDRAM_CLK -source \
    [get_pins {emu|pll|raizingpll_inst|altera_pll_i|general[5].gpll~PLL_OUTPUT_COUNTER|divclk}] \
    -divide_by 1 \
    [get_ports SDRAM_CLK]

# CL2 return data is consumed on the second controller edge.
set_multicycle_path -from [get_clocks {SDRAM_CLK}] -to \
    [get_clocks {emu|pll|raizingpll_inst|altera_pll_i|general[4].gpll~PLL_OUTPUT_COUNTER|divclk}] \
    -setup -end 2
set_multicycle_path -from [get_clocks {SDRAM_CLK}] -to \
    [get_clocks {emu|pll|raizingpll_inst|altera_pll_i|general[4].gpll~PLL_OUTPUT_COUNTER|divclk}] \
    -hold -end 2

# The drop-in Template SDC groups *|pll|pll_inst, but this core's PLL
# instance is raizingpll_inst. Keep SDRAM/game clocks related and cut
# unrelated framework/audio/video/HPS clock domains.
set_clock_groups -exclusive \
    -group [get_clocks {emu|pll|raizingpll_inst|altera_pll_i|general[4].gpll~PLL_OUTPUT_COUNTER|divclk emu|pll|raizingpll_inst|altera_pll_i|general[5].gpll~PLL_OUTPUT_COUNTER|divclk SDRAM_CLK}] \
    -group [get_clocks {pll_hdmi|pll_hdmi_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}] \
    -group [get_clocks {pll_audio|pll_audio_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] \
    -group [get_clocks {spi_sck}] \
    -group [get_clocks {hdmi_sck}] \
    -group [get_clocks {sysmem|fpga_interfaces|clocks_resets|h2f_user0_clk}] \
    -group [get_clocks {FPGA_CLK1_50}] \
    -group [get_clocks {FPGA_CLK2_50}] \
    -group [get_clocks {FPGA_CLK3_50}]

# SDRAM tAC/tOH read and tDS/tDH write timing.
set_input_delay  -clock SDRAM_CLK -max 6.0 [get_ports SDRAM_DQ[*]]
set_input_delay  -clock SDRAM_CLK -min 3.0 [get_ports SDRAM_DQ[*]]

# Pack SDRAM command, address, DQ, and DQ OE registers into I/O cells.
set_output_delay -clock SDRAM_CLK -max 1.5 \
    [get_ports {SDRAM_A[*] SDRAM_BA[*] SDRAM_CKE SDRAM_DQMH SDRAM_DQML \
                SDRAM_DQ[*] SDRAM_nCAS SDRAM_nCS SDRAM_nRAS SDRAM_nWE}]
set_output_delay -clock SDRAM_CLK -min -0.8 \
    [get_ports {SDRAM_A[*] SDRAM_BA[*] SDRAM_CKE SDRAM_DQMH SDRAM_DQML \
                SDRAM_DQ[*] SDRAM_nCAS SDRAM_nCS SDRAM_nRAS SDRAM_nWE}]

# The old standalone obj queue multicycle path used a u_gcu/u_obj hierarchy
# that no longer exists in the collapsed shared board, so it was ignored.
set_multicycle_path -from [get_clocks {emu|pll|raizingpll_inst|altera_pll_i|general[4].gpll~PLL_OUTPUT_COUNTER|divclk*}] -to [get_clocks {emu|pll|raizingpll_inst|altera_pll_i|general[4].gpll~PLL_OUTPUT_COUNTER|divclk}] -setup -end 2
set_multicycle_path -from [get_clocks {emu|pll|raizingpll_inst|altera_pll_i|general[4].gpll~PLL_OUTPUT_COUNTER|divclk*}] -to [get_clocks {emu|pll|raizingpll_inst|altera_pll_i|general[4].gpll~PLL_OUTPUT_COUNTER|divclk}] -hold -end 2

# JTFRAME
set_false_path -to [get_keepers {audio_out:audio_out|cl1[*]}]
set_false_path -to [get_keepers {audio_out:audio_out|cr1[*]}]

# Reset synchronization signal
set_false_path -from [get_keepers {emu:emu|jtframe_board:u_board|jtframe_reset:u_reset|rst_rom[0]}] -to [get_keepers {emu:emu|jtframe_board:u_board|jtframe_reset:u_reset|rst_rom_sync}]
set_false_path -to emu:emu|jtframe_board:u_board|jtframe_reset:u_reset|rst_req_sync[0]
# static signals
set_false_path -from FB_EN
set_false_path -to deb_osd[0]
set_false_path -from emu:emu|jtframe_board:u_board|jtframe_led:u_led|led

set_false_path -to [get_keepers {*altera_std_synchronizer:*|din_s1}]
