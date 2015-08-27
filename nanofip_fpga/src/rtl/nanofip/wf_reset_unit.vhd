--_________________________________________________________________________________________________
--                                                                                                |
--                                         |The nanoFIP|                                          |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                        wf_reset_unit                                           |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         wf_reset_unit.vhd                                                                 |
--                                                                                                |
-- Description  The unit is responsible for the generation of the:                                |
--                                                                                                |
--              o nanoFIP internal reset that resets all nanoFIP's logic, apart from WISHBONE.    |
--                It is asserted:                                                                 |
--                  - after the assertion of the "nanoFIP User Interface General signal" RSTIN;   |
--                    in this case it stays active for 4 uclk cycles                              |
--                  - after the reception of a var_rst with its 1st application-data byte         |
--                    containing the station's address; in this case as well it stays active for  |
--                    4 uclk cycles                                                               |
--                  - during the activation of the "nanoFIP User Interface General signal" RSTPON;|
--                    in this case it stays active for as long as the RSTPON is active.           |
--                                          __________                                            |
--                                  RSTIN  |          |       \ \                                 |
--                                 ________|   FSM    |_______ \ \                                |
--                                         |  RSTIN   |         \  \                              |
--                                         |__________|          \  \                             |
--                                          __________            |  \                            |
--                      rst_nFIP_and_FD_p  |          |           |   |      nFIP_rst             |
--                                 ________|   FSM    |________   |OR |  _______________          |
--                                         |  var_rst |           |   |                           |
--                                         |__________|           |  /                            |
--                                                               /  /                             |
--                                 RSTPON                       /  /                              |
--                                 __________________________  / /                                |
--                                                            / /                                 |
--                                                                                                |
--                                                                                                |
--              o FIELDRIVE reset: nanoFIP FIELDRIVE output FD_RSTN                               |
--                Same as the nanoFIP internal reset, it can be activated by the RSTIN,           |
--                the var_rst or the RSTPON.                                                      |
--                Regarding the activation time, for the first two cases (RSTIN, var_rst) it stays|
--                asserted for 4 FD_TXCK cycles whereas in the case of the RSTPON, it stays active|
--                for as long as the RSTPON is active.                                            |
--                                                                                                |
--                                          __________                                            |
--                                  RSTIN  |          |       \ \                                 |
--                                 ________|   FSM    |_______ \ \                                |
--                                         |  RSTIN   |         \  \                              |
--                                         |__________|          \  \                             |
--                                          __________            |  \                            |
--                      rst_nFIP_and_FD_p  |          |           |   |      FD_RSTN              |
--                                 ________|   FSM    |________   |OR |  _______________          |
--                                         |  var_rst |           |   |                           |
--                                         |__________|           |  /                            |
--                                                               /  /                             |
--                                 RSTPON                       /  /                              |
--                                 __________________________  / /                                |
--                                                            / /                                 |
--                                                                                                |
--              o reset to the external logic: "nanoFIP User Interface, General signal" RSTON     |
--                It is asserted after the reception of a var_rst with its 2nd data byte          |
--                containing the station's address.                                               |
--                It stays active for 8 uclk cycles.                                              |
--                                          _________                                             |
--                         assert_RSTON_p  |          |                       RSTON               |
--                                 ________|   FSM    |_________________________________          |
--                                         |  var_rst |                                           |
--                                         |__________|                                           |
--                                                                                                |
--              o nanoFIP internal reset for the WISHBONE logic:                                  |
--                It is asserted after the assertion of the "nanoFIP User Interface, WISHBONE     |
--                Slave" input RST_I or of the "nanoFIP User Interface General signal" RSTPON.    |
--                It stays asserted for as long as the RST_I or RSTPON stay asserted.             |
--                                                                                                |
--                                 RSTPON                                                         |
--                                 __________________________ \ \                                 |
--                                                             \  \           wb_rst              |
--                                 RST_I                        |OR|____________________          |
--                                 __________________________  /  /                               |
--                                                            / /                                 |
--                                                                                                |
--            Notes:                                                                              |
--            - The input signal RSTIN is considered only if it has been active for at least      |
--              4 uclk cycles; the functional specs define 8 uclks, but in reality we check for 4.|
--            - The pulses rst_nFIP_and_FD_p and assert_RSTON_p come from the wf_cons_outcome     |
--              unit only after the sucessful validation of the frame structure and of the        |
--              application-data bytes of the var_rst.                                            |
--            - The RSTPON (Power On Reset generated with an RC circuit) removal is synchronized  |
--              with both uclk and wb_clk.                                                        |
--                                                                                                |
--            The unit implements 2 state machines: one for resets coming from RSTIN              |
--                                                  and one for resets coming from a var_rst.     |
--                                                                                                |
--                                                                                                |
-- Authors      Erik van der Bij      (Erik.van.der.Bij@cern.ch)                                  |
--              Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)                             |
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)                                 |
-- Date         11/2011                                                                           |
-- Version      v0.03                                                                             |
-- Depends on   wf_consumption                                                                    |
----------------                                                                                  |
-- Last changes                                                                                   |
--     07/2009  v0.01  EB  First version                                                          |
--     08/2010  v0.02  EG  checking of bytes1 and 2 of reset var added                            |
--                         fd_rstn_o, nfip_rst_o enabled only if rstin has been active for>4 uclk |
--     01/2011  v0.03  EG  PoR added; signals assert_rston_p_i & rst_nfip_and_fd_p_i are inputs   |
--                         treated in the wf_cons_outcome; 2 state machines created; clean-up     |
--                         PoR also for internal WISHBONE resets                                  |
--     02/2011  v0.031  EG state nFIP_OFF_FD_OFF added                                            |
--     11/2011  v0.032  EG added s_rstin_c_is_full, s_var_rst_c_is_full signals that reset FSMs   |
--                         corrections on # cycles nFIP_rst is activated (was 6, now 4)           |
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
--                           Entity declaration for wf_reset_unit
--=================================================================================================
entity wf_reset_unit is port(
  -- INPUTS
    -- nanoFIP User Interface General signals
    uclk_i                                : in std_logic;    -- 40 MHz clock
    rstin_a_i           : in std_logic;     -- initialization control, active low
    rstpon_a_i          : in std_logic;     -- Power On Reset, active low
    rate_i              : in  std_logic_vector (1 downto 0); -- WorldFIP bit rate

    -- nanoFIP User Interface WISHBONE Slave
    rst_i               : in std_logic;     -- WISHBONE reset
    wb_clk_i            : in std_logic;     -- WISHBONE clock

    -- Signal from the wf_consumption unit
    rst_nfip_and_fd_p_i : in std_logic;     -- indicates that a var_rst with its 1st byte
                                            -- containing the station's address has been
                                            -- correctly received

    assert_rston_p_i    : in std_logic;     -- indicates that a var_rst with its 2nd byte
                                            -- containing the station's address has been
                                            -- correctly received


  -- OUTPUTS
    -- nanoFIP internal reset, to all the units
    nfip_rst_o          : out std_logic;    -- nanoFIP internal reset, active high
                                            -- resets all nanoFIP logic, apart from the WISHBONE

    -- Signal to the wf_wb_controller
    wb_rst_o            : out std_logic;    -- reset of the WISHBONE logic

    -- nanoFIP User Interface General signal output
    rston_o             : out std_logic;    -- reset output, active low

    -- nanoFIP FIELDRIVE output
    fd_rstn_o           : out std_logic);   -- FIELDRIVE reset, active low

end entity wf_reset_unit;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of wf_reset_unit is

  -- RSTIN and RSTPON synchronizers
  signal s_rsti_synch                                 : std_logic_vector (2 downto 0);
  signal s_wb_por_synch, s_u_por_synch                : std_logic_vector (1 downto 0);
  -- FSM for RSTIN
  type rstin_st_t is (IDLE, RSTIN_EVAL, nFIP_ON_FD_ON, nFIP_OFF_FD_ON, nFIP_OFF_FD_OFF);
  signal rstin_st, nx_rstin_st                        : rstin_st_t;
  -- RSTIN counter
  signal s_rstin_c, s_var_rst_c                       : unsigned (c_2_PERIODS_COUNTER_LGTH-1 downto 0);
  signal s_rstin_c_reinit, s_rstin_c_is_three         : std_logic; 
  signal s_rstin_c_is_seven, s_rstin_c_is_4txck       : std_logic;
  signal s_rstin_c_is_full                            : std_logic;
  -- resets generated after a RSTIN
  signal s_rstin_nfip, s_rstin_fd                     : std_logic;
  -- FSM for var_rst
  type var_rst_st_t is (VAR_RST_IDLE, VAR_RST_RSTON_ON, VAR_RST_nFIP_ON_FD_ON_RSTON_ON,
                        VAR_RST_nFIP_OFF_FD_ON_RSTON_ON, VAR_RST_nFIP_ON_FD_ON,
                        VAR_RST_nFIP_OFF_FD_ON_RSTON_OFF);
  signal var_rst_st, nx_var_rst_st                    : var_rst_st_t;
  -- var_rst counter 
  signal s_var_rst_c_reinit, s_var_rst_c_is_three     : std_logic;
  signal s_var_rst_c_is_seven, s_var_rst_c_is_4txck   : std_logic;
  signal s_var_rst_c_is_full                          : std_logic;
  -- resets generated after a var_rst
  signal s_var_rst_fd, s_var_rst_nfip, s_rston        : std_logic;
  -- info needed to define the length of the FD_RSTN
  signal s_transm_period                              : unsigned (c_PERIODS_COUNTER_LGTH - 1 downto 0);
  signal s_txck_four_periods                          : unsigned (c_2_PERIODS_COUNTER_LGTH-1 downto 0);


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


  s_transm_period     <= c_BIT_RATE_UCLK_TICKS(to_integer(unsigned(rate_i)));-- # uclk ticks of a
                                                                             -- transmission period

  s_txck_four_periods <= resize(s_transm_period, s_txck_four_periods'length) sll 1;-- # uclk ticks
                                                                                   -- of 2 transm.
                                                                                   -- periods = 4
                                                                                   -- FD_TXCK periods


---------------------------------------------------------------------------------------------------
--                                        Input Synchronizers                                    --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- RSTIN synchronization with the uclk, using a set of 3 registers.

  RSTIN_uclk_Synchronizer: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      s_rsti_synch <= s_rsti_synch (1 downto 0) &  not rstin_a_i;
    end if;
  end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- RSTPON synchronization, with the wb_clk.
-- The second flip-flop is used to remove metastabilities.

  PoR_wb_clk_Synchronizer: process (wb_clk_i, rstpon_a_i)
    begin
      if rstpon_a_i = '0' then
        s_wb_por_synch <= (others => '1');
      elsif rising_edge (wb_clk_i) then
        s_wb_por_synch <= s_wb_por_synch(0) & '0';
      end if;
    end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- RSTPON synchronization, with the uclk.
-- The second flip-flop is used to remove metastabilities.

  PoR_uclk_Synchronizer: process (uclk_i, rstpon_a_i)
    begin
      if rstpon_a_i = '0' then
        s_u_por_synch <= (others => '1');
      elsif rising_edge (uclk_i) then
        s_u_por_synch <= s_u_por_synch(0) & '0';
      end if;
    end process;



---------------------------------------------------------------------------------------------------
--                                             RSTIN                                             --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- RSTIN FSM: the state machine is divided in three parts (a clocked process
-- to store the current state, a combinatorial process to manage state transitions and finally a
-- combinatorial process to manage the output signals), which are the three processes that follow.

-- The FSM is following the "User Interface, General signal" RSTIN and checks whether it stays
-- active for at least 4 uclk cycles; if so, it enables the nanoFIP internal reset (s_rstin_nfip)
-- and the FIELDRIVE reset (s_rstin_fd). The nanoFIP internal reset stays active for 4 uclk cycles
-- and the  FIELDRIVE for 4 FD_TXCK cycles.
-- The state machine can be reset by the Power On Reset and the variable reset.
-- Note: The same counter is used for the evaluation of the RSTIN (if it is >= 4 uclk) and for the
-- generation of the two reset signals.

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Synchronous process RSTIN_FSM_Sync: Storage of the current state of the FSM.

  RSTIN_FSM_Sync: process (uclk_i)
    begin
      if rising_edge (uclk_i) then
        if s_u_por_synch(1) = '1' or rst_nfip_and_fd_p_i = '1' or s_rstin_c_is_full = '1' then
          rstin_st <= IDLE;
        else
          rstin_st <= nx_rstin_st;
        end if;
      end if;
    end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process RSTIN_FSM_Comb_State_Transitions: definition of the state
-- transitions of the FSM.

  RSTIN_FSM_Comb_State_Transitions: process (rstin_st, s_rsti_synch(2), s_rstin_c_is_three,
                                             s_rstin_c_is_seven, s_rstin_c_is_4txck)

  begin

  case rstin_st is

    when IDLE =>
                        if s_rsti_synch(2) = '1' then      -- RSTIN active
                          nx_rstin_st   <= RSTIN_EVAL;

                        else
                          nx_rstin_st   <= IDLE;
                        end if;


    when RSTIN_EVAL =>
                        if s_rsti_synch(2) = '0' then      -- RSTIN deactivated
                          nx_rstin_st   <= IDLE;

                        else
                          if s_rstin_c_is_three = '1' then -- counting the uclk cycles that
                            nx_rstin_st <= nFIP_ON_FD_ON;  -- RSTIN is active

                          else
                            nx_rstin_st <= RSTIN_EVAL;
                          end if;
                        end if;


    when nFIP_ON_FD_ON =>

                        if s_rstin_c_is_seven = '1' then   -- nanoFIP internal reset and
                          nx_rstin_st   <= nFIP_OFF_FD_ON; -- FIELDRIVE reset active for
                                                           -- 4 uclk cycles

                        else
                          nx_rstin_st   <= nFIP_ON_FD_ON;
                        end if;


    when nFIP_OFF_FD_ON =>
                                                           -- nanoFIP internal reset deactivated
                        if s_rstin_c_is_4txck = '1' then   -- FIELDRIVE reset continues being active
                          nx_rstin_st   <= nFIP_OFF_FD_OFF;-- until 4 FD_TXCK cycles have passed

                        else
                          nx_rstin_st   <= nFIP_OFF_FD_ON;
                        end if;


    when nFIP_OFF_FD_OFF =>

                        if s_rsti_synch(2) = '1' then      -- RSTIN still active
                          nx_rstin_st   <= nFIP_OFF_FD_OFF;
                        else
                          nx_rstin_st   <= IDLE;
                        end if;


    when OTHERS =>
                        nx_rstin_st   <= IDLE;
  end case;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process RSTIN_FSM_Comb_Output_Signals: definition of the output signals of
-- the FSM. The process is handling the signals for the nanoFIP internal reset (s_rstin_nfip)
-- and the FIELDRIVE reset (s_rstin_fd), as well as the inputs of the RSTIN_free_counter.

  RSTIN_FSM_Comb_Output_Signals: process (rstin_st)

  begin

    case rstin_st is

    when IDLE =>
                  s_rstin_c_reinit <= '1';    -- counter initialized

                  s_rstin_nfip     <= '0';
                  s_rstin_fd       <= '0';


    when RSTIN_EVAL =>
                  s_rstin_c_reinit <= '0';    -- counting until 4
                                              -- if RSTIN is active
                  s_rstin_nfip     <= '0';
                  s_rstin_fd       <= '0';


    when nFIP_ON_FD_ON =>
                  s_rstin_c_reinit <= '0';    -- free counter counting 4 uclk cycles

                 -------------------------------------
                  s_rstin_fd       <= '1';    -- FIELDRIVE     active
                  s_rstin_nfip     <= '1';    -- nFIP internal active
                 -------------------------------------


    when nFIP_OFF_FD_ON =>
                  s_rstin_c_reinit <= '0';    -- free counter counting until 4 FD_TXCK

                  s_rstin_nfip     <= '0';
                 -------------------------------------
                  s_rstin_fd       <= '1';    -- FIELDRIVE     active
                 -------------------------------------


    when nFIP_OFF_FD_OFF =>
                  s_rstin_c_reinit <= '1';    -- no counting

                  s_rstin_nfip     <= '0';
                  s_rstin_fd       <= '0';


    when OTHERS =>
                  s_rstin_c_reinit <= '1';    -- no counting

                  s_rstin_fd       <= '0';
                  s_rstin_nfip     <= '0';


    end case;
  end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Instantiation of a wf_incr_counter: the counter counts from 0 to 4 FD_TXCK.
-- In case something goes wrong and the counter continues conting after the 4 FD_TXCK, the
-- s_rstin_c_is_full will be activated and the FSM will be reset.

RSTIN_free_counter: wf_incr_counter
  generic map(g_counter_lgth => c_2_PERIODS_COUNTER_LGTH)
  port map(
    uclk_i            => uclk_i,
    counter_reinit_i  => s_rstin_c_reinit,
    counter_incr_i    => '1',
   ----------------------------------------
    counter_is_full_o => s_rstin_c_is_full,
    counter_o         => s_rstin_c);
   ----------------------------------------

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  s_rstin_c_is_three <= '1' when s_rstin_c = to_unsigned(3, s_rstin_c'length) else '0';
  s_rstin_c_is_seven <= '1' when s_rstin_c = to_unsigned(7, s_rstin_c'length) else '0';
  s_rstin_c_is_4txck <= '1' when s_rstin_c = s_txck_four_periods + 3          else '0';
                                          -- +3 bc of the first 4 RSTIN evaluation cycles



---------------------------------------------------------------------------------------------------
--                                            var_rst                                            --
---------------------------------------------------------------------------------------------------
-- Resets_after_a_var_rst FSM: the state machine is divided in three parts (a clocked process
-- to store the current state, a combinatorial process to manage state transitions and finally a
-- combinatorial process to manage the output signals), which are the three processes that follow.
-- If after the reception of a var_rst the signal assert_rston_p_i is asserted, the FSM
-- asserts the "nanoFIP user Interface General signal" RSTON for 8 uclk cycles.
-- If after the reception of a var_rst the signal rst_nfip_and_fd_p_i is asserted, the FSM
-- asserts the nanoFIP internal reset (s_var_rst_nfip) for 4 uclk cycles and the
-- "nanoFIP FIELDRIVE" output (s_var_rst_fd) for 4 FD_TXCK cycles.
-- If after the reception of a var_rst both assert_rston_p_i and rst_nfip_and_fd_p_i
-- are asserted, the FSM asserts the s_var_rst_nfip for 2 uclk cycles, the RSTON for 8
-- uclk cycles and the s_var_rst_fd for 4 FD_TXCK cycles.
-- The same counter is used for all the countings!

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Synchronous process Resets_after_a_var_rst_synch: Storage of the current state of the FSM
-- The state machine can be reset by the Power On Reset and the nanoFIP internal reset from RSTIN.
   Resets_after_a_var_rst_synch: process (uclk_i)
    begin
      if rising_edge (uclk_i) then
        if s_u_por_synch(1) = '1' or s_rstin_nfip = '1' or s_var_rst_c_is_full = '1' then
          var_rst_st <= VAR_RST_IDLE;
        else
          var_rst_st <= nx_var_rst_st;
        end if;
      end if;
  end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process Resets_after_a_var_rst_Comb_State_Transitions: definition of the
-- state transitions of the FSM.

  Resets_after_a_var_rst_Comb_State_Transitions: process (var_rst_st, rst_nfip_and_fd_p_i,
                                                          assert_rston_p_i, s_var_rst_c_is_three,
                                                          s_var_rst_c_is_seven,
                                                          s_var_rst_c_is_4txck)

  begin

  case var_rst_st is

    when VAR_RST_IDLE =>

                        if assert_rston_p_i = '1' and rst_nfip_and_fd_p_i = '1' then
                          nx_var_rst_st   <= VAR_RST_nFIP_ON_FD_ON_RSTON_ON;

                        elsif assert_rston_p_i = '1' then
                          nx_var_rst_st   <= VAR_RST_RSTON_ON;

                        elsif rst_nfip_and_fd_p_i = '1' then
                          nx_var_rst_st   <= VAR_RST_nFIP_ON_FD_ON;

                        else
                          nx_var_rst_st   <= VAR_RST_IDLE;
                        end if;


    when VAR_RST_RSTON_ON =>                              -- for 8 uclk cycles

                        if s_var_rst_c_is_seven = '1' then
                          nx_var_rst_st   <= VAR_RST_IDLE;

                        else
                          nx_var_rst_st <= VAR_RST_RSTON_ON;
                        end if;


    when VAR_RST_nFIP_ON_FD_ON_RSTON_ON =>                -- for 4 uclk cycles

                        if s_var_rst_c_is_three = '1' then
                          nx_var_rst_st <= VAR_RST_nFIP_OFF_FD_ON_RSTON_ON;

                        else
                          nx_var_rst_st <= VAR_RST_nFIP_ON_FD_ON_RSTON_ON;
                        end if;


    when VAR_RST_nFIP_OFF_FD_ON_RSTON_ON =>              -- for 4 more uclk cycles

                        if s_var_rst_c_is_seven = '1' then
                          nx_var_rst_st <= VAR_RST_nFIP_OFF_FD_ON_RSTON_OFF;

                        else
                          nx_var_rst_st <= VAR_RST_nFIP_OFF_FD_ON_RSTON_ON;
                        end if;


    when VAR_RST_nFIP_ON_FD_ON =>                        -- for 4 uclk cycles

                        if s_var_rst_c_is_three = '1' then
                          nx_var_rst_st <= VAR_RST_nFIP_OFF_FD_ON_RSTON_OFF;

                        else
                          nx_var_rst_st <= VAR_RST_nFIP_ON_FD_ON;
                        end if;


    when VAR_RST_nFIP_OFF_FD_ON_RSTON_OFF =>             -- until 4 TXCK

                        if s_var_rst_c_is_4txck = '1' then
                           nx_var_rst_st <= VAR_RST_IDLE;

                        else
                           nx_var_rst_st <= VAR_RST_nFIP_OFF_FD_ON_RSTON_OFF;
                        end if;


    when OTHERS =>
                        nx_var_rst_st <= VAR_RST_IDLE;
  end case;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process RSTIN_FSM_Comb_Output_Signals: definition of the output signals of
-- the FSM. The process is managing the signals for the nanoFIP internal reset and the FIELDRIVE
-- reset, as well as the arguments of the counter.

  rst_var_FSM_Comb_Output_Signals: process (var_rst_st)

  begin

    case var_rst_st is

    when VAR_RST_IDLE =>
                                     s_var_rst_c_reinit <= '1';    -- counter initialized

                                     s_rston            <= '1';
                                     s_var_rst_nfip     <= '0';
                                     s_var_rst_fd       <= '0';


    when VAR_RST_RSTON_ON =>
                                     s_var_rst_c_reinit <= '0';    -- counting 8 uclk cycles

                                    -------------------------------------
                                     s_rston            <= '0';    -- RSTON         active
                                    -------------------------------------
                                     s_var_rst_nfip     <= '0';
                                     s_var_rst_fd       <= '0';


    when VAR_RST_nFIP_ON_FD_ON_RSTON_ON =>
                                     s_var_rst_c_reinit <= '0';    -- counting 4 uclk cycles

                                    -------------------------------------
                                     s_rston            <= '0';    -- RSTON         active
                                     s_var_rst_nfip     <= '1';    -- nFIP internal active
                                     s_var_rst_fd       <= '1';    -- FIELDRIVE     active
                                    -------------------------------------


    when VAR_RST_nFIP_OFF_FD_ON_RSTON_ON =>
                                     s_var_rst_c_reinit <= '0';    -- counting 4 uclk cycles

                                     s_var_rst_nfip     <= '0';
                                    -------------------------------------
                                     s_rston            <= '0';    -- RSTON         active
                                     s_var_rst_fd       <= '1';    -- FIELDRIVE     active
                                    -------------------------------------


    when VAR_RST_nFIP_ON_FD_ON =>
                                     s_var_rst_c_reinit <= '0';    -- counting 4 uclk cycles

                                     s_rston            <= '1';
                                    -------------------------------------
                                     s_var_rst_nfip     <= '1';    -- nFIP internal active
                                     s_var_rst_fd       <= '1';    -- FIELDRIVE     active
                                    -------------------------------------


    when VAR_RST_nFIP_OFF_FD_ON_RSTON_OFF =>
                                     s_var_rst_c_reinit <= '0';    -- counting until 4 FD_TXCK cycles

                                     s_rston            <= '1';
                                     s_var_rst_nfip     <= '0';
                                    -------------------------------------
                                    s_var_rst_fd        <= '1';    -- FIELDRIVE     active
                                    -------------------------------------


    when OTHERS =>
                                     s_var_rst_c_reinit <= '1';    -- no counting

                                     s_rston            <= '1';
                                     s_var_rst_nfip     <= '0';
                                     s_var_rst_fd       <= '0';


    end case;
  end process;



--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Instantiation of a wf_incr_counter:
-- the counter counts from 0 to 8, if only assert_RSTON_p has been activated, or
--                    from 0 to 4 * FD_TXCK, if rst_nfip_and_fd_p_i has been activated.
-- In case something goes wrong and the counter continues conting after the 4 FD_TXCK, the
-- s_var_rst_c_is_full will be activated and the FSM will be reset.

free_counter: wf_incr_counter
  generic map(g_counter_lgth => c_2_PERIODS_COUNTER_LGTH)
  port map(
    uclk_i            => uclk_i,
    counter_reinit_i  => s_var_rst_c_reinit,
    counter_incr_i    => '1',
   ----------------------------------------
    counter_is_full_o => s_var_rst_c_is_full,
    counter_o         => s_var_rst_c);
   ----------------------------------------

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  s_var_rst_c_is_seven <= '1' when s_var_rst_c = to_unsigned(7, s_var_rst_c'length) else '0';
  s_var_rst_c_is_three <= '1' when s_var_rst_c = to_unsigned(3, s_var_rst_c'length) else '0';
  s_var_rst_c_is_4txck <= '1' when s_var_rst_c = s_txck_four_periods -1             else '0';



---------------------------------------------------------------------------------------------------
--                                         Output Signals                                        --
---------------------------------------------------------------------------------------------------

  wb_rst_o      <= rst_i or s_wb_por_synch(1);


  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  nfip_rst_o    <= s_rstin_nfip or s_var_rst_nfip or s_u_por_synch(1);


  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- Flip-flop with asynchronous reset to be sure that whenever nanoFIP is reset the user is not
  RSTON_Buffering: process (uclk_i, s_u_por_synch(1), s_rstin_nfip, s_var_rst_nfip)
  begin
    if s_rstin_nfip = '1' or s_var_rst_nfip = '1' or s_u_por_synch(1) = '1' then
      rston_o   <=  '1';
    elsif rising_edge (uclk_i) then
      rston_o   <= s_rston;
    end if;
  end process;


  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- FIELDRIVE reset
  FD_RST_Buffering: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      fd_rstn_o <= not (s_rstin_fd or s_var_rst_fd or s_u_por_synch(1));
    end if;
  end process;


end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------