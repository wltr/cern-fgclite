-------------------------------------------------------------------------------
--! @file      fetch_page.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-11-19
--! @brief     Prepare page for NanoFIP communication.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;

--! @brief Entity declaration of fetch_page
--! @details
--! The paged data of the NanoFIP response needs to be prepared every cycle.

entity fetch_page is
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
    --! Memory index type
    idx_type_i : in  std_ulogic_vector(2 downto 0);

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
    --! @name External SRAM ADC data
    --! @{

    --! Address
    sram_adc_addr_o    : out std_ulogic_vector(4 downto 0);
    --! Read request
    sram_adc_rd_en_o   : out std_ulogic;
    --! Data input
    sram_adc_data_i    : in  std_ulogic_vector(23 downto 0);
    --! Data input enable
    sram_adc_data_en_i : in  std_ulogic;
    --! Done flag
    sram_adc_done_o    : out std_ulogic;

    --! @}
    --! @name External SRAM DIM data
    --! @{

    --! Address
    sram_dim_addr_o    : out std_ulogic_vector(4 downto 0);
    --! Read request
    sram_dim_rd_en_o   : out std_ulogic;
    --! Data input
    sram_dim_data_i    : in  std_ulogic_vector(15 downto 0);
    --! Data input enable
    sram_dim_data_en_i : in  std_ulogic;
    --! Done flag
    sram_dim_done_o    : out std_ulogic;

    --! @}
    --! @name DIM data
    --! @{

    --! Address
    dim_addr_o    : out std_ulogic_vector(6 downto 0);
    --! Read enable
    dim_rd_en_o   : out std_ulogic;
    --! Data input
    dim_data_i    : in  std_ulogic_vector(15 downto 0);
    --! Data input enable
    dim_data_en_i : in  std_ulogic;

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
end entity fetch_page;

--! RTL implementation of fetch_page
architecture rtl of fetch_page is

  ---------------------------------------------------------------------------
  --! @name Types and Constants
  ---------------------------------------------------------------------------
  --! @{

  type source_t is (DIM, ONEWIRE, SRAM_ADC, SRAM_DIM);

  --! @}
  ---------------------------------------------------------------------------
  --! @name Internal Registers
  ---------------------------------------------------------------------------
  --! @{

  signal source : source_t;

  signal start_dim      : std_ulogic;
  signal start_ow       : std_ulogic;
  signal start_sram_adc : std_ulogic;
  signal start_sram_dim : std_ulogic;

  --! @}
  ---------------------------------------------------------------------------
  --! @name Internal Wires
  ---------------------------------------------------------------------------
  --! @{

  signal sram_adc_addr  : std_ulogic_vector(5 downto 0);
  signal sram_adc_wr_en : std_ulogic;
  signal sram_adc_data  : std_ulogic_vector(7 downto 0);
  signal sram_adc_done  : std_ulogic;

  signal sram_dim_addr  : std_ulogic_vector(5 downto 0);
  signal sram_dim_wr_en : std_ulogic;
  signal sram_dim_data  : std_ulogic_vector(7 downto 0);
  signal sram_dim_done  : std_ulogic;

  signal dim_addr  : std_ulogic_vector(5 downto 0);
  signal dim_wr_en : std_ulogic;
  signal dim_data  : std_ulogic_vector(7 downto 0);
  signal dim_done  : std_ulogic;

  signal ow_addr  : std_ulogic_vector(5 downto 0);
  signal ow_wr_en : std_ulogic;
  signal ow_data  : std_ulogic_vector(7 downto 0);
  signal ow_done  : std_ulogic;

  --! @}

begin -- architecture rtl

  ---------------------------------------------------------------------------
  -- Outputs
  ---------------------------------------------------------------------------

  with source select page_addr_o <=
    sram_adc_addr   when SRAM_ADC,
    sram_dim_addr   when SRAM_DIM,
    dim_addr        when DIM,
    ow_addr         when ONEWIRE,
    (others => '0') when others;

  with source select page_wr_en_o <=
    sram_adc_wr_en when SRAM_ADC,
    sram_dim_wr_en when SRAM_DIM,
    dim_wr_en      when DIM,
    ow_wr_en       when ONEWIRE,
    '0'            when others;

  with source select page_data_o <=
    sram_adc_data   when SRAM_ADC,
    sram_dim_data   when SRAM_DIM,
    dim_data        when DIM,
    ow_data         when ONEWIRE,
    (others => '0') when others;

  with source select done_o <=
    sram_adc_done when SRAM_ADC,
    sram_dim_done when SRAM_DIM,
    dim_done      when DIM,
    ow_done       when ONEWIRE,
    '0'           when others;

  sram_adc_done_o <= sram_adc_done;
  sram_dim_done_o <= sram_dim_done;

  ---------------------------------------------------------------------------
  -- Instances
  ---------------------------------------------------------------------------

  fetch_dim_inst : entity work.fetch_page_dim
    port map (
      clk_i         => clk_i,
      rst_asy_n_i   => rst_asy_n_i,
      rst_syn_i     => rst_syn_i,

      start_i       => start_dim,
      done_o        => dim_done,
      idx_i         => idx_i,

      page_addr_o   => dim_addr,
      page_wr_en_o  => dim_wr_en,
      page_data_o   => dim_data,
      page_done_i   => page_done_i,

      dim_addr_o    => dim_addr_o,
      dim_rd_en_o   => dim_rd_en_o,
      dim_data_i    => dim_data_i,
      dim_data_en_i => dim_data_en_i);

  fetch_ow_inst : entity work.fetch_page_ow
    port map (
      clk_i         => clk_i,
      rst_asy_n_i   => rst_asy_n_i,
      rst_syn_i     => rst_syn_i,

      start_i       => start_ow,
      done_o        => ow_done,
      idx_i         => idx_i,

      page_addr_o   => ow_addr,
      page_wr_en_o  => ow_wr_en,
      page_data_o   => ow_data,
      page_done_i   => page_done_i,

      ow_addr_o     => ow_addr_o,
      ow_rd_en_o    => ow_rd_en_o,
      ow_data_i     => ow_data_i,
      ow_data_en_i  => ow_data_en_i);

  fetch_sram_adc_inst : entity work.fetch_page_sram_adc
    port map (
      clk_i          => clk_i,
      rst_asy_n_i    => rst_asy_n_i,
      rst_syn_i      => rst_syn_i,

      start_i        => start_sram_adc,
      done_o         => sram_adc_done,

      page_addr_o    => sram_adc_addr,
      page_wr_en_o   => sram_adc_wr_en,
      page_data_o    => sram_adc_data,
      page_done_i    => page_done_i,

      sram_addr_o    => sram_adc_addr_o,
      sram_rd_en_o   => sram_adc_rd_en_o,
      sram_data_i    => sram_adc_data_i,
      sram_data_en_i => sram_adc_data_en_i);

  fetch_sram_dim_inst : entity work.fetch_page_sram_dim
    port map (
      clk_i          => clk_i,
      rst_asy_n_i    => rst_asy_n_i,
      rst_syn_i      => rst_syn_i,

      start_i        => start_sram_dim,
      done_o         => sram_dim_done,

      page_addr_o    => sram_dim_addr,
      page_wr_en_o   => sram_dim_wr_en,
      page_data_o    => sram_dim_data,
      page_done_i    => page_done_i,

      sram_addr_o    => sram_dim_addr_o,
      sram_rd_en_o   => sram_dim_rd_en_o,
      sram_data_i    => sram_dim_data_i,
      sram_data_en_i => sram_dim_data_en_i);

  ---------------------------------------------------------------------------
  -- Registers
  ---------------------------------------------------------------------------

  regs : process (clk_i, rst_asy_n_i) is
    procedure reset is
    begin
      source <= DIM;

      start_dim      <= '0';
      start_ow       <= '0';
      start_sram_adc <= '0';
      start_sram_dim <= '0';
    end procedure reset;
  begin -- process regs
    if rst_asy_n_i = '0' then
      reset;
    elsif rising_edge(clk_i) then
      if rst_syn_i = '1' then
        reset;
      else
        start_dim      <= '0';
        start_ow       <= '0';
        start_sram_adc <= '0';
        start_sram_dim <= '0';

        if start_i = '1' then
          if idx_type_i = "000" then
            source    <= DIM;
            start_dim <= '1';
          elsif idx_type_i = "001" then
            source   <= ONEWIRE;
            start_ow <= '1';
          elsif idx_type_i = "101" then
            source         <= SRAM_DIM;
            start_sram_dim <= '1';
          else
            source         <= SRAM_ADC;
            start_sram_adc <= '1';
          end if;
        end if;
      end if;
    end if;
  end process regs;

end architecture rtl;
