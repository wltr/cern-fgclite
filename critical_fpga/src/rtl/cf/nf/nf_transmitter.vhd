-------------------------------------------------------------------------------
--! @file      nf_transmitter.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-07-23
--! @brief     NanoFIP transmitter.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nf_pkg.all;

--! @brief Entity declaration of nf_transmitter
--! @details
--! All critical registers and the paged memory are concatenated and
--! transmitted to the gateway.

entity nf_transmitter is
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
    --! @name Control signals
    --! @{

    --! Start transmission
    start_i : in std_ulogic;

    --! @}
    --! @name Transmitter
    --! @{

    --! Address
    tx_addr_o    : out std_ulogic_vector(6 downto 0);
    --! Data
    tx_data_o    : out std_ulogic_vector(7 downto 0);
    --! Data enable
    tx_data_en_o : out std_ulogic;
    --! Busy flag
    tx_busy_i    : in  std_ulogic;
    --! Done flag
    tx_done_i    : in  std_ulogic;

    --! @}
    --! @name Memory
    --! @{

    --! Read enable
    mem_rd_en_o   : out std_ulogic;
    --! Address
    mem_addr_o    : out std_ulogic_vector(6 downto 0);
    --! Data
    mem_data_i    : in  std_ulogic_vector(7 downto 0);
    --! Data enable
    mem_data_en_i : in  std_ulogic);

    --! @}
end entity nf_transmitter;

--! RTL implementation of nf_transmitter
architecture rtl of nf_transmitter is

  ---------------------------------------------------------------------------
  --! @name Types and Constants
  ---------------------------------------------------------------------------
  --! @{

  constant nf_addr_offset_c : natural := 2;
  constant num_bytes_c      : natural := 124;

  --! @}
  ---------------------------------------------------------------------------
  --! @name Internal Registers
  ---------------------------------------------------------------------------
  --! @{

  signal addr  : unsigned(tx_addr_o'range);
  signal rd_en : std_ulogic;
  signal busy  : std_ulogic;

  --! @}

begin -- architecture rtl

  ---------------------------------------------------------------------------
  -- Outputs
  ---------------------------------------------------------------------------

  tx_addr_o    <= std_ulogic_vector(addr + nf_addr_offset_c);
  tx_data_o    <= mem_data_i;
  tx_data_en_o <= mem_data_en_i;

  mem_rd_en_o <= rd_en;
  mem_addr_o  <= std_ulogic_vector(addr);

  ---------------------------------------------------------------------------
  -- Registers
  ---------------------------------------------------------------------------

  regs : process (clk_i, rst_asy_n_i) is
    procedure reset is
    begin
      addr  <= to_unsigned(0, addr'length);
      rd_en <= '0';
      busy  <= '0';
    end procedure reset;
  begin -- process regs
    if rst_asy_n_i = '0' then
      reset;
    elsif rising_edge(clk_i) then
      if rst_syn_i = '1' then
        reset;
      else
        -- Defaults
        rd_en <= '0';

        if busy = '0' and tx_busy_i = '0' and start_i = '1' then
          rd_en <= '1';
          busy  <= '1';
        elsif busy = '1' and tx_done_i = '1' then
          busy <= '0';
          if to_integer(addr) < num_bytes_c - 1 then
            rd_en <= '1';
            busy  <= '1';
          end if;
        end if;

        if start_i = '1' then
          addr <= to_unsigned(0, addr'length);
        elsif tx_done_i = '1' then
          addr <= addr + 1;
        end if;
      end if;
    end if;
  end process regs;

end architecture rtl;
