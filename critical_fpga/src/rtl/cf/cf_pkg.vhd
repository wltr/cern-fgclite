-------------------------------------------------------------------------------
--! @file      cf_pkg.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-12-01
--! @brief     Critical FPGA package.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

--! @brief Package declaration of cf_pkg
--! @details
--! This provides types and constants for the Critical FPGA.

package cf_pkg is

  ---------------------------------------------------------------------------
  -- Types and Constants
  ---------------------------------------------------------------------------

  --! Critical FPGA version number
  constant CF_VERSION_c : std_ulogic_vector(3 downto 0) := "0001";

  --! Offset value for the first millisecond upon reception of COMMAND 0
  constant cmd_0_pre_value_c : std_ulogic_vector(15 downto 0) := x"5F78"; -- 24440 * 25 ns = 611 us

  --! Period for the millisecond strobe
  constant ms_period_c : std_ulogic_vector(15 downto 0) := x"9C40"; -- 40000 * 25 ns = 1 ms

end package cf_pkg;
