--_________________________________________________________________________________________________
--                                                                                                |
--                                         |The nanoFIP|                                          |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                           wf_tx_osc                                            |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         wf_tx_osc.vhd                                                                     |
--                                                                                                |
-- Description  Generation of the clock signals needed for the FIELDRIVE transmission.            |
--                                                                                                |
--              The unit generates the nanoFIP FIELDRIVE output FD_TXCK (line driver half bit     |
--              clock) and the nanoFIP internal signal tx_sched_p_buff:                           |
--                                                                                                |
--              uclk              :  _|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-| |
--              FD_TXCK           :  _____|--------...--------|________...________|--------...--- |
--              tx_sched_p_buff(3):   0   0   0   1                           0   0   0   1       |
--              tx_sched_p_buff(2):   0   0   1   0                           0   0   1   0       |
--              tx_sched_p_buff(1):   0   1   0   0                           0   1   0   0       |
--              tx_sched_p_buff(0):   1   0   0   0                           1   0   0   0       |
--                                                                                                |
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)                             |
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)                                 |
-- Date         14/02/2011                                                                        |
-- Version      v0.04                                                                             |
-- Depends on   wf_reset_unit                                                                     |
----------------                                                                                  |
-- Last changes                                                                                   |
--     08/2009  v0.01  PS  Entity Ports added, start of architecture content                      |
--     07/2010  v0.02  EG  tx counter changed from 20 bits signed, to 11 bits unsigned;           |
--                         c_TX_SCHED_BUFF_LGTH got 1 bit more                                    |
--     12/2010  v0.03  EG  code cleaned-up                                                        |
--     01/2011  v0.04  EG  wf_tx_osc as different unit; use of wf_incr_counter;added tx_osc_rst_p_i
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
--                            Entity declaration for wf_tx_osc
--=================================================================================================

entity wf_tx_osc is
  port (
  -- INPUTS
    -- nanoFIP User Interface, General signals
    uclk_i            : in std_logic;                 -- 40 MHz clock
    rate_i            : in std_logic_vector (1 downto 0); -- WorldFIP bit rate

    -- Signal from the wf_reset_unit
    nfip_rst_i        : in std_logic;                 -- nanoFIP internal reset

    -- Signals from the wf_engine_control
    tx_osc_rst_p_i    : in std_logic;                 -- transmitter timeout


  -- OUTPUTS
    -- nanoFIP FIELDRIVE output
    tx_clk_o          : out std_logic;                -- line driver half bit clock

    -- Signal to the wf_tx_serializer unit
    tx_sched_p_buff_o : out std_logic_vector (c_TX_SCHED_BUFF_LGTH -1 downto 0));
                                                      -- buffer of pulses used for the scheduling
                                                      -- of the actions of the wf_tx_serializer
end entity wf_tx_osc;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of wf_tx_osc is

  -- transmission periods counter
  signal s_period_c, s_period                   : unsigned  (c_PERIODS_COUNTER_LGTH -1 downto 0);
  signal s_one_forth_period                     : unsigned  (c_PERIODS_COUNTER_LGTH -1 downto 0);
  signal s_period_c_is_full, s_period_c_reinit  : std_logic;
  -- clocks
  signal s_tx_clk_d1, s_tx_clk, s_tx_clk_p      : std_logic;
  signal s_tx_sched_p_buff                      : std_logic_vector (c_TX_SCHED_BUFF_LGTH-1 downto 0);


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--                                       Periods Counter                                         --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  s_period           <= c_BIT_RATE_UCLK_TICKS(to_integer(unsigned(rate_i)));-- # uclk ticks for a
                                                                            -- transmission period

  s_one_forth_period <= s_period srl 2;                                     -- 1/4 s_period
  s_period_c_is_full <= '1' when s_period_c = s_period -1 else '0';         -- counter full


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Instantiation of a wf_incr_counter counting transmission periods.

  tx_periods_count: wf_incr_counter
  generic map(g_counter_lgth => c_PERIODS_COUNTER_LGTH)
  port map(
    uclk_i            => uclk_i,
    counter_reinit_i  => s_period_c_reinit,
    counter_incr_i    => '1',
    counter_is_full_o => open,
    ------------------------------------------
    counter_o         => s_period_c);
    ------------------------------------------

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- counter reinitialized : if the nfip_rst_i is active or
  --                         if the tx_osc_rst_p_i is active or
  --                         if it fills up
  s_period_c_reinit <= nfip_rst_i or tx_osc_rst_p_i or s_period_c_is_full;



---------------------------------------------------------------------------------------------------
--                                     Clocks Construction                                       --
---------------------------------------------------------------------------------------------------

-- Concurrent signals assignments and a synchronous process that use
-- the s_period_c to construct the tx_clk_o clock and the buffer of pulses tx_sched_p_buff_o.

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- Creation of the clock for the transmitter with period: 1/2 transmission period
  s_tx_clk        <= '1' when ((s_period_c < s_one_forth_period) or
                                ((s_period_c > (2*s_one_forth_period)-1) and
                                 (s_period_c < 3*s_one_forth_period)))
                else '0';
                                            -- transm. period       : _|-----------|___________|--
                                            -- tx_counter           :  0    1/4   1/2    3/4   1
                                            -- s_tx_clk             : _|-----|_____|-----|_____|--


  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- Edge detector for s_tx_clk
  s_tx_clk_p      <= s_tx_clk and (not s_tx_clk_d1);
                                            -- s_tx_clk             : _|-----|_____|-----|_____
                                            -- tx_clk_o/ s_tx_clk_d1: ___|-----|_____|-----|___
                                            -- not s_tx_clk_d1      : ---|_____|-----|_____|---
                                            -- s_tx_clk_p           : _|-|___|-|___|-|___|-|___


  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  clk_Signals_Construction: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if (nfip_rst_i = '1') or (tx_osc_rst_p_i = '1') then
        s_tx_sched_p_buff <= (others => '0');
        s_tx_clk_d1       <= '0';
      else

        s_tx_clk_d1       <= s_tx_clk;
        s_tx_sched_p_buff <= s_tx_sched_p_buff (s_tx_sched_p_buff'left-1 downto 0) & s_tx_clk_p;
                                            -- buffering of the s_tx_clk_p pulses
      end if;
    end if;
  end process;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- Output signals

  tx_clk_o          <= s_tx_clk_d1;
  tx_sched_p_buff_o <= s_tx_sched_p_buff;



end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------