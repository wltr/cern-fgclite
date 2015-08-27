--_________________________________________________________________________________________________
--                                                                                                |
--                                         |The nanoFIP|                                          |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                           nanoFIP                                              |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File       :  nanofip.vhd                                                                      |
--                                                                                                |
-- Description:  nanoFIP is an FPGA component acting as a client node/ agent in the communication |
-- over WorldFIP fieldbus. nanoFIP is designed to be radiation tolerant by using different        |
-- Single Event Upset mitigation techniques such as Triple Module Redundancy, fail-safe state     |
-- machines and several reset possibilities. The nanoFIP design is to be implemented in an Actel  |
-- ProASIC3 Flash family FPGA (130nm CMOS technology) that offers an inherent resistance to       |
-- radiation: it is immune to Single Event Latchups for the LHC environment, it has high tolerance|
-- to Total Ionizing Dose effects (>300 Gy) and its configuration memory is not disturbed by SEUs.|
-- nanoFIP is used in conjunction with a FIELDRIVE chip and FIELDTR insulating transformer,       |
-- both available from the company ALSTOM.                                                        |
--                                                                                                |
--  __________________________________________________________________                            |
-- |                                                                  |                           |
-- |                Field devices, Radioactive environment            |     Radiation free zone   |
-- |  _____________         _____________            _____________    |       _______________     |
-- | |             |       |             |          |             |   |      |               |    |
-- | |  user logic |       |  user logic |          |  user logic |   |      |               |    |
-- | |_____________|       |_____________|          |_____________|   |      |               |    |
-- |  ______|______         ______|______            ______|______    |      |               |    |
-- | |             |       |             |          |             |   |      | BUS ARBITRER  |    |
-- | |   nanoFIP   |       |   nanoFIP   |  . . .   |   nanoFIP   |   |      |               |    |
-- | |_____________|       |_____________|          |_____________|   |      |               |    |
-- |   _____|_____           _____|_____              _____|_____     |      |               |    |
-- |  |_FIELDRIVE_|         |_FIELDRIVE_|            |_FIELDRIVE_|    |      |               |    |
-- |   _____|_____           _____|_____              _____|_____     |      |               |    |
-- |  |__FIELDTR__|         |__FIELDTR__|            |__FIELDTR__|    |      |_______________|    |
-- |        |                     |                        |          |             |             |
-- |________|_____________________|________________________|__________|             |             |
--          |                     |                        |                        |             |
--   _______^_____________________^________________________^________________________^____________ |
--  0____________________________________WorldFIP FIELDBUS______________________________________O |
--                                                                                                |
--                                   Figure 1: Fieldbus layout                                    |
--                                                                                                |
-- In the WorldFIP protocol, the access to the bus is controlled by a central Bus Arbitrer (BA)   |
-- that grants bus access to the different agents following the sequence in a pre-configured      |
-- table. The BA is broadcasting ID_DAT frames to all the agents connected to the same network    |
-- segment requesting for a particular variable. Figure 2 shows the structure of an ID_DAT frame: |
--                   ___________ ______  _______ ______  ___________ _______                      |
--                  |____FSS____|_CTRL_||__Var__|_SUBS_||____FCS____|__FES__|                     |
--                                                                                                |
--                               Figure 2: ID_DAT frame structure                                 |
--                                                                                                |
-- nanoFIP agents can handle the following set of variables:                                      |
--   o ID_DAT Var_Subs = 14_xy: for the presence variable                                         |
--   o ID_DAT Var_Subs = 10_xy: for the identification variable                                   |
--   o ID_DAT Var_Subs = 05_xy: for the consumed variable of any length up to 124 bytes           |
--   o ID_DAT Var_Subs = aa_xy: for the JTAG consumed variable of any length up to 124 bytes      |
--   o ID_DAT Var_Subs = 91_..: for the broadcast consumed variable of any length up to 124 bytes |
--   o ID_DAT Var_Subs = 06_xy: for the produced variable of a user-settable length (P3_LGTH)     |
--   o ID_DAT Var_Subs = ab_xy: for the JTAG produced variable of a predefined length of 1 byte   |
--   o ID_DAT Var_Subs = E0_..: for the broadcast consumed reset variable                         |
--                                                                                                |
-- After a 14_xy, a 10_xy, a 06_xy or a ab_xy ID_DAT, if nanoFIP's address (SUBS) is xy, nanoFIP  |
-- will respond with an RP_DAT frame, containing the variable requested. Figure 3 shows the       |
-- structure of a RP_DAT frame:                                                                   |
--                ___________ ______  ____________________  ___________ _______                   |
--               |____FSS____|_CTRL_||_____...Data..._____||____FCS____|__FES__|                  |
--                                                                                                |
--                            Figure 3: RP_DAT frame structure                                    |
--                                                                                                |
-- After a 05_xy or an aa_xy ID_DAT, if nanoFIP's address (SUBS) is xy,                           |
-- or after a broadcast ID_DAT 91..h or E0..h, nanoFIP will receive/ "consume" the next incoming  |
-- RP_DAT frame.                                                                                  |
--                                                                                                |
-- Regarding the interface with the user logic, nanoFIP provides:                                 |
--   o data transfer over an integrated memory accessible with an 8-bit WISHBONE System-On-Chip   |
--     interconnection                                                                            |
--   o possibility of stand-alone mode with a 16 bits input bus and 16 bits output bus, without   |
--     the need to transfer data to or from the memory                                            |
--   o separate data valid outputs for the consumed (05_xy), broadcast consumed (91_..) and       |
--     produced (06_xy) variables                                                                 |
--   o JTAG master controller interfacing with the Test Access Port of the user logic FPGA        |
--                                                                                                |
-- nanoFIP provides several reset possibilities:                                                  |
--  o External reset input pin, RSTIN, activated by the user logic                                |
--  o External reset input pin, RST_I, activated by the user, that resets only the WISHBONE logic |
--  o Addressed reset by the reset broadcast consumed variable (E0..h),                           |
--    validated by station address as data                                                        |
--  o External Power On Reset input pin, RSTPON                                                   |
--                                                                                                |
-- nanoFIP also provides resets to the user and to the FIELDRIVE:                                 |
--  o Reset output available to external logic (RSTON) by the reset broadcast consumed variable   |
--    (E0..h), validated by station address as data                                               |
--  o FIELDRIVE reset output (FD_RSTN) by the reset broadcast consumed variable (E0..h),          |
--    validated by station address as data                                                        |
--                                                                                                |
-- nanoFIP's main building blocks are (Figure 4):                                                 |
--  o wf_reset_unit      : for the treatment of the reset input signals & the generation          |
--                         of the reset outputs                                                   |
--                                                                                                |
--  o wf_fd_receiver     : for the deserialization of the FIELDRIVE input and the formation       |
--                         of ID_DAT or consumed RP_DAT bytes of data                             |
--                                                                                                |
--  o wf_consumption     : for the processing, storage & validation of consumed RP_DAT frames     |
--                                                                                                |
--  o wf_fd_transmitter  : for the serialization of produced RP_DAT frames                        |
--                                                                                                |
--  o wf_production      : for the retrieval of bytes for produced RP_DAT frames                  |
--                                                                                                |
--  o wf_engine_control  : for the processing of the ID_DAT frames and the coordination of the    |
--                         wf_consumption, wf_fd_receiver, wf_production & wf_fd_transmitter units|
--                                                                                                |
--  o wf_model_constr_dec: for the decoding of the WorldFIP settings M_ID and C_ID and the        |
--                         generation of the S_ID                                                 |
--                                                                                                |
--  o wf_wb_controller   : for the handling of the "User Interface WISHBONE Slave" control        |
--                         signals                                                                |
--                                                                                                |
--  o wf_jtag_controller : for driving and monitoring the user logic TAP upon reception of JTAG   |
--                         variables (aa_xy and ab_xy).                                           |
--                                                                                                |
--           _____________      ____________________________________________________              |
--          |             |    |                   wf_WB_controller                 |             |
--          |   wf_reset  |    |____________________________________________________|             |
--          |    _unit    |     _____________                          _____________              |
--          |             |    |             |     ______________     |             |             |
--          |_____________|    |             |    |              |    |             |             |
--                             |     wf_     |    |              |    |     wf_     |             |
--           _____________     | consumption |    |              |    |  production |             |
--          |             |    |             |    |              |    |             |             |
--          |   wf_JTAG   |    |             |    |              |    |             |             |
--          | _controller |    |_____________|    |      wf_     |    |_____________|             |
--          |             |     _____________     |engine_control|     _____________              |
--          |_____________|    |             |    |              |    |             |             |
--                             |             |    |              |    |             |             |
--           _____________     |             |    |              |    |             |             |
--          |             |    |    wf_FD_   |    |              |    |   wf_FD_    |             |
--          |  wf_model_  |    |  receiver   |    |              |    | transmitter |             |
--          | constr_dec  |    |             |    |              |    |             |             |
--          |             |    |             |    |              |    |             |             |
--          |_____________|    |_____________|    |______________|    |_____________|             |
--                                                                                                |
--                                Figure 4: nanoFIP block diagram                                 |
--                                                                                                |
-- The design is based on the nanoFIP functional specification document, available at:            |
-- http://www.ohwr.org/projects/cern-fip/documents                                                |
-- Complete information about this project at: http://www.ohwr.org/projects/cern-fip              |
--                                                                                                |
--                                                                                                |
-- Authors      Erik Van der Bij      (Erik.Van.der.Bij@cern.ch)                                  |
--              Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)                             |
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)                                 |
-- Date         10/2011                                                                           |
-- Version      v0.06                                                                             |
-- Depends on   wf_reset_unit                                                                     |
--              wf_model_constr_dec                                                               |
--              wf_fd_receiver                                                                    |
--              wf_fd_transmitter                                                                 |
--              wf_consumption                                                                    |
--              wf_production                                                                     |
--              wf_engine_control                                                                 |
--              wf_wb_controller                                                                  |
--              wf_jtag_controller                                                                |
----------------                                                                                  |
-- Last changes                                                                                   |
--     30/06/2009  v0.010  EB  First version                                                      |
--     06/07/2009  v0.011  EB  Dummy blocks                                                       |
--     07/07/2009  v0.011  EB  Comments                                                           |
--     15/09/2009  v0.v2   PA                                                                     |
--     09/12/2010  v0.v3   EG  Logic removed (new unit inputs_synchronizer added)                 |
--     7/01/2011   v0.04   EG  major restructuring; only 7 units on top level                     |
--     20/01/2011  v0.05   EG  new unit wf_wb_controller(removes the or gate from top level)      |
--        06/2011  v0.06   EG  jtag_controller unit added                                         |
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
--                                  Entity declaration for nanoFIP
--=================================================================================================

entity nanofip is port(

-- MODIFIED
  nanofip_rst_o : out std_logic;

--INPUTS

  -- WorldFIP settings

  c_id_i     : in std_logic_vector (3 downto 0); -- Constructor identification settings
  m_id_i     : in std_logic_vector (3 downto 0); -- Model identification settings
  p3_lgth_i  : in std_logic_vector (2 downto 0); -- Produced variable data length
  rate_i     : in std_logic_vector (1 downto 0); -- WorldFIP bit rate
  subs_i     : in std_logic_vector (7 downto 0); -- Subscriber number coding (station address)


  --  FIELDRIVE

  fd_rxcdn_i : in std_logic;                     -- Reception activity detection, active low
  fd_rxd_i   : in std_logic;                     -- Receiver data
  fd_txer_i  : in std_logic;                     -- Transmitter error
  fd_wdgn_i  : in std_logic;                     -- Watchdog on transmitter


  --  User Interface, General signals

  nostat_i   : in std_logic;                     -- No nanoFIP status with produced data

  rstin_i    : in std_logic;                     -- Initialization control, active low
                                                 -- Resets nanoFIP & the FIELDRIVE

  rstpon_i   : in std_logic;                     -- Power On Reset, active low

  slone_i    : in std_logic;                     -- Stand-alone mode
  uclk_i     : in std_logic;                     -- 40 MHz clock


  --  User Interface, NON-WISHBONE

  var1_acc_i : in std_logic;                     -- Signals that the user logic is accessing var 1
  var2_acc_i : in std_logic;                     -- Signals that the user logic is accessing var 2
  var3_acc_i : in std_logic;                     -- Signals that the user logic is accessing var 3


  --  User Interface, WISHBONE Slave

  wclk_i     : in std_logic;                     -- WISHBONE clock; may be independent of uclk
  adr_i      : in std_logic_vector (9 downto 0); -- WISHBONE address
  cyc_i      : in std_logic;                     -- WISHBONE cycle

  dat_i      : in std_logic_vector (15 downto 0);-- DAT_I(7 downto 0) : WISHBONE data in, memory mode
                                                 -- DAT_I(15 downto 0): data in, stand-alone mode

  rst_i      : in std_logic;                     -- WISHBONE reset
                                                 -- Does not reset other internal logic

  stb_i      : in std_logic;                     -- WISHBONE strobe
  we_i       : in std_logic;                     -- WISHBONE write enable


  --  User Interface, JTAG Controller

  jc_tdo_i   : in std_logic;                     -- JTAG Test Data Out; input from the target TAP



-- OUTPUTS

  -- WorldFIP settings
-- MODIFIED
--s_id_o     : out std_logic_vector (1 downto 0);-- Identification selection


  --  FIELDRIVE

  fd_rstn_o  : out std_logic;                    -- Initialization control, active low
  fd_txck_o  : out std_logic;                    -- Line driver half bit clock
  fd_txd_o   : out std_logic;                    -- Transmitter data
  fd_txena_o : out std_logic;                    -- Transmitter enable


  --  User Interface, General signals

  rston_o    : out std_logic;                    -- Reset output, active low


  --  User Interface, NON-WISHBONE

  r_fcser_o  : out std_logic;                    -- nanoFIP status byte, bit 5
  r_tler_o   : out std_logic;                    -- nanoFIP status byte, bit 4
  u_cacer_o  : out std_logic;                    -- nanoFIP status byte, bit 2
  u_pacer_o  : out std_logic;                    -- nanoFIP status byte, bit 3

  var1_rdy_o : out std_logic;                    -- Signals new data received & can safely be read
  var2_rdy_o : out std_logic;                    -- Signals new data received & can safely be read
  var3_rdy_o : out std_logic;                    -- Signals that the var 3 can safely be written


  --  User Interface, WISHBONE Slave
-- MODIFIED was (15 downto 0)
  dat_o      : out std_logic_vector (7 downto 0);-- DAT_O(7 downto 0) : WISHBONE data out, memory mode
                                                  -- DAT_O(15 downto 0): data out, stand-alone mode

  ack_o      : out std_logic;                     -- WISHBONE acknowledge


  --  User Interface, JTAG Controller

  jc_tms_o   : out std_logic;                     -- Drives the JTAG Test Mode Select of the target TAP
  jc_tdi_o   : out std_logic;                     -- Drives the JTAG Test Data In of the target TAP
  jc_tck_o   : out std_logic);                    -- Drives the JTAG Test Clock of the target TAP

end entity nanofip;


--=================================================================================================
--                                   architecture declaration
--=================================================================================================

architecture struc of nanofip is

  -- wf_reset_unit outputs
  signal s_nfip_intern_rst, s_wb_rst                              : std_logic;
  -- wf_consumption outputs
  signal s_var1_rdy, s_var2_rdy, s_var3_rdy                       : std_logic;
  signal s_assert_RSTON_p, s_reset_nFIP_and_FD_p                  : std_logic;
  signal s_nfip_status_r_tler                                     : std_logic;
  signal s_jc_start_p                                             : std_logic;
  signal s_jc_mem_data                                            : std_logic_vector (7 downto 0);
  -- wf_fd_receiver outputs
  signal s_rx_fss_received_p, s_rx_fss_crc_fes_ok_p               : std_logic;
  signal s_rx_crc_wrong_p, s_rx_byte_ready_p                      : std_logic;
  signal s_rx_byte                                                : std_logic_vector (7 downto 0);
  -- wf_production outputs
  signal  s_byte_to_tx                                            : std_logic_vector (7 downto 0);
  -- wf_fd_transmitter outputs
  signal s_tx_last_byte_p, s_tx_completed_p                       : std_logic;
  -- wf_engine_control outputs
  signal s_tx_start_p, s_tx_request_byte_p                        : std_logic;
  signal s_byte_request_accepted_p, s_cons_bytes_excess, s_rx_rst : std_logic;
  signal s_var                                                    : t_var;
  signal s_prod_data_lgth, s_prod_byte_index, s_cons_byte_index   : std_logic_vector (7 downto 0);
  -- wf_model_constr_dec outputs
  signal s_model_id_dec, s_constr_id_dec                          : std_logic_vector (7 downto 0);
  -- wf_wb_controller outputs
  signal s_wb_ack_prod                                            : std_logic;
  -- wf_model_constr_dec outputs
  signal s_jc_mem_adr_rd                                          : std_logic_vector (8 downto 0);
  signal s_jc_tdo_byte                                            : std_logic_vector (7 downto 0);


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
begin

-- MODIFIED
  nanofip_rst_o <= s_nfip_intern_rst;

---------------------------------------------------------------------------------------------------
--                                         wf_reset_unit                                         --
---------------------------------------------------------------------------------------------------

  reset_unit : wf_reset_unit
    port map(
      uclk_i              => uclk_i,
      wb_clk_i            => wclk_i,
      rstin_a_i           => rstin_i,
      rstpon_a_i          => rstpon_i,
      rate_i              => rate_i,
      rst_i               => rst_i,
      rst_nFIP_and_FD_p_i => s_reset_nFIP_and_FD_p,
      assert_RSTON_p_i    => s_assert_RSTON_p,
  -------------------------------------------------------------
      nFIP_rst_o          => s_nfip_intern_rst,
      wb_rst_o            => s_wb_rst,
      rston_o             => rston_o,
      fd_rstn_o           => fd_rstn_o);
  -------------------------------------------------------------



---------------------------------------------------------------------------------------------------
--                                         wf_consumption                                        --
---------------------------------------------------------------------------------------------------

  Consumption: wf_consumption
  port map(
    uclk_i                 => uclk_i,
    slone_i                => slone_i,
    nfip_rst_i             => s_nfip_intern_rst,
    subs_i                 => subs_i,
    rx_byte_i              => s_rx_byte,
    rx_byte_ready_p_i      => s_rx_byte_ready_p,
    rx_fss_crc_fes_ok_p_i  => s_rx_fss_crc_fes_ok_p,
    rx_crc_wrong_p_i       => s_rx_crc_wrong_p,
    wb_clk_i               => wclk_i,
    wb_adr_i               => adr_i (8 downto 0),
    cons_bytes_excess_i    => s_cons_bytes_excess,
    var_i                  => s_var,
    byte_index_i           => s_cons_byte_index,
    jc_mem_adr_rd_i        => s_jc_mem_adr_rd,
  -------------------------------------------------------------
    var1_rdy_o             => s_var1_rdy,
    var2_rdy_o             => s_var2_rdy,
    jc_start_p_o           => s_jc_start_p,
    data_o                 => dat_o,
    nfip_status_r_tler_p_o => s_nfip_status_r_tler,
    assert_rston_p_o       => s_assert_RSTON_p,
    rst_nfip_and_fd_p_o    => s_reset_nFIP_and_FD_p,
    jc_mem_data_o          => s_jc_mem_data);
  -------------------------------------------------------------



---------------------------------------------------------------------------------------------------
--                                         wf_fd_receiver                                        --
---------------------------------------------------------------------------------------------------

  FIELDRIVE_Receiver: wf_fd_receiver
  port map(
    uclk_i                => uclk_i,
    rate_i                => rate_i,
    fd_rxd_a_i            => fd_rxd_i,
    nfip_rst_i            => s_nfip_intern_rst,
    rx_rst_i              => s_rx_rst,
  -------------------------------------------------------------
    rx_byte_o             => s_rx_byte,
    rx_byte_ready_p_o     => s_rx_byte_ready_p,
    rx_fss_crc_fes_ok_p_o => s_rx_fss_crc_fes_ok_p,
    rx_fss_received_p_o   => s_rx_fss_received_p,
    rx_crc_wrong_p_o      => s_rx_crc_wrong_p);
  -------------------------------------------------------------



---------------------------------------------------------------------------------------------------
--                                         wf_production                                         --
---------------------------------------------------------------------------------------------------

  Production: wf_production
  port map(
    uclk_i                  => uclk_i,
    slone_i                 => slone_i,
    nostat_i                => nostat_i,
    nfip_rst_i              => s_nfip_intern_rst,
    wb_clk_i                => wclk_i,
    wb_data_i               => dat_i(7 downto 0),
    wb_adr_i                => adr_i(8 downto 0),
    wb_ack_prod_p_i         => s_wb_ack_prod,
    slone_data_i            => dat_i,
    var1_acc_a_i            => var1_acc_i,
    var2_acc_a_i            => var2_acc_i,
    var3_acc_a_i            => var3_acc_i,
    fd_txer_a_i             => fd_txer_i,
    fd_wdgn_a_i             => fd_wdgn_i,
    var_i                   => s_var,
    data_lgth_i             => s_prod_data_lgth,
    byte_index_i            => s_prod_byte_index,
    byte_request_accept_p_i => s_byte_request_accepted_p,
    nfip_status_r_tler_p_i  => s_nfip_status_r_tler,
    nfip_status_r_fcser_p_i => s_rx_crc_wrong_p,
    var1_rdy_i              => s_var1_rdy,
    var2_rdy_i              => s_var2_rdy,
    model_id_dec_i          => s_model_id_dec,
    constr_id_dec_i         => s_constr_id_dec,
    jc_tdo_byte_i           => s_jc_tdo_byte,
  -------------------------------------------------------------
    byte_o                  => s_byte_to_tx,
    u_cacer_o               => u_cacer_o,
    u_pacer_o               => u_pacer_o,
    r_tler_o                => r_tler_o,
    r_fcser_o               => r_fcser_o,
    var3_rdy_o              => s_var3_rdy);
  -------------------------------------------------------------



---------------------------------------------------------------------------------------------------
--                                       wf_fd_transmitter                                       --
---------------------------------------------------------------------------------------------------

  FIELDRIVE_Transmitter: wf_fd_transmitter
  port map(
    uclk_i                     => uclk_i,
    rate_i                     => rate_i,
    nfip_rst_i                 => s_nfip_intern_rst,
    tx_byte_i                  => s_byte_to_tx,
    tx_byte_request_accept_p_i => s_byte_request_accepted_p,
    tx_last_data_byte_p_i      => s_tx_last_byte_p,
    tx_start_p_i               => s_tx_start_p,
  -------------------------------------------------------------
    tx_byte_request_p_o        => s_tx_request_byte_p,
    tx_completed_p_o           => s_tx_completed_p,
    tx_data_o                  => fd_txd_o,
    tx_enable_o                => fd_txena_o,
    tx_clk_o                   => fd_txck_o);
  -------------------------------------------------------------



---------------------------------------------------------------------------------------------------
--                                      wf_jtag_controller                                       --
---------------------------------------------------------------------------------------------------

  JTAG_controller: wf_jtag_controller
  port map(
    uclk_i          => uclk_i,
    nfip_rst_i      => s_nfip_intern_rst,
    jc_mem_data_i   => s_jc_mem_data,
    jc_start_p_i    => s_jc_start_p,
    jc_tdo_i        => jc_tdo_i,
  -----------------------------------------------------------------
    jc_tms_o        => jc_tms_o,
    jc_tdi_o        => jc_tdi_o,
    jc_tck_o        => jc_tck_o,
    jc_tdo_byte_o   => s_jc_tdo_byte,
    jc_mem_adr_rd_o => s_jc_mem_adr_rd);
  -----------------------------------------------------------------



---------------------------------------------------------------------------------------------------
--                                       wf_engine_control                                       --
---------------------------------------------------------------------------------------------------

  engine_control : wf_engine_control
  port map(
    uclk_i                      => uclk_i,
    nfip_rst_i                  => s_nfip_intern_rst,
    tx_byte_request_p_i         => s_tx_request_byte_p,
    tx_completed_p_i            => s_tx_completed_p,
    rx_fss_received_p_i         => s_rx_fss_received_p,
    rx_byte_i                   => s_rx_byte,
    rx_byte_ready_p_i           => s_rx_byte_ready_p,
    rx_fss_crc_fes_ok_p_i       => s_rx_fss_crc_fes_ok_p,
    rx_crc_wrong_p_i            => s_rx_crc_wrong_p,
    rate_i                      => rate_i,
    subs_i                      => subs_i,
    p3_lgth_i                   => p3_lgth_i,
    slone_i                     => slone_i,
    nostat_i                    => nostat_i,
  -------------------------------------------------------------
    var_o                       => s_var,
    tx_start_p_o                => s_tx_start_p,
    tx_byte_request_accept_p_o  => s_byte_request_accepted_p,
    tx_last_data_byte_p_o       => s_tx_last_byte_p,
    prod_byte_index_o           => s_prod_byte_index,
    cons_byte_index_o           => s_cons_byte_index,
    prod_data_lgth_o            => s_prod_data_lgth,
    cons_bytes_excess_o         => s_cons_bytes_excess,
    rx_rst_o                    => s_rx_rst);
  -------------------------------------------------------------

    var1_rdy_o <= s_var1_rdy;
    var2_rdy_o <= s_var2_rdy;
    var3_rdy_o <= s_var3_rdy;



---------------------------------------------------------------------------------------------------
--                                    wf_model_constr_decoder                                    --
---------------------------------------------------------------------------------------------------

  model_constr_decoder : wf_model_constr_decoder
  port map(
    uclk_i          => uclk_i,
    nfip_rst_i      => s_nfip_intern_rst,
    model_id_i      => m_id_i,
    constr_id_i     => c_id_i,
  -------------------------------------------------------------
-- MODIFIED
--  s_id_o          => s_id_o,
    model_id_dec_o  => s_model_id_dec,
    constr_id_dec_o => s_constr_id_dec);
  -------------------------------------------------------------



---------------------------------------------------------------------------------------------------
--                                      wf_wb_controller                                         --
---------------------------------------------------------------------------------------------------

  WISHBONE_controller: wf_wb_controller
  port map(
    wb_clk_i        => wclk_i,
    wb_rst_i        => s_wb_rst,
    wb_stb_i        => stb_i,
    wb_cyc_i        => cyc_i,
    wb_we_i         => we_i,
    wb_adr_id_i     => adr_i (9 downto 7),
  -------------------------------------------------------------
    wb_ack_prod_p_o => s_wb_ack_prod,
    wb_ack_p_o      => ack_o);
  -------------------------------------------------------------


end architecture struc;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------
