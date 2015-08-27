--_________________________________________________________________________________________________
--                                                                                                |
--                                         |The nanoFIP|                                          |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                         dualram_512x8                                          |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         dualram_512x8.vhd                                                                 |
--                                                                                                |
-- Description  Instantiation of a template ProAsic3 RAM4K9 memory component with                 |
--                o word width: 8 bits and                                                        |
--                o depth     : 512 bytes.                                                        |
--                                                                                                |
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)                             |
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)                                 |
-- Date         15/12/2010                                                                        |
-- Version      v0.02                                                                             |
-- Depends on   ProASIC3 lib                                                                      |
----------------                                                                                  |
-- Last changes                                                                                   |
--        08/2010  v0.01  EG  pepeline not used! data appears in output 1 clock cycle after the   |
--                            address is given (otherwise it was 2 clock cycles later) slack      |
--                            checked and is ok! code cleaned-up and commented                    |
--     15/12/2010  v0.02  EG  comments for BLKA, BLKB; cleaning-up                                |
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
-- Component specific library
library PROASIC3;            -- ProASIC3 library
use PROASIC3.all;


--=================================================================================================
--                             Entity declaration for dualram_512x8
--=================================================================================================

entity dualram_512x8 is port(
  -- INPUTS
    -- Inputs concerning port A
    CLKA   : in std_logic;  -- clock A for synchronous read/ write operations
    ADDRA  : in std_logic_vector (8 downto 0);  -- address A
    DINA   : in std_logic_vector (7 downto 0);  -- data in A
    RWA    : in std_logic;  -- read/ write mode; 1 for reading, 0 for writing

    -- Inputs concerning port B
    CLKB   : in std_logic;  -- clock B for synchronous read/ write operations
    ADDRB  : in std_logic_vector (8 downto 0);  -- address B
    DINB   : in std_logic_vector (7 downto 0);  -- data in B
    RWB    : in std_logic;  -- read/ write mode; 1 for reading, 0 for writing

    -- Reset
    RESETn : in std_logic;  -- sets all outputs low; does not reset the memory


  -- OUTPUTS
    -- Output concerning port A
    DOUTA  : out std_logic_vector (7 downto 0); -- data out A

    -- Output concerning port B
    DOUTB  : out std_logic_vector (7 downto 0));-- data out B
end dualram_512x8;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture RAM4K9 of dualram_512x8 is

---------------------------------------------------------------------------------------------------
-- General information concerning RAM4K9: a fully synchronous, true dual-port RAM with an optional
-- pipeline stage. It provides variable aspect ratios of 4096 x 1, 2048 x 2, 1024 x 4 and 512 x 9.
-- Both ports are capable of reading and writing, making it possible to write with both ports or
-- read with both ports simultaneously. Moreover, reading from one port while writing to the other
-- is possible.

-- WIDTHA0, WIDTHA1 and WIDTHB0, WIDTHB1:
-- Aspect ratio configuration.

-- WENA, WENB:
-- Switching between Read and Write modes for the respective ports.
-- A Low indicates Write operation and a High indicates a Read.

-- BLKA, BLKB:
-- Active low enable for the respective ports.

-- PIPEA, PIPEB:
-- Control of the optional pipeline stages.
-- A Low on the PIPEA or PIPEB indicates a non-pipelined Read and the data appears on the output
-- in the same clock cycle.
-- A High indicates a pipelined Read and data appears on the output in the next clock cycle.

-- WMODEA, WMODEB:
-- Configuration of the behavior of the output when the RAM is in the Write mode.
-- A Low on this signal makes the output retain data from the previous Read. A High indicates a
-- pass-through behavior where the data being written will appear on the output immediately.

  component RAM4K9
    generic (MEMORYFILE : string := "");

    port(
      ADDRA11, ADDRA10, ADDRA9, ADDRA8, ADDRA7, ADDRA6,
      ADDRA5, ADDRA4, ADDRA3, ADDRA2, ADDRA1, ADDRA0,
      ADDRB11, ADDRB10, ADDRB9, ADDRB8, ADDRB7, ADDRB6,
      ADDRB5, ADDRB4, ADDRB3, ADDRB2, ADDRB1, ADDRB0,
      DINA8, DINA7, DINA6, DINA5, DINA4, DINA3, DINA2, DINA1, DINA0,
      DINB8, DINB7, DINB6, DINB5, DINB4, DINB3, DINB2, DINB1, DINB0,
      WIDTHA0, WIDTHA1,
      WIDTHB0, WIDTHB1,
      PIPEA, PIPEB,
      WMODEA, WMODEB,
      BLKA, BLKB,
      WENA, WENB,
      CLKA, CLKB,
      RESET : in std_logic := 'U';
  ----------------------------------------------------
      DOUTA8, DOUTA7, DOUTA6, DOUTA5, DOUTA4, DOUTA3, DOUTA2, DOUTA1, DOUTA0,
      DOUTB8, DOUTB7, DOUTB6, DOUTB5, DOUTB4, DOUTB3, DOUTB2, DOUTB1, DOUTB0 : out std_logic);  
  ----------------------------------------------------
  end component;

---------------------------------------------------------------------------------------------------
-- Instantiation of the component VCC

  component VCC
    port (Y : out std_logic);
  end component;

---------------------------------------------------------------------------------------------------
-- Instantiation of the component GND

  component GND
    port (Y : out std_logic);
  end component;

---------------------------------------------------------------------------------------------------

  signal POWER, GROUND : std_logic;

--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


  power_supply_signal : VCC port map(Y => POWER);
  ground_signal       : GND port map(Y => GROUND);

---------------------------------------------------------------------------------------------------
-- Instantiation of the component RAM4K9.
-- The following configuration has been applied:
--  o aspect ratio  : 9 x 512  (WIDTHA0, WIDTHA1, WIDTHB0, WIDTHB1                : VCC)
--  o word width    : 8 bits   (DINA8, DINB8: GND; DOUTA8, DOUTB8                 : open)
--  o memory depth  : 512 bytes(ADDRA11, ADDRA10, ADDRA9, ADDRB11, ADDRB10, ADDRB9: GND)
--  o BLKA, BLKB    : GND      (ports enabled)
--  o PIPEA, PIPEB  : GND      (not pipelined read)
--  o WMODEA, WMODEB: GND      (in write mode the output retains the data from the previous read)

  A9D8DualClkRAM_R0C0 : RAM4K9
  port map(
  -- INPUTS
    -- inputs concerning port A
    -- data in A (1 byte, (7 downto 0))
    DINA8   => GROUND,
    DINA7   => DINA(7),
    DINA6   => DINA(6),
    DINA5   => DINA(5),
    DINA4   => DINA(4),
    DINA3   => DINA(3),
    DINA2   => DINA(2),
    DINA1   => DINA(1),
    DINA0   => DINA(0),
    -- address A (512 bytes depth, (8 downto 0))
    ADDRA11 => GROUND,
    ADDRA10 => GROUND,
    ADDRA9  => GROUND,
    ADDRA8  => ADDRA(8),
    ADDRA7  => ADDRA(7),
    ADDRA6  => ADDRA(6),
    ADDRA5  => ADDRA(5),
    ADDRA4  => ADDRA(4),
    ADDRA3  => ADDRA(3),
    ADDRA2  => ADDRA(2),
    ADDRA1  => ADDRA(1),
    ADDRA0  => ADDRA(0),
    -- read/ write mode for A
    WENA    => RWA,
    -- clock for A
    CLKA    => CLKA,
    -- aspect ratio, block, pipeline, write mode configurations for port A
    WIDTHA0 => POWER,
    WIDTHA1 => POWER,
    BLKA    => GROUND,
    PIPEA   => GROUND,
    WMODEA  => GROUND,

    -- inputs concerning port B
    -- data in B (1 byte, (7 downto 0))
    DINB8   => GROUND,
    DINB7   => DINB(7),
    DINB6   => DINB(6),
    DINB5   => DINB(5),
    DINB4   => DINB(4),
    DINB3   => DINB(3),
    DINB2   => DINB(2),
    DINB1   => DINB(1),
    DINB0   => DINB(0),
    -- address B (512 bytes depth, (8 downto 0))
    ADDRB11 => GROUND,
    ADDRB10 => GROUND,
    ADDRB9  => GROUND,
    ADDRB8  => ADDRB(8),
    ADDRB7  => ADDRB(7),
    ADDRB6  => ADDRB(6),
    ADDRB5  => ADDRB(5),
    ADDRB4  => ADDRB(4),
    ADDRB3  => ADDRB(3),
    ADDRB2  => ADDRB(2),
    ADDRB1  => ADDRB(1),
    ADDRB0  => ADDRB(0),
    -- read/ write mode for B
    WENB    => RWB,
    -- clock for B
    CLKB    => CLKB,
    -- aspect ratio, block, pipeline, write mode configurations for port B
    WIDTHB0 => POWER,
    WIDTHB1 => POWER,
    BLKB    => GROUND,
    PIPEB   => GROUND,
    WMODEB  => GROUND,
     -- input reset
    RESET => RESETn,
   -------------------------------
  -- OUTPUTS
    -- output concerning port A
    -- data out A (1 byte)
    DOUTA8 => open,
    DOUTA7 => DOUTA(7),
    DOUTA6 => DOUTA(6),
    DOUTA5 => DOUTA(5),
    DOUTA4 => DOUTA(4),
    DOUTA3 => DOUTA(3),
    DOUTA2 => DOUTA(2),
    DOUTA1 => DOUTA(1),
    DOUTA0 => DOUTA(0),

    -- output concerning port B
    -- data out B (1 byte)
    DOUTB8 => open,
    DOUTB7 => DOUTB(7),
    DOUTB6 => DOUTB(6),
    DOUTB5 => DOUTB(5),
    DOUTB4 => DOUTB(4),
    DOUTB3 => DOUTB(3),
    DOUTB2 => DOUTB(2),
    DOUTB1 => DOUTB(1),
    DOUTB0 => DOUTB(0));
  -------------------------------

end RAM4K9;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------