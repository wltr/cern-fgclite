--_________________________________________________________________________________________________
--                                                                                                |
--                                         |The nanoFIP|                                          |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                        wf_engine_control                                       |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         wf_engine_control.vhd                                                             |
--                                                                                                |
-- Description  The wf_engine_control is following the reception of an incoming ID_DAT frame and  |
--                o identifies the variable to be treated                                         |
--                o signals accordingly the wf_production or wf_consumption units.                |
--                                                                                                |
--              Reminder:                                                                         |
--                                                                                                |
--              ID_DAT frame structure:                                                           |
--               ___________ ______  _______ ______  ___________ _______                          |
--              |____FSS____|_CTRL_||__Var__|_SUBS_||____FCS____|__FES__|                         |
--                                                                                                |
--                                                                                                |
--              Produced RP_DAT frame structure:                                                  |
--     ___________ ______  _______ ______ _________________ _______ _______  ___________ _______  |
--    |____FSS____|_CTRL_||__PDU__|_LGTH_|__..User-Data..__|_nstat_|__MPS__||____FCS____|__FES__| |
--                                                                                                |
--                                                                                                |
--              Consumed RP_DAT frame structure:                                                  |
--     ___________ ______  _______ ______ _________________________ _______  ___________ _______  |
--    |____FSS____|_CTRL_||__PDU__|_LGTH_|_____..Applic-Data.._____|__MPS__||____FCS____|__FES__| |
--                                                                                                |
--                                                                                                |
--              Turnaround time: Time between the end of the reception of an ID_DAT frame         |
--              requesting for a variable to be produced and the starting of the delivery of a    |
--              produced RP_DAT frame.                                                            |
--                                                                                                |
--              Silence time   : Maximum time that nanoFIP waits for a consumed RP_DAT frame      |
--              after the reception of an ID_DAT frame that indicates a variable to be consumed.  |
--                                                                                                |
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)                             |
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)                                 |
-- Date         15/01/2011                                                                        |
-- Version      v0.06                                                                             |
-- Depends on   wf_reset_unit                                                                     |
--              wf_fd_transmitter                                                                 |
--              wf_fd_receiver                                                                    |
----------------                                                                                  |
-- Last changes                                                                                   |
--     07/2009  v0.01  EB  First version                                                          |
--     08/2010  v0.02  EG  E0 added as broadcast                                                  |
--                         PDU,LGTH,CTRL bytes of RP_DAT checked bf VAR1_RDY/var_2_rdy assertion; |
--                         if ID_DAT>8 bytes or RP_DAT>133 (bf reception of a FES) go to IDLE;    |
--                         state CONSUME_WAIT_FSS, for the correct use of the silence time(time   |
--                         stops counting when an RP_DAT frame has started)                       |
--     12/2010  v0.03  EG  state machine rewritten moore style; removed check on slone mode       |
--                         for #bytes>4; in slone no broadcast                                    |
--     01/2011  v0.04  EG  signals named according to their origin; signals var_rdy (1,2,3),      |
--                         assert_rston_p_o,rst_nfip_and_fd_p_o, nFIP status bits and             |
--                         rx_byte_ready_p_o removed cleaning-up+commenting                       |
--     02/2011  v0.05  EG  Independent timeout counter added; time counter 18 digits instead of 15|
--                         ID_DAT_FRAME_OK: corrected mistake if rx_fss_crc_fes_ok_p not          |
--                         activated; rx reset during production (rx_rst_o);                      |
--                         cons_bytes_excess_o added                                              |
--                         tx_completed_p_i added (bf for the engine ctrl production was finished |
--                         after the delivery of the last data byte (MPS))                        |
--     07/2011  v0.06  EG  RST_RX state added                                                     |
--     10/2011  v0.06b  EG  moved session_timedout in the synchronous FSM process                 |
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
--                          Entity declaration for wf_engine_control
--=================================================================================================
entity wf_engine_control is port(
  -- INPUTS
    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
    -- nanoFIP User Interface, General signals
    uclk_i                     : in std_logic;                     -- 40 MHz clock
    nostat_i                   : in std_logic;                     -- if negated, nFIP status is sent
    slone_i                    : in std_logic;                     -- stand-alone mode

    -- nanoFIP WorldFIP Settings
    p3_lgth_i                  : in std_logic_vector (2 downto 0); -- produced var user-data length
    rate_i                     : in std_logic_vector (1 downto 0); -- WorldFIP bit rate
    subs_i                     : in std_logic_vector (7 downto 0); -- subscriber number coding

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
    -- Signal from the wf_reset_unit
    nfip_rst_i                 : in std_logic;                     -- nanoFIP internal reset


    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
    -- Signal from the wf_fd_transmitter unit

    tx_completed_p_i           : in std_logic;                     -- pulse upon termination of a
                                                                   -- produced RP_DAT transmission

    tx_byte_request_p_i        : in std_logic;                     -- used for the counting of the
                                                                   -- # produced bytes

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
    -- Signals from the wf_fd_receiver unit

    rx_byte_i                  : in std_logic_vector (7 downto 0); -- deserialized ID_DAT/ RP_DAT byte
    rx_byte_ready_p_i          : in std_logic; -- indication of a new byte on rx_byte_i

    rx_fss_crc_fes_ok_p_i      : in std_logic; -- indication of a frame (ID_DAT or RP_DAT) with
                                               -- correct FSS, FES and CRC

    rx_crc_wrong_p_i           : in std_logic; -- indication of a frame with a wrong CRC
                                               -- pulse upon FES detection

    rx_fss_received_p_i        : in std_logic; -- pulse upon FSS detection (ID/ RP_DAT)



  -------------------------------------------------------------------------------------------------
  -- OUTPUTS

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
    -- Signal to the wf_fd_transmitter unit
    tx_start_p_o               : out std_logic; -- launches the transmitter
    tx_byte_request_accept_p_o : out std_logic; -- answer to tx_byte_request_p_i
    tx_last_data_byte_p_o      : out std_logic; -- indication of the last data-byte
                                                -- (CRC & FES not included)

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
    -- Signal to the wf_production unit
    prod_data_lgth_o           : out std_logic_vector (7 downto 0); -- # bytes of the Conrol & Data
                                                                    -- fields of a prod RP_DAT frame

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
    -- Signal to the wf_fd_receiver
    rx_rst_o                   : out std_logic; -- reset during production or
                                                -- reset pulse when during reception a frame is rejected
                                                -- (example: ID_DAT > 8 bytes, RP_DAT > 133 bytes, 
                                                --  wrong ID_DAT CTRL, variable, subs bytes)

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
    -- Signal to the wf_consumption unit
    cons_bytes_excess_o        : out std_logic; -- indication of a consumed RP_DAT frame with more
                                                -- than 133 bytes

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
    -- Signals to the wf_production & wf_consumption
    prod_byte_index_o          : out std_logic_vector (7 downto 0); -- index of the byte being
                                                                    -- produced
    cons_byte_index_o          : out std_logic_vector (7 downto 0); -- index of the byte being
                                                                    -- consumed

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
    -- Signals to the wf_production, wf_consumption, wf_reset_unit
    var_o                      : out t_var);   -- received variable; takes a value only after a
                                               -- valid ID_DAT frame with SUBS the station's address
end entity wf_engine_control;



--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of wf_engine_control is

  -- FSM
  type control_st_t  is (IDLE,
                         ID_DAT_CTRL_BYTE, ID_DAT_VAR_BYTE, ID_DAT_SUBS_BYTE, ID_DAT_FRAME_OK,
                         CONSUME_WAIT_FSS, CONSUME, RST_RX,
                         PRODUCE_WAIT_TURNAR_TIME, PRODUCE);
  signal control_st, nx_control_st                                                     : control_st_t;
  signal s_idle_state, s_id_dat_ctrl_byte, s_id_dat_var_byte, s_id_dat_frame_ok        : std_logic;
  signal s_cons_wait_FSS, s_consuming, s_rst_rx_p                                      : std_logic;
  signal s_prod_wait_turnar_time, s_producing                                          : std_logic;
  -- variable identification
  signal s_var_aux, s_var                                                              : t_var;
  signal s_var_identified, s_broadcast_var                                             : std_logic;
  signal s_prod_or_cons                                            : std_logic_vector (1 downto 0);
  -- time counters (turnaround, silence, timeout)
  signal s_time_c_top, s_turnaround_time, s_silence_time                  : unsigned (17 downto 0);
  signal s_time_c_load, s_time_c_is_zero                                               : std_logic;
  signal s_session_timedout                                                            : std_logic;
  -- received & produced byte counters
  signal s_rx_bytes_c, s_prod_bytes_c                                      : unsigned (7 downto 0);
  signal s_prod_bytes_c_rst, s_prod_bytes_c_inc                                        : std_logic;
  signal s_rx_bytes_c_rst, s_rx_bytes_c_inc                                            : std_logic;
  -- transmitter controls
  signal s_tx_start_prod_p, s_tx_byte_request_accept_p, s_tx_byte_request_accept_p_d1  : std_logic;
  signal s_tx_byte_request_accept_p_d2, s_tx_last_data_byte_p, s_tx_last_data_byte_p_d : std_logic;
  -- length of produced data
  signal s_prod_data_lgth                                          : std_logic_vector (7 downto 0);
  signal s_prod_data_lgth_match                                                        : std_logic;


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--                                       engine_control FSM                                      --
---------------------------------------------------------------------------------------------------

-- Central control FSM: the state machine is divided in three parts (a clocked process
-- to store the current state, a combinatorial process to manage state transitions and finally a
-- combinatorial process to manage the output signals), which are the three processes that follow.

-- The FSM stays in IDLE until the reception of a FSS from the wf_fd_receiver.
-- It continues by checking one by one the bytes of the frame as they arrive:
--   o if the CTRL byte corresponds to an ID_DAT,
--   o if the variable byte corresponds to a defined variable,
--   o if the subscriber byte matches the station's address, or if the variable is a broadcast
--   o and if the frame finishes with a correct CRC and FES.
-- If any of the bytes above has been different than the expected, the FSM resets the wf_fd_receiver
-- and goes back to IDLE.
--   o if the ID_DAT frame has been correct and the received variable is a produced (var_presence,
--     var_identif, var_3, var_5) the FSM stays in the "PRODUCE_WAIT_TURNAR_TIME" state until the
--     expiration of the turnaround time and then jumps to the "PRODUCE" state, waiting for the
--     wf_fd_serializer to finish the transmission; then it goes back to IDLE.
--   o if the received variable is a consumed (var_1, var_2, var_rst, var_4) the FSM stays in the
--     "CONSUME_WAIT_FSS" state until the arrival of a FSS or the expiration of the silence time.
--     After the arrival of the FSS the FSM jumps to the "CONSUME" state, where it stays until the
--     end of the reception of the consumed frame (marked by a FES).
--     Note: In the case of a var_5, it is the wf_consumption unit that signals the start-up of
--           the wf_jtag_controller which will work in parallel and independently from the
--           wf_engine_control; i.e. new frames reception can take place while the
--           wf_jtag_controller is working.
-- To add a robust layer of protection to the FSM, a counter dependent only on the system clock
-- has been implemented, that from any state can bring the FSM back to IDLE. At any bit rate the
-- reception of an ID_DAT frame followed by the reception/ transmission of an RP_DAT should not
-- last more than 41ms. Hence, we have generated a 21 bits (c_SESSION_TIMEOUT_C_LGTH)counter that
-- will reset the machine if more than 52ms (complete 21 bit counter) have passed since it has
-- left this IDLE state.

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Synchronous process Engine_Control_FSM_Sync: storage of the current state of the FSM

  Engine_Control_FSM_Sync: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' or s_session_timedout = '1' then
        control_st <= IDLE;
      else
        control_st <= nx_control_st;
      end if;
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process Engine_Control_FSM_Comb_State_Transitions: definition of the state
-- transitions of the FSM.

  Engine_Control_FSM_Comb_State_Transitions: process (s_time_c_is_zero, s_prod_or_cons,subs_i,
                                                      rx_crc_wrong_p_i, rx_fss_crc_fes_ok_p_i,
                                                      s_broadcast_var, s_var_identified, rx_byte_i,
                                                      rx_byte_ready_p_i, control_st, s_rx_bytes_c,
                                                      rx_fss_received_p_i,tx_completed_p_i)

  begin


    case control_st is

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when IDLE =>

        if rx_fss_received_p_i = '1' then      -- new frame FSS detected
          nx_control_st <= ID_DAT_CTRL_BYTE;

        else
          nx_control_st <= IDLE;
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when ID_DAT_CTRL_BYTE =>

        if (rx_byte_ready_p_i = '1') and (rx_byte_i(5 downto 0) = c_ID_DAT_CTRL_BYTE) then
          nx_control_st <= ID_DAT_VAR_BYTE;    -- check of ID_DAT CTRL byte

        elsif rx_byte_ready_p_i = '1' then
          nx_control_st <= RST_RX;             -- byte different than the expected ID_DAT CTRL

        else
          nx_control_st <= ID_DAT_CTRL_BYTE;   -- ID_DAT CTRL byte being arriving
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when ID_DAT_VAR_BYTE =>

        if (rx_byte_ready_p_i = '1') and (s_var_identified = '1') then
          nx_control_st <= ID_DAT_SUBS_BYTE;   -- check of the ID_DAT variable

        elsif rx_byte_ready_p_i = '1' then
          nx_control_st <= RST_RX;             -- byte not corresponding to an expected variable

        else
          nx_control_st <= ID_DAT_VAR_BYTE;    -- ID_DAT variable byte being arriving
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when ID_DAT_SUBS_BYTE =>

        if (rx_byte_ready_p_i = '1') and ((rx_byte_i = subs_i) or (s_broadcast_var = '1')) then
          nx_control_st <= ID_DAT_FRAME_OK;  -- checking of the ID_DAT subscriber
                                             -- or if it is a broadcast variable
                                             -- note: broadcast consumed vars are only treated in
                                             -- memory mode, but at this moment we do not do this
                                             -- check as the var_rst which is broadcast is treated
                                             -- also in stand-alone mode.

        elsif rx_byte_ready_p_i = '1' then   -- not the station's address, neither a broadcast var
          nx_control_st <= RST_RX;

        else
          nx_control_st <= ID_DAT_SUBS_BYTE; -- ID_DAT subscriber byte being arriving
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when ID_DAT_FRAME_OK =>

        if (rx_fss_crc_fes_ok_p_i = '1') and (s_prod_or_cons = "10") then
          nx_control_st <= PRODUCE_WAIT_TURNAR_TIME; -- ID_DAT frame ok! station has to PRODUCE

        elsif (rx_fss_crc_fes_ok_p_i = '1') and (s_prod_or_cons = "01") then
          nx_control_st <= CONSUME_WAIT_FSS;         -- ID_DAT frame ok! station has to CONSUME

        elsif (s_rx_bytes_c > 2)  then               -- 3 bytes after the arrival of the subscriber
          nx_control_st <= RST_RX;                   -- byte, a FES has not been detected

        else
          nx_control_st <= ID_DAT_FRAME_OK;          -- CRC & FES bytes being arriving
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when PRODUCE_WAIT_TURNAR_TIME =>

        if s_time_c_is_zero = '1' then               -- turnaround time passed
          nx_control_st <= PRODUCE;

        else
          nx_control_st <= PRODUCE_WAIT_TURNAR_TIME; -- waiting for turnaround time to pass
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when CONSUME_WAIT_FSS =>

        if rx_fss_received_p_i = '1' then      -- FSS of the consumed RP_DAT arrived
          nx_control_st <= CONSUME;

        elsif s_time_c_is_zero = '1' then      -- if the FSS of the consumed RP_DAT frame doesn't
          nx_control_st <= RST_RX;             -- arrive before the expiration of the silence time,
                                               -- the engine goes back to IDLE
        else
          nx_control_st <= CONSUME_WAIT_FSS;   -- counting silence time
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when CONSUME =>

        if (rx_fss_crc_fes_ok_p_i = '1') or    -- the cons frame arrived to the end, as expected
              (rx_crc_wrong_p_i = '1')    then -- FES detected but wrong CRC or wrong # bits
          nx_control_st <= IDLE;

        elsif (s_rx_bytes_c > c_MAX_FRAME_BYTES) then -- no FES detected after the max number of bytes
          nx_control_st <= RST_RX;

        else
          nx_control_st <= CONSUME;            -- consuming bytes
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when PRODUCE =>

        if tx_completed_p_i = '1' then         -- end of production (including CRC and FES)
          nx_control_st <= IDLE;

        else
          nx_control_st <= PRODUCE;            -- producing bytes
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when RST_RX =>                           -- the current reception has finished
                                               -- a reset pulse is sent to the wf_receiver
          nx_control_st <= IDLE;               -- which will start looking for a new FSS


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when others =>
          nx_control_st <= IDLE;
    end case;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process Engine_Control_FSM_Comb_Output_Signals : definition of the output
-- signals of the FSM

  Engine_Control_FSM_Comb_Output_Signals: process (control_st)
  begin

    case control_st is

      when IDLE =>

                 ---------------------------------
                  s_idle_state            <= '1';
                 ---------------------------------
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                  s_rst_rx_p              <= '0';
                  s_producing             <= '0';


      when ID_DAT_CTRL_BYTE =>

                  s_idle_state            <= '0';
                 ---------------------------------
                  s_id_dat_ctrl_byte      <= '1';
                 ---------------------------------
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                  s_rst_rx_p              <= '0';
                  s_producing             <= '0';


      when ID_DAT_VAR_BYTE =>

                  s_idle_state            <= '0';
                  s_id_dat_ctrl_byte      <= '0';
                 ---------------------------------
                  s_id_dat_var_byte       <= '1';
                 ---------------------------------
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                  s_rst_rx_p              <= '0';
                  s_producing             <= '0';


      when ID_DAT_SUBS_BYTE =>

                  s_idle_state            <= '0';
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                  s_rst_rx_p              <= '0';
                  s_producing             <= '0';


      when ID_DAT_FRAME_OK =>

                  s_idle_state            <= '0';
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                 ---------------------------------
                  s_id_dat_frame_ok       <= '1';
                 ---------------------------------
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                  s_rst_rx_p              <= '0';
                  s_producing             <= '0';


      when PRODUCE_WAIT_TURNAR_TIME =>

                  s_idle_state            <= '0';
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_frame_ok       <= '0';
                 ---------------------------------
                  s_prod_wait_turnar_time <= '1';
                 ---------------------------------
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                  s_rst_rx_p              <= '0';
                  s_producing             <= '0';


      when CONSUME_WAIT_FSS =>

                  s_idle_state            <= '0';
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                 ---------------------------------
                  s_cons_wait_FSS         <= '1';
                 ---------------------------------
                  s_consuming             <= '0';
                  s_rst_rx_p              <= '0';
                  s_producing             <= '0';


      when CONSUME =>

                  s_idle_state            <= '0';
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                 ---------------------------------
                  s_consuming             <= '1';
                 ---------------------------------
                  s_rst_rx_p              <= '0';
                  s_producing             <= '0';


      when RST_RX =>

                  s_idle_state            <= '0';
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                 ---------------------------------
                  s_rst_rx_p              <= '1';
                 ---------------------------------
                  s_producing             <= '0';


      when PRODUCE =>

                  s_idle_state            <= '0';
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                  s_rst_rx_p              <= '0';
                 ---------------------------------
                  s_producing             <= '1';
                 ---------------------------------


      when others =>

                 ---------------------------------
                  s_idle_state            <= '1';
                 ---------------------------------
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                  s_rst_rx_p              <= '0';
                  s_producing             <= '0';


    end case;
  end process;



---------------------------------------------------------------------------------------------------
--                   Counters for the number of bytes being received or produced                 --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Instantiation of the wf_prod_data_lgth_calc unit that calculates the amount of bytes that have
-- to be transmitted when a variable is produced; the CTRL, MPS and nanoFIP_status bytes are
-- included; The FSS, CRC and FES bytes are not included!

  Produced_Data_Length_Calculator: wf_prod_data_lgth_calc
  port map(
    uclk_i             => uclk_i,
    nfip_rst_i         => nfip_rst_i,
    slone_i            => slone_i,
    nostat_i           => nostat_i,
    p3_lgth_i          => p3_lgth_i,
    var_i              => s_var,
    -------------------------------------------------------
    prod_data_lgth_o   => s_prod_data_lgth);
    -------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Instantiation of a wf_incr_counter for the counting of the number of the bytes that are
-- being produced. The counter is reset at the "PRODUCE_WAIT_TURNAR_TIME" state of the FSM and
-- counts bytes following the "tx_byte_request_p_i" pulse in the "PRODUCE" state.

  Prod_Bytes_Counter: wf_incr_counter
  generic map(g_counter_lgth => 8)
  port map(
    uclk_i            => uclk_i,
    counter_reinit_i  => s_prod_bytes_c_rst,
    counter_incr_i    => s_prod_bytes_c_inc,
    counter_is_full_o => open,
    -------------------------------------------------------
    counter_o         => s_prod_bytes_c);
    -------------------------------------------------------

  --  --  --  --  --  --  --  --  --  --  --
  s_prod_bytes_c_rst <= '0'                 when s_producing = '1' else '1';
  s_prod_bytes_c_inc <= tx_byte_request_p_i when s_producing = '1' else '0';

  -- when s_prod_data_lgth bytes have been counted,the signal s_prod_data_lgth_match is activated
  s_prod_data_lgth_match <= '1' when s_prod_bytes_c = unsigned (s_prod_data_lgth) else '0';


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Instantiation of a wf_incr_counter for the counting of the number of bytes that are being
-- received. The same counter is used for the bytes of an ID_DAT frame or a consumed RP_DAT
-- frame (hence the name of the counter is s_rx_bytes_c and not s_cons_bytes_c).
-- Regarding an ID_DAT frame: the FSS, CTRL, var and SUBS bytes are being followed by the
-- Engine_Control_FSM; the counter is used for the counting of the bytes from then on and until
-- the arrival of a FES. Therefore, the counter is reset at the "ID_DAT_SUBS_BYTE" state and counts
-- bytes following the "rx_byte_ready_p_i" pulse in the "ID_DAT_FRAME_OK" state.
-- Regarding a RP_DAT frame : the counter is reset at the "CONSUME_WAIT_FSS" state and counts
-- bytes following the "rx_byte_ready_p_i" pulse in the "CONSUME" state.

  Rx_Bytes_Counter: wf_incr_counter
  generic map(g_counter_lgth => 8)
  port map(
    uclk_i            => uclk_i,
    counter_reinit_i  => s_rx_bytes_c_rst,
    counter_incr_i    => s_rx_bytes_c_inc,
    counter_is_full_o => open,
    -------------------------------------------------------
    counter_o         => s_rx_bytes_c);
    -------------------------------------------------------

  --  --  --  --  --  --  --  --  --  --  --
  s_rx_bytes_c_rst   <= '0'               when (s_id_dat_frame_ok = '1') or (s_consuming = '1') else '1';
  s_rx_bytes_c_inc   <= rx_byte_ready_p_i when (s_id_dat_frame_ok = '1') or (s_consuming = '1') else '0';



---------------------------------------------------------------------------------------------------
--                                  Independent Timeout Counter                                  --
---------------------------------------------------------------------------------------------------

-- Instantiation of a wf_decr_counter relying only on the system clock as an additional
-- way to go back to IDLE state, in case any other logic is being stuck.

  Session_Timeout_Counter: wf_decr_counter
  generic map(g_counter_lgth => c_SESSION_TIMEOUT_C_LGTH)
  port map(
    uclk_i            => uclk_i,
    counter_rst_i     => nfip_rst_i,
    counter_top_i     => (others => '1'),
    counter_load_i    => s_idle_state,
    counter_decr_i    => '1', -- on each uclk tick
    counter_o         => open,
    ---------------------------------------------------
    counter_is_zero_o => s_session_timedout);
    ---------------------------------------------------



---------------------------------------------------------------------------------------------------
--                                   Turnaround & Silence times                                  --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- retrieval of the turnaround and silence times (in equivalent number of uclk ticks) from the
-- c_TIMEOUTS_TABLE declared in the WF_PACKAGE unit.

  s_turnaround_time <= to_unsigned((c_TIMEOUTS_TABLE(to_integer(unsigned(rate_i))).turnaround),
                                                                         s_turnaround_time'length);
  s_silence_time    <= to_unsigned((c_TIMEOUTS_TABLE(to_integer(unsigned(rate_i))).silence),
                                                                         s_turnaround_time'length);

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Instantiation of a wf_decr_counter for the counting of turnaround and silence times.
-- The same counter is used in both cases. The signal s_time_c_top initializes the counter
-- to either the turnaround or the silence time. If after the correct arrival of an ID_DAT frame
-- the identified variable is a produced one the counter loads to the turnaround time, whereas if
-- it had been a consumed variable it loads to the silence. The counting takes place during the
-- states "PRODUCE_WAIT_TURNAR_TIME" and "CONSUME_WAIT_FSS" respectively.

  Turnaround_and_Silence_Time_Counter: wf_decr_counter
  generic map(g_counter_lgth => 18)
  port map(
    uclk_i            => uclk_i,
    counter_rst_i     => nfip_rst_i,
    counter_top_i     => s_time_c_top,
    counter_load_i    => s_time_c_load,
    counter_decr_i    => '1', -- on each uclk tick
    counter_o         => open,
    -------------------------------------------------------
    counter_is_zero_o => s_time_c_is_zero);
    -------------------------------------------------------

  --  --  --  --  --  --  --  --  --  --  --
  s_time_c_top  <= s_turnaround_time when (s_id_dat_frame_ok = '1' and s_prod_or_cons = "10")   else s_silence_time;
  s_time_c_load <= '0'               when s_prod_wait_turnar_time= '1' or s_cons_wait_FSS = '1' else '1';



---------------------------------------------------------------------------------------------------
--                   Identification of the variable received by an ID_DAT frame                  --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- The following process generates the signals:
--   o internal signal s_var_aux that locks to the value of the ID_DAT.Identifier.Variable byte
--     upon its arrival
--   o output signal var_o (or s_var, used also internally by the wf_prod_data_lgth_calc) that
--     locks to the value of the ID_DAT.Identifier.Variable byte at the end of the reception of a
--     valid ID_DAT frame, if the received SUBS byte matches the station's address.
--     For a produced var this takes place at the "PRODUCE_WAIT_TURNAR_TIME" state, and
--     for a consumed at the "CONSUME" state (not in the "consume_wait_silence_time", as at this
--     state there is no knowledge that a consumed RP_DAT frame will indeed arrive!).
-- (the process is very simple but very big as we decided not to use a for loop:s)

  ID_DAT_var: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        s_var_aux           <= var_whatever;
        s_var               <= var_whatever;
        s_prod_or_cons      <= "00";
        s_broadcast_var     <= '0';
      else

        -------------------------------------------------------------------------------------------
        if (s_idle_state = '1') or (s_id_dat_ctrl_byte = '1')  then    -- new frame initializations
          s_var_aux         <= var_whatever;
          s_var             <= var_whatever;
          s_prod_or_cons    <= "00";
          s_broadcast_var   <= '0';


        -------------------------------------------------------------------------------------------
        elsif (s_id_dat_var_byte = '1') and (rx_byte_ready_p_i = '1') then      -- var byte arrived

          case rx_byte_i is

          --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
          when c_VARS_ARRAY(c_VAR_PRESENCE_INDEX).hexvalue             =>
            s_var_aux       <= var_presence;
            s_prod_or_cons  <= c_VARS_ARRAY(c_VAR_PRESENCE_INDEX).prod_or_cons;
            s_broadcast_var <= c_VARS_ARRAY(c_VAR_PRESENCE_INDEX).broadcast;

          --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
           when c_VARS_ARRAY(c_VAR_IDENTIF_INDEX).hexvalue =>
             s_var_aux       <= var_identif;
             s_prod_or_cons  <= c_VARS_ARRAY(c_VAR_IDENTIF_INDEX).prod_or_cons;
             s_broadcast_var <= c_VARS_ARRAY(c_VAR_IDENTIF_INDEX).broadcast;

          --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
           when c_VARS_ARRAY(c_VAR_1_INDEX).hexvalue       =>
             s_var_aux       <= var_1;
             s_prod_or_cons  <= c_VARS_ARRAY(c_VAR_1_INDEX).prod_or_cons;
             s_broadcast_var <= c_VARS_ARRAY(c_VAR_1_INDEX).broadcast;

          --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
           when c_VARS_ARRAY(c_VAR_2_INDEX).hexvalue       =>
             s_var_aux       <= var_2;
             s_prod_or_cons  <= c_VARS_ARRAY(c_VAR_2_INDEX).prod_or_cons;
             s_broadcast_var <= c_VARS_ARRAY(c_VAR_2_INDEX).broadcast;

          --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
           when c_VARS_ARRAY(c_VAR_3_INDEX).hexvalue       =>
             s_var_aux       <= var_3;
             s_prod_or_cons  <= c_VARS_ARRAY(c_VAR_3_INDEX).prod_or_cons;
             s_broadcast_var <= c_VARS_ARRAY(c_VAR_3_INDEX).broadcast;

          --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
           when c_VARS_ARRAY(c_VAR_RST_INDEX).hexvalue     =>
             s_var_aux       <= var_rst;
             s_prod_or_cons  <= c_VARS_ARRAY(c_VAR_RST_INDEX).prod_or_cons;
             s_broadcast_var <= c_VARS_ARRAY(c_VAR_RST_INDEX).broadcast;

          --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
           when c_VARS_ARRAY(c_VAR_4_INDEX).hexvalue     =>
             s_var_aux       <= var_4;
             s_prod_or_cons  <= c_VARS_ARRAY(c_VAR_4_INDEX).prod_or_cons;
             s_broadcast_var <= c_VARS_ARRAY(c_VAR_4_INDEX).broadcast;

          --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
           when c_VARS_ARRAY(c_VAR_5_INDEX).hexvalue     =>
             s_var_aux       <= var_5;
             s_prod_or_cons  <= c_VARS_ARRAY(c_VAR_5_INDEX).prod_or_cons;
             s_broadcast_var <= c_VARS_ARRAY(c_VAR_5_INDEX).broadcast;

          --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
           when others =>
             s_var_aux       <= var_whatever;
             s_prod_or_cons  <= "00";
             s_broadcast_var <= '0';
          end case;


        -------------------------------------------------------------------------------------------
        elsif (s_prod_wait_turnar_time = '1') or (s_consuming = '1') then             -- ID_DAT OK!

         s_var              <= s_var_aux;

        end if;
      end if;
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --   --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Concurrent signal assignment (used by the FSM)

  s_var_identified <= '1' when rx_byte_i = c_VARS_ARRAY(c_VAR_PRESENCE_INDEX).hexvalue or
                               rx_byte_i = c_VARS_ARRAY(c_VAR_IDENTIF_INDEX).hexvalue  or
                               rx_byte_i = c_VARS_ARRAY(c_VAR_RST_INDEX).hexvalue      or
                               rx_byte_i = c_VARS_ARRAY(c_VAR_1_INDEX).hexvalue        or
                               rx_byte_i = c_VARS_ARRAY(c_VAR_2_INDEX).hexvalue        or
                               rx_byte_i = c_VARS_ARRAY(c_VAR_3_INDEX).hexvalue        or
                               rx_byte_i = c_VARS_ARRAY(c_VAR_4_INDEX).hexvalue        or
                               rx_byte_i = c_VARS_ARRAY(c_VAR_5_INDEX).hexvalue else '0';



---------------------------------------------------------------------------------------------------
--                                     Signals Registration                                      --
---------------------------------------------------------------------------------------------------

  process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        tx_last_data_byte_p_o         <= '0';
        s_tx_last_data_byte_p_d       <= '0';
        s_tx_byte_request_accept_p_d1 <= '0';
        s_tx_byte_request_accept_p_d2 <= '0';
        s_tx_start_prod_p             <= '0';

      else
        s_tx_last_data_byte_p_d       <= s_tx_last_data_byte_p;
        tx_last_data_byte_p_o         <= s_tx_last_data_byte_p_d;
        s_tx_byte_request_accept_p_d1 <= s_tx_byte_request_accept_p;
        s_tx_byte_request_accept_p_d2 <= s_tx_byte_request_accept_p_d1;
        s_tx_start_prod_p             <= (s_prod_wait_turnar_time and s_time_c_is_zero);
      end if;
    end if;
  end process;

  --  --  --  --  --  --  --  --  --  --  --
  s_tx_byte_request_accept_p <= s_producing and (tx_byte_request_p_i or s_tx_start_prod_p);
  s_tx_last_data_byte_p      <= s_producing and s_prod_data_lgth_match and tx_byte_request_p_i;



---------------------------------------------------------------------------------------------------
--                                 Concurrent Signal Assignments                                 --
---------------------------------------------------------------------------------------------------

-- variable received by a valid ID_DAT frame that concerns this station
  var_o                      <= s_var;

-- number of bytes for the CTRL & Data fields of a produced RP_DAT frame
  prod_data_lgth_o           <= s_prod_data_lgth;

-- response to wf_tx_serializer request for a byte
  tx_byte_request_accept_p_o <= s_tx_byte_request_accept_p_d2;

-- index of the byte being produced/ consumed
  prod_byte_index_o          <= std_logic_vector (s_prod_bytes_c);
  cons_byte_index_o          <= std_logic_vector (s_rx_bytes_c);

-- The wf_fd_receiver receives a 1 uclk long reset pulse if during the reception of an ID or an
-- RP_DAT the engine control FSM has to go back to IDLE.
-- This may happen if : any of the CTRL, variable, subs bytes of an ID_DAT frame are wrong or
--                      an ID_DAT is lasting more than 8 bytes or
--                      an RP_DAT is lasting more than 133 bytes or
--                      the silence times expires
--                      the engine control FSM times out
-- After this reset, the receiver will discard any frame being received and will restart looking
-- for the FSS of a new one.
-- The wf_fd_receiver also stays reset during a production session.
  rx_rst_o                   <= '1' when (s_rst_rx_p = '1')              or
                                         (s_prod_wait_turnar_time = '1') or (s_producing = '1') else '0';

-- indication of a consumed RP_DAT frame with more than 133 bytes 
  cons_bytes_excess_o        <= '1' when (s_consuming = '1') and (s_rx_bytes_c > c_MAX_FRAME_BYTES) else '0';

-- production starts after the expiration of the turnaround time
  tx_start_p_o               <= s_tx_start_prod_p;



end architecture rtl;

--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------