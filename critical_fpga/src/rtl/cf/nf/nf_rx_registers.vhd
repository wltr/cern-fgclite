-------------------------------------------------------------------------------
--! @file      nf_rx_registers.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-07-22
--! @brief     NanoFIP receiver registers.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nf_pkg.all;
use work.cf_pkg.all;

--! @brief Entity declaration of nf_rx_registers
--! @details
--! The gateway is sending 32-bit long commands to the FGClite which are stored
--! in this register map. Each address is then assigned to internal control
--! signals.

entity nf_rx_registers is
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
    --! @name NanoFIP write interface
    --! @{

    --! Write enable
    wr_en_i   : in std_ulogic;
    --! Address
    addr_i    : in std_ulogic_vector(1 downto 0);
    --! Data
    data_i    : in std_ulogic_vector(31 downto 0);

    --! @}
    --! @name Registers
    --! @{

    --! Gateway commands
    command_o : out nf_command_t);

    --! @}
end entity nf_rx_registers;

--! RTL implementation of nf_rx_registers
architecture rtl of nf_rx_registers is

  ---------------------------------------------------------------------------
  --! @name Types and Constants
  ---------------------------------------------------------------------------
  --! @{

  type reg_t is array (0 to 2**addr_i'length - 1) of std_ulogic_vector(data_i'range);

  --! @}
  ---------------------------------------------------------------------------
  --! @name Internal Registers
  ---------------------------------------------------------------------------
  --! @{

  signal reg  : reg_t;
  signal cmd1 : std_ulogic;

  --! @}

begin -- architecture rtl

  ---------------------------------------------------------------------------
  -- Outputs
  ---------------------------------------------------------------------------

  -- Command 0
  command_o.sefi_test_vs_m0 <= reg(0)(27 downto 26);
  command_o.sefi_test_vs_m1 <= reg(0)(25 downto 24);
  command_o.sefi_test_ia_m0 <= reg(0)(23 downto 22);
  command_o.sefi_test_ia_m1 <= reg(0)(21 downto 20);
  command_o.sefi_test_ib_m0 <= reg(0)(19 downto 18);
  command_o.sefi_test_ib_m1 <= reg(0)(17 downto 16);
  command_o.ms_period       <= reg(0)(15 downto 0);

  -- Command 1
  command_o.serial_data     <= reg(1);
  command_o.serial_data_en  <= cmd1;

  -- Command 2
  command_o.index           <= reg(2)(30 downto 16);
  command_o.index_type      <= reg(2)(10 downto 8);
  command_o.adc_log_freeze  <= reg(2)(6);
  command_o.dim_log_freeze  <= reg(2)(5);
  command_o.dim_reset       <= reg(2)(4);
  command_o.ow_scan         <= reg(2)(3);
  command_o.ow_bus_select   <= reg(2)(2 downto 0);

  -- Command 3

  -- Had to flip signed bit for gateway
  command_o.v_ref           <= (not reg(3)(31)) & reg(3)(30 downto 16);

  command_o.cal_source      <= reg(3)(15 downto 14);
  command_o.cal_vs_en       <= reg(3)(13);
  command_o.cal_ia_en       <= reg(3)(12);
  command_o.cal_ib_en       <= reg(3)(11);
  command_o.adc_vs_reset_n  <= reg(3)(10);
  command_o.adc_ia_reset_n  <= reg(3)(9);
  command_o.adc_ib_reset_n  <= reg(3)(8);
  command_o.vs_cmd          <= reg(3)(7 downto 0);

  ---------------------------------------------------------------------------
  -- Registers
  ---------------------------------------------------------------------------

  regs : process (clk_i, rst_asy_n_i) is
    procedure reset is
    begin
      reg <= (others => (others => '0'));

      reg(0)(15 downto 0) <= ms_period_c;
      reg(3)(10 downto 8) <= "111";

      cmd1 <= '0';
    end procedure reset;
  begin -- process regs
    if rst_asy_n_i = '0' then
      reset;
    elsif rising_edge(clk_i) then
      if rst_syn_i = '1' then
        reset;
      else
        cmd1 <= '0';

        if wr_en_i = '1' then
          reg(to_integer(unsigned(addr_i))) <= data_i;

          if to_integer(unsigned(addr_i)) = 1 then
            cmd1 <= '1';
          end if;
        end if;
      end if;
    end if;
  end process regs;

end architecture rtl;
