-------------------------------------------------------------------------------
--! @file      nf_top_pkg.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-12-01
--! @brief     NanoFIP FPGA package.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

--! @brief Package declaration of nf_top_pkg
--! @details
--! This provides types and constants for the NanoFIP FPGA.

package nf_top_pkg is

  ---------------------------------------------------------------------------
  -- Types and Constants
  ---------------------------------------------------------------------------

  --! NanoFIP FPGA version number
  constant NF_VERSION_c : std_ulogic_vector(3 downto 0) := "0001";

end package nf_top_pkg;
