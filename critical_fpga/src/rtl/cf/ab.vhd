-------------------------------------------------------------------------------
--! @file      ab.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-07-08
--! @brief     Analogue board control and filters.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.ab_pkg.all;
use work.nf_pkg.all;
use work.ads1281_filter_pkg.all;

--! @brief Entity declaration of ab
--! @details
--! This component controls the analogue board switches, DAC and ADCs. It
--! also provides FIR filter implementations for the ADCs and has an internal
--! pattern generator for test purposes.

entity ab is
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
    --! @name Analogue board interface
    --! @{

    --! Inputs
    ab_i : in  ab_in_t;
    --! Outputs
    ab_o : out ab_out_t;

    --! @}
    --! @name Internal interface
    --! @{

    --! Millisecond strobe
    ms_strobe_i   : in std_ulogic;
    --! Millisecond strobe indicating start of cycle
    ms_0_strobe_i : in std_ulogic;
    --! Commands
    command_i     : in nf_command_t;
    --! SEFI detector
    sefi_o        : out std_ulogic_vector(5 downto 0);
    --! Voltage reference when ramping down
    pf_vref_i     : in  std_ulogic_vector(15 downto 0);
    --! Voltage reference enable
    pf_vref_en_i  : in  std_ulogic;
    --! Voltage reference override
    pf_vref_ovr_i : in  std_ulogic;

    --! @}
    --! @name ADC results
    --! @{

    --! ADC VS result
    adc_vs_o    : out std_ulogic_vector(23 downto 0);
    --! ADC VS result enable
    adc_vs_en_o : out std_ulogic;
    --! ADC IA result
    adc_ia_o    : out std_ulogic_vector(23 downto 0);
    --! ADC IA result enable
    adc_ia_en_o : out std_ulogic;
    --! ADC IB result
    adc_ib_o    : out std_ulogic_vector(23 downto 0);
    --! ADC IB result enable
    adc_ib_en_o : out std_ulogic;

    --! @}
    --! @name Accumulator results
    --! @{

    --! Accumulator VS result
    acc_vs_o    : out std_ulogic_vector(31 downto 0);
    --! Accumulator VS result enable
    acc_vs_en_o : out std_ulogic;
    --! Accumulator IA result
    acc_ia_o    : out std_ulogic_vector(31 downto 0);
    --! Accumulator IA result enable
    acc_ia_en_o : out std_ulogic;
    --! Accumulator IB result
    acc_ib_o    : out std_ulogic_vector(31 downto 0);
    --! Accumulator IB result enable
    acc_ib_en_o : out std_ulogic);

    --! @}
end entity ab;

--! RTL implementation of ab
architecture rtl of ab is

  ---------------------------------------------------------------------------
  --! @name Types and Constants
  ---------------------------------------------------------------------------
  --! @{

  type acc_result_t is array (0 to 2) of std_ulogic_vector(27 downto 0);

  type sefi_mode_t is array (0 to 5) of std_ulogic_vector(1 downto 0);

  --! @}
  ---------------------------------------------------------------------------
  --! @name Internal Wires
  ---------------------------------------------------------------------------
  --! @{

  signal adc_m0 : std_ulogic_vector(2 downto 0);
  signal adc_m1 : std_ulogic_vector(2 downto 0);

  signal adc_result    : ads1281_filter_result_t;
  signal adc_result_en : std_ulogic_vector(2 downto 0);

  signal acc_result    : acc_result_t;
  signal acc_result_en : std_ulogic_vector(2 downto 0);

  signal ab : ab_out_t;

  signal sample_strb : std_ulogic;

  signal adc_m   : std_ulogic_vector(5 downto 0);
  signal sefi_in : std_ulogic_vector(5 downto 0);

  signal sefi_mode : sefi_mode_t;

  signal vref    : std_ulogic_vector(15 downto 0);
  signal vref_en : std_ulogic;
  --! @}

begin -- architecture rtl

  ---------------------------------------------------------------------------
  -- Outputs
  ---------------------------------------------------------------------------

  -- Power up analogue board
  ab_o.pwr_on_n   <= '0';
  -- Start temperature control on analogue board
  ab_o.temp_stop  <= '0';

  ab_o.cal_dac    <= ab.cal_dac;
  ab_o.cal_offset <= ab.cal_offset;
  ab_o.cal_vref_p <= ab.cal_vref_p;
  ab_o.cal_vref_n <= ab.cal_vref_n;

  ab_o.adc_vs_rst_n <= ab.adc_vs_rst_n;
  ab_o.sw_in_vs     <= ab.sw_in_vs;

  ab_o.adc_a_rst_n  <= ab.adc_a_rst_n;
  ab_o.sw_in_a      <= ab.sw_in_a;

  ab_o.adc_b_rst_n  <= ab.adc_b_rst_n;
  ab_o.sw_in_b      <= ab.sw_in_b;

  adc_vs_o    <= adc_result(0);
  adc_vs_en_o <= adc_result_en(0);

  adc_ia_o    <= adc_result(1);
  adc_ia_en_o <= adc_result_en(1);

  adc_ib_o    <= adc_result(2);
  adc_ib_en_o <= adc_result_en(2);

  acc_vs_o(31 downto 28) <= (31 downto 28 => acc_result(0)(acc_result(0)'high));
  acc_vs_o(27 downto 0)  <= acc_result(0);
  acc_vs_en_o            <= acc_result_en(0);

  acc_ia_o(31 downto 28) <= (31 downto 28 => acc_result(1)(acc_result(1)'high));
  acc_ia_o(27 downto 0)  <= acc_result(1);
  acc_ia_en_o            <= acc_result_en(1);

  acc_ib_o(31 downto 28) <= (31 downto 28 => acc_result(2)(acc_result(2)'high));
  acc_ib_o(27 downto 0)  <= acc_result(2);
  acc_ib_en_o            <= acc_result_en(2);

  ---------------------------------------------------------------------------
  -- Signal Assignments
  ---------------------------------------------------------------------------

  adc_m0 <= ab_i.adc_vs(0) & ab_i.adc_a(0) & ab_i.adc_b(0);
  adc_m1 <= ab_i.adc_vs(1) & ab_i.adc_a(1) & ab_i.adc_b(1);

  adc_m <= ab_i.adc_b & ab_i.adc_a & ab_i.adc_vs;

  sefi_mode(0) <= command_i.sefi_test_vs_m0;
  sefi_mode(1) <= command_i.sefi_test_vs_m1;
  sefi_mode(2) <= command_i.sefi_test_ia_m0;
  sefi_mode(3) <= command_i.sefi_test_ia_m1;
  sefi_mode(4) <= command_i.sefi_test_ib_m0;
  sefi_mode(5) <= command_i.sefi_test_ib_m1;

  vref    <= pf_vref_i when pf_vref_ovr_i = '1' else command_i.v_ref;
  vref_en <= pf_vref_en_i when pf_vref_ovr_i = '1' else ms_0_strobe_i;

  ---------------------------------------------------------------------------
  -- Instances
  ---------------------------------------------------------------------------

  --! SEFI detector test
  sefi_test_gen : for i in 0 to 5 generate
    sefi_test_inst : entity work.sefi_detector_test
      port map (
        clk_i       => clk_i,
        rst_asy_n_i => rst_asy_n_i,
        rst_syn_i   => rst_syn_i,

        ms_0_strobe_i => ms_0_strobe_i,
        en_i          => command_i.vs_cmd(0),
        mode_i        => sefi_mode(i),
        strb_i        => sample_strb,
        adc_i         => adc_m(i),
        test_o        => sefi_in(i));
  end generate sefi_test_gen;

  --! SEFI detectors
  sefi_detector_gen : for i in 0 to 5 generate
    sefi_detector_inst : entity work.sefi_detector
      generic map (
        num_g => 30)
      port map (
        clk_i       => clk_i,
        rst_asy_n_i => rst_asy_n_i,
        rst_syn_i   => ms_0_strobe_i,

        en_i        => sample_strb,
        sig_i       => sefi_in(i),
        sefi_o      => sefi_o(i));
  end generate sefi_detector_gen;

  --! Analogue board DAC interface
  max5541_interface_inst : entity work.max5541_interface
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      data_i      => vref,
      data_en_i   => vref_en,
      busy_o      => open,
      done_o      => open,

      cs_o        => ab_o.dac_cs,
      sclk_o      => ab_o.dac_sclk,
      din_o       => ab_o.dac_din);

  --! ADS1281 filter
  ads1281_filter_inst : entity work.ads1281_filter
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      strb_ms_i     => ms_strobe_i,
      strb_sample_o => sample_strb,

      adc_m0_i    => adc_m0,
      adc_m1_i    => adc_m1,

      result_o    => adc_result,
      result_en_o => adc_result_en);

  --! ADS1281 result accumulator
  ads1281_result_accumulator_gen : for i in 0 to 2 generate
    ads1281_result_accumulator_inst : entity work.ads1281_result_accumulator
      generic map (
        num_results_g => 10)
      port map (
        clk_i       => clk_i,
        rst_asy_n_i => rst_asy_n_i,
        rst_syn_i   => ms_0_strobe_i,

        result_i    => adc_result(i),
        result_en_i => adc_result_en(i),

        result_o    => acc_result(i),
        result_en_o => acc_result_en(i));
  end generate ads1281_result_accumulator_gen;

  ---------------------------------------------------------------------------
  -- Registers
  ---------------------------------------------------------------------------

  regs : process (clk_i, rst_asy_n_i) is
    procedure reset is
    begin
      ab.cal_dac    <= '0';
      ab.cal_offset <= '0';
      ab.cal_vref_p <= '0';
      ab.cal_vref_n <= '0';

      ab.adc_vs_rst_n <= '1';
      ab.sw_in_vs     <= '0';

      ab.adc_a_rst_n  <= '1';
      ab.sw_in_a      <= '0';

      ab.adc_b_rst_n  <= '1';
      ab.sw_in_b      <= '0';
    end procedure reset;
  begin -- process regs
    if rst_asy_n_i = '0' then
      reset;
    elsif rising_edge(clk_i) then
      if rst_syn_i = '1' then
        reset;
      elsif ms_0_strobe_i = '1' then
        case command_i.cal_source is
          when "00" =>
            ab.cal_dac    <= '0';
            ab.cal_offset <= '1';
            ab.cal_vref_n <= '0';
            ab.cal_vref_p <= '0';
          when "01" =>
            ab.cal_dac    <= '0';
            ab.cal_offset <= '0';
            ab.cal_vref_n <= '0';
            ab.cal_vref_p <= '1';
          when "10" =>
            ab.cal_dac    <= '0';
            ab.cal_offset <= '0';
            ab.cal_vref_n <= '1';
            ab.cal_vref_p <= '0';
          when "11" =>
            ab.cal_dac    <= '1';
            ab.cal_offset <= '0';
            ab.cal_vref_n <= '0';
            ab.cal_vref_p <= '0';
          when others => null;
        end case;

        ab.adc_vs_rst_n <= command_i.adc_vs_reset_n;
        ab.adc_a_rst_n  <= command_i.adc_ia_reset_n;
        ab.adc_b_rst_n  <= command_i.adc_ib_reset_n;

        if command_i.vs_cmd(0) = '0' then
          ab.sw_in_vs <= command_i.cal_vs_en;
          ab.sw_in_a  <= command_i.cal_ia_en;
          ab.sw_in_b  <= command_i.cal_ib_en;
        else
          ab.sw_in_vs <= '0';
          ab.sw_in_a  <= '0';
          ab.sw_in_b  <= '0';
        end if;
      end if;
    end if;
  end process regs;

end architecture rtl;
