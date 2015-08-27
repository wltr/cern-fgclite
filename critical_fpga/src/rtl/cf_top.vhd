-------------------------------------------------------------------------------
--! @file      cf_top.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-05-06
--! @brief     FGClite Critical FPGA (CF) top-level.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.ab_pkg.all;
use work.nf_pkg.all;
use work.xf_pkg.all;
use work.sram_pkg.all;

--! @brief Entity declaration of cf_top
--! @details
--! The top-level component for the Critical FPGA implementation.

entity cf_top is
  port (
    --! @name Clock and resets
    --! @{

    --! System clock
    clk_i      : in    std_ulogic;

    --! Power-on reset
    po_rst_i   : inout std_logic;
    --! Push-button reset
    pb_rst_n_i : in    std_ulogic;
    --! NF reset
    nf_rst_n_i : in    std_ulogic;

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

    --! Address
    sram_addr_o  : out   std_ulogic_vector(19 downto 0);
    --! Control signals (CS2, OE, LB, UB, BYTE, CS1, WE)
    sram_ctrl_o  : out   std_ulogic_vector(6 downto 0);
    --! Data bus
    sram_data_io : inout std_logic_vector(15 downto 0);

    --! @}
    --! @name Optical interface
    --! @{

    --! Optical input
    optical_i : in std_ulogic_vector(1 downto 0);

    --! @}
    --! @name Analogue board interface
    --! @{

    --! Stop temperature control
    ab_temp_stop_o : out std_ulogic;
    --! Power control
    ab_pwr_on_n_o  : out std_ulogic;

    --! @}
    --! @name Analogue board calibration multiplexer (only one can be active)
    --! @{

    --! Set calibration source to DAC
    ab_cal_dac_o    : out std_ulogic;
    --! Set calibration source to GND
    ab_cal_offset_o : out std_ulogic;
    --! Set calibration source to +VREF
    ab_cal_vref_p_o : out std_ulogic;
    --! Set calibration source to -VREF
    ab_cal_vref_n_o : out std_ulogic;

    --! @}
    --! @name Analogue board DAC interface
    --! @{

    --! DAC data
    ab_dac_din_o  : out std_ulogic;
    --! DAC clock
    ab_dac_sclk_o : out std_ulogic;
    --! DAC chip-select
    ab_dac_cs_o   : out std_ulogic;

    --! @}
    --! @name Analogue board ADC V_MEAS
    --! @{

    --! ADC V_MEAS bit streams M1 and M0
    ab_adc_vs_i       : in  std_ulogic_vector(1 downto 0);
    --! ADC V_MEAS bit stream clock
    ab_adc_vs_clk_i   : in  std_ulogic;
    --! ADC V_MEAS reset (active-low)
    ab_adc_vs_rst_n_o : out std_ulogic;
    --! Calibrate ADC V_MEAS
    ab_sw_in_vs_o     : out std_ulogic;

    --! @}
    --! @name Analogue board ADC I_A
    --! @{

    --! ADC I_A bit streams M1 and M0
    ab_adc_a_i        : in  std_ulogic_vector(1 downto 0);
    --! ADC I_A bit stream clock
    ab_adc_a_clk_i    : in  std_ulogic;
    --! ADC I_A reset (active-low)
    ab_adc_a_rst_n_o  : out std_ulogic;
    --! Calibrate ADC I_A
    ab_sw_in_a_o      : out std_ulogic;

    --! @}
    --! @name Analogue board ADC I_B
    --! @{

    --! ADC I_B bit streams M1 and M0
    ab_adc_b_i        : in  std_ulogic_vector(1 downto 0);
    --! ADC I_B bit stream clock
    ab_adc_b_clk_i    : in  std_ulogic;
    --! ADC I_B reset (active-low)
    ab_adc_b_rst_n_o  : out std_ulogic;
    --! Calibrate ADC I_B
    ab_sw_in_b_o      : out std_ulogic;

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
    pf_pwr_dwn_i    : in std_ulogic;

    --! @}
    --! @name NF interface
    --! @{

    --! NF received FGClite CMD 0
    nf_cmd_0_i   : in std_ulogic;
    --! NF transmitter ready
    nf_tx_rdy_i  : in std_ulogic;

    --! NanoFIP status byte - bit 5
    nf_r_fcser_i : in std_ulogic;
    --! NanoFIP status byte - bit 4
    nf_r_tler_i  : in std_ulogic;
    --! NanoFIP status byte - bit 2
    nf_u_cacer_i : in std_ulogic;
    --! NanoFIP status byte - bit 3
    nf_u_pacer_i : in std_ulogic;

    --! @}
    --! @name 3-wire serial receiver from NF
    --! @{

    --! Frame
    nf_rx_frame_i  : in std_ulogic;
    --! Bit enable
    nf_rx_bit_en_i : in std_ulogic;
    --! Data
    nf_rx_i        : in std_ulogic;

    --! @}
    --! @name 3-wire serial transmitter to NF
    --! @{

    --! Frame
    nf_tx_frame_o  : out std_ulogic;
    --! Bit enable
    nf_tx_bit_en_o : out std_ulogic;
    --! Data
    nf_tx_o        : out std_ulogic;

    --! @}
    --! @name 2 x 3-wire serial receiver from XF
    --! @{

    --! Frame
    xf_rx_frame_i  : in std_ulogic_vector(1 downto 0);
    --! Bit enable
    xf_rx_bit_en_i : in std_ulogic_vector(1 downto 0);
    --! Data
    xf_rx_i        : in std_ulogic_vector(1 downto 0);

    --! @}
    --! @name Control signals to XF
    --! @{

    --! Trigger DIM bus readout
    xf_dim_trig_o   : out std_ulogic;
    --! Reset all DIMs on bus
    xf_dim_rst_o    : out std_ulogic;
    --! Trigger 1-wire bus readout
    xf_ow_trig_o    : out std_ulogic;
    --! 1-wire bus select
    xf_ow_bus_sel_o : out std_ulogic_vector(2 downto 0);

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
end entity cf_top;

--! RTL implementation of cf_top
architecture rtl of cf_top is

  ---------------------------------------------------------------------------
  --! @name Internal Wires
  ---------------------------------------------------------------------------
  --! @{

  -- Safe reset generation
  signal po_rst_n : std_ulogic;
  signal pb_rst_n : std_ulogic;
  signal nf_rst_n : std_ulogic;
  signal rst_n    : std_ulogic;

  -- Input synchronization and glitch filter
  signal leds_test_n_syn   : std_ulogic;
  signal conv_stat_syn     : std_ulogic_vector(15 downto 0);
  signal optical_syn       : std_ulogic_vector(1 downto 0);
  signal interlock_syn     : std_ulogic_vector(1 downto 0);
  signal pf_pwr_flr_syn    : std_ulogic;
  signal pf_pwr_dwn_syn    : std_ulogic;
  signal aux_syn           : std_ulogic;
  signal debug_rx_syn      : std_ulogic;

  -- External SRAM interface
  signal sram_in  : sram_in_t;
  signal sram_out : sram_out_t;

  -- Analogue board interface
  signal ab_in  : ab_in_t;
  signal ab_out : ab_out_t;

  -- NanoFIP interface
  signal nf_in  : nf_in_t;
  signal nf_out : nf_out_t;

  -- Auxiliary FPGA interface
  signal xf_in  : xf_in_t;
  signal xf_out : xf_out_t;

  --! @}

begin -- architecture rtl

  ---------------------------------------------------------------------------
  -- Outputs
  ---------------------------------------------------------------------------

  -- External SRAM interface
  sram_data_io   <= std_logic_vector(sram_out.data) when sram_out.we_n = '0' else (others => 'Z');
  sram_addr_o    <= sram_out.addr;
  sram_ctrl_o(0) <= sram_out.we_n;
  sram_ctrl_o(1) <= sram_out.cs1_n;
  sram_ctrl_o(2) <= sram_out.byte_n;
  sram_ctrl_o(3) <= sram_out.ue_n;
  sram_ctrl_o(4) <= sram_out.le_n;
  sram_ctrl_o(5) <= sram_out.oe_n;
  sram_ctrl_o(6) <= sram_out.cs2;

  -- Analogue board interface
  ab_temp_stop_o    <= ab_out.temp_stop;
  ab_pwr_on_n_o     <= ab_out.pwr_on_n;
  ab_cal_dac_o      <= ab_out.cal_dac;
  ab_cal_offset_o   <= ab_out.cal_offset;
  ab_cal_vref_p_o   <= ab_out.cal_vref_p;
  ab_cal_vref_n_o   <= ab_out.cal_vref_n;
  ab_dac_din_o      <= ab_out.dac_din;
  ab_dac_sclk_o     <= ab_out.dac_sclk;
  ab_dac_cs_o       <= ab_out.dac_cs;
  ab_adc_vs_rst_n_o <= ab_out.adc_vs_rst_n;
  ab_sw_in_vs_o     <= ab_out.sw_in_vs;
  ab_adc_a_rst_n_o  <= ab_out.adc_a_rst_n;
  ab_sw_in_a_o      <= ab_out.sw_in_a;
  ab_adc_b_rst_n_o  <= ab_out.adc_b_rst_n;
  ab_sw_in_b_o      <= ab_out.sw_in_b;

  -- NanoFIP interface
  nf_tx_frame_o  <= nf_out.tx_frame;
  nf_tx_bit_en_o <= nf_out.tx_bit_en;
  nf_tx_o        <= nf_out.tx;

  -- Auxiliary FPGA interface
  xf_dim_trig_o   <= xf_out.dim_trig;
  xf_dim_rst_o    <= xf_out.dim_rst;
  xf_ow_trig_o    <= xf_out.ow_trig;
  xf_ow_bus_sel_o <= xf_out.ow_bus_select;

  ---------------------------------------------------------------------------
  -- Signal Assignments
  ---------------------------------------------------------------------------

  -- Safe reset generation
  rst_n <= po_rst_n and pb_rst_n and nf_rst_n;

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
      rst_asy_io => po_rst_i,
      rst_o      => po_rst_n);

  --! Safe push-button reset generation
  pb_reset_inst : entity work.reset_generator
    generic map (
      num_delay_g => 4,
      active_g    => '0')
    port map (
      clk_i     => clk_i,
      rst_asy_i => pb_rst_n_i,
      rst_o     => pb_rst_n);

  --! Safe NF reset generation
  nf_reset_inst : entity work.reset_generator
    generic map (
      num_delay_g => 4,
      active_g    => '0')
    port map (
      clk_i     => clk_i,
      rst_asy_i => nf_rst_n_i,
      rst_o     => nf_rst_n);

  --! Input synchronization and glitch filter for power converter status
  ext_inputs_inst_0 : entity work.external_inputs
    generic map (
      init_value_g => '0',
      num_inputs_g => conv_stat_i'length)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_n,
      rst_syn_i   => '0',
      sig_i       => conv_stat_i,
      sig_o       => conv_stat_syn);

  --! Input synchronization and glitch filter for SRAM data
  ext_inputs_inst_1 : entity work.external_inputs
    generic map (
      init_value_g => '0',
      num_inputs_g => sram_data_io'length)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_n,
      rst_syn_i   => '0',
      sig_i       => std_ulogic_vector(sram_data_io),
      sig_o       => sram_in.data);

  --! Input synchronization and glitch filter for all other inputs
  ext_inputs_inst_2 : entity work.external_inputs
    generic map (
      init_value_g => '0',
      num_inputs_g => 33)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_n,
      rst_syn_i   => '0',

      sig_i(0)    => leds_test_n_i,
      sig_i(1)    => optical_i(0),
      sig_i(2)    => optical_i(1),
      sig_i(3)    => ab_adc_vs_i(0),
      sig_i(4)    => ab_adc_vs_i(1),
      sig_i(5)    => ab_adc_vs_clk_i,
      sig_i(6)    => ab_adc_a_i(0),
      sig_i(7)    => ab_adc_a_i(1),
      sig_i(8)    => ab_adc_a_clk_i,
      sig_i(9)    => ab_adc_b_i(0),
      sig_i(10)   => ab_adc_b_i(1),
      sig_i(11)   => ab_adc_b_clk_i,
      sig_i(12)   => interlock_i(0),
      sig_i(13)   => interlock_i(1),
      sig_i(14)   => pf_pwr_flr_i,
      sig_i(15)   => pf_pwr_dwn_i,
      sig_i(16)   => nf_cmd_0_i,
      sig_i(17)   => nf_tx_rdy_i,
      sig_i(18)   => nf_r_fcser_i,
      sig_i(19)   => nf_r_tler_i,
      sig_i(20)   => nf_u_cacer_i,
      sig_i(21)   => nf_u_pacer_i,
      sig_i(22)   => nf_rx_frame_i,
      sig_i(23)   => nf_rx_bit_en_i,
      sig_i(24)   => nf_rx_i,
      sig_i(25)   => xf_rx_frame_i(0),
      sig_i(26)   => xf_rx_frame_i(1),
      sig_i(27)   => xf_rx_bit_en_i(0),
      sig_i(28)   => xf_rx_bit_en_i(1),
      sig_i(29)   => xf_rx_i(0),
      sig_i(30)   => xf_rx_i(1),
      sig_i(31)   => aux_i,
      sig_i(32)   => debug_rx_i,

      sig_o(0)    => leds_test_n_syn,
      sig_o(1)    => optical_syn(0),
      sig_o(2)    => optical_syn(1),
      sig_o(3)    => ab_in.adc_vs(0),
      sig_o(4)    => ab_in.adc_vs(1),
      sig_o(5)    => ab_in.adc_vs_clk,
      sig_o(6)    => ab_in.adc_a(0),
      sig_o(7)    => ab_in.adc_a(1),
      sig_o(8)    => ab_in.adc_a_clk,
      sig_o(9)    => ab_in.adc_b(0),
      sig_o(10)   => ab_in.adc_b(1),
      sig_o(11)   => ab_in.adc_b_clk,
      sig_o(12)   => interlock_syn(0),
      sig_o(13)   => interlock_syn(1),
      sig_o(14)   => pf_pwr_flr_syn,
      sig_o(15)   => pf_pwr_dwn_syn,
      sig_o(16)   => nf_in.cmd_0,
      sig_o(17)   => nf_in.tx_rdy,
      sig_o(18)   => nf_in.r_fcser,
      sig_o(19)   => nf_in.r_tler,
      sig_o(20)   => nf_in.u_cacer,
      sig_o(21)   => nf_in.u_pacer,
      sig_o(22)   => nf_in.rx_frame,
      sig_o(23)   => nf_in.rx_bit_en,
      sig_o(24)   => nf_in.rx,
      sig_o(25)   => xf_in.rx_frame(0),
      sig_o(26)   => xf_in.rx_frame(1),
      sig_o(27)   => xf_in.rx_bit_en(0),
      sig_o(28)   => xf_in.rx_bit_en(1),
      sig_o(29)   => xf_in.rx(0),
      sig_o(30)   => xf_in.rx(1),
      sig_o(31)   => aux_syn,
      sig_o(32)   => debug_rx_syn);

  --! CF core component
  cf_inst : entity work.cf
    port map (
      clk_i           => clk_i,
      rst_asy_n_i     => rst_n,
      rst_syn_i       => '0',

      leds_red_n_o    => leds_red_n_o,
      leds_green_n_o  => leds_green_n_o,
      leds_test_n_i   => leds_test_n_syn,

      conv_cmd_o      => conv_cmd_o,
      conv_stat_i     => conv_stat_syn,

      sram_i          => sram_in,
      sram_o          => sram_out,

      optical_i       => optical_syn,

      ab_i            => ab_in,
      ab_o            => ab_out,

      interlock_i     => interlock_syn,
      interlock_o     => interlock_o,

      pf_req_n_o      => pf_req_n_o,
      pf_pwr_dwn_en_o => pf_pwr_dwn_en_o,
      pf_pwr_flr_i    => pf_pwr_flr_syn,
      pf_pwr_dwn_i    => pf_pwr_dwn_syn,

      nf_i            => nf_in,
      nf_o            => nf_out,

      xf_i            => xf_in,
      xf_o            => xf_out,

      aux_i           => aux_syn,
      aux_o           => aux_o,

      debug_rx_i      => debug_rx_syn,
      debug_tx_o      => debug_tx_o,
      debug_probe_o   => debug_probe_o);

end architecture rtl;
