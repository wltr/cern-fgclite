-------------------------------------------------------------------------------
--! @file      nf_tx_registers.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-07-23
--! @brief     NanoFIP transmitter registers.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nf_pkg.all;

--! @brief Entity declaration of nf_tx_registers
--! @details
--! FGClite is sending 60 bytes of status registers as part of it's response
--! to the gateway.

entity nf_tx_registers is
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
    --! @name NanoFIP read interface
    --! @{

    --! Read enable
    rd_en_i   : in  std_ulogic;
    --! Address
    addr_i    : in  std_ulogic_vector(5 downto 0);
    --! Data
    data_o    : out std_ulogic_vector(7 downto 0);
    --! Data enable
    data_en_o : out std_ulogic;

    --! @}
    --! @name Registers
    --! @{

    --! FGClite status
    status_i : in nf_status_t);

    --! @}
end entity nf_tx_registers;

--! RTL implementation of nf_tx_registers
architecture rtl of nf_tx_registers is

  ---------------------------------------------------------------------------
  --! @name Types and Constants
  ---------------------------------------------------------------------------
  --! @{

  type reg_t is array (0 to 2**addr_i'length - 1) of std_ulogic_vector(data_o'range);

  --! @}
  ---------------------------------------------------------------------------
  --! @name Internal Registers
  ---------------------------------------------------------------------------
  --! @{

  signal reg : reg_t;

  signal data    : std_ulogic_vector(data_o'range);
  signal data_en : std_ulogic;

  --! @}

begin -- architecture rtl

  ---------------------------------------------------------------------------
  -- Outputs
  ---------------------------------------------------------------------------

  data_o    <= data;
  data_en_o <= data_en;

  ---------------------------------------------------------------------------
  -- Registers
  ---------------------------------------------------------------------------

  regs : process (clk_i, rst_asy_n_i) is
    procedure reset is
    begin
      reg <= (others => (others => '0'));

      data    <= (others => '0');
      data_en <= '0';
    end procedure reset;
  begin -- process regs
    if rst_asy_n_i = '0' then
      reset;
    elsif rising_edge(clk_i) then
      if rst_syn_i = '1' then
        reset;
      else
        --Defaults
        data_en <= '0';

        if rd_en_i = '1' then
          data    <= reg(to_integer(unsigned(addr_i)));
          data_en <= '1';
        end if;

        if status_i.adc_acc_vs_0_en = '1' then
          reg(0) <= status_i.adc_acc_vs_0(7 downto 0);
          reg(1) <= status_i.adc_acc_vs_0(15 downto 8);
          reg(2) <= status_i.adc_acc_vs_0(23 downto 16);
          reg(3) <= status_i.adc_acc_vs_0(31 downto 24);
        end if;

        if status_i.adc_acc_vs_1_en = '1' then
          reg(4) <= status_i.adc_acc_vs_1(7 downto 0);
          reg(5) <= status_i.adc_acc_vs_1(15 downto 8);
          reg(6) <= status_i.adc_acc_vs_1(23 downto 16);
          reg(7) <= status_i.adc_acc_vs_1(31 downto 24);
        end if;

        if status_i.adc_acc_ia_0_en = '1' then
          reg(8) <= status_i.adc_acc_ia_0(7 downto 0);
          reg(9) <= status_i.adc_acc_ia_0(15 downto 8);
          reg(10) <= status_i.adc_acc_ia_0(23 downto 16);
          reg(11) <= status_i.adc_acc_ia_0(31 downto 24);
        end if;

        if status_i.adc_acc_ia_1_en = '1' then
          reg(12) <= status_i.adc_acc_ia_1(7 downto 0);
          reg(13) <= status_i.adc_acc_ia_1(15 downto 8);
          reg(14) <= status_i.adc_acc_ia_1(23 downto 16);
          reg(15) <= status_i.adc_acc_ia_1(31 downto 24);
        end if;

        if status_i.adc_acc_ib_0_en = '1' then
          reg(16) <= status_i.adc_acc_ib_0(7 downto 0);
          reg(17) <= status_i.adc_acc_ib_0(15 downto 8);
          reg(18) <= status_i.adc_acc_ib_0(23 downto 16);
          reg(19) <= status_i.adc_acc_ib_0(31 downto 24);
        end if;

        if status_i.adc_acc_ib_1_en = '1' then
          reg(20) <= status_i.adc_acc_ib_1(7 downto 0);
          reg(21) <= status_i.adc_acc_ib_1(15 downto 8);
          reg(22) <= status_i.adc_acc_ib_1(23 downto 16);
          reg(23) <= status_i.adc_acc_ib_1(31 downto 24);
        end if;

        if status_i.dim_a_trig_lat_en = '1' then
          reg(24) <= status_i.dim_a_trig_lat(7 downto 0);
          reg(25) <= status_i.dim_a_trig_lat(15 downto 8);
        end if;

        if status_i.dim_a_trig_unl_en = '1' then
          reg(26) <= status_i.dim_a_trig_unl(7 downto 0);
          reg(27) <= status_i.dim_a_trig_unl(15 downto 8);
        end if;

        if status_i.dim_a1_ana_0_en = '1' then
          reg(28) <= status_i.dim_a1_ana_0(7 downto 0);
          reg(29) <= status_i.dim_a1_ana_0(15 downto 8);
        end if;

        if status_i.dim_a1_ana_1_en = '1' then
          reg(30) <= status_i.dim_a1_ana_1(7 downto 0);
          reg(31) <= status_i.dim_a1_ana_1(15 downto 8);
        end if;

        if status_i.dim_a1_ana_2_en = '1' then
          reg(32) <= status_i.dim_a1_ana_2(7 downto 0);
          reg(33) <= status_i.dim_a1_ana_2(15 downto 8);
        end if;

        if status_i.dim_a1_ana_3_en = '1' then
          reg(34) <= status_i.dim_a1_ana_3(7 downto 0);
          reg(35) <= status_i.dim_a1_ana_3(15 downto 8);
        end if;

        if status_i.cycle_period_en = '1' then
          reg(36) <= status_i.cycle_period(7 downto 0);
          reg(37) <= status_i.cycle_period(15 downto 8);
          reg(38) <= status_i.cycle_period(23 downto 16);
          reg(39) <= status_i.cycle_period(31 downto 24);
        end if;

        if status_i.version_cfnf_en = '1' then
          reg(40) <= status_i.version_cfnf(7 downto 0);
        end if;

        if status_i.version_xfpf_en = '1' then
          reg(41) <= status_i.version_xfpf(7 downto 0);
        end if;

        if status_i.adc_log_idx_en = '1' then
          reg(42) <= status_i.adc_log_idx(7 downto 0);
          reg(43) <= status_i.adc_log_idx(15 downto 8);
        end if;

        if status_i.dim_log_idx_en = '1' then
          reg(44) <= status_i.dim_log_idx(7 downto 0);
          reg(45) <= status_i.dim_log_idx(15 downto 8);
        end if;

        if status_i.vs_dig_in_en = '1' then
          reg(46) <= status_i.vs_dig_in(7 downto 0);
          reg(47) <= status_i.vs_dig_in(15 downto 8);
        end if;

        if status_i.vs_dig_out_en = '1' then
          reg(48) <= status_i.vs_dig_out;
        end if;

        if status_i.seu_count_en = '1' then
          reg(49) <= status_i.seu_count;
        end if;

        if status_i.fgc_status_en = '1' then
          reg(50) <= status_i.fgc_status(7 downto 0);
          reg(51) <= status_i.fgc_status(15 downto 8);
        end if;

        if status_i.backplane_en = '1' then
          reg(52) <= status_i.backplane;
        end if;

        if status_i.serial_data_en = '1' then
          reg(53 + to_integer(unsigned(status_i.serial_num))) <= status_i.serial_data;
        end if;
      end if;
    end if;
  end process regs;

end architecture rtl;
