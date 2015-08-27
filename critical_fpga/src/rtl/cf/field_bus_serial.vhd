-------------------------------------------------------------------------------
--! @file      field_bus_serial.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-12-01
--! @brief     Field-bus serial interface.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nf_pkg.all;

--! @brief Entity declaration of field_bus_serial
--! @details
--! Provide a serial interface over NanoFIP.

entity field_bus_serial is
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
    --! @name Gateway communication
    --! @{

    --! Start of field-bus cycle
    start_i    : in  std_ulogic;
    --! Commands
    command_i  : in  nf_command_t;
    --! Serial data
    data_o     : out std_ulogic_vector(7 downto 0);
    --! Serial data number
    data_num_o : out std_ulogic_vector(3 downto 0);
    --! Serial data enable
    data_en_o  : out std_ulogic;

    --! @}
    --! @name Serial communication
    --! @{

    --! Serial receiver
    rx_i : in  std_ulogic;
    --! Serial transmitter
    tx_o : out std_ulogic);

    --! @}
end entity field_bus_serial;

--! RTL implementation of field_bus_serial
architecture rtl of field_bus_serial is

  ---------------------------------------------------------------------------
  --! @name Internal Registers
  ---------------------------------------------------------------------------
  --! @{

  signal data_num : unsigned(3 downto 0);

  --! @}
  ---------------------------------------------------------------------------
  --! @name Internal Wires
  ---------------------------------------------------------------------------
  --! @{

  signal cmd_fifo_rd_en   : std_ulogic;
  signal cmd_fifo_data    : std_ulogic_vector(31 downto 0);
  signal cmd_fifo_data_en : std_ulogic;
  signal cmd_fifo_empty   : std_ulogic;
  signal cmd_fifo_wr_busy : std_ulogic;
  signal cmd_fifo_rd_busy : std_ulogic;

  signal stat_fifo_rd_en   : std_ulogic;
  signal stat_fifo_empty   : std_ulogic;
  signal stat_fifo_data_en : std_ulogic;

  signal tx_data    : std_ulogic_vector(7 downto 0);
  signal tx_data_en : std_ulogic;
  signal tx_done    : std_ulogic;

  signal rx_data    : std_ulogic_vector(7 downto 0);
  signal rx_data_en : std_ulogic;

  signal array_tx_busy : std_ulogic;

  --! @}

begin -- architecture rtl

  ---------------------------------------------------------------------------
  -- Outputs
  ---------------------------------------------------------------------------

  data_num_o <= std_ulogic_vector(data_num);
  data_en_o  <= stat_fifo_data_en;

  ---------------------------------------------------------------------------
  -- Signal Assignments
  ---------------------------------------------------------------------------

  cmd_fifo_rd_en <= (not command_i.serial_data_en) and (not cmd_fifo_wr_busy) and (not cmd_fifo_rd_busy) and (not cmd_fifo_empty) and (not array_tx_busy);

  ---------------------------------------------------------------------------
  -- Instances
  ---------------------------------------------------------------------------

  --! Command FIFO
  cmd_fifo_inst : entity work.fifo_tmr
    generic map (
      depth_g => 8,
      width_g => 32)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      wr_en_i     => command_i.serial_data_en,
      data_i      => command_i.serial_data,
      done_o      => open,
      full_o      => open,
      wr_busy_o   => cmd_fifo_wr_busy,

      rd_en_i     => cmd_fifo_rd_en,
      data_o      => cmd_fifo_data,
      data_en_o   => cmd_fifo_data_en,
      empty_o     => cmd_fifo_empty,
      rd_busy_o   => cmd_fifo_rd_busy);

  --! Status FIFO
  stat_fifo_inst : entity work.fifo_tmr
    generic map (
      depth_g => 256,
      width_g => 8)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      wr_en_i     => rx_data_en,
      data_i      => rx_data,
      done_o      => open,
      full_o      => open,
      wr_busy_o   => open,

      rd_en_i     => stat_fifo_rd_en,
      data_o      => data_o,
      data_en_o   => stat_fifo_data_en,
      empty_o     => stat_fifo_empty,
      rd_busy_o   => open);

  --! Array transmitter
  array_tx_inst : entity work.array_tx
    generic map (
      data_count_g => 4,
      data_width_g => 8)
    port map (
      clk_i        => clk_i,
      rst_asy_n_i  => rst_asy_n_i,
      rst_syn_i    => rst_syn_i,

      data_i       => cmd_fifo_data,
      data_en_i    => cmd_fifo_data_en,
      busy_o       => array_tx_busy,
      done_o       => open,

      tx_data_o    => tx_data,
      tx_data_en_o => tx_data_en,
      tx_done_i    => tx_done);

  --! Serial transmitter
  uart_tx_inst : entity work.uart_tx
    generic map (
      data_width_g => 8,
      parity_g     => 0,
      stop_bits_g  => 1,
      num_ticks_g  => 4166)
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
      num_ticks_g  => 4166)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      rx_i        => rx_i,

      data_o      => rx_data,
      data_en_o   => rx_data_en,
      error_o     => open);

  ---------------------------------------------------------------------------
  -- Registers
  ---------------------------------------------------------------------------

  regs : process (clk_i, rst_asy_n_i) is
    procedure reset is
    begin
      data_num <= to_unsigned(0, data_num'length);
    end procedure reset;
  begin -- process regs
    if rst_asy_n_i = '0' then
      reset;
    elsif rising_edge(clk_i) then
      if rst_syn_i = '1' then
        reset;
      else
        stat_fifo_rd_en <= '0';

        if start_i = '1' then
          data_num        <= to_unsigned(0, data_num'length);
          stat_fifo_rd_en <= not stat_fifo_empty;
        end if;

        if stat_fifo_data_en = '1' and to_integer(data_num) < 6 then
          data_num        <= data_num + 1;
          stat_fifo_rd_en <= not stat_fifo_empty;
        end if;
      end if;
    end if;
  end process regs;

end architecture rtl;
