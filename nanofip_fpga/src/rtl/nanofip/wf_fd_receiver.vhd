--_________________________________________________________________________________________________
--                                                                                                |
--                                         |The nanoFIP|                                          |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                         wf_fd_receiver                                         |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         wf_fd_receiver.vhd                                                                |
--                                                                                                |
-- Description  The unit groups the main actions that regard FIELDRIVE data reception.            |
--              It instantiates the units:                                                        |
--                                                                                                |
--              o wf_rx_deserializer: for the formation of bytes of data to be provided to the:   |
--                                    o wf_engine_control unit, for the contents of ID_DAT frames |
--                                    o wf_cons_bytes_processor unit, for the contents of consumed|
--                                      RP_DAT frames                                             |
--                                                                                                |
--              o wf_rx_osc         : for the clock recovery                                      |
--                                                                                                |
--              o wf_rx_deglitcher  : for the filtering of the input FD_RXD                       |
--                                                                                                |
--                                                                                                |
--                     _________________________         _________________________                |
--                    |                         |       |                         |               |
--                    |      wf_Consumption     |       |    wf_engine_control    |               |
--                    |_________________________|       |_________________________|               |
--                                /\                                /\                            |
--                     ___________________________________________________________                |
--                    |                      wf_fd_revceiver                      |               |
--                    |                                                _________  |               |
--                    |   _______________________________________     |         | |               |
--                    |  |                                       |    |         | |               |
--                    |  |           wf_rx_deserializer          |    |  wf_rx  | |               |
--                    |  |                                       |  < |  _osc   | |               |
--                    |  |_______________________________________|    |         | |               |
--                    |                     /\                        |_________| |               |
--                    |   _______________________________________                 |               |
--                    |  |                                       |                |               |
--                    |  |            wf_rx_deglitcher           |                |               |
--                    |  |_______________________________________|                |               |
--                    |                                                           |               |
--                    |___________________________________________________________|               |
--                                                 /\                                             |
--              ___________________________________________________________________               |
--               0_____________________________FIELDBUS______________________________O            |
--                                                                                                |
--                                                                                                |
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)                             |
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)                                 |
-- Date         15/02/2011                                                                        |
-- Version      v0.01                                                                             |
-- Depends on   wf_reset_unit                                                                     |
--              wf_engine_control                                                                 |
----------------                                                                                  |
-- Last changes                                                                                   |
--     02/2011  v0.01  EG  First version                                                          |
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
--                              Entity declaration for wf_fd_receiver
--=================================================================================================
entity wf_fd_receiver is port(
  -- INPUTS
    -- nanoFIP User Interface, General signals
    uclk_i                : in std_logic;  -- 40 MHZ clock

    -- nanoFIP WorldFIP Settings
    rate_i                : in std_logic_vector (1 downto 0);  -- WorldFIP bit rate

    -- nanoFIP FIELDRIVE
    fd_rxd_a_i            : in std_logic;  -- receiver data

    -- Signal from the wf_reset_unit
    nfip_rst_i            : in std_logic;  -- nanoFIP internal reset

    -- Signal from the wf_engine_control unit
    rx_rst_i              : in std_logic;  -- reset during production or
                                           -- reset pulse when during reception a frame is rejected
                                           -- by the engine_control (example: ID_DAT > 8 bytes, 
                                           -- RP_DAT > 133 bytes, wrong ID_DAT CTRL/ VAR/ SUBS bytes)


  -- OUTPUTS
    -- Signals to the wf_engine_control and wf_consumption
    rx_byte_o             : out std_logic_vector (7 downto 0); -- retrieved data byte
    rx_byte_ready_p_o     : out std_logic; -- pulse indicating a new retrieved data byte
    rx_fss_crc_fes_ok_p_o : out std_logic; -- indication of a frame (ID_DAT or RP_DAT) with
                                           -- correct FSS, FES & CRC; pulse upon FES detection
    rx_crc_wrong_p_o      : out std_logic; -- indication of a frame (ID_DAT or RP_DAT) with
                                           -- wrong CRC; pulse upon FES detection

    -- Signals to the wf_engine_control
    rx_fss_received_p_o   : out std_logic);-- pulse upon FSS detection (ID/ RP_DAT)

end entity wf_fd_receiver;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture struc of wf_fd_receiver is

  signal s_rx_osc_rst, s_adjac_bits_window, s_signif_edge_window : std_logic;
  signal s_sample_bit_p, s_sample_manch_bit_p                    : std_logic;
  signal s_fd_rxd_filt, s_rxd_filt_edge_p                        : std_logic;
  signal s_fd_rxd_filt_f_edge_p, s_fd_rxd_filt_r_edge_p          : std_logic;


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--                                          Deglitcher                                           --
---------------------------------------------------------------------------------------------------

  FIELDRIVE_Receiver_Deglitcher: wf_rx_deglitcher
  port map(
    uclk_i                 => uclk_i,
    nfip_rst_i             => nfip_rst_i,
    fd_rxd_a_i             => fd_rxd_a_i,
  -----------------------------------------------------------------
    fd_rxd_filt_o          => s_fd_rxd_filt,
    fd_rxd_filt_edge_p_o   => s_rxd_filt_edge_p,
    fd_rxd_filt_f_edge_p_o => s_fd_rxd_filt_f_edge_p);
  -----------------------------------------------------------------

    s_fd_rxd_filt_r_edge_p <= s_rxd_filt_edge_p and (not s_fd_rxd_filt_f_edge_p);



---------------------------------------------------------------------------------------------------
--                                          Oscillator                                           --
---------------------------------------------------------------------------------------------------

  FIELDRIVE_Receiver_Oscillator: wf_rx_osc
  port map(
    uclk_i                  => uclk_i,
    rate_i                  => rate_i,
    nfip_rst_i              => nfip_rst_i,
    fd_rxd_edge_p_i         => s_rxd_filt_edge_p,
    rx_osc_rst_i            => s_rx_osc_rst,
  -----------------------------------------------------------------
    rx_manch_clk_p_o        => s_sample_manch_bit_p,
    rx_bit_clk_p_o          => s_sample_bit_p,
    rx_signif_edge_window_o => s_signif_edge_window,
    rx_adjac_bits_window_o  => s_adjac_bits_window);
  -----------------------------------------------------------------



---------------------------------------------------------------------------------------------------
--                                         Deserializer                                          --
---------------------------------------------------------------------------------------------------

  FIELDRIVE_Receiver_Deserializer: wf_rx_deserializer
  port map(
    uclk_i                  => uclk_i,
    nfip_rst_i              => nfip_rst_i,
    rx_rst_i                => rx_rst_i,
    sample_bit_p_i          => s_sample_bit_p,
    sample_manch_bit_p_i    => s_sample_manch_bit_p,
    signif_edge_window_i    => s_signif_edge_window,
    adjac_bits_window_i     => s_adjac_bits_window,
    fd_rxd_f_edge_p_i       => s_fd_rxd_filt_f_edge_p,
    fd_rxd_r_edge_p_i       => s_fd_rxd_filt_r_edge_p,
    fd_rxd_i                => s_fd_rxd_filt,
  -----------------------------------------------------------------
    byte_ready_p_o          => rx_byte_ready_p_o,
    byte_o                  => rx_byte_o,
    fss_crc_fes_ok_p_o      => rx_fss_crc_fes_ok_p_o,
    rx_osc_rst_o            => s_rx_osc_rst,
    fss_received_p_o        => rx_fss_received_p_o,
    crc_wrong_p_o           => rx_crc_wrong_p_o);
  -----------------------------------------------------------------


end architecture struc;

--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------