-------------------------------------------------------------------------------
--! @file      sram.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-11-19
--! @brief     External SRAM communication.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.sram_pkg.all;

--! @brief Entity declaration of sram
--! @details
--! This component handles the interface with the external SRAM.

entity sram is
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
    --! @name Command and status
    --! @{

    --! ADC log index
    adc_log_idx_o : out std_ulogic_vector(15 downto 0);
    --! DIM log index
    dim_log_idx_o : out std_ulogic_vector(15 downto 0);
    --! ADC log freeze
    adc_freeze_i  : in  std_ulogic;
    --! DIM log freeze
    dim_freeze_i  : in  std_ulogic;
    --! Millisecond strobe indicating start of cycle
    ms_0_strobe_i : in  std_ulogic;

    --! @}
    --! @name ADC and DIM data
    --! @{

    --! ADC VS data
    adc_vs_i    : in std_ulogic_vector(23 downto 0);
    --! ADC VS data enable
    adc_vs_en_i : in std_ulogic;
    --! ADC IA data
    adc_ia_i    : in std_ulogic_vector(23 downto 0);
    --! ADC IA data enable
    adc_ia_en_i : in std_ulogic;
    --! ADC IB data
    adc_ib_i    : in std_ulogic_vector(23 downto 0);
    --! ADC IB data enable
    adc_ib_en_i : in std_ulogic;
    --! DIM data
    dim_i       : in std_ulogic_vector(19 downto 0);
    --! DIM data enable
    dim_en_i    : in std_ulogic;

    --! @}
    --! @name Read interface
    --! @{

    --! Memory index
    idx_i         : in  std_ulogic_vector(14 downto 0);
    --! Memory index type
    idx_type_i    : in  std_ulogic_vector(2 downto 0);
    --! ADC Address
    adc_addr_i    : in  std_ulogic_vector(4 downto 0);
    --! ADC Read enable
    adc_rd_en_i   : in  std_ulogic;
    --! ADC Data output
    adc_data_o    : out std_ulogic_vector(23 downto 0);
    --! ADC Data output enable
    adc_data_en_o : out std_ulogic;
    --! ADC Done flag
    adc_done_i    : in  std_ulogic;
    --! DIM Address
    dim_addr_i    : in  std_ulogic_vector(4 downto 0);
    --! DIM Read enable
    dim_rd_en_i   : in  std_ulogic;
    --! DIM Data output
    dim_data_o    : out std_ulogic_vector(15 downto 0);
    --! DIM Data output enable
    dim_data_en_o : out std_ulogic;
    --! DIM Done flag
    dim_done_i    : in  std_ulogic;

    --! @}
    --! @name External SRAM interface
    --! @{

    --! Inputs
    sram_i : in  sram_in_t;
    --! Outputs
    sram_o : out sram_out_t);

    --! @}
end entity sram;

--! RTL implementation of sram
architecture rtl of sram is

  ---------------------------------------------------------------------------
  --! @name Types and Constants
  ---------------------------------------------------------------------------
  --! @{

  constant adc_vs_base_addr_c : unsigned(2 downto 0)  := "000";
  constant adc_ia_base_addr_c : unsigned(2 downto 0)  := "001";
  constant adc_ib_base_addr_c : unsigned(2 downto 0)  := "010";
  constant dim_base_addr_c    : unsigned(18 downto 0) := "0110000000000000000";

  type state_t is (RD_CHECK, RD_ADC_IA, WR_ADC_IA_0, WR_ADC_IA_1, RD_ADC_IB,
    WR_ADC_IB_0, WR_ADC_IB_1, RD_ADC_VS, WR_ADC_VS_0, WR_ADC_VS_1,
    RD_DIM, WR_DIM, FETCH_REQ, FETCH_ADC_0, STORE_ADC_0, FETCH_ADC_1,
    STORE_ADC_1, FETCH_DIM, STORE_DIM);

  type reg_t is record
    state       : state_t;
    adc_idx     : unsigned(14 downto 0);
    dim_idx     : unsigned(10 downto 0);
    adc_rd_req  : std_ulogic;
    dim_rd_req  : std_ulogic;
    adc_data    : std_ulogic_vector(23 downto 0);
    adc_data_en : std_ulogic;
    dim_data    : std_ulogic_vector(15 downto 0);
    dim_data_en : std_ulogic;
  end record;

  constant init_c : reg_t := (
    state       => RD_CHECK,
    adc_idx     => (others => '0'),
    dim_idx     => (others => '0'),
    adc_rd_req  => '0',
    dim_rd_req  => '0',
    adc_data    => (others => '0'),
    adc_data_en => '0',
    dim_data    => (others => '0'),
    dim_data_en => '0');

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

  signal next_reg: reg_t;

  signal tmr_addr     : std_ulogic_vector(18 downto 0);
  signal tmr_rd_en    : std_ulogic;
  signal tmr_wr_en    : std_ulogic;
  signal tmr_data_in  : std_ulogic_vector(15 downto 0);
  signal tmr_data_out : std_ulogic_vector(15 downto 0);
  signal tmr_data_en  : std_ulogic;
  signal tmr_done     : std_ulogic;
  signal tmr_busy     : std_ulogic;

  signal sram_addr     : std_ulogic_vector(19 downto 0);
  signal sram_rd_en    : std_ulogic;
  signal sram_wr_en    : std_ulogic;
  signal sram_data_in  : std_ulogic_vector(15 downto 0);
  signal sram_data_out : std_ulogic_vector(15 downto 0);
  signal sram_data_en  : std_ulogic;
  signal sram_busy     : std_ulogic;
  signal sram_done     : std_ulogic;

  signal dim_fifo_rd_en   : std_ulogic;
  signal dim_fifo_data    : std_ulogic_vector(19 downto 0);
  signal dim_fifo_data_en : std_ulogic;
  signal dim_fifo_empty   : std_ulogic;
  signal dim_fifo_wr_busy : std_ulogic;

  signal adc_vs_fifo_rd_en   : std_ulogic;
  signal adc_vs_fifo_data    : std_ulogic_vector(23 downto 0);
  signal adc_vs_fifo_data_en : std_ulogic;
  signal adc_vs_fifo_empty   : std_ulogic;
  signal adc_vs_fifo_wr_busy : std_ulogic;

  signal adc_ia_fifo_rd_en   : std_ulogic;
  signal adc_ia_fifo_data    : std_ulogic_vector(23 downto 0);
  signal adc_ia_fifo_data_en : std_ulogic;
  signal adc_ia_fifo_empty   : std_ulogic;
  signal adc_ia_fifo_wr_busy : std_ulogic;

  signal adc_ib_fifo_rd_en   : std_ulogic;
  signal adc_ib_fifo_data    : std_ulogic_vector(23 downto 0);
  signal adc_ib_fifo_data_en : std_ulogic;
  signal adc_ib_fifo_empty   : std_ulogic;
  signal adc_ib_fifo_wr_busy : std_ulogic;

  signal adc_req_base_addr : unsigned(2 downto 0);

  --! @}

begin -- architecture rtl

  ---------------------------------------------------------------------------
  -- Outputs
  ---------------------------------------------------------------------------

  adc_log_idx_o <= '0' & std_ulogic_vector(reg.adc_idx);
  dim_log_idx_o <= "00000" & std_ulogic_vector(reg.dim_idx);

  adc_data_o    <= reg.adc_data;
  adc_data_en_o <= reg.adc_data_en;

  dim_data_o    <= reg.dim_data;
  dim_data_en_o <= reg.dim_data_en;

  ---------------------------------------------------------------------------
  -- Signal Assignments
  ---------------------------------------------------------------------------

  with idx_type_i select adc_req_base_addr <=
    adc_vs_base_addr_c when "010",
    adc_ia_base_addr_c when "011",
    adc_ib_base_addr_c when "100",
    (others => '0')    when others;

  ---------------------------------------------------------------------------
  -- Instances
  ---------------------------------------------------------------------------

  --! DIM FIFO
  dim_fifo_inst : entity work.fifo_tmr
    generic map (
      depth_g => 32,
      width_g => 20)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      wr_en_i     => dim_en_i,
      data_i      => dim_i,
      done_o      => open,
      full_o      => open,
      wr_busy_o   => dim_fifo_wr_busy,

      rd_en_i     => dim_fifo_rd_en,
      data_o      => dim_fifo_data,
      data_en_o   => dim_fifo_data_en,
      empty_o     => dim_fifo_empty,
      rd_busy_o   => open);

  --! ADC VS FIFO
  adc_vs_fifo_inst : entity work.fifo_tmr
    generic map (
      depth_g => 20,
      width_g => 24)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      wr_en_i     => adc_vs_en_i,
      data_i      => adc_vs_i,
      done_o      => open,
      full_o      => open,
      wr_busy_o   => adc_vs_fifo_wr_busy,

      rd_en_i     => adc_vs_fifo_rd_en,
      data_o      => adc_vs_fifo_data,
      data_en_o   => adc_vs_fifo_data_en,
      empty_o     => adc_vs_fifo_empty,
      rd_busy_o   => open);

  --! ADC IA FIFO
  adc_ia_fifo_inst : entity work.fifo_tmr
    generic map (
      depth_g => 20,
      width_g => 24)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      wr_en_i     => adc_ia_en_i,
      data_i      => adc_ia_i,
      done_o      => open,
      full_o      => open,
      wr_busy_o   => adc_ia_fifo_wr_busy,

      rd_en_i     => adc_ia_fifo_rd_en,
      data_o      => adc_ia_fifo_data,
      data_en_o   => adc_ia_fifo_data_en,
      empty_o     => adc_ia_fifo_empty,
      rd_busy_o   => open);

  --! ADC IB FIFO
  adc_ib_fifo_inst : entity work.fifo_tmr
    generic map (
      depth_g => 20,
      width_g => 24)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      wr_en_i     => adc_ib_en_i,
      data_i      => adc_ib_i,
      done_o      => open,
      full_o      => open,
      wr_busy_o   => adc_ib_fifo_wr_busy,

      rd_en_i     => adc_ib_fifo_rd_en,
      data_o      => adc_ib_fifo_data,
      data_en_o   => adc_ib_fifo_data_en,
      empty_o     => adc_ib_fifo_empty,
      rd_busy_o   => open);

  --! External SRAM data triplicator
  tmr_inst : entity work.mem_data_triplicator
    generic map (
      depth_g => 2**sram_addr'length,
      width_g => 16)
    port map (
      clk_i         => clk_i,
      rst_asy_n_i   => rst_asy_n_i,
      rst_syn_i     => rst_syn_i,

      addr_i        => tmr_addr,
      rd_en_i       => tmr_rd_en,
      wr_en_i       => tmr_wr_en,
      data_i        => tmr_data_in,
      data_o        => tmr_data_out,
      data_en_o     => tmr_data_en,
      busy_o        => tmr_busy,
      done_o        => tmr_done,
      voted_o       => open,

      mem_addr_o    => sram_addr,
      mem_rd_en_o   => sram_rd_en,
      mem_wr_en_o   => sram_wr_en,
      mem_data_o    => sram_data_in,
      mem_data_i    => sram_data_out,
      mem_data_en_i => sram_data_en,
      mem_busy_i    => sram_busy,
      mem_done_i    => sram_done);

  --! External SRAM interface
  sram_if_inst : entity work.sram_interface
    generic map (
      addr_width_g  => 20,
      data_width_g  => 16,
      read_delay_g  => 8,
      write_delay_g => 4)
    port map (
      clk_i         => clk_i,
      rst_asy_n_i   => rst_asy_n_i,
      rst_syn_i     => rst_syn_i,

      addr_i        => sram_addr,
      rd_en_i       => sram_rd_en,
      wr_en_i       => sram_wr_en,
      data_i        => sram_data_in,
      data_o        => sram_data_out,
      data_en_o     => sram_data_en,
      busy_o        => sram_busy,
      done_o        => sram_done,

      sram_addr_o   => sram_o.addr,
      sram_data_i   => sram_i.data,
      sram_data_o   => sram_o.data,
      sram_cs1_n_o  => sram_o.cs1_n,
      sram_cs2_o    => sram_o.cs2,
      sram_we_n_o   => sram_o.we_n,
      sram_oe_n_o   => sram_o.oe_n,
      sram_le_n_o   => sram_o.le_n,
      sram_ue_n_o   => sram_o.ue_n,
      sram_byte_n_o => sram_o.byte_n);

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

  comb : process (reg, idx_i, tmr_busy, tmr_done, tmr_data_out, tmr_data_en,
    adc_ia_fifo_empty, adc_ia_fifo_data_en, adc_ia_fifo_data,
    adc_ib_fifo_empty, adc_ib_fifo_data_en, adc_ib_fifo_data,
    adc_vs_fifo_empty, adc_vs_fifo_data_en, adc_vs_fifo_data,
    dim_fifo_empty, dim_fifo_data_en, dim_fifo_data, adc_rd_en_i,
    dim_rd_en_i, adc_addr_i, dim_addr_i, adc_req_base_addr,
    adc_done_i, dim_done_i, adc_freeze_i, dim_freeze_i, dim_fifo_wr_busy,
    adc_vs_fifo_wr_busy, adc_ia_fifo_wr_busy, adc_ib_fifo_wr_busy,
    ms_0_strobe_i) is
  begin -- comb
    -- Defaults
    next_reg <= reg;

    next_reg.adc_data_en <= '0';
    next_reg.dim_data_en <= '0';

    adc_vs_fifo_rd_en <= '0';
    adc_ia_fifo_rd_en <= '0';
    adc_ib_fifo_rd_en <= '0';
    dim_fifo_rd_en    <= '0';

    tmr_rd_en   <= '0';
    tmr_wr_en   <= '0';
    tmr_data_in <= (others => '0');
    tmr_addr    <= (others => '0');

    if adc_rd_en_i = '1' then
      next_reg.adc_rd_req <= '1';
    end if;

    if dim_rd_en_i = '1' then
      next_reg.dim_rd_req <= '1';
    end if;

    if ms_0_strobe_i = '1' and dim_freeze_i = '0' then
      next_reg.dim_idx <= reg.dim_idx + 1;
    end if;

    case reg.state is
      when RD_CHECK =>
        if adc_freeze_i = '0' and adc_ia_fifo_empty = '0' and adc_ib_fifo_empty = '0' and adc_vs_fifo_empty = '0' then
          next_reg.adc_idx <= reg.adc_idx + 1;
          next_reg.state   <= RD_ADC_IA;
        else
          next_reg.state <= RD_DIM;
        end if;

      when RD_ADC_IA =>
        if tmr_busy = '0' and adc_ia_fifo_wr_busy = '0' then
          adc_ia_fifo_rd_en <= '1';
          next_reg.state    <= WR_ADC_IA_0;
        end if;

      when WR_ADC_IA_0 =>
        if adc_ia_fifo_data_en = '1' then
          tmr_wr_en      <= '1';
          tmr_data_in    <= adc_ia_fifo_data(15 downto 0);
          tmr_addr       <= std_ulogic_vector(adc_ia_base_addr_c & reg.adc_idx & '0');
          next_reg.state <= WR_ADC_IA_1;
        end if;

      when WR_ADC_IA_1 =>
        if tmr_busy = '0' then
          tmr_wr_en      <= '1';
          tmr_data_in    <= (31 downto 24 => adc_ia_fifo_data(adc_ia_fifo_data'high)) & adc_ia_fifo_data(23 downto 16);
          tmr_addr       <= std_ulogic_vector(adc_ia_base_addr_c & reg.adc_idx & '1');
          next_reg.state <= RD_ADC_IB;
        end if;

      when RD_ADC_IB =>
        if tmr_busy = '0' and adc_ib_fifo_wr_busy = '0' then
          adc_ib_fifo_rd_en <= '1';
          next_reg.state    <= WR_ADC_IB_0;
        end if;

      when WR_ADC_IB_0 =>
        if adc_ib_fifo_data_en = '1' then
          tmr_wr_en      <= '1';
          tmr_data_in    <= adc_ib_fifo_data(15 downto 0);
          tmr_addr       <= std_ulogic_vector(adc_ib_base_addr_c & reg.adc_idx & '0');
          next_reg.state <= WR_ADC_IB_1;
        end if;

      when WR_ADC_IB_1 =>
        if tmr_busy = '0' then
          tmr_wr_en      <= '1';
          tmr_data_in    <= (31 downto 24 => adc_ib_fifo_data(adc_ib_fifo_data'high)) & adc_ib_fifo_data(23 downto 16);
          tmr_addr       <= std_ulogic_vector(adc_ib_base_addr_c & reg.adc_idx & '1');
          next_reg.state <= RD_ADC_VS;
        end if;

      when RD_ADC_VS =>
        if tmr_busy = '0' and adc_vs_fifo_wr_busy = '0' then
          adc_vs_fifo_rd_en <= '1';
          next_reg.state    <= WR_ADC_VS_0;
        end if;

      when WR_ADC_VS_0 =>
        if adc_vs_fifo_data_en = '1' then
          tmr_wr_en      <= '1';
          tmr_data_in    <= adc_vs_fifo_data(15 downto 0);
          tmr_addr       <= std_ulogic_vector(adc_vs_base_addr_c & reg.adc_idx & '0');
          next_reg.state <= WR_ADC_VS_1;
        end if;

      when WR_ADC_VS_1 =>
        if tmr_busy = '0' then
          tmr_wr_en      <= '1';
          tmr_data_in    <= (31 downto 24 => adc_vs_fifo_data(adc_vs_fifo_data'high)) & adc_vs_fifo_data(23 downto 16);
          tmr_addr       <= std_ulogic_vector(adc_vs_base_addr_c & reg.adc_idx & '1');
          next_reg.state <= RD_DIM;
        end if;

      when RD_DIM =>
        if tmr_busy = '0' and dim_fifo_wr_busy = '0' then
          if dim_fifo_empty = '0' and dim_freeze_i = '0' then
            dim_fifo_rd_en <= '1';
            next_reg.state <= WR_DIM;
          else
            next_reg.state <= FETCH_REQ;
          end if;
        end if;

      when WR_DIM =>
        if dim_fifo_data_en = '1' then
          tmr_wr_en      <= '1';
          tmr_data_in    <= dim_fifo_data(15 downto 0);
          tmr_addr       <= std_ulogic_vector(dim_base_addr_c + (unsigned(dim_fifo_data(19 downto 16)) & reg.dim_idx & unsigned(dim_fifo_data(13 downto 12))));
          next_reg.state <= FETCH_REQ;
        end if;

      when FETCH_REQ =>
        if reg.adc_rd_req = '1' then
          next_reg.state <= FETCH_ADC_0;
        elsif reg.dim_rd_req = '1' then
          next_reg.state <= FETCH_DIM;
        else
          next_reg.state <= RD_CHECK;
        end if;

      when FETCH_ADC_0 =>
        if tmr_busy = '0' then
          tmr_rd_en      <= '1';
          tmr_addr       <= std_ulogic_vector(adc_req_base_addr & (unsigned(idx_i) + unsigned(adc_addr_i)) & '0');
          next_reg.state <= STORE_ADC_0;
        end if;

      when STORE_ADC_0 =>
        if tmr_data_en = '1' then
          next_reg.adc_data(15 downto 0) <= tmr_data_out;
          next_reg.state <= FETCH_ADC_1;
        end if;

      when FETCH_ADC_1 =>
        if tmr_busy = '0' then
          tmr_rd_en      <= '1';
          tmr_addr       <= std_ulogic_vector(adc_req_base_addr & (unsigned(idx_i) + unsigned(adc_addr_i)) & '1');
          next_reg.state <= STORE_ADC_1;
        end if;

      when STORE_ADC_1 =>
        if tmr_data_en = '1' then
          next_reg.adc_data(23 downto 16) <= tmr_data_out(7 downto 0);
          next_reg.adc_data_en <= '1';
        end if;

        if adc_rd_en_i = '1' then
          next_reg.state <= FETCH_ADC_0;
        elsif adc_done_i = '1' then
          next_reg.state      <= RD_CHECK;
          next_reg.adc_rd_req <= '0';
        end if;

      when FETCH_DIM =>
        if tmr_busy = '0' then
          tmr_rd_en      <= '1';
          tmr_addr       <= std_ulogic_vector((dim_base_addr_c(18 downto 2) + unsigned(idx_i) + unsigned(dim_addr_i(4 downto 2)))) & dim_addr_i(1 downto 0);
          next_reg.state <= STORE_DIM;
        end if;

      when STORE_DIM =>
        if tmr_data_en = '1' then
          next_reg.dim_data    <= tmr_data_out;
          next_reg.dim_data_en <= '1';
        end if;

        if dim_rd_en_i = '1' then
          next_reg.state <= FETCH_DIM;
        elsif dim_done_i = '1' then
          next_reg.state      <= RD_CHECK;
          next_reg.dim_rd_req <= '0';
        end if;

    end case;
  end process comb;

end architecture rtl;
