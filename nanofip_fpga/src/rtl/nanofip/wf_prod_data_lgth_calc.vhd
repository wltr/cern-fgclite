--_________________________________________________________________________________________________
--                                                                                                |
--                                         |The nanoFIP|                                          |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                     wf_prod_data_lgth_calc                                     |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         wf_prod_data_lgth_calc.vhd                                                        |
--                                                                                                |
-- Description  Calculation of the number of bytes, after the FSS and before the FCS, that have to|
--              be transferred when a variable is produced (var_pres, var_identif, var_3, var_5)  |
--              As the following figure indicates, in detail, the unit adds-up:                   |
--               o  1 byte RP_DAT.CTRL,                                                           |
--               o  1 byte RP_DAT.Data.PDU_TYPE,                                                  |
--               o  1 byte RP_DAT.Data.LGTH,                                                      |
--               o  1-124 RP_DAT.Data.User_Data bytes according to the variable type:             |
--                  - var_pres: 5 bytes                                                           |
--                  - var_pres: 8 bytes                                                           |
--                  - var_5   : 1 byte                                                            |
--                  - var_3   : 2-124 bytes defined by the "nanoFIP User Interface,General signal"| 
--                              SLONE and the "nanoFIP WorldFIP Settings" input P3_LGTH,          |
--               o  1 byte RP_DAT.Data.nanoFIP_status, always for a var_5                         |
--                                                     and for a var_3, if the "nanoFIP User      |
--                                                     Interface General signal"NOSTAT is negated,|
--               o  1 byte RP_DAT.Data.MPS_status, for a var_3 and a var_5                        |
--                                                                                                |
--                                                                                                |
--              Reminder:                                                                         |
--                                                                                                |
--              Produced RP_DAT frame structure :                                                 |
--                     ||--------------------- Data ---------------------||                       |
--   ___________ ______  _______ ______ _________________ _______ _______  ___________ _______    |
--  |____FSS____|_CTRL_||__PDU__|_LGTH_|__..User-Data..__|_nstat_|__MPS__||____FCS____|__FES__|   |
--                                                                                                |
--                                     |-----P3_LGTH-----|                                        |
--                                                                                                |
--                                                                                                |
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)                             |
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)                                 |
-- Date         09/12/2010                                                                        |
-- Version      v0.02                                                                             |
-- Depends on   wf_engine_control                                                                 |
----------------                                                                                  |
-- Last changes                                                                                   |
--     12/2010 v0.02 EG  code cleaned-up+commented                                                |
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
--                                      Libraries & Packages
--=================================================================================================

-- Standard library
library IEEE;
use IEEE.STD_LOGIC_1164.all; -- std_logic definitions
use IEEE.NUMERIC_STD.all;    -- conversion functions
-- Specific library
library work;
use work.WF_PACKAGE.all;     -- definitions of types, constants, entities


--=================================================================================================
--                           Entity declaration for wf_prod_data_lgth_calc
--=================================================================================================

entity wf_prod_data_lgth_calc is port(
  -- INPUTS
    -- nanoFIP User Interface, General signals
    uclk_i               : in std_logic;                 -- 40 MHz clock

    -- Signal from the wf_reset_unit
    nfip_rst_i           : in std_logic;                 -- nanoFIP internal reset

    -- nanoFIP WorldFIP Settings
    p3_lgth_i        : in std_logic_vector (2 downto 0); -- produced var user-data length

    -- User Interface, General signals
    nostat_i         : in std_logic;                     -- if negated, nFIP status is sent
    slone_i          : in std_logic;                     -- stand-alone mode

    -- Signal from the wf_engine_control unit
    var_i            : in t_var;                         -- variable type that is being treated


  -- OUTPUT
    -- Signal to the wf_engine_control and wf_production units
    prod_data_lgth_o : out std_logic_vector (7 downto 0));

end entity wf_prod_data_lgth_calc;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture behavior of wf_prod_data_lgth_calc is

  signal s_prod_data_lgth, s_p3_lgth_decoded : unsigned (7 downto 0);


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin

---------------------------------------------------------------------------------------------------
-- Combinatorial process data_length_calcul: calculation of the amount of bytes, after the
-- FSS and before the FCS, that have to be transferred when a variable is produced. In the case
-- of the presence, the identification and the var5 variables, the data length is predefined in the
-- WF_PACKAGE. In the case of a var3 the inputs SLONE, NOSTAT and P3_LGTH[] are accounted for the
-- calculation.

  data_length_calcul: process (var_i, s_p3_lgth_decoded, slone_i, nostat_i, p3_lgth_i)
  begin

    s_p3_lgth_decoded        <= c_P3_LGTH_TABLE (to_integer(unsigned(p3_lgth_i)));

    case var_i is


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
      when var_presence =>
      -- data length information retrieval from the c_VARS_ARRAY matrix (WF_PACKAGE)
        s_prod_data_lgth     <= c_VARS_ARRAY(c_VAR_PRESENCE_INDEX).array_lgth;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
      when var_identif =>
      -- data length information retrieval from the c_VARS_ARRAY matrix (WF_PACKAGE)
        s_prod_data_lgth     <= c_VARS_ARRAY(c_VAR_IDENTIF_INDEX).array_lgth;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
      when var_3 =>
      -- data length calculation according to the operational mode (memory or stand-alone)

      -- in slone mode                   2 bytes of user-data are produced (independently of P3_LGTH)
      -- to these there should be added: 1 byte CTRL
      --                                 1 byte PDU_TYPE
      --                                 1 byte LGTH
      --                                 1 byte MPS status
      --                      optionally 1 byte nFIP status

      -- in memory mode the signal      "s_p3_lgth_decoded" indicates the amount of user-data;
      -- to these, there should be added 1 byte CTRL
      --                                 1 byte PDU_TYPE
      --                                 1 byte LGTH
      --                                 1 byte MPS status
      --                      optionally 1 byte nFIP status

        if slone_i = '1' then

          if nostat_i = '1' then                              -- 6 bytes (counting starts from 0!)
            s_prod_data_lgth <= to_unsigned(5, s_prod_data_lgth'length);

          else                                                -- 7 bytes
            s_prod_data_lgth <= to_unsigned(6, s_prod_data_lgth'length);
          end if;


        else
          if nostat_i = '0' then
            s_prod_data_lgth <= s_p3_lgth_decoded + 4;

          else
            s_prod_data_lgth <= s_p3_lgth_decoded + 3;
          end if;
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
      when var_5 =>
      -- data length information retrieval from the c_VARS_ARRAY matrix (WF_PACKAGE)
        s_prod_data_lgth     <= c_VARS_ARRAY(c_VAR_5_INDEX).array_lgth;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
      when others =>
        s_prod_data_lgth     <= (others => '0');

    end case;
  end process;



  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- Registration of the output (coz of slack)

  Prod_Data_Lgth_Reg: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        prod_data_lgth_o <= (others =>'0');

      else
        prod_data_lgth_o <= std_logic_vector (s_prod_data_lgth);
 
      end if;
    end if;
  end process;


end architecture behavior;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------