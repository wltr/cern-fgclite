-------------------------------------------------------------------------------
--! @file      cf.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-07-06
--! @brief     Critical FPGA core component.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ab_pkg.all;
use work.nf_pkg.all;
use work.xf_pkg.all;
use work.cf_pkg.all;
use work.sram_pkg.all;

--! @brief Entity declaration of cf
--! @details
--! The core component for the Critical FPGA implementation.

entity cf is
  port (
    --! @name Clock and resets
    --! @{

    --! System clock
    clk_i       : in std_ulogic;
    --! Asynchronous active-low reset
    rst_asy_n_i : in std_ulogic;
    --! Synchronous active-high reset
    rst_syn_i   : in std_ulogic;

    --! @}
    --! @name LEDs
    --! @{

    --! Red LEDs
    leds_red_n_o   : out std_ulogic_vector(5 downto 0);
    --! Green LEDs
    leds_green_n_o : out std_ulogic_vector(5 downto 0);
    --! Test LEDs
    leds_test_n_i  : in  std_ulogic;

    --! @}
    --! @name Power converter interface
    --! @{

    --! Power converter commands
    conv_cmd_o  : out std_ulogic_vector(7 downto 0);
    --! Power converter status
    conv_stat_i : in  std_ulogic_vector(15 downto 0);

    --! @}
    --! @name External SRAM interface
    --! @{

    --! Inputs
    sram_i : in  sram_in_t;
    --! Outputs
    sram_o : out sram_out_t;

    --! @}
    --! @name Optical interface
    --! @{

    --! Optical input
    optical_i : in std_ulogic_vector(1 downto 0);

    --! @}
    --! @name Analogue board interface
    --! @{

    --! Inputs
    ab_i : in  ab_in_t;
    --! Outputs
    ab_o : out ab_out_t;

    --! @}
    --! @name Interlocks
    --! @{

    --! Interlock inputs
    interlock_i : in  std_ulogic_vector(1 downto 0);
    --! Interlock outputs
    interlock_o : out std_ulogic_vector(1 downto 0);

    --! @}
    --! @name PF interface
    --! @{

    --! Send power cycle request to PF
    pf_req_n_o      : out std_ulogic;
    --! Enable power down on PF
    pf_pwr_dwn_en_o : out std_ulogic;
    --! Failure flag from PF
    pf_pwr_flr_i    : in  std_ulogic;
    --! Power down signal from PF
    pf_pwr_dwn_i    : in  std_ulogic;

    --! @}
    --! @name NanoFIP interface
    --! @{

    --! Inputs
    nf_i : in  nf_in_t;
    --! Outputs
    nf_o : out nf_out_t;

    --! @}
    --! @name Auxiliary FPGA interface
    --! @{

    --! Inputs
    xf_i : in  xf_in_t;
    --! Outputs
    xf_o : out xf_out_t;

    --! @}
    --! @name Auxiliary interface (UART to diagnostics connector)
    --! @{

    --! Input
    aux_i : in  std_ulogic;
    --! Output
    aux_o : out std_ulogic;

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
end entity cf;

--! RTL implementation of cf
architecture rtl of cf is

  ---------------------------------------------------------------------------
  --! @name Internal Registers
  ---------------------------------------------------------------------------
  --! @{

  signal acc_sel_vs : std_ulogic;
  signal acc_sel_ia : std_ulogic;
  signal acc_sel_ib : std_ulogic;

  signal command_received      : std_ulogic_vector(3 downto 0);
  signal command_received_dlyd : std_ulogic_vector(3 downto 0);

  signal conv_cmd : std_ulogic_vector(7 downto 0);

  signal powering_failure : std_ulogic;

  signal sequence_num : unsigned(1 downto 0);

  signal adc_log_freeze : std_ulogic;
  signal dim_log_freeze : std_ulogic;

  signal comm_ok : std_ulogic;

  signal dim_trig_latched   : std_ulogic_vector(15 downto 0);
  signal dim_trig_unlatched : std_ulogic_vector(15 downto 0);

  signal nanofip_version : std_ulogic_vector(3 downto 0);

  --! @}
  ---------------------------------------------------------------------------
  --! @name Internal Wires
  ---------------------------------------------------------------------------
  --! @{

  signal leds_red   : std_ulogic_vector(5 downto 0);
  signal leds_green : std_ulogic_vector(5 downto 0);

  signal command : nf_command_t;
  signal status  : nf_status_t;

  signal ms_strobe : std_ulogic;
  signal ms_number : std_ulogic_vector(0 to 19);
  signal ms_0_dlyd : std_ulogic;

  signal adc_sefi : std_ulogic_vector(5 downto 0);

  signal adc_vs    : std_ulogic_vector(23 downto 0);
  signal adc_vs_en : std_ulogic;
  signal adc_ia    : std_ulogic_vector(23 downto 0);
  signal adc_ia_en : std_ulogic;
  signal adc_ib    : std_ulogic_vector(23 downto 0);
  signal adc_ib_en : std_ulogic;

  signal acc_vs    : std_ulogic_vector(31 downto 0);
  signal acc_vs_en : std_ulogic;
  signal acc_ia    : std_ulogic_vector(31 downto 0);
  signal acc_ia_en : std_ulogic;
  signal acc_ib    : std_ulogic_vector(31 downto 0);
  signal acc_ib_en : std_ulogic;

  signal ow_scan_busy : std_ulogic;

  signal cmd_num    : std_ulogic_vector(1 downto 0);
  signal cmd_num_en : std_ulogic;

  signal page_addr  : std_ulogic_vector(5 downto 0);
  signal page_data  : std_ulogic_vector(7 downto 0);
  signal page_wr_en : std_ulogic;
  signal page_done  : std_ulogic;
  signal page_ready : std_ulogic;

  signal dim    : std_ulogic_vector(19 downto 0);
  signal dim_en : std_ulogic;

  signal sram_adc_addr    : std_ulogic_vector(4 downto 0);
  signal sram_adc_rd_en   : std_ulogic;
  signal sram_adc_data    : std_ulogic_vector(23 downto 0);
  signal sram_adc_data_en : std_ulogic;
  signal sram_adc_done    : std_ulogic;

  signal sram_dim_addr    : std_ulogic_vector(4 downto 0);
  signal sram_dim_rd_en   : std_ulogic;
  signal sram_dim_data    : std_ulogic_vector(15 downto 0);
  signal sram_dim_data_en : std_ulogic;
  signal sram_dim_done    : std_ulogic;

  signal dim_addr     : std_ulogic_vector(6 downto 0);
  signal dim_rd_en    : std_ulogic;
  signal dim_data     : std_ulogic_vector(15 downto 0);
  signal dim_data_en  : std_ulogic;

  signal ow_addr    : std_ulogic_vector(5 downto 0);
  signal ow_rd_en   : std_ulogic;
  signal ow_data    : std_ulogic_vector(79 downto 0);
  signal ow_data_en : std_ulogic;

  signal pf_vref     : std_ulogic_vector(15 downto 0);
  signal pf_vref_en  : std_ulogic;
  signal pf_vref_ovr : std_ulogic;

  signal nf_debug    : std_ulogic_vector(7 downto 0);
  signal nf_debug_en : std_ulogic;

  signal dim_trig_num : std_ulogic_vector(3 downto 0);
  signal dim_trig_lat : std_ulogic;
  signal dim_trig_unl : std_ulogic;

  signal nf_version    : std_ulogic_vector(3 downto 0);
  signal nf_version_en : std_ulogic;

  signal cycle_period    : std_ulogic_vector(19 downto 0);

  --! @}

begin -- architecture rtl

  ---------------------------------------------------------------------------
  -- Outputs
  ---------------------------------------------------------------------------

  conv_cmd_o <= conv_cmd;

  interlock_o(0) <= powering_failure;
  interlock_o(1) <= conv_cmd(6);

  debug_probe_o <= adc_log_freeze; -- ms_number(0);

  -- Test LEDs
  leds_red_n_o   <= (others => '0') when leds_test_n_i = '0' else (not leds_red);
  leds_green_n_o <= (others => '0') when leds_test_n_i = '0' else (not leds_green);

  ---------------------------------------------------------------------------
  -- Signal Assignments
  ---------------------------------------------------------------------------

  -- NanoFIP status
  leds_green(0) <= comm_ok;
  -- FGC status
  leds_green(1) <= not (adc_sefi(0) or adc_sefi(1) or adc_sefi(2) or adc_sefi(3) or adc_sefi(4) or adc_sefi(5));
  -- PSU status (?)
  leds_green(2) <= '1';
  -- Voltage source status
  leds_green(3) <= not conv_stat_i(2); -- not VS_FAULT
  -- DCCT status
  leds_green(4) <= conv_stat_i(8) and conv_stat_i(9); -- DCCTA_OK and DCCTB_OK
  -- Power Interlock Controller status
  leds_green(5) <= not powering_failure;

  leds_red <= not leds_green;

  status.fgc_status_en <= ms_0_dlyd;

  status.fgc_status(15) <= conv_cmd(6);
  status.fgc_status(14) <= powering_failure;
  status.fgc_status(13) <= interlock_i(1);
  status.fgc_status(12) <= interlock_i(0);
  status.fgc_status(11) <= ow_scan_busy;
  status.fgc_status(10) <= not command_received_dlyd(3);
  status.fgc_status(9)  <= not command_received_dlyd(2);
  status.fgc_status(8)  <= not command_received_dlyd(0);

  status.fgc_status(7) <= adc_sefi(0);
  status.fgc_status(6) <= adc_sefi(1);
  status.fgc_status(5) <= adc_sefi(2);
  status.fgc_status(4) <= adc_sefi(3);
  status.fgc_status(3) <= adc_sefi(4);
  status.fgc_status(2) <= adc_sefi(5);

  status.fgc_status(1 downto 0) <= std_ulogic_vector(sequence_num);

  status.adc_acc_vs_0 <= acc_vs;
  status.adc_acc_vs_1 <= acc_vs;
  status.adc_acc_ia_0 <= acc_ia;
  status.adc_acc_ia_1 <= acc_ia;
  status.adc_acc_ib_0 <= acc_ib;
  status.adc_acc_ib_1 <= acc_ib;

  status.adc_acc_vs_0_en <= acc_vs_en and acc_sel_vs;
  status.adc_acc_vs_1_en <= acc_vs_en and not acc_sel_vs;
  status.adc_acc_ia_0_en <= acc_ia_en and acc_sel_ia;
  status.adc_acc_ia_1_en <= acc_ia_en and not acc_sel_ia;
  status.adc_acc_ib_0_en <= acc_ib_en and acc_sel_ib;
  status.adc_acc_ib_1_en <= acc_ib_en and not acc_sel_ib;

  status.vs_dig_out    <= conv_cmd;
  status.vs_dig_out_en <= ms_0_dlyd;

  status.vs_dig_in    <= conv_stat_i;
  status.vs_dig_in_en <= ms_number(0);

  status.adc_log_idx_en <= ms_number(0);
  status.dim_log_idx_en <= ms_number(0);

  status.dim_a_trig_lat    <= dim_trig_latched;
  status.dim_a_trig_lat_en <= ms_number(0);

  status.dim_a_trig_unl    <= dim_trig_unlatched;
  status.dim_a_trig_unl_en <= ms_number(0);

  status.dim_a1_ana_0      <= dim(15 downto 0);
  status.dim_a1_ana_0_en   <= dim_en when (dim(19 downto 16) = "0001" and dim(13 downto 12) = "00") else '0';

  status.dim_a1_ana_1      <= dim(15 downto 0);
  status.dim_a1_ana_1_en   <= dim_en when (dim(19 downto 16) = "0001" and dim(13 downto 12) = "01") else '0';

  status.dim_a1_ana_2      <= dim(15 downto 0);
  status.dim_a1_ana_2_en   <= dim_en when (dim(19 downto 16) = "0001" and dim(13 downto 12) = "10") else '0';

  status.dim_a1_ana_3      <= dim(15 downto 0);
  status.dim_a1_ana_3_en   <= dim_en when (dim(19 downto 16) = "0001" and dim(13 downto 12) = "11") else '0';

  status.version_cfnf(3 downto 0) <= CF_VERSION_c;
  status.version_cfnf(7 downto 4) <= nanofip_version;
  status.version_cfnf_en          <= '1';

  status.cycle_period(19 downto 0)  <= cycle_period;
  status.cycle_period(31 downto 20) <= (others => '0');
  status.cycle_period_en            <= ms_number(0);

  ---------------------------------------------------------------------------
  -- Instances
  ---------------------------------------------------------------------------

  --! Field-bus timing synchronization
  timing_inst : entity work.field_bus_timing
    port map (
      clk_i          => clk_i,
      rst_asy_n_i    => rst_asy_n_i,
      rst_syn_i      => rst_syn_i,

      cmd_0_i        => nf_i.cmd_0,
      ms_strobe_o    => ms_strobe,
      ms_period_i    => command.ms_period,
      ms_number_o    => ms_number,
      cycle_period_o => cycle_period);

  --! NanoFIP communication and synchronization
  nf_inst : entity work.nf
    port map (
      clk_i           => clk_i,
      rst_asy_n_i     => rst_asy_n_i,
      rst_syn_i       => ms_number(2),

      tx_start_i      => page_ready,
      cmd_num_o       => cmd_num,
      cmd_num_en_o    => cmd_num_en,
      nf_version_o    => nf_version,
      nf_version_en_o => nf_version_en,

      nf_debug_o      => nf_debug,
      nf_debug_en_o   => nf_debug_en,

      nf_i            => nf_i,
      nf_o            => nf_o,

      command_o       => command,
      status_i        => status,

      page_addr_i     => page_addr,
      page_wr_en_i    => page_wr_en,
      page_data_i     => page_data,
      page_done_o     => page_done);

  --! Analogue board filtering and control
  ab_inst : entity work.ab
    port map (
      clk_i         => clk_i,
      rst_asy_n_i   => rst_asy_n_i,
      rst_syn_i     => rst_syn_i,

      ab_i          => ab_i,
      ab_o          => ab_o,

      ms_strobe_i   => ms_strobe,
      ms_0_strobe_i => ms_0_dlyd,
      command_i     => command,
      sefi_o        => adc_sefi,
      pf_vref_i     => pf_vref,
      pf_vref_en_i  => pf_vref_en,
      pf_vref_ovr_i => pf_vref_ovr,

      adc_vs_o      => adc_vs,
      adc_vs_en_o   => adc_vs_en,
      adc_ia_o      => adc_ia,
      adc_ia_en_o   => adc_ia_en,
      adc_ib_o      => adc_ib,
      adc_ib_en_o   => adc_ib_en,

      acc_vs_o      => acc_vs,
      acc_vs_en_o   => acc_vs_en,
      acc_ia_o      => acc_ia,
      acc_ia_en_o   => acc_ia_en,
      acc_ib_o      => acc_ib,
      acc_ib_en_o   => acc_ib_en);

  --! Auxiliary FPGA communication
  xf_inst : entity work.xf
    port map (
      clk_i               => clk_i,
      rst_asy_n_i         => rst_asy_n_i,
      rst_syn_i           => rst_syn_i,

      xf_i                => xf_i,
      xf_o                => xf_o,

      ms_0_strobe_i       => ms_number(0),
      ms_1_strobe_i       => ms_number(1),
      command_i           => command,

      dim_o               => dim,
      dim_en_o            => dim_en,
      dim_trig_num_o      => dim_trig_num,
      dim_trig_lat_o      => dim_trig_lat,
      dim_trig_unl_o      => dim_trig_unl,
      backplane_type_o    => status.backplane,
      backplane_type_en_o => status.backplane_en,
      version_xfpf_o      => status.version_xfpf,
      version_xfpf_en_o   => status.version_xfpf_en,
      seu_count_o         => status.seu_count,
      seu_count_en_o      => status.seu_count_en,
      ow_scan_busy_o      => ow_scan_busy,

      dim_addr_i          => dim_addr,
      dim_rd_en_i         => dim_rd_en,
      dim_data_o          => dim_data,
      dim_data_en_o       => dim_data_en,

      ow_addr_i           => ow_addr,
      ow_rd_en_i          => ow_rd_en,
      ow_data_o           => ow_data,
      ow_data_en_o        => ow_data_en);

  --! Power FPGA communication
  pf_inst : entity work.pf
    port map (
      clk_i              => clk_i,
      rst_asy_n_i        => rst_asy_n_i,
      rst_syn_i          => rst_syn_i,

      pf_req_n_o         => pf_req_n_o,
      pf_pwr_dwn_en_o    => pf_pwr_dwn_en_o,
      pf_pwr_dwn_i       => pf_pwr_dwn_i,

      ms_0_strobe_i      => ms_number(0),
      ms_9_strobe_i      => ms_number(9),
      ms_11_strobe_i     => ms_number(11),
      v_ref_i            => command.v_ref,
      v_ref_o            => pf_vref,
      v_ref_en_o         => pf_vref_en,
      v_ref_override_o   => pf_vref_ovr,
      backplane_i        => status.backplane,
      command_received_i => command_received_dlyd);

  --! Serial field-bus communication
  serial_inst : entity work.field_bus_serial
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      start_i     => ms_number(0),
      command_i   => command,
      data_o      => status.serial_data,
      data_num_o  => status.serial_num,
      data_en_o   => status.serial_data_en,

      rx_i        => aux_i,
      tx_o        => aux_o);

  --! External SRAM access arbitration
  sram_inst : entity work.sram
    port map (
      clk_i         => clk_i,
      rst_asy_n_i   => rst_asy_n_i,
      rst_syn_i     => rst_syn_i,

      adc_log_idx_o => status.adc_log_idx,
      dim_log_idx_o => status.dim_log_idx,
      adc_freeze_i  => adc_log_freeze,
      dim_freeze_i  => dim_log_freeze,
      ms_0_strobe_i => ms_0_dlyd,

      adc_vs_i      => adc_vs,
      adc_vs_en_i   => adc_vs_en,
      adc_ia_i      => adc_ia,
      adc_ia_en_i   => adc_ia_en,
      adc_ib_i      => adc_ib,
      adc_ib_en_i   => adc_ib_en,
      dim_i         => dim,
      dim_en_i      => dim_en,

      idx_i         => command.index,
      idx_type_i    => command.index_type,
      adc_addr_i    => sram_adc_addr,
      adc_rd_en_i   => sram_adc_rd_en,
      adc_data_o    => sram_adc_data,
      adc_data_en_o => sram_adc_data_en,
      adc_done_i    => sram_adc_done,
      dim_addr_i    => sram_dim_addr,
      dim_rd_en_i   => sram_dim_rd_en,
      dim_data_o    => sram_dim_data,
      dim_data_en_o => sram_dim_data_en,
      dim_done_i    => sram_dim_done,

      sram_i        => sram_i,
      sram_o        => sram_o);

  --! Prepare page to be sent via NanoFIP
  fetch_page_inst : entity work.fetch_page
    port map (
      clk_i              => clk_i,
      rst_asy_n_i        => rst_asy_n_i,
      rst_syn_i          => ms_number(0),

      start_i            => ms_0_dlyd,
      done_o             => page_ready,
      idx_i              => command.index,
      idx_type_i         => command.index_type,

      page_addr_o        => page_addr,
      page_wr_en_o       => page_wr_en,
      page_data_o        => page_data,
      page_done_i        => page_done,

      sram_adc_addr_o    => sram_adc_addr,
      sram_adc_rd_en_o   => sram_adc_rd_en,
      sram_adc_data_i    => sram_adc_data,
      sram_adc_data_en_i => sram_adc_data_en,
      sram_adc_done_o    => sram_adc_done,

      sram_dim_addr_o    => sram_dim_addr,
      sram_dim_rd_en_o   => sram_dim_rd_en,
      sram_dim_data_i    => sram_dim_data,
      sram_dim_data_en_i => sram_dim_data_en,
      sram_dim_done_o    => sram_dim_done,

      dim_addr_o         => dim_addr,
      dim_rd_en_o        => dim_rd_en,
      dim_data_i         => dim_data,
      dim_data_en_i      => dim_data_en,

      ow_addr_o          => ow_addr,
      ow_rd_en_o         => ow_rd_en,
      ow_data_i          => ow_data,
      ow_data_en_i       => ow_data_en);

  debug_inst : entity work.debug_serial
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      start_i     => ms_number(1),
      debug_i     => nf_debug,
      debug_en_i  => nf_debug_en,
      debug_o     => open,
      debug_en_o  => open,

      rx_i        => debug_rx_i,
      tx_o        => debug_tx_o);

  ---------------------------------------------------------------------------
  -- Registers
  ---------------------------------------------------------------------------

  regs : process (clk_i, rst_asy_n_i) is
    procedure reset is
    begin
      acc_sel_vs <= '1';
      acc_sel_ia <= '1';
      acc_sel_ib <= '1';

      ms_0_dlyd <= '0';

      sequence_num <= to_unsigned(0, sequence_num'length);

      command_received      <= (others => '0');
      command_received_dlyd <= (others => '0');

      conv_cmd <= (others => '0');

      powering_failure <= '0';

      adc_log_freeze <= '0';
      dim_log_freeze <= '0';

      comm_ok <= '0';

      dim_trig_latched   <= (others => '0');
      dim_trig_unlatched <= (others => '0');

      nanofip_version <= (others => '0');
    end procedure reset;
  begin -- process regs
    if rst_asy_n_i = '0' then
      reset;
    elsif rising_edge(clk_i) then
      if rst_syn_i = '1' then
        reset;
      else
        ms_0_dlyd <= ms_number(0);

        command_received_dlyd <= command_received;

        if ms_number(4) = '1' then
          acc_sel_vs <= '1';
        elsif acc_vs_en = '1' then
          acc_sel_vs <= '0';
        end if;

        if ms_number(4) = '1' then
          acc_sel_ia <= '1';
        elsif acc_ia_en = '1' then
          acc_sel_ia <= '0';
        end if;

        if ms_number(4) = '1' then
          acc_sel_ib <= '1';
        elsif acc_ib_en = '1' then
          acc_sel_ib <= '0';
        end if;

        if dim_trig_lat = '1' then
          dim_trig_latched(to_integer(unsigned(dim_trig_num))) <= '1';
        end if;

        if dim_trig_unl = '1' then
          dim_trig_unlatched(to_integer(unsigned(dim_trig_num))) <= '1';
        end if;

        if nf_version_en = '1' then
          nanofip_version <= nf_version;
        end if;

        if ms_number(0) = '1' then
          sequence_num     <= sequence_num + 1;
          conv_cmd         <= command.vs_cmd;
          powering_failure <= command.vs_cmd(7) or pf_pwr_flr_i;

          adc_log_freeze <= command.adc_log_freeze;
          dim_log_freeze <= command.dim_log_freeze;

          -- Stop VS_RUN when VS_FAULT
          if conv_stat_i(2) = '1' then
            conv_cmd(0) <= '0';
          end if;

          if command_received = "1111" then
            comm_ok <= '1';
          else
            comm_ok <= '0';
          end if;
        end if;

        if ms_number(0) = '1' then
          command_received <= (others => '0');
        elsif cmd_num_en = '1' then
          command_received(to_integer(unsigned(cmd_num))) <= '1';
        end if;

        if ms_0_dlyd = '1' then
          dim_trig_latched   <= (others => '0');
          dim_trig_unlatched <= (others => '0');
        end if;
      end if;
    end if;
  end process regs;

end architecture rtl;
