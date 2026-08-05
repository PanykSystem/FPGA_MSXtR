module gw_gao(
    uart_tx,
    \u_bootrom/bootrom_cs ,
    \u_bootrom/bus_write ,
    \u_bootrom/bus_valid ,
    \u_bootrom/bus_rdata_en ,
    \u_bootrom/bus_ready ,
    \u_bootrom/bus_address[15] ,
    \u_bootrom/bus_address[14] ,
    \u_bootrom/bus_address[13] ,
    \u_bootrom/bus_address[12] ,
    \u_bootrom/bus_address[11] ,
    \u_bootrom/bus_address[10] ,
    \u_bootrom/bus_address[9] ,
    \u_bootrom/bus_address[8] ,
    \u_bootrom/bus_address[7] ,
    \u_bootrom/bus_address[6] ,
    \u_bootrom/bus_address[5] ,
    \u_bootrom/bus_address[4] ,
    \u_bootrom/bus_address[3] ,
    \u_bootrom/bus_address[2] ,
    \u_bootrom/bus_address[1] ,
    \u_bootrom/bus_address[0] ,
    \u_bootrom/ff_rom_q[7] ,
    \u_bootrom/ff_rom_q[6] ,
    \u_bootrom/ff_rom_q[5] ,
    \u_bootrom/ff_rom_q[4] ,
    \u_bootrom/ff_rom_q[3] ,
    \u_bootrom/ff_rom_q[2] ,
    \u_bootrom/ff_rom_q[1] ,
    \u_bootrom/ff_rom_q[0] ,
    \u_bootrom/ff_rom_q_en ,
    \u_z80/u_cz80/a[15] ,
    \u_z80/u_cz80/a[14] ,
    \u_z80/u_cz80/a[13] ,
    \u_z80/u_cz80/a[12] ,
    \u_z80/u_cz80/a[11] ,
    \u_z80/u_cz80/a[10] ,
    \u_z80/u_cz80/a[9] ,
    \u_z80/u_cz80/a[8] ,
    \u_z80/u_cz80/a[7] ,
    \u_z80/u_cz80/a[6] ,
    \u_z80/u_cz80/a[5] ,
    \u_z80/u_cz80/a[4] ,
    \u_z80/u_cz80/a[3] ,
    \u_z80/u_cz80/a[2] ,
    \u_z80/u_cz80/a[1] ,
    \u_z80/u_cz80/a[0] ,
    \u_z80/u_cz80/di[7] ,
    \u_z80/u_cz80/di[6] ,
    \u_z80/u_cz80/di[5] ,
    \u_z80/u_cz80/di[4] ,
    \u_z80/u_cz80/di[3] ,
    \u_z80/u_cz80/di[2] ,
    \u_z80/u_cz80/di[1] ,
    \u_z80/u_cz80/di[0] ,
    \u_s2026a/u_cpu_select/z80_m1_n ,
    clk27m,
    tms_pad_i,
    tck_pad_i,
    tdi_pad_i,
    tdo_pad_o
);

input uart_tx;
input \u_bootrom/bootrom_cs ;
input \u_bootrom/bus_write ;
input \u_bootrom/bus_valid ;
input \u_bootrom/bus_rdata_en ;
input \u_bootrom/bus_ready ;
input \u_bootrom/bus_address[15] ;
input \u_bootrom/bus_address[14] ;
input \u_bootrom/bus_address[13] ;
input \u_bootrom/bus_address[12] ;
input \u_bootrom/bus_address[11] ;
input \u_bootrom/bus_address[10] ;
input \u_bootrom/bus_address[9] ;
input \u_bootrom/bus_address[8] ;
input \u_bootrom/bus_address[7] ;
input \u_bootrom/bus_address[6] ;
input \u_bootrom/bus_address[5] ;
input \u_bootrom/bus_address[4] ;
input \u_bootrom/bus_address[3] ;
input \u_bootrom/bus_address[2] ;
input \u_bootrom/bus_address[1] ;
input \u_bootrom/bus_address[0] ;
input \u_bootrom/ff_rom_q[7] ;
input \u_bootrom/ff_rom_q[6] ;
input \u_bootrom/ff_rom_q[5] ;
input \u_bootrom/ff_rom_q[4] ;
input \u_bootrom/ff_rom_q[3] ;
input \u_bootrom/ff_rom_q[2] ;
input \u_bootrom/ff_rom_q[1] ;
input \u_bootrom/ff_rom_q[0] ;
input \u_bootrom/ff_rom_q_en ;
input \u_z80/u_cz80/a[15] ;
input \u_z80/u_cz80/a[14] ;
input \u_z80/u_cz80/a[13] ;
input \u_z80/u_cz80/a[12] ;
input \u_z80/u_cz80/a[11] ;
input \u_z80/u_cz80/a[10] ;
input \u_z80/u_cz80/a[9] ;
input \u_z80/u_cz80/a[8] ;
input \u_z80/u_cz80/a[7] ;
input \u_z80/u_cz80/a[6] ;
input \u_z80/u_cz80/a[5] ;
input \u_z80/u_cz80/a[4] ;
input \u_z80/u_cz80/a[3] ;
input \u_z80/u_cz80/a[2] ;
input \u_z80/u_cz80/a[1] ;
input \u_z80/u_cz80/a[0] ;
input \u_z80/u_cz80/di[7] ;
input \u_z80/u_cz80/di[6] ;
input \u_z80/u_cz80/di[5] ;
input \u_z80/u_cz80/di[4] ;
input \u_z80/u_cz80/di[3] ;
input \u_z80/u_cz80/di[2] ;
input \u_z80/u_cz80/di[1] ;
input \u_z80/u_cz80/di[0] ;
input \u_s2026a/u_cpu_select/z80_m1_n ;
input clk27m;
input tms_pad_i;
input tck_pad_i;
input tdi_pad_i;
output tdo_pad_o;

wire uart_tx;
wire \u_bootrom/bootrom_cs ;
wire \u_bootrom/bus_write ;
wire \u_bootrom/bus_valid ;
wire \u_bootrom/bus_rdata_en ;
wire \u_bootrom/bus_ready ;
wire \u_bootrom/bus_address[15] ;
wire \u_bootrom/bus_address[14] ;
wire \u_bootrom/bus_address[13] ;
wire \u_bootrom/bus_address[12] ;
wire \u_bootrom/bus_address[11] ;
wire \u_bootrom/bus_address[10] ;
wire \u_bootrom/bus_address[9] ;
wire \u_bootrom/bus_address[8] ;
wire \u_bootrom/bus_address[7] ;
wire \u_bootrom/bus_address[6] ;
wire \u_bootrom/bus_address[5] ;
wire \u_bootrom/bus_address[4] ;
wire \u_bootrom/bus_address[3] ;
wire \u_bootrom/bus_address[2] ;
wire \u_bootrom/bus_address[1] ;
wire \u_bootrom/bus_address[0] ;
wire \u_bootrom/ff_rom_q[7] ;
wire \u_bootrom/ff_rom_q[6] ;
wire \u_bootrom/ff_rom_q[5] ;
wire \u_bootrom/ff_rom_q[4] ;
wire \u_bootrom/ff_rom_q[3] ;
wire \u_bootrom/ff_rom_q[2] ;
wire \u_bootrom/ff_rom_q[1] ;
wire \u_bootrom/ff_rom_q[0] ;
wire \u_bootrom/ff_rom_q_en ;
wire \u_z80/u_cz80/a[15] ;
wire \u_z80/u_cz80/a[14] ;
wire \u_z80/u_cz80/a[13] ;
wire \u_z80/u_cz80/a[12] ;
wire \u_z80/u_cz80/a[11] ;
wire \u_z80/u_cz80/a[10] ;
wire \u_z80/u_cz80/a[9] ;
wire \u_z80/u_cz80/a[8] ;
wire \u_z80/u_cz80/a[7] ;
wire \u_z80/u_cz80/a[6] ;
wire \u_z80/u_cz80/a[5] ;
wire \u_z80/u_cz80/a[4] ;
wire \u_z80/u_cz80/a[3] ;
wire \u_z80/u_cz80/a[2] ;
wire \u_z80/u_cz80/a[1] ;
wire \u_z80/u_cz80/a[0] ;
wire \u_z80/u_cz80/di[7] ;
wire \u_z80/u_cz80/di[6] ;
wire \u_z80/u_cz80/di[5] ;
wire \u_z80/u_cz80/di[4] ;
wire \u_z80/u_cz80/di[3] ;
wire \u_z80/u_cz80/di[2] ;
wire \u_z80/u_cz80/di[1] ;
wire \u_z80/u_cz80/di[0] ;
wire \u_s2026a/u_cpu_select/z80_m1_n ;
wire clk27m;
wire tms_pad_i;
wire tck_pad_i;
wire tdi_pad_i;
wire tdo_pad_o;
wire tms_i_c;
wire tck_i_c;
wire tdi_i_c;
wire tdo_o_c;
wire [9:0] control0;
wire gao_jtag_tck;
wire gao_jtag_reset;
wire run_test_idle_er1;
wire run_test_idle_er2;
wire shift_dr_capture_dr;
wire update_dr;
wire pause_dr;
wire enable_er1;
wire enable_er2;
wire gao_jtag_tdi;
wire tdo_er1;

IBUF tms_ibuf (
    .I(tms_pad_i),
    .O(tms_i_c)
);

IBUF tck_ibuf (
    .I(tck_pad_i),
    .O(tck_i_c)
);

IBUF tdi_ibuf (
    .I(tdi_pad_i),
    .O(tdi_i_c)
);

OBUF tdo_obuf (
    .I(tdo_o_c),
    .O(tdo_pad_o)
);

GW_JTAG  u_gw_jtag(
    .tms_pad_i(tms_i_c),
    .tck_pad_i(tck_i_c),
    .tdi_pad_i(tdi_i_c),
    .tdo_pad_o(tdo_o_c),
    .tck_o(gao_jtag_tck),
    .test_logic_reset_o(gao_jtag_reset),
    .run_test_idle_er1_o(run_test_idle_er1),
    .run_test_idle_er2_o(run_test_idle_er2),
    .shift_dr_capture_dr_o(shift_dr_capture_dr),
    .update_dr_o(update_dr),
    .pause_dr_o(pause_dr),
    .enable_er1_o(enable_er1),
    .enable_er2_o(enable_er2),
    .tdi_o(gao_jtag_tdi),
    .tdo_er1_i(tdo_er1),
    .tdo_er2_i(1'b0)
);

gw_con_top  u_icon_top(
    .tck_i(gao_jtag_tck),
    .tdi_i(gao_jtag_tdi),
    .tdo_o(tdo_er1),
    .rst_i(gao_jtag_reset),
    .control0(control0[9:0]),
    .enable_i(enable_er1),
    .shift_dr_capture_dr_i(shift_dr_capture_dr),
    .update_dr_i(update_dr)
);

ao_top_0  u_la0_top(
    .control(control0[9:0]),
    .trig0_i(\u_s2026a/u_cpu_select/z80_m1_n ),
    .data_i({uart_tx,\u_bootrom/bootrom_cs ,\u_bootrom/bus_write ,\u_bootrom/bus_valid ,\u_bootrom/bus_rdata_en ,\u_bootrom/bus_ready ,\u_bootrom/bus_address[15] ,\u_bootrom/bus_address[14] ,\u_bootrom/bus_address[13] ,\u_bootrom/bus_address[12] ,\u_bootrom/bus_address[11] ,\u_bootrom/bus_address[10] ,\u_bootrom/bus_address[9] ,\u_bootrom/bus_address[8] ,\u_bootrom/bus_address[7] ,\u_bootrom/bus_address[6] ,\u_bootrom/bus_address[5] ,\u_bootrom/bus_address[4] ,\u_bootrom/bus_address[3] ,\u_bootrom/bus_address[2] ,\u_bootrom/bus_address[1] ,\u_bootrom/bus_address[0] ,\u_bootrom/ff_rom_q[7] ,\u_bootrom/ff_rom_q[6] ,\u_bootrom/ff_rom_q[5] ,\u_bootrom/ff_rom_q[4] ,\u_bootrom/ff_rom_q[3] ,\u_bootrom/ff_rom_q[2] ,\u_bootrom/ff_rom_q[1] ,\u_bootrom/ff_rom_q[0] ,\u_bootrom/ff_rom_q_en ,\u_z80/u_cz80/a[15] ,\u_z80/u_cz80/a[14] ,\u_z80/u_cz80/a[13] ,\u_z80/u_cz80/a[12] ,\u_z80/u_cz80/a[11] ,\u_z80/u_cz80/a[10] ,\u_z80/u_cz80/a[9] ,\u_z80/u_cz80/a[8] ,\u_z80/u_cz80/a[7] ,\u_z80/u_cz80/a[6] ,\u_z80/u_cz80/a[5] ,\u_z80/u_cz80/a[4] ,\u_z80/u_cz80/a[3] ,\u_z80/u_cz80/a[2] ,\u_z80/u_cz80/a[1] ,\u_z80/u_cz80/a[0] ,\u_z80/u_cz80/di[7] ,\u_z80/u_cz80/di[6] ,\u_z80/u_cz80/di[5] ,\u_z80/u_cz80/di[4] ,\u_z80/u_cz80/di[3] ,\u_z80/u_cz80/di[2] ,\u_z80/u_cz80/di[1] ,\u_z80/u_cz80/di[0] }),
    .clk_i(clk27m)
);

endmodule
