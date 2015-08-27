-------------------------------------------------------------------------------
--! @file      debug_serial.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2015-01-20
--! @brief     Debugging serial interface.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;

--! @brief Entity declaration of debug_serial
--! @details
--! Provide a serial debugging interface over UART.

entity debug_serial is
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
    --! @name Debugging interface
    --! @{

    --! TX start flag
    start_i    : in  std_ulogic;
    --! Data input
    debug_i    : in  std_ulogic_vector(7 downto 0);
    --! Data input enable
    debug_en_i : in  std_ulogic;
    --! Data output
    debug_o    : out std_ulogic_vector(7 downto 0);
    --! Data output enable
    debug_en_o : out std_ulogic;

    --! @}
    --! @name Serial communication
    --! @{

    --! Serial receiver
    rx_i : in  std_ulogic;
    --! Serial transmitter
    tx_o : out std_ulogic);

    --! @}
end entity debug_serial;

--! RTL implementation of debug_serial
architecture rtl of debug_serial is

  ---------------------------------------------------------------------------
  --! @name Internal Wires
  ---------------------------------------------------------------------------
  --! @{

  signal tx_data    : std_ulogic_vector(7 downto 0);
  signal tx_data_en : std_ulogic;
  signal tx_done    : std_ulogic;

  signal fifo_rd_en : std_ulogic;
  signal fifo_empty : std_ulogic;

  --! @}

begin -- architecture rtl

  ---------------------------------------------------------------------------
  -- Signal Assignments
  ---------------------------------------------------------------------------

  fifo_rd_en <= (start_i or tx_done) and (not fifo_empty);

  ---------------------------------------------------------------------------
  -- Instances
  ---------------------------------------------------------------------------

  --! FIFO
  fifo_inst : entity work.fifo_tmr
    generic map (
      depth_g => 256,
      width_g => 8)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      wr_en_i     => debug_en_i,
      data_i      => debug_i,
      done_o      => open,
      full_o      => open,
      wr_busy_o   => open,

      rd_en_i     => fifo_rd_en,
      data_o      => tx_data,
      data_en_o   => tx_data_en,
      empty_o     => fifo_empty,
      rd_busy_o   => open);

  --! Serial transmitter
  uart_tx_inst : entity work.uart_tx
    generic map (
      data_width_g => 8,
      parity_g     => 0,
      stop_bits_g  => 1,
      num_ticks_g  => 156)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      data_i      => tx_data,
      data_en_i   => tx_data_en,
      busy_o      => open,
      done_o      => tx_done,

      tx_o        => tx_o);

  --! Serial receiver
  uart_rx_inst : entity work.uart_rx
    generic map (
      data_width_g => 8,
      parity_g     => 0,
      stop_bits_g  => 1,
      num_ticks_g  => 156)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      rx_i        => rx_i,

      data_o      => debug_o,
      data_en_o   => debug_en_o,
      error_o     => open);

end architecture rtl;
