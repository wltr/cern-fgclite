-------------------------------------------------------------------------------
--! @file      field_bus_timing.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-11-09
--! @brief     Field-bus timing synchronization.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.cf_pkg.all;

--! @brief Entity declaration of field_bus_timing
--! @details
--! Synchronize internal timing to COMMAND 0 of field-bus transmission.

entity field_bus_timing is
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
    --! @name Timing signals
    --! @{

    --! Cycle synchronization marker
    cmd_0_i        : in std_ulogic;
    --! Millisecond strobe
    ms_strobe_o    : out std_ulogic;
    --! Millisecond period (nominally 40000 * 25 ns clock cycles)
    ms_period_i    : in std_ulogic_vector(15 downto 0);
    --! Millisecond number (0-19)
    ms_number_o    : out std_ulogic_vector(0 to 19);
    --! Field-bus cycle period in 25 ns clock cycles (nominally 800000)
    cycle_period_o : out std_ulogic_vector(19 downto 0));

    --! @}
end entity field_bus_timing;

--! RTL implementation of field_bus_timing
architecture rtl of field_bus_timing is

  ---------------------------------------------------------------------------
  --! @name Internal Registers
  ---------------------------------------------------------------------------
  --! @{

  signal ms_period : std_ulogic_vector(15 downto 0);
  signal ms_number : unsigned(15 downto 0);

  signal ms_strobe_dlyd : std_ulogic;

  --! @}
  ---------------------------------------------------------------------------
  --! @name Internal Wires
  ---------------------------------------------------------------------------
  --! @{

  signal ms_strobe : std_ulogic;
  signal cmd_0     : std_ulogic;

  --! @}

begin -- architecture rtl

  ---------------------------------------------------------------------------
  -- Outputs
  ---------------------------------------------------------------------------

  ms_number_o(00) <= '1' when (ms_strobe_dlyd = '1' and to_integer(ms_number) = 00) else '0';
  ms_number_o(01) <= '1' when (ms_strobe_dlyd = '1' and to_integer(ms_number) = 01) else '0';
  ms_number_o(02) <= '1' when (ms_strobe_dlyd = '1' and to_integer(ms_number) = 02) else '0';
  ms_number_o(03) <= '1' when (ms_strobe_dlyd = '1' and to_integer(ms_number) = 03) else '0';
  ms_number_o(04) <= '1' when (ms_strobe_dlyd = '1' and to_integer(ms_number) = 04) else '0';
  ms_number_o(05) <= '1' when (ms_strobe_dlyd = '1' and to_integer(ms_number) = 05) else '0';
  ms_number_o(06) <= '1' when (ms_strobe_dlyd = '1' and to_integer(ms_number) = 06) else '0';
  ms_number_o(07) <= '1' when (ms_strobe_dlyd = '1' and to_integer(ms_number) = 07) else '0';
  ms_number_o(08) <= '1' when (ms_strobe_dlyd = '1' and to_integer(ms_number) = 08) else '0';
  ms_number_o(09) <= '1' when (ms_strobe_dlyd = '1' and to_integer(ms_number) = 09) else '0';
  ms_number_o(10) <= '1' when (ms_strobe_dlyd = '1' and to_integer(ms_number) = 10) else '0';
  ms_number_o(11) <= '1' when (ms_strobe_dlyd = '1' and to_integer(ms_number) = 11) else '0';
  ms_number_o(12) <= '1' when (ms_strobe_dlyd = '1' and to_integer(ms_number) = 12) else '0';
  ms_number_o(13) <= '1' when (ms_strobe_dlyd = '1' and to_integer(ms_number) = 13) else '0';
  ms_number_o(14) <= '1' when (ms_strobe_dlyd = '1' and to_integer(ms_number) = 14) else '0';
  ms_number_o(15) <= '1' when (ms_strobe_dlyd = '1' and to_integer(ms_number) = 15) else '0';
  ms_number_o(16) <= '1' when (ms_strobe_dlyd = '1' and to_integer(ms_number) = 16) else '0';
  ms_number_o(17) <= '1' when (ms_strobe_dlyd = '1' and to_integer(ms_number) = 17) else '0';
  ms_number_o(18) <= '1' when (ms_strobe_dlyd = '1' and to_integer(ms_number) = 18) else '0';
  ms_number_o(19) <= '1' when (ms_strobe_dlyd = '1' and to_integer(ms_number) = 19) else '0';

  ms_strobe_o <= ms_strobe_dlyd;

  ---------------------------------------------------------------------------
  -- Instances
  ---------------------------------------------------------------------------

  --! Detect rising edges on COMMAND 0 input signal
  edge_detector_inst : entity work.edge_detector
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      en_i        => '1',
      ack_i       => '0',
      sig_i       => cmd_0_i,
      edge_o      => cmd_0);

  --! Millisecond strobe generator
  strobe_gen_inst : entity work.strobe_generator
    generic map (
      init_value_g => 0,
      bit_width_g  => 16)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      en_i        => '1',

      period_i    => ms_period,

      pre_i       => cmd_0,
      pre_value_i => cmd_0_pre_value_c,

      strobe_o    => ms_strobe);

  --! Field-bus cycle period counter
  stop_watch_inst : entity work.stop_watch
    generic map (
      bit_width_g => 20)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      en_i        => '1',

      sample_i    => cmd_0,

      value_o     => cycle_period_o);

  ---------------------------------------------------------------------------
  -- Registers
  ---------------------------------------------------------------------------

  regs : process (clk_i, rst_asy_n_i) is
    procedure reset is
    begin
      ms_period <= ms_period_c;
      ms_number <= to_unsigned(0, ms_number'length);

      ms_strobe_dlyd <= '0';
    end procedure reset;
  begin -- process regs
    if rst_asy_n_i = '0' then
      reset;
    elsif rising_edge(clk_i) then
      if rst_syn_i = '1' then
        reset;
      else
        ms_strobe_dlyd <= ms_strobe;

        if cmd_0 = '1' then
          ms_number <= to_unsigned(0, ms_number'length);
        elsif ms_strobe = '1' then
          if to_integer(ms_number) < 19 then
            ms_number <= ms_number + 1;
          else
            ms_number <= to_unsigned(0, ms_number'length);
          end if;
        end if;

        if ms_strobe = '1' and to_integer(ms_number) = 2 then
          ms_period <= ms_period_i;
        end if;
      end if;
    end if;
  end process regs;

end architecture rtl;
