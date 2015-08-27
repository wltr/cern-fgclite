-------------------------------------------------------------------------------
--! @file      pf.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2015-01-19
--! @brief     Power FPGA communication.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

--! @brief Entity declaration of pf
--! @details
--! This component handles the Power FPGA communication and takes action in
--! case field-bus communication is broken.

entity pf is
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
    --! @name PF interface
    --! @{

    --! Send power cycle request to PF
    pf_req_n_o      : out std_ulogic;
    --! Enable power down on PF
    pf_pwr_dwn_en_o : out std_ulogic;
    --! Power down signal from PF
    pf_pwr_dwn_i    : in  std_ulogic;

    --! @}
    --! @name Internal interface
    --! @{

    --! Start of cycle
    ms_0_strobe_i      : in  std_ulogic;
    --! Millisecond strobe
    ms_9_strobe_i      : in  std_ulogic;
    --! Millisecond strobe
    ms_11_strobe_i     : in  std_ulogic;
    --! Voltage reference input
    v_ref_i            : in  std_ulogic_vector(15 downto 0);
    --! Voltage reference output
    v_ref_o            : out std_ulogic_vector(15 downto 0);
    --! Voltage reference output enable
    v_ref_en_o         : out std_ulogic;
    --! Flag indicating voltage reference override
    v_ref_override_o   : out std_ulogic;
    --! Backplane type
    backplane_i        : in  std_ulogic_vector(7 downto 0);
    --! Flags indicating which commands have been received
    command_received_i : in  std_ulogic_vector(3 downto 0));

    --! @}
end entity pf;

--! RTL implementation of pf
architecture rtl of pf is

  ---------------------------------------------------------------------------
  --! @name Internal Registers
  ---------------------------------------------------------------------------
  --! @{

  signal pf_req_n      : std_ulogic;
  signal pf_pwr_dwn_en : std_ulogic;
  signal pwr_cyc_chk   : std_ulogic_vector(1 downto 0);

  signal v_ref     : unsigned(15 downto 0);
  signal v_ref_en  : std_ulogic;
  signal v_ref_ovr : std_ulogic;

  --! @}
  ---------------------------------------------------------------------------
  --! @name Internal Wires
  ---------------------------------------------------------------------------
  --! @{

  signal rmp_dwn_strb_rst : std_ulogic;
  signal rmp_dwn_strb_en  : std_ulogic;
  signal rmp_dwn_strb     : std_ulogic;

  signal pf_pwr_dwn_redge : std_ulogic;

  --! @}

begin -- architecture rtl

  ---------------------------------------------------------------------------
  -- Outputs
  ---------------------------------------------------------------------------

  pf_req_n_o      <= pf_req_n;
  pf_pwr_dwn_en_o <= pf_pwr_dwn_en;

  v_ref_o          <= std_ulogic_vector(v_ref);
  v_ref_en_o       <= v_ref_en;
  v_ref_override_o <= v_ref_ovr;

  ---------------------------------------------------------------------------
  -- Signal Assignments
  ---------------------------------------------------------------------------

  rmp_dwn_strb_rst <= not rmp_dwn_strb_en;
  rmp_dwn_strb_en  <= v_ref_ovr;

  ---------------------------------------------------------------------------
  -- Instances
  ---------------------------------------------------------------------------

  strobe_inst : entity work.lfsr_strobe_generator
    generic map (
      period_g       => 3051, -- 3051 * 25 ns = 76.275 us
      preset_value_g => 0)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      en_i     => rmp_dwn_strb_en,
      pre_i    => rmp_dwn_strb_rst,
      strobe_o => rmp_dwn_strb);

  pwr_dwn_edge_inst : entity work.edge_detector
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,

      en_i   => '1',
      ack_i  => '1',
      sig_i  => pf_pwr_dwn_i,
      edge_o => pf_pwr_dwn_redge);

  ---------------------------------------------------------------------------
  -- Registers
  ---------------------------------------------------------------------------

  regs : process (clk_i, rst_asy_n_i) is
    procedure reset is
    begin
      pf_req_n      <= '1';
      pf_pwr_dwn_en <= '0';
      pwr_cyc_chk   <= "00";

      v_ref     <= to_unsigned(0, v_ref'length);
      v_ref_en  <= '0';
      v_ref_ovr <= '0';
    end procedure reset;
  begin -- process regs
    if rst_asy_n_i = '0' then
      reset;
    elsif rising_edge(clk_i) then
      if rst_syn_i = '1' then
        reset;
      else
        if ms_0_strobe_i = '1' then
          if command_received_i = "0000" then
            pwr_cyc_chk <= pwr_cyc_chk(0) & '1';
          else
            pwr_cyc_chk   <= "00";
            pf_pwr_dwn_en <= '1';
          end if;
        end if;

        if ms_9_strobe_i = '1' and pwr_cyc_chk(1) = '1' then
          pf_req_n <= '0';
        elsif ms_11_strobe_i = '1' then
          if pf_req_n = '0' then
            pf_pwr_dwn_en <= '0';
          end if;
          pf_req_n <= '1';
        end if;

        if pf_pwr_dwn_redge = '1' and pwr_cyc_chk(1) = '1' then
          v_ref     <= unsigned(v_ref_i);
          v_ref_ovr <= '1';
        end if;

        v_ref_en <= '0';
        if v_ref_ovr = '1' and rmp_dwn_strb = '1' then
          if to_integer(v_ref) > 0 then
            v_ref    <= v_ref - 1;
            v_ref_en <= '1';
          end if;
        end if;

        -- Don't do anything when backplane type is x00
        if backplane_i = x"00" then
          reset;
        end if;
      end if;
    end if;
  end process regs;

end architecture rtl;
