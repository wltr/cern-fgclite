--_________________________________________________________________________________________________
--                                                                                                |
--                                         |The nanoFIP|                                          |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                         wf_fd_transmitter                                      |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         wf_fd_transmitter.vhd                                                             |
--                                                                                                |
-- Description  The unit groups the main actions that regard FIELDRIVE data transmission.         |
--              It instantiates the units:                                                        |
--                                                                                                |
--              o wf_tx_serializer: that receives bytes from the wf_production, encodes them      |
--                                  (Manchester 2), adds the FSS, FCS & FES fields and puts one   |
--                                  by one bits to the FIELDRIVE output FD_TXD, following the     |
--                                  synchronization signals from the wf_tx_osc unit.              |
--                                  Also generates the nanoFIP output FD_TXENA.                   |
--                                                                                                |
--              o wf_tx_osc       : that generates the nanoFIP FIELDRIVE output FD_TXCK           |
--                                  and the array of pulses tx_sched_p_buff, used for the         |
--                                  synchronization of the wf_tx_serializer's actions.            |
--                                                                                                |
--                                            _____________________________________               |
--                                           |                                     |              |
--                                           |           wf_Production             |              |
--                                           |_____________________________________|              |
--                                                             \/                                 |
--                      ___________________________________________________________               |
--                     |                      wf_fd_transmitter                    |              |
--                     |                                                           |              |
--                     |   _____________      __________________________________   |              |
--                     |  |             |    |                                  |  |              |
--                     |  |  wf_tx_osc  |  > |          wf_tx_serializer        |  |              |
--                     |  |             |    |                                  |  |              |
--                     |  |_____________|    |__________________________________|  |              |
--                     |___________________________________________________________|              |
--                                                  \/                                            |
--                  ___________________________________________________________________           |
--                0_____________________________FIELDBUS______________________________O           |
--                                                                                                |
--                                                                                                |
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)                             |
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)                                 |
-- Date         11/01/2011                                                                        |
-- Version      v0.01                                                                             |
-- Depends on   wf_reset_unit                                                                     |
--              wf_production                                                                     |
--              wf_engine_control                                                                 |
----------------                                                                                  |
-- Last changes                                                                                   |
--     01/2011  EG  v0.01  first version                                                          |
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
--                           Entity declaration for wf_fd_transmitter
--=================================================================================================

entity wf_fd_transmitter is port(
  -- INPUTS
    -- nanoFIP User Interface, General signal
    uclk_i                     : in std_logic;  -- 40 MHz clock

    -- nanoFIP WorldFIP Settings
    rate_i                     : in std_logic_vector (1 downto 0); -- WorldFIP bit rate

    -- Signal from the wf_reset_unit
    nfip_rst_i                 : in std_logic;  -- nanoFIP internal reset

    -- Signals from the wf_production unit
    tx_byte_i                  : in std_logic_vector (7 downto 0); -- byte to be delivered

    -- Signals from the wf_engine_control
    tx_start_p_i               : in std_logic;  -- indication for the start of the production
    tx_byte_request_accept_p_i : in std_logic;  -- indication that a byte is ready to be delivered
    tx_last_data_byte_p_i      : in std_logic;  -- indication of he last data byte
                                                -- (CRC & FES not included)


  -- OUTPUTS
    -- Signal to the wf_engine_control
    tx_byte_request_p_o        : out std_logic; -- request for a new byte to be transmitted; pulse
                                                -- at the end of the transmission of a previous byte
    tx_completed_p_o           : out std_logic; -- pulse upon termination of a transmission
                                                -- (CRC & FES included)

    -- nanoFIP FIELDRIVE outputs
    tx_data_o                  : out std_logic; -- transmitter data
    tx_enable_o                : out std_logic; -- transmitter enable
    tx_clk_o                   : out std_logic);-- line driver half bit clock

end entity wf_fd_transmitter;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture struc of wf_fd_transmitter is

  signal s_tx_clk_p_buff : std_logic_vector (c_TX_SCHED_BUFF_LGTH-1 downto 0);
  signal s_tx_osc_rst_p  : std_logic;


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--                                           Oscillator                                          --
---------------------------------------------------------------------------------------------------

  tx_oscillator: wf_tx_osc
  port map(
    uclk_i                  => uclk_i,
    rate_i                  => rate_i,
    nfip_rst_i              => nfip_rst_i,
    tx_osc_rst_p_i          => s_tx_osc_rst_p,
   -----------------------------------------------
    tx_clk_o                => tx_clk_o,
    tx_sched_p_buff_o       => s_tx_clk_p_buff);
   -----------------------------------------------



---------------------------------------------------------------------------------------------------
--                                           Serializer                                          --
---------------------------------------------------------------------------------------------------

  tx_serializer: wf_tx_serializer
  port map(
    uclk_i                  => uclk_i,
    nfip_rst_i              => nfip_rst_i,
    tx_start_p_i            => tx_start_p_i,
    byte_request_accept_p_i => tx_byte_request_accept_p_i,
    byte_i                  => tx_byte_i,
    last_byte_p_i           => tx_last_data_byte_p_i,
    tx_sched_p_buff_i       => s_tx_clk_p_buff,
   -----------------------------------------------
    tx_byte_request_p_o     => tx_byte_request_p_o,
    tx_completed_p_o        => tx_completed_p_o,
    tx_data_o               => tx_data_o,
    tx_osc_rst_p_o          => s_tx_osc_rst_p,
    tx_enable_o             => tx_enable_o );
   -----------------------------------------------


end architecture struc;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------