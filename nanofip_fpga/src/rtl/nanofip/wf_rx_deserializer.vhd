--_________________________________________________________________________________________________
--                                                                                                |
--                                         |The nanoFIP|                                          |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                       wf_rx_deserializer                                       |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         wf_rx_deserializer.vhd                                                            |
--                                                                                                |
-- Description  De-serialization of the deglitched "nanoFIP FIELDRIVE" input signal FD_RXD and    |
--              construction of bytes of data to be provided to:                                  |
--                o the wf_engine_control unit, for the contents of ID_DAT frames                 |
--                o the wf_consumption unit,    for the contents of consumed RP_DAT frames.       |
--              The unit is also responsible for the identification of the FSS and FES fields of  |
--              ID_DAT and RP_DAT frames and the verification of their CRC.                       |
--              At the end of a frame (FES detection) either the fss_crc_fes_ok_p_o pulse         |
--              is assserted, indicating a frame with with correct FSS, CRC and FES               |
--              or the pulse crc_wrong_p_o is asserted indicating an error on the CRC.            |
--              If a FES is not detected after the reception of more than 8 bytes for an ID_DAT   |
--              or more than 133 bytes for a RP_DAT the unit is reset by the wf_engine_control.   |
--              The unit also remains reset during data production.                               |
--                                                                                                |
--              Remark: We refer to                                                               |
--               o a significant edge          : for the edge of a manch. encoded bit             |
--                 (bit 0: _|-, bit 1: -|_).                                                      |
--                                                                                                |
--               o a transition	               : for the moment in between two adjacent bits, that|
--                 may or may not result in an edge (eg. a 0 followed by a 0 will give an edge:   |
--                 _|-|_|-, but a 0 followed by a 1 will not: _|--|_ ).                           |
--                                                                                                |
--               o the sampling of a manch. bit: for the moments when a manch. encoded bit should |
--                 be sampled, before and after a significant edge.                               |
--                                                                                                |
--               o the sampling of a bit       : for the sampling of only the 1st part,           |
--                 before the transition.                                                         |
--                                                                                                |
--               Example:                                                                         |
--                 bits              :  0   1                                                     |
--                 manch. encoded    : _|- -|_                                                    |
--                 significant edge  :  ^   ^                                                     |
--                 transition        :    ^                                                       |
--                 sample_manch_bit_p: ^ ^ ^ ^                                                    |
--                 sample_bit_p      : ^   ^   (this sampling will give the 0 and the 1)          |
--                                                                                                |
--                                                                                                |
--               Reminder of the consumed RP_DAT frame structure:                                 |
--       _______ _______ ______  _______ ______ ________________ _______  ___________ _______     |
--      |__PRE__|__FSD__|_CTRL_||__PDU__|_LGTH_|_..ApplicData.._|__MPS__||____FCS____|__FES__|    |
--                                                                                                |
--                                                                                                |
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)                             |
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)                                 |
-- Date         15/02/2011                                                                        |
-- Version      v0.05                                                                             |
-- Depends on   wf_reset_unit                                                                     |
--              wf_rx_osc                                                                         |
--              wf_rx_deglitcher                                                                  |
--              wf_engine_control                                                                 |
----------------                                                                                  |
-- Last changes                                                                                   |
--     09/2009 v0.01 PAS First version                                                            |
--     10/2010 v0.02 EG  state switch_to_deglitched added;                                        |
--                       output signal rx_osc_rst_o added; signals renamed;                       |
--                       state machine rewritten (moore style);                                   |
--                       units wf_rx_manch_code_check and Incoming_Bits_Index created;            |
--                       each manch bit of FES checked (bf was just each bit, so any D5 was FES)  |
--                       code cleaned-up + commented.                                             |
--     12/2010 v0.03 EG  CRC_ok pulse transfered 16 bits later to match the FES;                  |
--                       like this we confirm that the CRC_ok_p arrived just before the FES,      |
--                       and any 2 bytes that could by chanche be seen as CRC, are neglected.     |
--                       FSM data_field_byte state: redundant code removed:                       |
--                       "s_fes_wrong_bit = '1' and s_manch_code_viol_p = '1' then IDLE"          |
--                       code(more!)cleaned-up                                                    |
--     01/2011 v0.04 EG  changed way of detecting the FES to be able to detect a FES even if      |
--                       bytes with size different than 8 have preceeded.                         |
--                       crc_wrong_p_o replaced the crc_wrong_p_o.                                |
--     02/2011 v0.05 EG  changed crc pulse transfer; removed switch to deglitch state             |
--                       s_fes_detected removed and s_byte_ready_p_d1; if bytes arrive with       |
--                       bits not x8, the fss_crc_fes_ok_p_o stays 0 (bc of s_byte_ready_p_d1)    |
--                       and the crc_wrong_p_o is asserted (bc of s_sample_manch_bit_p_d1);       |
--                       unit reset during production;                                            |
--                       check for code vilations completely removed!                             |
--    10/2011  v0.05b EG moved session_timedout in the synchronous FSM process                    |
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
--                           Entity declaration for wf_rx_deserializer
--=================================================================================================

entity wf_rx_deserializer is port(
  -- INPUTS
    -- nanoFIP User Interface general signal
    uclk_i               : in std_logic; -- 40 MHz clock

    -- Signal from the wf_reset_unit
    nfip_rst_i           : in std_logic; -- nanoFIP internal reset

    -- Signal from the wf_engine_control unit
    rx_rst_i             : in std_logic; -- reset during production or
                                         -- reset pulse when during reception a frame is rejected
                                         -- by the engine_control (example: ID_DAT > 8 bytes, 
                                         -- RP_DAT > 133 bytes, wrong ID_DAT CTRL/ VAR/ SUBS bytes)

    -- Signals from the wf_rx_deglitcher
    fd_rxd_f_edge_p_i    : in std_logic; -- indicates a falling edge on the deglitched FD_RXD
    fd_rxd_r_edge_p_i    : in std_logic; -- indicates a rising  edge on the deglitched FD_RXD
    fd_rxd_i             : in std_logic; -- deglitched FD_RXD

    -- Signals from the wf_rx_osc unit
    sample_manch_bit_p_i : in std_logic; -- pulse indicating the sampling of a manch. bit
    sample_bit_p_i       : in std_logic; -- pulse indicating the sampling of a bit
    signif_edge_window_i : in std_logic; -- time window where a significant edge is expected
    adjac_bits_window_i  : in std_logic; -- time window where a transition between adjacent
                                         -- bits is expected


  -- OUTPUTS
    -- Signals to the wf_consumption and the wf_engine_control units
    byte_o               : out std_logic_vector (7 downto 0) ;   -- retrieved data byte
    byte_ready_p_o       : out std_logic; -- pulse indicating a new retrieved data byte
    fss_crc_fes_ok_p_o   : out std_logic; -- indication of a frame (ID_DAT or RP_DAT) with
                                          -- correct FSS, FES and CRC

    -- Signal to the wf_production and the wf_engine_control units
    crc_wrong_p_o        : out std_logic; -- indication of a frame (ID_DAT or RP_DAT) with a
                                          -- wrong CRC; pulse upon FES detection

    -- Signal to the wf_engine_control unit
    fss_received_p_o     : out std_logic; -- pulse upon reception of a correct FSS (ID/RP)

    -- Signal to the wf_rx_osc unit
    rx_osc_rst_o         : out std_logic);-- resets the clk recovery procedure

end entity wf_rx_deserializer;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of wf_rx_deserializer is

  -- FSM
  type rx_st_t  is (IDLE, PRE_FIELD_FIRST_F_EDGE, PRE_FIELD_R_EDGE, PRE_FIELD_F_EDGE, FSD_FIELD,
                                                                         CTRL_DATA_FCS_FES_FIELDS);
  signal rx_st, nx_rx_st                                                               : rx_st_t;
  signal s_idle, s_receiving_pre, s_receiving_fsd, s_receiving_bytes                   : std_logic;
  -- PRE detection
  signal s_manch_r_edge_p, s_manch_f_edge_p, s_bit_r_edge_p, s_edge_out_manch_window_p : std_logic;
  -- FSD, FES detection
  signal s_fsd_bit, s_fsd_wrong_bit, s_fsd_last_bit, s_fes_detected                    : std_logic;
  signal s_arriving_fes                                           : std_logic_vector (15 downto 0);
  -- bytes construction
  signal s_write_bit_to_byte_p,s_byte_ready_p,s_byte_ready_p_d1,s_sample_manch_bit_p_d1: std_logic;
  signal s_manch_bit_index_load_p, s_manch_bit_index_decr_p, s_manch_bit_index_is_zero : std_logic;
  signal s_manch_bit_index, s_manch_bit_index_top                          : unsigned (3 downto 0);
  signal s_byte                                                   : std_logic_vector  (7 downto 0);
  -- CRC calculation
  signal s_CRC_ok_p, s_CRC_ok_p_d, s_CRC_ok_p_found                                    : std_logic;
  -- independent timeout counter
  signal s_session_timedout                                                            : std_logic;


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--                                       Deserializer's FSM                                      --
---------------------------------------------------------------------------------------------------

-- Receiver's state machine: The state machine is divided in three parts (a clocked process
-- to store the current state, a combinatorial process to manage state transitions and finally a
-- combinatorial process to manage the output signals), which are the three processes that follow.

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Synchronous process Deserializer_FSM_Sync: storage of the current state of the FSM
-- A robust protection, that depends only on the system clock, has been implemented:
-- knowing that at any bit rate the reception of a frame should not last more than 35ms (this
-- corresponds to the consumption of 133 bytes at 31.25 Kbps), a counter has been implemented,
-- responsible for bringing the machine back to IDLE if more than 52ms (complete 21 bit counter)
-- have passed since the machine left the IDLE state.

  Deserializer_FSM_Sync: process (uclk_i)
    begin
      if rising_edge (uclk_i) then
        if nfip_rst_i = '1' or rx_rst_i = '1' or s_session_timedout = '1' then
          rx_st <= IDLE;
        else
          rx_st <= nx_rx_st;
        end if;
      end if;
    end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process Deserializer_FSM_Comb_State_Transitions: Definition of the state
-- transitions of the FSM.

  Deserializer_FSM_Comb_State_Transitions: process (s_bit_r_edge_p, s_edge_out_manch_window_p,
                                                    fd_rxd_f_edge_p_i, s_manch_r_edge_p, rx_st,
                                                    s_fsd_wrong_bit, s_manch_f_edge_p,
                                                    s_fsd_last_bit, s_fes_detected)
  begin

  case rx_st is

    -- During the PRE, the wf_rx_osc is trying to synchronize to the transmitter's clock and every
    -- edge detected in the FD_RXD is taken into account. At this phase, the unit uses
    -- the wf_rx_osc signals: adjac_bits_window_i and signif_edge_window_i and if edges are found
    -- outside those windows the unit goes back to IDLE and the wf_rx_osc is reset.
    -- For the rest of the frame, the unit is just sampling the deglitched FD_RXD on the moments
    -- specified by the wf_rx_osc signals: sample_manch_bit_p_i and sample_bit_p_i.

    when IDLE =>

                        if fd_rxd_f_edge_p_i = '1' then        -- falling edge detection
                          nx_rx_st <= PRE_FIELD_FIRST_F_EDGE;

                        else
                          nx_rx_st <= IDLE;
                        end if;


    when PRE_FIELD_FIRST_F_EDGE =>

                        if s_manch_r_edge_p = '1' then         -- arrival of a manch.
                          nx_rx_st <= PRE_FIELD_R_EDGE;        -- rising edge

                        elsif s_edge_out_manch_window_p = '1' then -- arrival of any other edge
                          nx_rx_st <= IDLE;

                        else
                          nx_rx_st <= PRE_FIELD_FIRST_F_EDGE;
                        end if;


    when PRE_FIELD_R_EDGE =>

                        if s_manch_f_edge_p = '1' then         -- arrival of a manch. falling edge
                          nx_rx_st <= PRE_FIELD_F_EDGE;        -- note: several loops between
                                                               -- a rising and a falling edge are
                                                               -- expected for the PRE

                        elsif s_edge_out_manch_window_p = '1' then -- arrival of any other edge
                           nx_rx_st <= IDLE;

                        else
                           nx_rx_st <= PRE_FIELD_R_EDGE;
                        end if;


    when PRE_FIELD_F_EDGE =>

                        if s_manch_r_edge_p = '1' then         -- arrival of a manch. rising edge
                          nx_rx_st <= PRE_FIELD_R_EDGE;

                        elsif s_bit_r_edge_p = '1' then        -- arrival of a rising edge between
                          nx_rx_st <=  FSD_FIELD;              -- adjacent bits, signaling the
                                                               -- beginning of the 1st V+ violation
                                                               -- of the FSD

                        elsif s_edge_out_manch_window_p = '1' then -- arrival of any other edge
                          nx_rx_st <= IDLE;

                        else
                          nx_rx_st <= PRE_FIELD_F_EDGE;
                         end if;

    -- For the monitoring of the FSD, the unit is sampling each manch. bit of the incoming
    -- FD_RXD and it is comparing it to the nominal bit of the FSD; the signal s_fsd_wrong_bit
    -- is doing this comparison. If a wrong bit is received, the state machine jumps back to IDLE,
    -- whereas if the complete byte is correctly received, it jumps to the CTRL_DATA_FCS_FES_FIELDS.

    when FSD_FIELD =>

                        if s_fsd_last_bit = '1' then           -- reception of the last (15th)
                          nx_rx_st <= CTRL_DATA_FCS_FES_FIELDS;-- FSD bit

                        elsif s_fsd_wrong_bit = '1' then       -- wrong bit
                          nx_rx_st <= IDLE;

                        else
                          nx_rx_st <= FSD_FIELD;
                        end if;

    -- The state machine stays in the CTRL_DATA_FCS_FES_FIELDS state until a FES detection (or
    -- a reset rx_rst_i signal or a s_session_timeout signal). In this state bytes are "blindly"
    -- being constructed and it is the wf_engine_control unit that supervises what is being received;
    -- if for example an ID_DAT is being received without a FES detected after 8 bytes or an
    -- RP_DAT without a FES after 133 bytes, or if the CTRL byte of an ID_DAT is wrong, the
    -- engine_control will discard the current reception and reset the FSM through the rx_rst_i.

    when CTRL_DATA_FCS_FES_FIELDS =>

                        if s_fes_detected = '1' then
                          nx_rx_st <= IDLE;

                        else
                          nx_rx_st <= CTRL_DATA_FCS_FES_FIELDS;
                        end if;


    when OTHERS =>
                        nx_rx_st <= IDLE;

  end case;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process Deserializer_FSM_Comb_Output_Signals: Definition of the output
-- signals of the FSM

  Deserializer_FSM_Comb_Output_Signals: process (rx_st)

  begin

    case rx_st is

    when IDLE =>
                  ------------------------------------
                   s_idle                    <= '1';
                  ------------------------------------
                   s_receiving_pre           <= '0';
                   s_receiving_fsd           <= '0';
                   s_receiving_bytes         <= '0';


    when PRE_FIELD_FIRST_F_EDGE | PRE_FIELD_R_EDGE | PRE_FIELD_F_EDGE =>

                   s_idle                    <= '0';
                  ------------------------------------
                   s_receiving_pre           <= '1';
                  ------------------------------------
                   s_receiving_fsd           <= '0';
                   s_receiving_bytes         <= '0';


    when FSD_FIELD =>

                   s_idle                    <= '0';
                   s_receiving_pre           <= '0';
                  ------------------------------------
                   s_receiving_fsd           <= '1';
                  ------------------------------------
                   s_receiving_bytes         <= '0';


    when CTRL_DATA_FCS_FES_FIELDS =>

                   s_idle                    <= '0';
                   s_receiving_pre           <= '0';
                   s_receiving_fsd           <= '0';
                  ------------------------------------
                   s_receiving_bytes         <= '1';
                  ------------------------------------


    when OTHERS =>

                  ------------------------------------
                   s_idle                    <= '1';
                  ------------------------------------
                   s_receiving_pre           <= '0';
                   s_receiving_fsd           <= '0';
                   s_receiving_bytes         <= '0';

    end case;
  end process;



---------------------------------------------------------------------------------------------------
--                                         Bytes Creation                                        --
---------------------------------------------------------------------------------------------------

-- Synchronous process Append_Bit_To_Byte: Creation of bytes of data.
-- A new bit of the FD_RXD is appended to the output byte that is being formed when the FSM is in
-- the "CTRL_DATA_FCS_FES_FIELDS" state, on the "sample_bit_p_i" moments.

  Append_Bit_To_Byte: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        s_byte_ready_p_d1       <= '0';
        s_sample_manch_bit_p_d1 <= '0';
        s_byte                  <= (others => '0');
      else

        s_byte_ready_p_d1       <= s_byte_ready_p;
        s_sample_manch_bit_p_d1 <= sample_manch_bit_p_i;

        if s_write_bit_to_byte_p = '1' then
          s_byte                <= s_byte(6 downto 0) & fd_rxd_i;

        end if;
      end if;
    end if;
  end process;

 --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  s_write_bit_to_byte_p <= s_receiving_bytes and sample_bit_p_i;
  s_byte_ready_p        <= s_receiving_bytes and s_manch_bit_index_is_zero and sample_manch_bit_p_i
                                                                           and (not s_fes_detected);



--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Instantiation of a counter that manages the position of an incoming FD_RXD bit inside a manch.
-- encoded byte (16 bits).

  Incoming_Bits_Index: wf_decr_counter
  generic map(g_counter_lgth => 4)
  port map(
    uclk_i            => uclk_i,
    counter_rst_i     => nfip_rst_i,
    counter_top_i     => s_manch_bit_index_top,
    counter_load_i    => s_manch_bit_index_load_p,
    counter_decr_i    => s_manch_bit_index_decr_p,
    ---------------------------------------------------
    counter_o         => s_manch_bit_index,
    counter_is_zero_o => s_manch_bit_index_is_zero);
    ---------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  s_manch_bit_index_top    <= to_unsigned (c_FSD'left-2, s_manch_bit_index_top'length) when s_receiving_pre  = '1' else
                              to_unsigned (15,           s_manch_bit_index_top'length) when s_receiving_bytes ='1' else
                              to_unsigned (0,            s_manch_bit_index_top'length);

  s_manch_bit_index_load_p <= '1'                                                when (s_idle ='1')                                        else
                              s_manch_bit_index_is_zero and sample_manch_bit_p_i when (s_receiving_pre = '1') or (s_receiving_bytes = '1') else --reloading for every new byte
                              '0';

  s_manch_bit_index_decr_p <= sample_manch_bit_p_i when (s_receiving_fsd = '1') or (s_receiving_bytes = '1') else '0';



---------------------------------------------------------------------------------------------------
--                                         FSD detection                                         --
---------------------------------------------------------------------------------------------------

  -- FSD aux signals concurrent assignments:

  s_fsd_bit           <= s_receiving_fsd   and c_FSD (to_integer(s_manch_bit_index));
  s_fsd_last_bit      <= s_manch_bit_index_is_zero and sample_manch_bit_p_i;
  s_fsd_wrong_bit     <= (s_fsd_bit xor fd_rxd_i) and sample_manch_bit_p_i;



---------------------------------------------------------------------------------------------------
--                                         FES detection                                         --
---------------------------------------------------------------------------------------------------

-- Synchronous process FES_Detector: The s_arriving_fes register is storing the last 16
-- manch. encoded bits received and the s_fes_detected indicates whether they match the FES.

  FES_Detector: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if s_receiving_bytes = '0' then
        s_arriving_fes <= (others =>'0');

      elsif s_receiving_bytes = '1' and sample_manch_bit_p_i = '1' then

        s_arriving_fes <= s_arriving_fes (14 downto 0) & fd_rxd_i;

      end if;
    end if;
  end process;

  --  --  --  --  --  --  --  --  --  --  --
  s_fes_detected <= '1' when s_arriving_fes = c_FES else '0';



---------------------------------------------------------------------------------------------------
--                                        CRC Verification                                       --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Instantiation of the CRC calculator unit that verifies the received FCS field.

  CRC_Verification : wf_crc
  port map(
    uclk_i             => uclk_i,
    nfip_rst_i         => nfip_rst_i,
    start_crc_p_i      => s_receiving_fsd,
    data_bit_ready_p_i => s_write_bit_to_byte_p,
    data_bit_i         => fd_rxd_i,
    crc_o              => open,
   ---------------------------------------------------
    crc_ok_p_o         => s_CRC_ok_p);
   ---------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Synchronous process that checks the position of the CRC bytes in the frame: The 1 uclk-
-- wide crc_ok_p coming from the CRC calculator is delayed for 1 complete byte. The matching of
-- this delayed pulse with the end of frame pulse (s_fes_detected), would confirm that the two
-- last bytes received before the FES were the correct CRC.

  CRC_OK_pulse_delay: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' or s_receiving_bytes = '0' then
        s_CRC_ok_p_d       <= '0';
        s_CRC_ok_p_found   <= '0';
      else

        if s_CRC_ok_p = '1' then
          s_CRC_ok_p_found <= '1';
        end if;

        if s_byte_ready_p = '1' and s_CRC_ok_p_found = '1' then -- arrival of the next byte
          s_CRC_ok_p_d     <= '1';                              -- (FES normally)
          s_CRC_ok_p_found <= '0';

        else
          s_CRC_ok_p_d     <= '0';
        end if;

      end if;
    end if;
  end process;



---------------------------------------------------------------------------------------------------
--                                  Independent Timeout Counter                                  --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Instantiation of a wf_decr_counter relying only on the system clock, as an additional
-- way to go back to IDLE state, in case any other logic is being stuck. The length of the counter
-- is defined using the slowest bit rate and considering reception of the upper limit of 133 bytes. 

  Session_Timeout_Counter: wf_decr_counter
  generic map(g_counter_lgth => c_SESSION_TIMEOUT_C_LGTH)
  port map(
    uclk_i            => uclk_i,
    counter_rst_i     => nfip_rst_i,
    counter_top_i     => (others => '1'),
    counter_load_i    => s_idle,
    counter_decr_i    => '1', -- on each uclk tick
    counter_o         => open,
    ---------------------------------------------------
    counter_is_zero_o => s_session_timedout);
    ---------------------------------------------------



---------------------------------------------------------------------------------------------------
--                                 Concurrent signal assignments                                 --
---------------------------------------------------------------------------------------------------
-- aux signals concurrent assignments :

  s_manch_r_edge_p          <= signif_edge_window_i and fd_rxd_r_edge_p_i;
  s_manch_f_edge_p          <= signif_edge_window_i and fd_rxd_f_edge_p_i;
  s_bit_r_edge_p            <= adjac_bits_window_i  and fd_rxd_r_edge_p_i;
  s_edge_out_manch_window_p <= (not signif_edge_window_i)and(fd_rxd_r_edge_p_i or fd_rxd_f_edge_p_i);


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- output signals concurrent assignments :

  byte_o                    <= s_byte;
  byte_ready_p_o            <= s_byte_ready_p_d1;
  rx_osc_rst_o              <= s_idle;
  fss_received_p_o          <= s_receiving_fsd  and s_fsd_last_bit;

  -- frame with correct FSS, CRC, FES (plus with number of bits multiple of 8) 
  fss_crc_fes_ok_p_o        <= s_fes_detected and s_byte_ready_p_d1 and s_CRC_ok_p_d;

  -- frame with wrong CRC; pulse upon FES detection
  -- here the s_sample_manch_bit_p_d1 and not the s_byte_ready_p_d1 is used, so that frames
  -- with number of bits not multiple of 8, but with correct FES, can be detected. 
  crc_wrong_p_o             <= s_fes_detected and s_sample_manch_bit_p_d1 and (not s_CRC_ok_p_d);


end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------