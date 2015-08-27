--_________________________________________________________________________________________________
--                                                                                                |
--                                         |The nanoFIP|                                          |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                         wf_production                                          |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         wf_production.vhd                                                                 |
--                                                                                                |
-- Description  The unit groups the main actions that regard data production.                     |
--              It instantiates the units:                                                        |
--                                                                                                |
--              o wf_prod_bytes_retriever: that retrieves                                         |
--                                         o user-data bytes from :                               |
--                                           - the Produced RAM or                                |
--                                           - or the"nanoFIP User Interface,NON-WISHBONE"bus DAT_I
--                                           - or the wf_jtag_controller unit                     |
--                                         o PDU,CTRL bytes : from the WF_PACKAGE                 |
--                                         o MPS,nFIP status: from the wf_status_bytes_gen        |
--                                         o LGTH byte      : from the wf_prod_data_lgth_calc     |
--                                        and following the signals from the external unit,       |
--                                        wf_engine_control,forwards them to the wf_fd_transmitter|
--                                                                                                |
--               o wf_status_bytes_gen   : that receives information from the wf_consumption unit,|
--                                         the "FIELDRIVE" & "User Interface,NON-WISHBONE" inputs |
--                                         and outputs, and generates the nanoFIP and the MPS     |
--                                         status bytes                                           |
--                                                                                                |
--               o wf_prod_permit        : that signals the user that user-data bytes can safely  |
--                                         be written to the memory or the DAT_I bus              |
--                                                                                                |
--                      ___________________________________________________________               |
--                     |                       wf_production                       |              |
--                     |                                                           |              |
--                     |   _________________________________                       |              |
--                     |  |                                 |                      |              |
--                     |  |          wf_prod_permit         |                      |              |
--                     |  |_________________________________|                      |              |
--                     |                                                           |              |
--                     |   _________________________________     ________________  |              |
--                     |  |                                 |   |                | |              |
--                     |  |      wf_prod_bytes_retriever    | < | wf_status_bytes| |              |
--                     |  |                                 |   |      _gen      | |              |
--                     |  |_________________________________|   |________________| |              |
--                     |___________________________________________________________|              |
--                                                  \/                                            |
--                      ___________________________________________________________               |
--                     |                                                           |              |
--                     |                     wf_fd_transmitter                     |              |
--                     |___________________________________________________________|              |
--                                                  \/                                            |
--                   ___________________________________________________________________          |
--                 0_____________________________FIELDBUS______________________________O          |
--                                                                                                |
--              Note: In the entity declaration of this unit, below each input signal, we mark    |
--              which of the instantiated units needs it.                                         |
--                                                                                                |
--                                                                                                |
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)                             |
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)                                 |
-- Date         6/2011                                                                            |
-- Version      v0.03                                                                             |
-- Depends on   wf_reset_unit                                                                     |
--              wf_consumption                                                                    |
--              wf_engine_control                                                                 |
--              wf_wb_controller                                                                  |
--              wf_model_constr_decoder                                                           |
--              wf_jtag_controller                                                                |
----------------                                                                                  |
-- Last changes                                                                                   |
--     2/2011  v0.02  EG  wf_serializer removed from this unit                                    |
--     6/2011  v0.03  EG  added wf_jtag_controller+handling                                       |
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
--                           Entity declaration for wf_production
--=================================================================================================

entity wf_production is port(
  -- INPUTS
	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP User Interface, General signals

      uclk_i                  : in std_logic;
      -- used by: all the units

      slone_i                 : in std_logic;
      -- used by: wf_prod_bytes_retriever for the selection of data bytes from the RAM or the DAT_I
      -- used by: wf_status_bytes_gen because the MPS status is different in memory & stand-alone

      nostat_i                : in std_logic;
      -- used by: wf_prod_bytes_retriever for the delivery or not of the nanoFIP status byte


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signal from the wf_reset_unit unit

      nfip_rst_i              : in std_logic;
       -- used by: all the units


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP User Interface, WISHBONE Slave

      wb_clk_i                : in std_logic;
      wb_adr_i                : in std_logic_vector (8 downto 0);
      wb_data_i               : in std_logic_vector (7 downto 0);
       -- used by: wf_prod_bytes_retriever for the managment of the Production RAM


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signal from the wf_wb_controller

      wb_ack_prod_p_i         : in std_logic;
       -- used by: wf_prod_bytes_retriever for the latching of the wb_data_i


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP User Interface, NON-WISHBONE

      slone_data_i            : in std_logic_vector (15 downto 0);
      -- used by: wf_prod_bytes_retriever for the bytes retrieval in stand-alone mode

      var1_acc_a_i            : in std_logic;
      var2_acc_a_i            : in std_logic;
      var3_acc_a_i            : in std_logic;
      -- used by: wf_status_bytes_gen for the nanoFIP status byte, bits 2, 3


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP FIELDRIVE

      fd_txer_a_i             : in  std_logic;
      fd_wdgn_a_i             : in  std_logic;
      -- used by: wf_status_bytes_gen for the nanoFIP status byte, bits 6, 7


 	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signals from the wf_jtag_controller unit
      jc_tdo_byte_i           : in std_logic_vector (7 downto 0);
      -- used by: wf_prod_bytes_retriever for the bytes retrieval of a var_5


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signals from the wf_engine_control

      byte_index_i            : in std_logic_vector (7 downto 0);
      data_lgth_i             : in std_logic_vector (7 downto 0);
      byte_request_accept_p_i : in std_logic;
      var_i                   : in t_var; -- also used by: wf_prod_permit for the VAR3_RDY generation
      -- used by: wf_prod_bytes_retriever for the definition of the bytes to be delivered


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signals from the wf_consumption

      var1_rdy_i              : in std_logic;
      var2_rdy_i              : in std_logic;
      nfip_status_r_fcser_p_i : in std_logic;
      nfip_status_r_tler_p_i  : in std_logic;
      -- used by: wf_status_bytes_gen for the generation of the nanoFIP status byte, bits 2, 4, 5


 	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signals from the wf_model_constr_decoder unit

      constr_id_dec_i         : in  std_logic_vector (7 downto 0);
      model_id_dec_i          : in  std_logic_vector (7 downto 0);
      -- used by: wf_prod_bytes_retriever for the production of a var_identif



  -------------------------------------------------------------------------------------------------
  -- OUTPUTS

    -- Signal to the wf_FD_transmitter
      byte_o                  : out std_logic_vector (7 downto 0);

    -- nanoFIP User Interface, NON-WISHBONE outputs
      u_cacer_o               : out std_logic;
      r_fcser_o               : out std_logic;
      u_pacer_o               : out std_logic;
      r_tler_o                : out std_logic;
      var3_rdy_o              : out std_logic);

end entity wf_production;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture struc of wf_production is

  signal s_var3_rdy           : std_logic;
  signal s_rst_status_bytes_p : std_logic;
  signal s_nfip_stat, s_mps   : std_logic_vector (7 downto 0);


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--                                       Production Permit                                       --
---------------------------------------------------------------------------------------------------

-- Instantiation of the wf_prod_permit unit

  production_VAR3_RDY_generation: wf_prod_permit
  port map(
    uclk_i                  => uclk_i,
    nfip_rst_i              => nfip_rst_i,
    var_i                   => var_i,
   -----------------------------------------------
    var3_rdy_o              => s_var3_rdy);
   -----------------------------------------------



---------------------------------------------------------------------------------------------------
--                                          Bytes retrieval                                      --
---------------------------------------------------------------------------------------------------

-- Instantiation of the wf_prod_bytes_retriever unit

  production_bytes_retriever : wf_prod_bytes_retriever
  port map(
    uclk_i                  => uclk_i,
    model_id_dec_i          => model_id_dec_i,
    constr_id_dec_i         => constr_id_dec_i,
    slone_i                 => slone_i,
    nostat_i                => nostat_i,
    nfip_rst_i              => nfip_rst_i,
    wb_clk_i                => wb_clk_i,
    wb_adr_i                => wb_adr_i,
    wb_ack_prod_p_i         => wb_ack_prod_p_i,
    nFIP_status_byte_i      => s_nfip_stat,
    mps_status_byte_i       => s_mps,
    var_i                   => var_i,
    byte_index_i            => byte_index_i,
    byte_being_sent_p_i     => byte_request_accept_p_i,
    data_lgth_i             => data_lgth_i,
    wb_data_i               => wb_data_i,
    slone_data_i            => slone_data_i,
    var3_rdy_i              => s_var3_rdy,
    jc_tdo_byte_i           => jc_tdo_byte_i,
   -----------------------------------------------
    rst_status_bytes_p_o    => s_rst_status_bytes_p,
    byte_o                  => byte_o);
   -----------------------------------------------



---------------------------------------------------------------------------------------------------
--                                    Status Byte Generation                                     --
---------------------------------------------------------------------------------------------------

-- Instantiation of the wf_status_bytes_gen unit

  production_status_bytes_generator : wf_status_bytes_gen
  port map(
    uclk_i                  => uclk_i,
    nfip_rst_i              => nfip_rst_i,
    slone_i                 => slone_i,
    fd_wdgn_a_i             => fd_wdgn_a_i,
    fd_txer_a_i             => fd_txer_a_i,
    nfip_status_r_fcser_p_i => nfip_status_r_fcser_p_i,
    var1_rdy_i              => var1_rdy_i,
    var2_rdy_i              => var2_rdy_i,
    var3_rdy_i              => s_var3_rdy,
    var1_acc_a_i            => var1_acc_a_i,
    var2_acc_a_i            => var2_acc_a_i,
    var3_acc_a_i            => var3_acc_a_i,
    nfip_status_r_tler_p_i  => nfip_status_r_tler_p_i,
    rst_status_bytes_p_i    => s_rst_status_bytes_p,
    var_i                   => var_i,
   -----------------------------------------------
    u_cacer_o               => u_cacer_o,
    u_pacer_o               => u_pacer_o,
    r_tler_o                => r_tler_o,
    r_fcser_o               => r_fcser_o,
    nFIP_status_byte_o      => s_nfip_stat,
    mps_status_byte_o       => s_mps);
   -----------------------------------------------

    var3_rdy_o              <= s_var3_rdy;



end architecture struc;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------