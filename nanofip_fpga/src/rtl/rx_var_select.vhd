-------------------------------------------------------------------------------
--! @file      rx_var_select.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-04-03
--! @brief     Toggle between VAR1 and VAR2 when receiving data.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

--! @brief Entity declaration of rx_var_select
--! @details
--! Multiplexer control for data reception. When VAR1 or VAR2 are received,
--! the Wishbone interface will be connected to the corresponding receiver.

entity rx_var_select is
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
    --! @name Ready signals
    --! @{

    --! VAR1 is ready
    var1_rdy_i : in std_ulogic;
    --! VAR2 is ready
    var2_rdy_i : in std_ulogic;

    --! @}
    --! @name Multiplexer control
    --! @{

    --! Select receiver, 0 = VAR1, 1 = VAR2, VAR2 is default
    var_select_o : out std_ulogic);

    --! @}
end entity rx_var_select;

--! RTL implementation of rx_var_select
architecture rtl of rx_var_select is

  ---------------------------------------------------------------------------
  --! @name Internal Registers
  ---------------------------------------------------------------------------
  --! @{

  signal var_select : std_ulogic;

  --! @}

begin -- architecture rtl

  ---------------------------------------------------------------------------
  -- Outputs
  ---------------------------------------------------------------------------

  var_select_o <= var_select;

  ---------------------------------------------------------------------------
  -- Registering
  ---------------------------------------------------------------------------

  regs : process (clk_i, rst_asy_n_i) is
    procedure reset is
    begin
      var_select <= '1';
    end procedure reset;
  begin -- process regs
    if rst_asy_n_i = '0' then
      reset;
    elsif rising_edge(clk_i) then
      if rst_syn_i = '1' then
        reset;
      elsif var1_rdy_i = '1' then
        var_select <= '0';
      elsif var2_rdy_i = '1' then
        var_select <= '1';
      end if;
    end if;
  end process regs;

end architecture rtl;
