-------------------------------------------------------------------------------
--! @file      fetch_page_ow.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-11-19
--! @brief     Prepare one-wire page for NanoFIP communication.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

--! @brief Entity declaration of fetch_page_ow
--! @details
--! This component prepares the one-wire page for the NanoFIP response.

entity fetch_page_ow is
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
    --! @name Commands
    --! @{

    --! Start flag
    start_i    : in  std_ulogic;
    --! Done flag
    done_o     : out std_ulogic;
    --! Memory index
    idx_i      : in  std_ulogic_vector(14 downto 0);

    --! @}
    --! @name Memory page interface
    --! @{

    --! Address
    page_addr_o  : out std_ulogic_vector(5 downto 0);
    --! Write enable
    page_wr_en_o : out std_ulogic;
    --! Data output
    page_data_o  : out std_ulogic_vector(7 downto 0);
    --! Done flag
    page_done_i  : in  std_ulogic;

    --! @}
    --! @name One-wire data
    --! @{

    --! Address
    ow_addr_o    : out std_ulogic_vector(5 downto 0);
    --! Read enable
    ow_rd_en_o   : out std_ulogic;
    --! Data input
    ow_data_i    : in  std_ulogic_vector(79 downto 0);
    --! Data input enable
    ow_data_en_i : in  std_ulogic);

    --! @}
end entity fetch_page_ow;

--! RTL implementation of fetch_page_ow
architecture rtl of fetch_page_ow is

  ---------------------------------------------------------------------------
  --! @name Types and Constants
  ---------------------------------------------------------------------------
  --! @{

  type state_t is (IDLE, STORE, DONE);

  type reg_t is record
    state : state_t;
    addr  : unsigned(5 downto 0);
    data  : std_ulogic_vector(79 downto 0);
    wr_en : std_ulogic;
    rd_en : std_ulogic;
    done  : std_ulogic;
  end record;

  constant init_c : reg_t := (
    state => IDLE,
    addr  => (others => '0'),
    data  => (others => '0'),
    wr_en => '0',
    rd_en => '0',
    done  => '0');

  --! @}
  ---------------------------------------------------------------------------
  --! @name Internal Registers
  ---------------------------------------------------------------------------
  --! @{

  signal reg : reg_t;

  --! @}
  ---------------------------------------------------------------------------
  --! @name Internal Wires
  ---------------------------------------------------------------------------
  --! @{

  signal next_reg : reg_t;

  --! @}

begin -- architecture rtl

  ---------------------------------------------------------------------------
  -- Outputs
  ---------------------------------------------------------------------------

  page_addr_o  <= std_ulogic_vector(reg.addr);
  page_wr_en_o <= reg.wr_en;
  page_data_o  <= reg.data(7 downto 0);

  ow_addr_o  <= idx_i(3 downto 0) & std_ulogic_vector(reg.addr(5 downto 4));
  ow_rd_en_o <= reg.rd_en;

  done_o <= reg.done;

  ---------------------------------------------------------------------------
  -- Registers
  ---------------------------------------------------------------------------

  regs : process (clk_i, rst_asy_n_i) is
    procedure reset is
    begin
      reg <= init_c;
    end procedure reset;
  begin -- process regs
    if rst_asy_n_i = '0' then
      reset;
    elsif rising_edge(clk_i) then
      if rst_syn_i = '1' then
        reset;
      else
        reg <= next_reg;
      end if;
    end if;
  end process regs;

  ---------------------------------------------------------------------------
  -- Combinatorics
  ---------------------------------------------------------------------------

  comb : process (reg, start_i, page_done_i, ow_data_i, ow_data_en_i) is
  begin -- comb
    -- Defaults
    next_reg <= reg;

    next_reg.rd_en <= '0';
    next_reg.wr_en <= '0';
    next_reg.done  <= '0';

    case reg.state is
      when IDLE =>
        if start_i = '1' then
          next_reg.rd_en <= '1';
          next_reg.state <= STORE;
        end if;

      when STORE =>
        if ow_data_en_i = '1' then
          next_reg.data  <= ow_data_i;
          next_reg.wr_en <= '1';
          next_reg.state <= DONE;
        end if;

      when DONE =>
        if page_done_i = '1' then
          if to_integer(reg.addr) < 63 then
            next_reg.addr  <= reg.addr + 1;
            if to_integer(reg.addr(3 downto 0)) < 15 then
              next_reg.wr_en <= '1';
              next_reg.data  <= x"00" & reg.data(reg.data'high downto reg.data'low + 8);
            else
              next_reg.rd_en <= '1';
              next_reg.state <= STORE;
            end if;
          else
            next_reg <= init_c;
            next_reg.done <= '1';
          end if;
        end if;
    end case;
  end process comb;

end architecture rtl;
