--_________________________________________________________________________________________________
--                                                                                                |
--                                         |The nanoFIP|                                          |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                        wf_prod_permit                                          |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         wf_prod_permit.vhd                                                                |
--                                                                                                |
-- Description  Generation of the "nanoFIP User Interface, NON_WISHBONE" output signal VAR3_RDY,  |
--              according to the variable (var_i) that is being treated.                          |
--                                                                                                |
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)                             |
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)                                 |
-- Date         14/1/2011                                                                         |
-- Version      v0.01                                                                             |
-- Depends on   wf_engine_control                                                                 |
--              wf_reset_unit                                                                     |
----------------                                                                                  |
-- Last changes                                                                                   |
--     1/2011  v0.01  EG  First version                                                           |
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
--                               GNU LESSER GENERAL PUBLIC LICENSE                                |
--                              ------------------------------------                              |
-- This source file is free software; you can redistribute it and/or modify it under the terms of |
-- the GNU Lesser General Public License as published by the Free Software Foundation; either     |
-- version 2.1 of the License, or (at your option) any later version.                             |
-- This source is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;       |
-- without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.      |
-- See the GNU Lesser General Public License for more details.                                    |
-- You should have received a copy of the GNU Lesser General Public License along with this       |
-- source; if not, download it from http://www.gnu.org/licenses/lgpl-2.1.html                     |
---------------------------------------------------------------------------------------------------



--=================================================================================================
--                                       Libraries & Packages
--=================================================================================================

-- Standard library
library IEEE;
use IEEE.STD_LOGIC_1164.all; -- std_logic definitions
use IEEE.NUMERIC_STD.all;    -- conversion functions
-- Specific library
library work;
use work.WF_PACKAGE.all;     -- definitions of types, constants, entities


--=================================================================================================
--                           Entity declaration for wf_prod_permit
--=================================================================================================

entity wf_prod_permit is port(
  -- INPUTS
    -- nanoFIP User Interface, General signals
    uclk_i                : in std_logic;      -- 40 MHz clock

    -- Signal from the wf_reset_unit
    nfip_rst_i            : in std_logic;      -- nanoFIP internal reset

    -- Signals from the wf_engine_control
    var_i                 : in t_var;          -- variable type that is being treated


  -- OUTPUT
    -- nanoFIP User Interface, NON-WISHBONE outputs
    var3_rdy_o            : out std_logic);    -- signals the user that data can safely be written

end entity wf_prod_permit;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of wf_prod_permit is

--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
-- Synchronous process VAR3_RDY_Generation:

-- VAR3_RDY: signals that the user can safely write to the produced variable memory or to the
-- DAT_I bus. It is deasserted right after the end of the reception of a correct var_3 ID_DAT frame
-- and stays de-asserted until the end of the transmission of the corresponding RP_DAT from nanoFIP.

-- Note: A correct ID_DAT frame along with the variable it contained is signaled by the var_i.
-- For produced variables, the signal var_i gets its value after the reception of a correct ID_DAT
-- frame and retains it until the end of the transmission of the corresponding RP_DAT.
-- An example follows:
-- frames  : ___[ID_DAT,var_3]__[......RP_DAT......]______________[ID_DAT,var_3]___[.....RP_DAT..
-- var_i   :    var_whatever  > <       var_3      > <        var_whatever        > <   var_3
-- VAR3_RDY: -------------------|__________________|--------------------------------|___________

  VAR_RDY_Generation: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        var3_rdy_o   <= '0';

      else
      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --
        case var_i is

         when var_3 =>                     -- nanoFIP is producing
                                              ---------------------
          var3_rdy_o <= '0';               -- while producing, VAR3_RDY is 0


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --
        when others =>

          var3_rdy_o <= '1';

        end case;
      end if;
    end if;
  end process;


end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------