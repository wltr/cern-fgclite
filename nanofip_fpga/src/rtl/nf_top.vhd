-------------------------------------------------------------------------------
--! @file      nf_top.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-02-24
--! @brief     FGClite NanoFIP FPGA (NF) top-level.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.nf_top_pkg.all;

--! @brief Entity declaration of nf_top
--! @details
--! The top-level component for the NanoFIP FPGA implementation.

entity nf_top is
  port (
    --! @name Clock and resets
    --! @{

    --! System clock
    clk_i : in std_ulogic;

    --! @}
    --! @name NanoFIP core
    --! @{

    --! The FGClite station ID
    subs_i     : in  std_ulogic_vector(4 downto 0);

    --! Fieldrive reception activity detection
    fd_rxcdn_i : in  std_ulogic;
    --! Fieldrive receiver data
    fd_rxd_i   : in  std_ulogic;
    --! Fieldrive transmitter error
    fd_txer_i  : in  std_ulogic;
    --! Fieldrive watchdog on transmitter
    fd_wdgn_i  : in  std_ulogic;

    --! Push-button reset
    rstin_i    : in    std_ulogic;
    --! Power-on reset
    rstpon_i   : inout std_logic;

    --! JTAG TDO
    jc_tdo_i   : in  std_ulogic;

    --! Fieldrive reset
    fd_rstn_o  : out std_ulogic;
    --! Fieldrive transmitter clock
    fd_txck_o  : out std_ulogic;
    --! Fieldrive transmitter data
    fd_txd_o   : out std_ulogic;
    --! Fieldrive transmitter enable
    fd_txena_o : out std_ulogic;

    --! Reset output (FGClite power cycle to PF)
    rston_o    : out std_ulogic;

    --! NanoFIP status byte - bit 5
    r_fcser_o  : out std_ulogic;
    --! NanoFIP status byte - bit 4
    r_tler_o   : out std_ulogic;
    --! NanoFIP status byte - bit 2
    u_cacer_o  : out std_ulogic;
    --! NanoFIP status byte - bit 3
    u_pacer_o  : out std_ulogic;

    --! JTAG TMS
    jc_tms_o   : out std_ulogic;
    --! JTAG TDI
    jc_tdi_o   : out std_ulogic;
    --! JTAG TCK
    jc_tck_o   : out std_ulogic;

    --! @}
    --! @name NanoFIP extensions
    --! @{

    --! JTAG TRST
    jc_trst_o    : out std_ulogic;
    --! CF and XF reset
    cfxf_rst_n_o : out std_ulogic;
    --! CMD 0 was received
    cmd_0_o      : out std_ulogic;
    --! VAR3 (TX buffer) can be accessed
    tx_rdy_o     : out std_ulogic;
    --! PF inhibit
    pf_inh_n_o   : out std_ulogic;

    --! @}
    --! @name 3-wire serial receiver from CF
    --! @{

    --! Frame
    cf_rx_frame_i  : in std_ulogic;
    --! Bit enable
    cf_rx_bit_en_i : in std_ulogic;
    --! Data
    cf_rx_i        : in std_ulogic;

    --! @}
    --! @name 3-wire serial transmitter to CF
    --! @{

    --! Frame
    cf_tx_frame_o  : out std_ulogic;
    --! Bit enable
    cf_tx_bit_en_o : out std_ulogic;
    --! Data
    cf_tx_o        : out std_ulogic;

    --! @}
    --! @name Debugging
    --! @{

    --! Serial receiver
    debug_rx_i    : in  std_ulogic;
    --! Serial transmitter
    debug_tx_o    : out std_ulogic;
    --! Debugging probe
    debug_probe_o : out std_ulogic);

    --! @}
end entity nf_top;

--! RTL implementation of nf_top
architecture rtl of nf_top is

  ---------------------------------------------------------------------------
  --! @name Internal Wires
  ---------------------------------------------------------------------------
  --! @{

  -- Safe reset generation
  signal rstpon      : std_ulogic;
  signal nanofip_rst : std_ulogic;
  signal rst         : std_ulogic;

  -- Input synchronization and glitch filter
  signal station_id_syn   : std_ulogic_vector(4 downto 0);
  signal cf_rx_frame_syn  : std_ulogic;
  signal cf_rx_bit_en_syn : std_ulogic;
  signal cf_rx_syn        : std_ulogic;
  signal debug_rx_syn     : std_ulogic;

  -- NanoFIP core
  signal var1_rdy : std_ulogic;
  signal var1_acc : std_ulogic;
  signal var2_rdy : std_ulogic;
  signal var2_acc : std_ulogic;
  signal var3_rdy : std_ulogic;
  signal var3_acc : std_ulogic;

  signal nf_wb_rst     : std_ulogic;
  signal nf_wb_addr    : std_ulogic_vector(9 downto 0);
  signal nf_wb_data_rx : std_ulogic_vector(7 downto 0);
  signal nf_wb_data_tx : std_ulogic_vector(7 downto 0);
  signal nf_wb_we      : std_ulogic;
  signal nf_wb_stb     : std_ulogic;
  signal nf_wb_cyc     : std_ulogic;
  signal nf_wb_ack     : std_ulogic;

  -- NanoFIP Wishbone interface
  signal wb_if_rx_var1_rdy : std_ulogic;
  signal wb_if_rx_var2_rdy : std_ulogic;
  signal wb_if_rx_var_sel  : std_ulogic;
  signal wb_if_rx_addr     : std_ulogic_vector(6 downto 0);
  signal wb_if_rx_en       : std_ulogic;
  signal wb_if_rx_data     : std_ulogic_vector(7 downto 0);
  signal wb_if_rx_data_en  : std_ulogic;

  signal wb_if_tx_addr : std_ulogic_vector(6 downto 0);
  signal wb_if_tx_en   : std_ulogic;
  signal wb_if_tx_data : std_ulogic_vector(7 downto 0);

  signal wb_if_err_rw_coll : std_ulogic;
  signal wb_if_err_bsy     : std_ulogic;
  signal wb_if_err_not_rdy : std_ulogic;
  signal wb_if_err_timeout : std_ulogic;

  -- NanoFIP extensions
  signal jtag_trst : std_ulogic;
  signal cmd_0     : std_ulogic;

  -- VAR1 receiver
  signal var1_rx_addr    : std_ulogic_vector(6 downto 0);
  signal var1_rx_en      : std_ulogic;
  signal var1_rx_data    : std_ulogic_vector(7 downto 0);
  signal var1_rx_data_en : std_ulogic;

  -- VAR2 receiver
  signal var2_rx_addr    : std_ulogic_vector(6 downto 0);
  signal var2_rx_en      : std_ulogic;
  signal var2_rx_data    : std_ulogic_vector(7 downto 0);
  signal var2_rx_data_en : std_ulogic;

  -- 3-wire serial receiver from CF
  signal cf_rx_data    : std_ulogic_vector(14 downto 0);
  signal cf_rx_data_en : std_ulogic;

  -- 3-wire serial transmitter to CF
  signal cf_tx_data    : std_ulogic_vector(39 downto 0);
  signal cf_tx_data_en : std_ulogic;
  signal cf_tx_busy    : std_ulogic;

  -- Debugging
  signal debug_tx_data    : std_ulogic_vector(7 downto 0);
  signal debug_tx_data_en : std_ulogic;
  signal debug_tx_done    : std_ulogic;

  --! @}

begin -- architecture rtl

  ---------------------------------------------------------------------------
  -- Outputs
  ---------------------------------------------------------------------------

  tx_rdy_o <= var3_rdy;
  cmd_0_o  <= cmd_0;

  cfxf_rst_n_o <= not rst;

  pf_inh_n_o <= jtag_trst;
  jc_trst_o  <= jtag_trst;

  debug_probe_o <= cmd_0;

  ---------------------------------------------------------------------------
  -- Signal Assignments
  ---------------------------------------------------------------------------

  wb_if_tx_addr <= cf_rx_data(14 downto 8);
  wb_if_tx_data <= cf_rx_data(7 downto 0);
  wb_if_tx_en   <= cf_rx_data_en;

  wb_if_rx_addr <= var1_rx_addr when wb_if_rx_var_sel = '0' else var2_rx_addr;
  wb_if_rx_en   <= var1_rx_en when wb_if_rx_var_sel = '0' else var2_rx_en;

  var1_rx_data    <= wb_if_rx_data;
  var1_rx_data_en <= wb_if_rx_data_en when wb_if_rx_var_sel = '0' else '0';

  var2_rx_data    <= wb_if_rx_data;
  var2_rx_data_en <= wb_if_rx_data_en when wb_if_rx_var_sel = '1' else '0';

  ---------------------------------------------------------------------------
  -- Instances
  ---------------------------------------------------------------------------

  --! Power-on reset generation for Microsemi devices
  po_reset_inst : entity work.microsemi_reset_generator
    generic map (
      num_delay_g => 4,
      active_g    => '0')
    port map (
      clk_i      => clk_i,
      rst_asy_io => rstpon_i,
      rst_o      => rstpon);

  --! Safe reset generation for logic except NanoFIP core
  nf_reset_inst : entity work.reset_generator
    generic map (
      num_delay_g => 16,
      active_g    => '1')
    port map (
      clk_i     => clk_i,
      rst_asy_i => nanofip_rst,
      rst_o     => rst);

  --! Input synchronization and glitch filter for serial receiver
  ext_inputs_inst_0 : entity work.external_inputs
    generic map (
      init_value_g => '0',
      num_inputs_g => 4)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => '1',
      rst_syn_i   => rst,

      sig_i(0)    => cf_rx_frame_i,
      sig_i(1)    => cf_rx_bit_en_i,
      sig_i(2)    => cf_rx_i,
      sig_i(3)    => debug_rx_i,

      sig_o(0)    => cf_rx_frame_syn,
      sig_o(1)    => cf_rx_bit_en_syn,
      sig_o(2)    => cf_rx_syn,
      sig_o(3)    => debug_rx_syn);

  --! Input synchronization and glitch filter for station ID
  ext_inputs_inst_1 : entity work.external_inputs
    generic map (
      init_value_g => '0',
      num_inputs_g => subs_i'length)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => '1',
      rst_syn_i   => rst,
      sig_i       => subs_i,
      sig_o       => station_id_syn);

  --! NanoFIP core
  nanofip_inst: entity work.nanofip
    port map (
      nanofip_rst_o => nanofip_rst,

      c_id_i     => "0001",
      m_id_i     => "0001",
      p3_lgth_i  => "101",
      rate_i     => "10",

      subs_i(4 downto 0) => std_logic_vector(subs_i),
      subs_i(7 downto 5) => "000",

      fd_rxcdn_i => fd_rxcdn_i,
      fd_rxd_i   => fd_rxd_i,
      fd_txer_i  => fd_txer_i,
      fd_wdgn_i  => fd_wdgn_i,
      nostat_i   => '0',
      rstin_i    => rstin_i,
      rstpon_i   => rstpon,
      slone_i    => '0',

      uclk_i     => clk_i,

      var1_acc_i => var1_acc,
      var2_acc_i => var2_acc,
      var3_acc_i => var3_acc,

      wclk_i     => clk_i,
      adr_i      => std_logic_vector(nf_wb_addr),
      cyc_i      => nf_wb_cyc,

      dat_i(7 downto 0)  => std_logic_vector(nf_wb_data_tx),
      dat_i(15 downto 8) => x"00",

      rst_i      => nf_wb_rst,
      stb_i      => nf_wb_stb,
      we_i       => nf_wb_we,

      jc_tdo_i   => jc_tdo_i,
      --s_id_o     => open, -- UNUSED: Information is not used anywhere
      fd_rstn_o  => fd_rstn_o,
      fd_txck_o  => fd_txck_o,
      fd_txd_o   => fd_txd_o,
      fd_txena_o => fd_txena_o,
      rston_o    => rston_o,
      r_fcser_o  => r_fcser_o,
      r_tler_o   => r_tler_o,
      u_cacer_o  => u_cacer_o,
      u_pacer_o  => u_pacer_o,

      var1_rdy_o => var1_rdy,
      var2_rdy_o => var2_rdy,
      var3_rdy_o => var3_rdy,

      std_ulogic_vector(dat_o) => nf_wb_data_rx,

      ack_o      => nf_wb_ack,

      jc_tms_o   => jc_tms_o,
      jc_tdi_o   => jc_tdi_o,
      jc_tck_o   => jc_tck_o);

  --! NanoFIP Wishbone interface
  nanofip_wb_if_inst : entity work.nanofip_wb_if
    generic map (
      watchdog_max_g => 32)
    port map (
      clk_i         => clk_i,
      rst_asy_n_i   => '1',
      rst_syn_i     => rst,

      var1_rdy_i    => var1_rdy,
      var1_acc_o    => var1_acc,
      var2_rdy_i    => var2_rdy,
      var2_acc_o    => var2_acc,
      var3_rdy_i    => var3_rdy,
      var3_acc_o    => var3_acc,

      wb_clk_o      => open,
      wb_rst_o      => nf_wb_rst,
      wb_addr_o     => nf_wb_addr,
      wb_data_i     => nf_wb_data_rx,
      wb_data_o     => nf_wb_data_tx,
      wb_we_o       => nf_wb_we,
      wb_stb_o      => nf_wb_stb,
      wb_cyc_o      => nf_wb_cyc,
      wb_ack_i      => nf_wb_ack,

      rx_var1_rdy_o => wb_if_rx_var1_rdy,
      rx_var2_rdy_o => wb_if_rx_var2_rdy,
      rx_var_sel_i  => wb_if_rx_var_sel,
      rx_addr_i     => wb_if_rx_addr,
      rx_en_i       => wb_if_rx_en,
      rx_data_o     => wb_if_rx_data,
      rx_data_en_o  => wb_if_rx_data_en,

      tx_rdy_o      => open, -- UNUSED: CF knows when VAR3 is ready
      tx_addr_i     => wb_if_tx_addr,
      tx_en_i       => wb_if_tx_en,
      tx_data_i     => wb_if_tx_data,
      tx_done_o     => open, -- UNUSED: Serial receiver is slower than Wishbone interface

      err_rw_coll_o => wb_if_err_rw_coll,
      err_bsy_o     => wb_if_err_bsy,
      err_not_rdy_o => wb_if_err_not_rdy,
      err_timeout_o => wb_if_err_timeout);

  --! Receiver VAR select
  rx_var_sel_inst : entity work.rx_var_select
    port map (
      clk_i        => clk_i,
      rst_asy_n_i  => '1',
      rst_syn_i    => rst,

      var1_rdy_i   => wb_if_rx_var1_rdy,
      var2_rdy_i   => wb_if_rx_var2_rdy,
      var_select_o => wb_if_rx_var_sel);

  --! VAR1 receiver
  var1_rx_inst : entity work.var1_rx
    port map (
      clk_i         => clk_i,
      rst_asy_n_i   => '1',
      rst_syn_i     => rst,

      rx_rdy_i      => wb_if_rx_var1_rdy,
      rx_addr_o     => var1_rx_addr,
      rx_en_o       => var1_rx_en,
      rx_data_i     => var1_rx_data,
      rx_data_en_i  => var1_rx_data_en,

      jtag_trst_o   => jtag_trst,

      err_rw_coll_i => wb_if_err_rw_coll,
      err_bsy_i     => wb_if_err_bsy,
      err_not_rdy_i => wb_if_err_not_rdy,
      err_timeout_i => wb_if_err_timeout);

  --! VAR2 receiver
  var2_rx_inst : entity work.var2_rx
    port map (
      clk_i         => clk_i,
      rst_asy_n_i   => '1',
      rst_syn_i     => rst,

      station_id_i  => station_id_syn,
      cmd_0_o       => cmd_0,

      rx_rdy_i      => wb_if_rx_var2_rdy,
      rx_addr_o     => var2_rx_addr,
      rx_en_o       => var2_rx_en,
      rx_data_i     => var2_rx_data,
      rx_data_en_i  => var2_rx_data_en,

      tx_data_o     => cf_tx_data,
      tx_data_en_o  => cf_tx_data_en,
      tx_bsy_i      => cf_tx_busy,

      err_rw_coll_i => wb_if_err_rw_coll,
      err_bsy_i     => wb_if_err_bsy,
      err_not_rdy_i => wb_if_err_not_rdy,
      err_timeout_i => wb_if_err_timeout);

  --! 3-wire serial receiver from CF
  cf_rx_inst : entity work.serial_3wire_rx
    generic map (
      data_width_g => 15)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => '1',
      rst_syn_i   => rst,

      rx_frame_i  => cf_rx_frame_syn,
      rx_bit_en_i => cf_rx_bit_en_syn,
      rx_i        => cf_rx_syn,

      data_o      => cf_rx_data,
      data_en_o   => cf_rx_data_en,
      error_o     => open); -- UNUSED: CF can't be notified of errors anyway

  --! 3-wire serial transmitter to CF
  cf_tx_inst : entity work.serial_3wire_tx
    generic map (
      data_width_g => 44,
      num_ticks_g  => 6)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => '1',
      rst_syn_i   => rst,

      data_i(43 downto 40) => NF_VERSION_c,
      data_i(39 downto 0)  => cf_tx_data,

      data_en_i   => cf_tx_data_en,
      busy_o      => cf_tx_busy,
      done_o      => open,

      tx_frame_o  => cf_tx_frame_o,
      tx_bit_en_o => cf_tx_bit_en_o,
      tx_o        => cf_tx_o);

  --! Serial debugging receiver
  debug_rx_inst : entity work.uart_rx
    generic map (
      data_width_g => 8,
      parity_g     => 0,
      stop_bits_g  => 1,
      num_ticks_g  => 156)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => '1',
      rst_syn_i   => rst,

      rx_i        => debug_rx_syn,

      data_o      => open,
      data_en_o   => open,
      error_o     => open);

  --! Serial debugging transmitter
  debug_tx_inst : entity work.uart_tx
    generic map (
      data_width_g => 8,
      parity_g     => 0,
      stop_bits_g  => 1,
      num_ticks_g  => 156)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => '1',
      rst_syn_i   => rst,

      data_i      => debug_tx_data,
      data_en_i   => debug_tx_data_en,
      busy_o      => open,
      done_o      => debug_tx_done,

      tx_o        => debug_tx_o);

  --! Debugging packet transmitter
  debug_array_tx_inst : entity work.array_tx
    generic map (
      data_count_g => 5,
      data_width_g => 8)
    port map (
      clk_i        => clk_i,
      rst_asy_n_i  => '1',
      rst_syn_i    => rst,

      data_i       => cf_tx_data,
      data_en_i    => cf_tx_data_en,
      busy_o       => open,
      done_o       => open,

      tx_data_o    => debug_tx_data,
      tx_data_en_o => debug_tx_data_en,
      tx_done_i    => debug_tx_done);

end architecture rtl;
