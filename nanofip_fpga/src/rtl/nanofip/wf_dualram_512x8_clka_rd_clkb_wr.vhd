--_________________________________________________________________________________________________
--                                                                                                |
--                                         |The nanoFIP|                                          |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                 wf_dualram_512x8_clka_rd_clkb_wr                               |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         wf_dualram_512x8_clka_rd_clkb_wr.vhd                                              |
--                                                                                                |
-- Description  The unit adds a layer over the dual port 512x8 memory, by disabling writing from  |
--              one side and reading from the other. Finally from port A only reading is possible |
--              and from port B only writing.                                                     |
--              Commented in the unit is the memory triplication. Precision RadTol makes the      |
--              triplication automatically; in Synplify the comments have to be removed. With the |
--              triplication each incoming byte is written at the same position in the three      |
--              memories, whereas each outgoing one is the outcome of a majority voter.           |
--                                                                                                |
--                                                                                                |
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)                             |
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)                                 |
-- Date         10/12/2010                                                                        |
-- Version      v0.02                                                                             |
-- Depends on   dualram_512x8.vhd                                                                 |
----------------                                                                                  |
-- Last changes                                                                                   |
--     12/2010  v0.02  EG  code cleaned-up+commented                                              |
--     11/2011  v0.03  EG  removed generics! addr+data lgth already defined at the                |
--                         dualram_512x8                                                          |
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
--                   Entity declaration for wf_dualram_512x8_clka_rd_clkb_wr
--=================================================================================================

entity wf_dualram_512x8_clka_rd_clkb_wr is port(
  -- INPUTS
    -- Inputs concerning port A
    clk_porta_i      : in std_logic;
    addr_porta_i     : in std_logic_vector (8 downto 0);

    -- Inputs concerning port B
    clk_portb_i      : in std_logic;
    addr_portb_i     : in std_logic_vector (8 downto 0);
    data_portb_i     : in std_logic_vector (7 downto 0);
    write_en_portb_i : in std_logic;


  -- OUTPUT
    -- Output concerning port A
    data_porta_o     : out std_logic_vector (7 downto 0));

end wf_dualram_512x8_clka_rd_clkb_wr;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture syn of wf_dualram_512x8_clka_rd_clkb_wr is

  signal s_one, s_rwB : std_logic;
  signal s_zeros      : std_logic_vector (7 downto 0);


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin

  s_one   <= '1';
  s_zeros <= (others => '0');
  s_rwB   <= not write_en_portb_i;

---------------------------------------------------------------------------------------------------
-- Port A used for reading only, port B for writing only.

--  for triplication: G_memory_triplication: for I in 0 to 2 generate

    DualRam : dualram_512x8
    port map(
      DINA   => s_zeros,
      ADDRA  => addr_porta_i,
      RWA    => s_one,
      CLKA   => clk_porta_i,

      DINB   => data_portb_i,
      ADDRB  => addr_portb_i,
      RWB    => s_rwB,
      CLKB   => clk_portb_i,

      RESETn => s_one,

      DOUTA  => data_porta_o, -- for triplication: s_data_o_A_array(I)
      DOUTB  => open);

--  end generate;


---------------------------------------------------------------------------------------------------
-- for triplication: Combinatorial Majority_Voter

-- for triplication: Majority_Voter: data_porta_o <= (s_data_o_A_array(0) and s_data_o_A_array(1)) or
--                                                   (s_data_o_A_array(1) and s_data_o_A_array(2)) or
--                                                   (s_data_o_A_array(2) and s_data_o_A_array(0));

end syn;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------