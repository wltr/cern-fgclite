-------------------------------------------------------------------------------
--! @file      sram_pkg.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-11-19
--! @brief     External SRAM package.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

--! @brief Package declaration of sram_pkg
--! @details
--! This provides types and constants for the external SRAM component.

package sram_pkg is

  ---------------------------------------------------------------------------
  -- Types and Constants
  ---------------------------------------------------------------------------

  type sram_in_t is record
    --! @brief Signals from external SRAM
    --! @param data SRAM data
    data : std_ulogic_vector(15 downto 0);
  end record sram_in_t;

  type sram_out_t is record
    --! @brief Signals to external SRAM
    --! @param addr   SRAM address
    --! @param data   SRAM data
    --! @param cs1_n  First chip-select (active-low)
    --! @param cs2    Second chip-select (active-high)
    --! @param we_n   Write enable (active-low)
    --! @param oe_n   Output enable (active-low)
    --! @param le_n   Lower byte enable (active-low)
    --! @param ue_n   Upper byte enable (active-low)
    --! @param byte_n Byte enable (active-low)
    addr   : std_ulogic_vector(19 downto 0);
    data   : std_ulogic_vector(15 downto 0);
    cs1_n  : std_ulogic;
    cs2    : std_ulogic;
    we_n   : std_ulogic;
    oe_n   : std_ulogic;
    le_n   : std_ulogic;
    ue_n   : std_ulogic;
    byte_n : std_ulogic;
  end record sram_out_t;

end package sram_pkg;
