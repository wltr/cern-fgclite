--_________________________________________________________________________________________________
--                                                                                                |
--                                         |The nanoFIP|                                          |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                        wf_incr_counter                                         |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         wf_incr_counter.vhd                                                               |
-- Description  Increasing counter with synchronous reinitialise and increase enable              |
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)                             |
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)                                 |
-- Date         01/2011                                                                           |
-- Version      v0.011                                                                            |
-- Depends on   -                                                                                 |
----------------                                                                                  |
-- Last changes                                                                                   |
--     10/2010  EG  v0.01   first version                                                         |
--     01/2011  EG  v0.011  counter_full became a constant                                        |
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
--                           Entity declaration for wf_incr_counter
--=================================================================================================

entity wf_incr_counter is
  generic(g_counter_lgth : natural := 4);                       -- default length
  port(
  -- INPUTS
   -- nanoFIP User Interface general signal
   uclk_i           : in std_logic;                             -- 40 MHz clock

   -- Signals from any unit
   counter_incr_i    : in std_logic;                             -- increment enable
   counter_reinit_i  : in std_logic;                             -- reinitializes counter to 0


  -- OUTPUT
    -- Signal to any unit
   counter_o         : out unsigned (g_counter_lgth-1 downto 0); -- counter
   counter_is_full_o : out std_logic);                           -- counter full indication
                                                                 -- (all bits to '1')
end entity wf_incr_counter;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of wf_incr_counter is

constant c_COUNTER_FULL : unsigned (g_counter_lgth-1 downto 0) := (others => '1');
signal   s_counter      : unsigned (g_counter_lgth-1 downto 0);


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
  -- Synchronous process Incr_Counter

  Incr_Counter: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if counter_reinit_i = '1' then
        s_counter   <= (others => '0');

      elsif counter_incr_i = '1' then
        s_counter   <= s_counter + 1;

      end if;
    end if;
  end process;

 --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --

  counter_o         <= s_counter;
  counter_is_full_o <= '1' when s_counter = c_COUNTER_FULL else '0';


end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------