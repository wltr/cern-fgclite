-------------------------------------------------------------------------------
--! @file      xf.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-07-08
--! @brief     Auxiliary FPGA communication.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.xf_pkg.all;
use work.nf_pkg.all;

--! @brief Entity declaration of xf
--! @details
--! This component handles the NanoFIP communication and provides a
--! synchronization mechanism with the field-bus cycle.

entity xf is
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
    --! @name Auxiliary FPGA interface
    --! @{

    --! Inputs
    xf_i : in  xf_in_t;
    --! Outputs
    xf_o : out xf_out_t;

    --! @}
    --! @name Internal interface
    --! @{

    --! Millisecond strobe indicating start of cycle
    ms_0_strobe_i : in std_ulogic;
    --! Millisecond strobe indicating start of second millisecond
    ms_1_strobe_i : in std_ulogic;
    --! Commands
    command_i     : in nf_command_t;

    --! @}
    --! @name Auxiliary FPGA data
    --! @{

    --! DIM analogue data
    dim_o               : out std_ulogic_vector(19 downto 0);
    --! DIM analogue data enable
    dim_en_o            : out std_ulogic;
    --! DIM trigger number
    dim_trig_num_o      : out std_ulogic_vector(3 downto 0);
    --! DIM latched trigger
    dim_trig_lat_o      : out std_ulogic;
    --! DIM unlatched trigger
    dim_trig_unl_o      : out std_ulogic;
    --! Backplane type
    backplane_type_o    : out std_ulogic_vector(7 downto 0);
    --! Backplane type enable
    backplane_type_en_o : out std_ulogic;
    --! XF and PF versions
    version_xfpf_o      : out std_ulogic_vector(7 downto 0);
    --! XF and PF versions enable
    version_xfpf_en_o   : out std_ulogic;
    --! Single-event upset (SEU) count
    seu_count_o         : out std_ulogic_vector(7 downto 0);
    --! Single-event upset (SEU) count enable
    seu_count_en_o      : out std_ulogic;
    --! 1-wire scan busy
    ow_scan_busy_o      : out std_ulogic;

    --! @}
    --! @name DIM data
    --! @{

    --! Address
    dim_addr_i    : in  std_ulogic_vector(6 downto 0);
    --! Read enable
    dim_rd_en_i   : in  std_ulogic;
    --! Data output
    dim_data_o    : out std_ulogic_vector(15 downto 0);
    --! Data output enable
    dim_data_en_o : out std_ulogic;

    --! @}
    --! @name One-wire data
    --! @{

    --! Address
    ow_addr_i    : in  std_ulogic_vector(5 downto 0);
    --! Read enable
    ow_rd_en_i   : in  std_ulogic;
    --! Data output
    ow_data_o    : out std_ulogic_vector(79 downto 0);
    --! Data output enable
    ow_data_en_o : out std_ulogic);

    --! @}
end entity xf;

--! RTL implementation of xf
architecture rtl of xf is

  ---------------------------------------------------------------------------
  --! @name Internal Registers
  ---------------------------------------------------------------------------
  --! @{

  signal ow_scan_busy  : std_ulogic;
  signal dim_trigger   : std_ulogic;
  signal dim_reset     : std_ulogic;
  signal ow_scan       : std_ulogic;
  signal ow_bus_select : std_ulogic_vector(2 downto 0);

  --! @}
  ---------------------------------------------------------------------------
  --! @name Internal Wires
  ---------------------------------------------------------------------------
  --! @{

  signal xf_rx_data_0    : std_ulogic_vector(41 downto 0);
  signal xf_rx_data_en_0 : std_ulogic;
  signal xf_rx_error_0   : std_ulogic;

  signal xf_rx_data_1    : std_ulogic_vector(83 downto 0);
  signal xf_rx_data_en_1 : std_ulogic;
  signal xf_rx_error_1   : std_ulogic;

  signal dim_addr : std_ulogic_vector(6 downto 0);
  signal ow_addr  : std_ulogic_vector(5 downto 0);

  --! @}

begin -- architecture rtl

  ---------------------------------------------------------------------------
  -- Outputs
  ---------------------------------------------------------------------------

  xf_o.dim_trig      <= dim_trigger;
  xf_o.dim_rst       <= dim_reset;
  xf_o.ow_trig       <= ow_scan;
  xf_o.ow_bus_select <= ow_bus_select;

  backplane_type_o    <= "00" & xf_rx_data_0(13 downto 8);
  backplane_type_en_o <= xf_rx_data_en_0;

  version_xfpf_o    <= xf_rx_data_0(7 downto 0);
  version_xfpf_en_o <= xf_rx_data_en_0;

  seu_count_o    <= xf_rx_data_0(21 downto 14);
  seu_count_en_o <= xf_rx_data_en_0 when dim_addr = "0000000" else '0';

  ow_scan_busy_o <= ow_scan_busy;

  dim_o    <= xf_rx_data_0(41 downto 22);
  dim_en_o <= xf_rx_data_en_0 and xf_rx_data_0(36); -- only save analogue values

  dim_trig_num_o <= xf_rx_data_0(41 downto 38);
  dim_trig_lat_o <= xf_rx_data_en_0 when (xf_rx_data_0(37) = '1' and xf_rx_data_0(36 downto 34) = "010") else '0';
  dim_trig_unl_o <= xf_rx_data_en_0 when (xf_rx_data_0(37) = '1' and xf_rx_data_0(36) = '1') else '0';

  ---------------------------------------------------------------------------
  -- Signal Assignments
  ---------------------------------------------------------------------------

  dim_addr <= xf_rx_data_0(41 downto 38) & xf_rx_data_0(36 downto 34);
  ow_addr  <= "00" & xf_rx_data_1(83 downto 80);

  ---------------------------------------------------------------------------
  -- Instances
  ---------------------------------------------------------------------------

  --! 1st 3-wire serial receiver from XF
  xf_rx_inst_0 : entity work.serial_3wire_rx
    generic map (
      data_width_g => 42)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      rx_frame_i  => xf_i.rx_frame(0),
      rx_bit_en_i => xf_i.rx_bit_en(0),
      rx_i        => xf_i.rx(0),

      data_o      => xf_rx_data_0,
      data_en_o   => xf_rx_data_en_0,
      error_o     => xf_rx_error_0);

  --! 2nd 3-wire serial receiver from XF
  xf_rx_inst_1 : entity work.serial_3wire_rx
    generic map (
      data_width_g => 84)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      rx_frame_i  => xf_i.rx_frame(1),
      rx_bit_en_i => xf_i.rx_bit_en(1),
      rx_i        => xf_i.rx(1),

      data_o      => xf_rx_data_1,
      data_en_o   => xf_rx_data_en_1,
      error_o     => xf_rx_error_1);

  --! DIM pages
  dim_page_inst : entity work.two_port_ram_tmr
    generic map (
      depth_g => 128,
      width_g => 16)
    port map (
      clk_i        => clk_i,
      rst_asy_n_i  => rst_asy_n_i,
      rst_syn_i    => rst_syn_i,

      wr_addr_i    => dim_addr,
      wr_en_i      => xf_rx_data_en_0,
      wr_data_i    => xf_rx_data_0(37 downto 22),
      wr_done_o    => open,
      wr_busy_o    => open,

      rd_addr_i    => dim_addr_i,
      rd_en_i      => dim_rd_en_i,
      rd_data_o    => dim_data_o,
      rd_data_en_o => dim_data_en_o,
      rd_busy_o    => open);

  --! One-wire pages
  ow_page_inst : entity work.two_port_ram_tmr
    generic map (
      depth_g => 64,
      width_g => 80)
    port map (
      clk_i        => clk_i,
      rst_asy_n_i  => rst_asy_n_i,
      rst_syn_i    => rst_syn_i,

      wr_addr_i    => ow_addr,
      wr_en_i      => xf_rx_data_en_1,
      wr_data_i    => xf_rx_data_1(79 downto 0),
      wr_done_o    => open,
      wr_busy_o    => open,

      rd_addr_i    => ow_addr_i,
      rd_en_i      => ow_rd_en_i,
      rd_data_o    => ow_data_o,
      rd_data_en_o => ow_data_en_o,
      rd_busy_o    => open);

  ---------------------------------------------------------------------------
  -- Registers
  ---------------------------------------------------------------------------

  regs : process (clk_i, rst_asy_n_i) is
    procedure reset is
    begin
      dim_trigger   <= '0';
      ow_scan_busy  <= '0';
      dim_reset     <= '0';
      ow_scan       <= '0';
      ow_bus_select <= (others => '0');
    end procedure reset;
  begin -- process regs
    if rst_asy_n_i = '0' then
      reset;
    elsif rising_edge(clk_i) then
      if rst_syn_i = '1' then
        reset;
      else
        if ms_0_strobe_i = '1' then
          dim_reset     <= command_i.dim_reset;
          ow_scan       <= command_i.ow_scan;
          ow_bus_select <= command_i.ow_bus_select;
        end if;

        if ms_0_strobe_i = '1' then
          dim_trigger <= '1';
        elsif ms_1_strobe_i = '1' then
          dim_trigger <= '0';
        end if;

        if command_i.ow_scan = '1' then
          ow_scan_busy <= '1';
        elsif xf_rx_data_en_1 = '1' then
          ow_scan_busy <= '0';
        end if;
      end if;
    end if;
  end process regs;

end architecture rtl;
