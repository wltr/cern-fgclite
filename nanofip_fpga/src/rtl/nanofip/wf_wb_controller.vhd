--_________________________________________________________________________________________________
--                                                                                                |
--                                         |The nanoFIP|                                          |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                       wf_wb_controller                                         |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         wf_wb_controller.vhd                                                              |
--                                                                                                |
-- Description  The unit generates the "User Interface WISHBONE" signal ACK, nanoFIP's answer to  |
--              the user's STBs.                                                                  |
--                                                                                                |
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)                             |
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)                                 |
-- Date         21/01/2011                                                                        |
-- Version      v0.01                                                                             |
-- Depends on   wf_production                                                                     |
----------------                                                                                  |
-- Last changes                                                                                   |
--     21/01/2011  v0.011  EG  changed registering                                                |
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
--                           Entity declaration for wf_wb_controller
--=================================================================================================

entity wf_wb_controller is port(
  -- INPUTS
    -- nanoFIP User Interface, WISHBONE Slave
    wb_clk_i        : in std_logic;                      -- WISHBONE clock
    wb_rst_i        : in std_logic;                      -- WISHBONE reset
    wb_stb_i        : in std_logic;                      -- WISHBONE strobe
    wb_cyc_i        : in std_logic;                      -- WISHBONE cycle
    wb_we_i         : in std_logic;                      -- WISHBONE write enable
    wb_adr_id_i     : in  std_logic_vector (2 downto 0); -- 3 first bits of WISHBONE address


  -- OUTPUTS
    -- Signal from the wf_production_unit
    wb_ack_prod_p_o : out std_logic;                     -- response to a write cycle
                                                         -- latching moment of wb_dat_i
    -- nanoFIP User Interface, WISHBONE Slave output
    wb_ack_p_o      : out std_logic);                    -- WISHBONE acknowledge

end entity wf_wb_controller;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of wf_wb_controller is

  signal s_wb_ack_write_p, s_wb_ack_read_p, s_wb_stb_r_edge_p : std_logic;
  signal s_wb_we_synch, s_wb_cyc_synch                        : std_logic_vector (2 downto 0);
  signal s_wb_stb_synch                                       : std_logic_vector (3 downto 0);


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--                                       Input Synchronizers                                     --
---------------------------------------------------------------------------------------------------

-- Synchronization of the WISHBONE control signals: stb, cyc, we.

  WISHBONE_inputs_synchronization: process (wb_clk_i)
  begin
   if rising_edge (wb_clk_i) then
     if wb_rst_i = '1' then          -- wb_rst is not buffered to comply with WISHBONE rule 3.15
       s_wb_stb_synch  <= (others => '0');
       s_wb_cyc_synch  <= (others => '0');
       s_wb_we_synch   <= (others => '0');

      else
        s_wb_stb_synch <= s_wb_stb_synch (2 downto 0) & wb_stb_i;
        s_wb_cyc_synch <= s_wb_cyc_synch (1 downto 0) & wb_cyc_i;
        s_wb_we_synch  <= s_wb_we_synch  (1 downto 0) & wb_we_i;
      end if;
    end if;
  end process;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  s_wb_stb_r_edge_p  <= (not s_wb_stb_synch(3)) and s_wb_stb_synch(2);



---------------------------------------------------------------------------------------------------
--                                      ACK outputs Generation                                   --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Generation of the wb_ack_write_p signal (acknowledgement from WISHBONE Slave of the write cycle,
-- as a response to the master's storbe). The 1 wb_clk-wide pulse is generated if the wb_cyc and
-- wb_we are asserted and the WISHBONE input address corresponds to an address in the Produced
-- memory block.

  s_wb_ack_write_p <= '1' when ((s_wb_stb_r_edge_p = '1') and
                                (s_wb_we_synch (2) = '1') and
                                (s_wb_cyc_synch(2) = '1') and
                                (wb_adr_id_i       = "010")) else '0';

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Generation of the wb_ack_read_p signal (acknowledgement from WISHBONE Slave of the read cycle,
-- as a response to the master's strobe). The 1 wb_clk-wide pulse is generated if the wb_cyc is
-- asserted, the wb_we is deasserted and the WISHBONE input address corresponds to an address in
-- the Consumed memory block.

  s_wb_ack_read_p <= '1' when ((s_wb_stb_r_edge_p       = '1') and
                               (s_wb_cyc_synch(2)       = '1') and
                               (s_wb_we_synch(2)        = '0') and
                               (wb_adr_id_i(2 downto 1) = "00")) else '0';

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Output registrers

   WB_ACK_Output_Reg: process (wb_clk_i)
   begin
     if rising_edge (wb_clk_i) then
       if wb_rst_i = '1' then
         wb_ack_p_o      <= '0';
         wb_ack_prod_p_o <= '0';
       else
         wb_ack_p_o      <= s_wb_ack_read_p or s_wb_ack_write_p;
         wb_ack_prod_p_o <= s_wb_ack_write_p;
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