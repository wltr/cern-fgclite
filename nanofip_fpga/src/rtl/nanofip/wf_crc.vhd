--_________________________________________________________________________________________________
--                                                                                                |
--                                         |The nanoFIP|                                          |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                             wf_crc                                             |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         wf_crc.vhd                                                                        |
--                                                                                                |
-- Description  The unit creates the modules for:                                                 |
--                o the generation of the CRC of serial data,                                     |
--                o the verification of an incoming CRC syndrome.                                 |
--              The unit is instantiated in both the wf_fd_transmitter, for the generation of the |
--              FCS field of produced RP_DAT frames, and the wf_fd_receiver for the validation of |
--              of an incoming ID_DAT or consumed RP_DAT frame.                                   |
--                                                                                                |
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)                             |
-- Date         23/02/2011                                                                        |
-- Version      v0.04                                                                             |
-- Depends on   wf_reset_unit                                                                     |
--              wf_rx_deserializer                                                                |
--              wf_tx_serializer                                                                  |
----------------                                                                                  |
-- Last changes                                                                                   |
--     07/08/2009  v0.02  PAS Entity Ports added, start of architecture content                   |
--        08/2010  v0.03  EG  Data_FCS_select and crc_ready_p_o signals removed,                  |
--                            variable v_q_check_mask replaced with a signal,                     |
--                            code cleaned-up+commented                                           |
--        02/2011  v0.04  EG  s_q_check_mask was not in Syndrome_Verification sensitivity list!   |
--                            xor replaced with if(Syndrome_Verification); processes rewritten;   |
--                            delay on data_bit_ready_p_i removed.                                |
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
--                                 Entity declaration for wf_crc
--=================================================================================================
entity wf_crc is port(
  -- INPUTS
    -- nanoFIP User Interface, General signals
    uclk_i             : in std_logic;              -- 40 MHz clock

    -- Signal from the wf_reset_unit
    nfip_rst_i         : in std_logic;              -- nanoFIP internal reset

    -- Signals from the wf_rx_deserializer/ wf_tx_serializer units
    data_bit_i         : in std_logic;              -- incoming data bit stream
    data_bit_ready_p_i : in std_logic;              -- indicates the sampling moment of data_bit_i
    start_crc_p_i      : in std_logic;              -- beginning of the CRC calculation


  -- OUTPUTS
    -- Signal to the wf_rx_deserializer unit
    crc_ok_p_o         : out std_logic;             -- signals a correct received CRC syndrome

    -- Signal to the wf_tx_serializer unit
    crc_o              : out  std_logic_vector (c_CRC_POLY_LGTH-1 downto 0)); -- calculated CRC

end entity wf_crc;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of wf_crc is

  signal s_q, s_q_nx : std_logic_vector (c_CRC_POLY_LGTH - 1 downto 0);


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin

---------------------------------------------------------------------------------------------------
--                                         CRC Calculation                                       --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- The Gen_16_bit_Register_and_Interconnections generator, follows the scheme of figure A.1
-- of the Annex A 61158-4-7 IEC:2007 and constructs a register of 16 master-slave flip-flops which
-- are interconnected as a linear feedback shift register.

  Generate_16_bit_Register_and_Interconnections:

    s_q_nx(0)   <= data_bit_i xor s_q(s_q'left);

    G: for I in 1 to c_CRC_GENER_POLY'left generate
      s_q_nx(I) <= s_q(I-1) xor (c_CRC_GENER_POLY(I) and (data_bit_i xor s_q(s_q'left)));
    end generate;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Synchronous process CRC_calculation: the process "moves" the shift register described
-- above, for the calculation of the CRC.

  CRC_calculation: process (uclk_i)
  begin
    if rising_edge (uclk_i) then

      if nfip_rst_i = '1' then
        s_q     <= (others => '0');

      else

        if start_crc_p_i = '1' then
          s_q   <= (others => '1');          -- register initialization
                                             -- (initially preset, according to the Annex)

        elsif data_bit_ready_p_i = '1' then  -- new bit to be considered for the CRC calculation
          s_q   <= s_q_nx;                   -- data propagation

        end if;
      end if;
    end if;
  end process;

  --  --  --  --  --
  crc_o         <= not s_q;



---------------------------------------------------------------------------------------------------
--                                       CRC Verification                                        --
---------------------------------------------------------------------------------------------------

-- During reception, the CRC is being calculated as data is arriving (same as in the transmission)
-- and at the same time it is being compared to the predefined c_CRC_VERIF_POLY. When the CRC
-- calculated from the received data matches the c_CRC_VERIF_POLY, it is implied that a correct CRC
-- word has been received for the preceded data and the signal crc_ok_p_o gives a 1 uclk-wide pulse.

  crc_ok_p_o <= data_bit_ready_p_i when s_q = not c_CRC_VERIF_POLY else '0';



end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------