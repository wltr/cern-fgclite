-------------------------------------------------------------------------------
--! @file      sefi_detector.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-11-19
--! @brief     Detect SEFI on external inputs.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.lfsr_pkg.all;

--! @brief Entity declaration of sefi_detector
--! @details
--! Detect a Single Event Functional Interrupt (SEFI) on an external input.

entity sefi_detector is
  generic (
    --! Number of stages to check
    num_g : positive := 10);
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
    --! @name SEFI signals
    --! @{

    --! Enable
    en_i   : in std_ulogic;
    --! Input
    sig_i  : in std_ulogic;
    --! Output
    sefi_o : out std_ulogic);

    --! @}
end entity sefi_detector;

--! RTL implementation of sefi_detector
architecture rtl of sefi_detector is

  ---------------------------------------------------------------------------
  -- Types and Constants
  ---------------------------------------------------------------------------

  -- LFSR counter bit length
  constant len_c : natural := lfsr_length(num_g);

  -- LFSR counter initial value
  constant seed_c : std_ulogic_vector(len_c - 1 downto 0) := lfsr_seed(len_c);

  -- LFSR counter max value
  constant max_c : std_ulogic_vector(len_c - 1 downto 0) := lfsr_shift(seed_c, num_g - 1);

  ---------------------------------------------------------------------------
  --! @name Internal Registers
  ---------------------------------------------------------------------------
  --! @{

  signal count : std_ulogic_vector(len_c - 1 downto 0);
  signal sig   : std_ulogic;
  signal sefi  : std_ulogic;

  --! @}

begin -- architecture rtl

  ---------------------------------------------------------------------------
  -- Outputs
  ---------------------------------------------------------------------------

  sefi_o <= sefi;

  ---------------------------------------------------------------------------
  -- Registers
  ---------------------------------------------------------------------------

  regs : process (clk_i, rst_asy_n_i) is
    procedure reset is
    begin
      count <= seed_c;
      sig   <= '0';
      sefi  <= '0';
    end procedure reset;
  begin -- process regs
    if rst_asy_n_i = '0' then
      reset;
    elsif rising_edge(clk_i) then
      if rst_syn_i = '1' then
        reset;
      else
        if en_i = '1' then
          sig  <= sig_i;

          if sig_i = sig then
            count <= lfsr_shift(count);
          else
            count <= seed_c;
          end if;
        end if;

        if count = max_c then
          sefi <= '1';
          count <= seed_c;
        end if;
      end if;
    end if;
  end process regs;

end architecture rtl;
