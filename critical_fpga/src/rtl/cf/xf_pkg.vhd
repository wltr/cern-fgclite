-------------------------------------------------------------------------------
--! @file      xf_pkg.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-07-11
--! @brief     Auxiliary FPGA package.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

--! @brief Package declaration of xf_pkg
--! @details
--! This provides types and constants for the Auxiliary FPGA component.

package xf_pkg is

  ---------------------------------------------------------------------------
  -- Types and Constants
  ---------------------------------------------------------------------------

  type xf_in_t is record
    --! @brief Signals from XF
    --! @param rx_frame  2 x serial frame
    --! @param rx_bit_en 2 x serial bit enable
    --! @param rx        2 x serial data
    rx_frame  : std_ulogic_vector(1 downto 0);
    rx_bit_en : std_ulogic_vector(1 downto 0);
    rx        : std_ulogic_vector(1 downto 0);
  end record xf_in_t;

  type xf_out_t is record
    --! @brief Signals to XF
    --! @param dim_trig      2 x serial frame
    --! @param dim_rst       2 x serial bit enable
    --! @param ow_trig       2 x serial data
    --! @param ow_bus_select 2 x serial data
    dim_trig      : std_ulogic;
    dim_rst       : std_ulogic;
    ow_trig       : std_ulogic;
    ow_bus_select : std_ulogic_vector(2 downto 0);
  end record xf_out_t;

end package xf_pkg;
