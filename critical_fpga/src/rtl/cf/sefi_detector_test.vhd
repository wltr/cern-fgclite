-------------------------------------------------------------------------------
--! @file      sefi_detector_test.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-11-19
--! @brief     Test SEFI detectors.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

--! @brief Entity declaration of sefi_detector_test
--! @details
--! Emulate SEFIs in order to test SEFI detectors.

entity sefi_detector_test is
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
    --! @name SEFI signals
    --! @{

    --! Millisecond strobe indicating start of cycle
    ms_0_strobe_i : in std_ulogic;
    --! Test enable
    en_i          : in std_ulogic;
    --! Select mode
    mode_i        : in std_ulogic_vector(1 downto 0);
    --! Sample strobe for toggling signal
    strb_i        : in std_ulogic;
    --! Input from ADCs
    adc_i         : in std_ulogic;
    --! Output
    test_o        : out std_ulogic);

    --! @}
end entity sefi_detector_test;

--! RTL implementation of sefi_detector_test
architecture rtl of sefi_detector_test is

  ---------------------------------------------------------------------------
  --! @name Internal Registers
  ---------------------------------------------------------------------------
  --! @{

  signal toggle : std_ulogic;
  signal en     : std_ulogic;

  --! @}
  ---------------------------------------------------------------------------
  --! @name Internal Wires
  ---------------------------------------------------------------------------
  --! @{

  signal test : std_ulogic;

  --! @}

begin -- architecture rtl

  ---------------------------------------------------------------------------
  -- Outputs
  ---------------------------------------------------------------------------

  test_o <= test when en = '0' else adc_i;

  ---------------------------------------------------------------------------
  -- Signal Assignments
  ---------------------------------------------------------------------------

  with mode_i select test <=
    adc_i  when "00",
    '0'    when "01",
    '1'    when "10",
    toggle when "11",
    '0'    when others;

  ---------------------------------------------------------------------------
  -- Registers
  ---------------------------------------------------------------------------

  regs : process (clk_i, rst_asy_n_i) is
    procedure reset is
    begin
      toggle <= '0';
      en     <= '0';
    end procedure reset;
  begin -- process regs
    if rst_asy_n_i = '0' then
      reset;
    elsif rising_edge(clk_i) then
      if rst_syn_i = '1' then
        reset;
      else
        if strb_i = '1' then
          toggle <= not toggle;
        end if;

        if ms_0_strobe_i = '1' then
          en <= en_i;
        end if;
      end if;
    end if;
  end process regs;

end architecture rtl;
