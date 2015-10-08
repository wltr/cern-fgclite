-------------------------------------------------------------------------------
--! @file      nf.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-07-08
--! @brief     NanoFIP communication and synchronization.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.nf_pkg.all;

--! @brief Entity declaration of nf
--! @details
--! This component handles the NanoFIP communication and provides a
--! synchronization mechanism with the field-bus cycle.

entity nf is
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
    tx_start_i      : in  std_ulogic;
    --! Received command number
    cmd_num_o       : out std_ulogic_vector(1 downto 0);
    --! Received command number enable
    cmd_num_en_o    : out std_ulogic;
    --! NanoFIP FPGA version
    nf_version_o    : out std_ulogic_vector(3 downto 0);
    --! NanoFIP FPGA version enable
    nf_version_en_o : out std_ulogic;

    --! @}
    --! @name Debugging
    --! @{

    --! Data output
    nf_debug_o    : out std_ulogic_vector(7 downto 0);
    --! Data output enable
    nf_debug_en_o : out std_ulogic;

    --! @}
    --! @name NanoFIP interface
    --! @{

    --! Inputs
    nf_i : in  nf_in_t;
    --! Outputs
    nf_o : out nf_out_t;


    --! @}
    --! @name Registers
    --! @{

    --! Gateway commands
    command_o : out nf_command_t;
    --! FGClite status
    status_i  : in nf_status_t;

    --! @}
    --! @name Page
    --! @{

    --! Address
    page_addr_i  : in  std_ulogic_vector(5 downto 0);
    --! Write enable
    page_wr_en_i : in  std_ulogic;
    --! Data input
    page_data_i  : in  std_ulogic_vector(7 downto 0);
    --! Done flag
    page_done_o  : out std_ulogic);

    --! @}
end entity nf;

--! RTL implementation of nf
architecture rtl of nf is

  ---------------------------------------------------------------------------
  --! @name Internal Wires
  ---------------------------------------------------------------------------
  --! @{

  signal rx_data    : std_ulogic_vector(43 downto 0);
  signal rx_data_en : std_ulogic;

  signal tx_data    : std_ulogic_vector(14 downto 0);
  signal tx_data_en : std_ulogic;
  signal tx_busy    : std_ulogic;
  signal tx_done    : std_ulogic;

  signal tx_reg_rd_en   : std_ulogic;
  signal tx_reg_addr    : std_ulogic_vector(5 downto 0);
  signal tx_reg_data    : std_ulogic_vector(7 downto 0);
  signal tx_reg_data_en : std_ulogic;

  signal tx_mem_rd_en   : std_ulogic;
  signal tx_mem_addr    : std_ulogic_vector(5 downto 0);
  signal tx_mem_data    : std_ulogic_vector(7 downto 0);
  signal tx_mem_data_en : std_ulogic;

  signal mem_rd_en   : std_ulogic;
  signal mem_addr    : std_ulogic_vector(6 downto 0);
  signal mem_data    : std_ulogic_vector(7 downto 0);
  signal mem_data_en : std_ulogic;

  --! @}

begin -- architecture rtl

  ---------------------------------------------------------------------------
  -- Outputs
  ---------------------------------------------------------------------------

  cmd_num_o    <= rx_data(33 downto 32);
  cmd_num_en_o <= rx_data_en;

  nf_debug_o    <= tx_data(7 downto 0);
  nf_debug_en_o <= tx_data_en;

  nf_version_o    <= rx_data(43 downto 40);
  nf_version_en_o <= rx_data_en;

  ---------------------------------------------------------------------------
  -- Signal Assignments
  ---------------------------------------------------------------------------

  tx_reg_rd_en   <= mem_rd_en and mem_addr(6);
  tx_reg_addr    <= mem_addr(5 downto 0);

  tx_mem_rd_en   <= mem_rd_en and not mem_addr(6);
  tx_mem_addr    <= mem_addr(5 downto 0);

  mem_data    <= tx_reg_data when mem_addr(6) = '1' else tx_mem_data;
  mem_data_en <= tx_reg_data_en when mem_addr(6) = '1' else tx_mem_data_en;

  ---------------------------------------------------------------------------
  -- Instances
  ---------------------------------------------------------------------------

  --! 3-wire serial receiver from NF
  nf_rx_inst : entity work.serial_3wire_rx
    generic map (
      data_width_g => 44)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      rx_frame_i  => nf_i.rx_frame,
      rx_bit_en_i => nf_i.rx_bit_en,
      rx_i        => nf_i.rx,

      data_o      => rx_data,
      data_en_o   => rx_data_en,
      error_o     => open);

  --! 3-wire serial transmitter to NF
  nf_tx_inst : entity work.serial_3wire_tx
    generic map (
      data_width_g => 15,
      num_ticks_g  => 8)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      data_i      => tx_data,
      data_en_i   => tx_data_en,
      busy_o      => tx_busy,
      done_o      => tx_done,

      tx_frame_o  => nf_o.tx_frame,
      tx_bit_en_o => nf_o.tx_bit_en,
      tx_o        => nf_o.tx);

  --! NF receiver registers
  nf_rx_registers_inst : entity work.nf_rx_registers
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => '0',

      wr_en_i     => rx_data_en,
      addr_i      => rx_data(33 downto 32),
      data_i      => rx_data(31 downto 0),

      command_o   => command_o);

  --! NF transmitter registers
  nf_tx_registers_inst : entity work.nf_tx_registers
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      rd_en_i     => tx_reg_rd_en,
      addr_i      => tx_reg_addr,
      data_o      => tx_reg_data,
      data_en_o   => tx_reg_data_en,

      status_i    => status_i);

  --! NF transmitter page
  nf_tx_page_inst : entity work.two_port_ram_tmr
    generic map (
      depth_g => 64,
      width_g => 8)
    port map (
      clk_i        => clk_i,
      rst_asy_n_i  => rst_asy_n_i,
      rst_syn_i    => rst_syn_i,

      wr_addr_i    => page_addr_i,
      wr_en_i      => page_wr_en_i,
      wr_data_i    => page_data_i,
      wr_done_o    => page_done_o,
      wr_busy_o    => open,

      rd_addr_i    => tx_mem_addr,
      rd_en_i      => tx_mem_rd_en,
      rd_data_o    => tx_mem_data,
      rd_data_en_o => tx_mem_data_en,
      rd_busy_o    => open);

  --! NF transmitter
  nf_transmitter_inst : entity work.nf_transmitter
    port map (
      clk_i         => clk_i,
      rst_asy_n_i   => rst_asy_n_i,
      rst_syn_i     => rst_syn_i,

      start_i       => tx_start_i,

      tx_addr_o     => tx_data(14 downto 8),
      tx_data_o     => tx_data(7 downto 0),
      tx_data_en_o  => tx_data_en,
      tx_busy_i     => tx_busy,
      tx_done_i     => tx_done,

      mem_rd_en_o   => mem_rd_en,
      mem_addr_o    => mem_addr,
      mem_data_i    => mem_data,
      mem_data_en_i => mem_data_en);

end architecture rtl;
