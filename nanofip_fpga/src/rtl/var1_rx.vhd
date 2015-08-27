-------------------------------------------------------------------------------
--! @file      var1_rx.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2013-10-24
--! @brief     NanoFIP VAR1 receiver controlling JTAG TRST.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! @brief Entity declaration of var1_rx
--! @details
--! NanoFIP VAR1 packets are controlling the JTAG TRST output. The first byte
--! either sets TRST high or low.
--!
--! 0xDB sets TRST to '1'
--! 0xA5 sets TRST to '0'

entity var1_rx is
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
    --! @name Receiver interface
    --! @{

    --! Data is ready to be received
    rx_rdy_i     : in  std_ulogic;
    --! Read address
    rx_addr_o    : out std_ulogic_vector(6 downto 0);
    --! Read enable
    rx_en_o      : out std_ulogic;
    --! Read data input
    rx_data_i    : in  std_ulogic_vector(7 downto 0);
    --! Read data input enable
    rx_data_en_i : in  std_ulogic;

    --! @}
    --! @name VAR1 interface
    --! @{

    --! JTAG TRST
    jtag_trst_o : out std_ulogic;

    --! @}
    --! @name Error flags
    --! @{

    --! Read-write collision
    err_rw_coll_i : in std_ulogic;
    --! Interface busy
    err_bsy_i     : in std_ulogic;
    --! VAR not ready
    err_not_rdy_i : in std_ulogic;
    --! Wishbone bus acknowledge timeout
    err_timeout_i : in std_ulogic);

    --! @}
end entity var1_rx;

--! RTL implementation of var1_rx
architecture rtl of var1_rx is

  ---------------------------------------------------------------------------
  -- Types and Constants
  ---------------------------------------------------------------------------

  --! Base address for data payload
  constant base_addr_c : natural := 2;

  ---------------------------------------------------------------------------
  --! @name Internal Registers
  ---------------------------------------------------------------------------
  --! @{

  signal en   : std_ulogic;
  signal trst : std_ulogic;

  --! @}
  ---------------------------------------------------------------------------
  --! @name Internal Wires
  ---------------------------------------------------------------------------
  --! @{

  signal wb_if_err : std_ulogic;

  --! @}

begin -- architecture rtl

  ---------------------------------------------------------------------------
  -- Outputs
  ---------------------------------------------------------------------------

  rx_addr_o <= std_ulogic_vector(to_unsigned(base_addr_c, rx_addr_o'length));
  rx_en_o   <= en;

  jtag_trst_o <= trst;

  ---------------------------------------------------------------------------
  -- Signal Assignments
  ---------------------------------------------------------------------------

  -- Combine errors into one signal
  wb_if_err <= err_rw_coll_i or err_not_rdy_i or err_timeout_i or err_bsy_i;

  ---------------------------------------------------------------------------
  -- Registers
  ---------------------------------------------------------------------------

  regs : process (clk_i, rst_asy_n_i) is
    procedure reset is
    begin
      en   <= '0';
      trst <= '0';
    end procedure reset;
  begin -- process regs
    if rst_asy_n_i = '0' then
      reset;
    elsif rising_edge(clk_i) then
      if rst_syn_i = '1' then
        reset;
      else
        en <= rx_rdy_i;

        if rx_data_en_i = '1' then
          if rx_data_i = "11011011" then    -- 0xDB
            trst <= '1';
          elsif rx_data_i = "10100101" then -- 0xA5
            trst <= '0';
          end if;
        end if;

        -- Reset on error
        if wb_if_err = '1' then
          reset;
        end if;
      end if;
    end if;
  end process regs;

end architecture rtl;
