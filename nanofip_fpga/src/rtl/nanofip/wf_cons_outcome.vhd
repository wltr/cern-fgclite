--_________________________________________________________________________________________________
--                                                                                                |
--                                         |The nanoFIP|                                          |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                        wf_cons_outcome                                         |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         wf_cons_outcome.vhd                                                               |
--                                                                                                |
-- Description  The unit starts by validating a consumed RP_DAT frame with respect to the         |
--              correctness of:                                                                   |
--                o the CTRL, PDU_TYPE and LGTH bytes; these bytes are received from the          |
--                  wf_consumption unit                                                           |
--                o the CRC, FSS & FES bytes; the rx_fss_crc_fes_ok_p_i pulse, received from the  |
--                  wf_fd_receiver unit, groups these checks                                      |
--                                                                                                |
--              Then, according to the consumed variable that has been received (var_1, var_2,    |
--              var_rst, var_4) it generates the signals:                                         |
--                o "nanoFIP User Interface, NON_WISHBONE" output signals VAR1_RDY and VAR2_RDY   |
--                o "nanoFIP User Interface, NON_WISHBONE" output signal r_tler_o, also used by   |
--                  the wf_status_bytes_generator unit (nanoFIP status byte, bit 4)               |
--                o rst_nFIP_and_FD_p and assert_RSTON_p, that are inputs to the wf_reset_unit    |
--                o jc_start_p that triggers the start-up of thr wf_jtag_controller unit          |
--                                                                                                |
--                                                                                                |
--              Reminder:                                                                         |
--                                                                                                |
--              Consumed RP_DAT frame structure :                                                 |
--   ___________ ______  _______ ______ _________________________ _______  ___________ _______    |
--  |____FSS____|_CTRL_||__PDU__|_LGTH_|_____..Applic-Data.._____|__MPS__||____FCS____|__FES__|   |
--                                                                                                |
--                                     |-----------&LGTH bytes-----------|                        |
--                                     |---------- >0 and <128 ----------|                        |
--              |--------------------------&byte_index_i bytes--------------------------------|   |
--                                                                                                |
--              The LGTH byte is considered correct if it is coherent with the actual number of   |
--              bytes received in the frame and also respects the frame limits.                   |
--                                                                                                |
--                                                                                                |
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)                             |
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)                                 |
-- Date         06/2011                                                                           |
-- Version      v0.06                                                                             |
-- Depends on   wf_reset_unit                                                                     |
--              wf_engine_control                                                                 |
--              wf_fd_receiver                                                                    |
--              wf_consumption                                                                    |
----------------                                                                                  |
-- Last changes                                                                                   |
--     10/2010  v0.01  EG  First version                                                          |
--     11/2010  v0.02  EG  Treatment of reset vars added to the unit                              |
--                         Correction on var1_rdy, var2_rdy for slone                             |
--     12/2010  v0.03  EG  Finally no broadcast in slone, cleanning-up+commenting                 |
--     01/2011  v0.04  EG  Unit wf_var_rdy_generator separated in wf_cons_outcome                 |
--                         (for var1_rdy,var2_rdy+var_rst outcome) & wf_prod_permit (for var3)    |
--     02/2011  v0.05  EG  Added here functionality of wf_cons_frame_validator                    |
--                         Bug on var1_rdy, var2_rdy generation corrected (the s_varX_received    |
--                         was always set to 1!)                                                  |
--                         Added check of CTRL byte for rtler                                     |
--                         Added cons_bytes_excess_i for tracking of too long RP_DATs             |
--     06/2011  v0.06  EG  added var_4 treatment                                                  |
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
--                           Entity declaration for wf_cons_outcome
--=================================================================================================

entity wf_cons_outcome is port(
  -- INPUTS
    -- nanoFIP User Interface, General signals
    uclk_i                 : in std_logic;                     -- 40 MHz clock
    slone_i                : in std_logic;                     -- stand-alone mode

    -- nanoFIP WorldFIP Settings
    subs_i                 : in std_logic_vector (7 downto 0); -- subscriber number coding

    -- Signal from the wf_reset_unit
    nfip_rst_i             : in std_logic;                     -- nanoFIP internal reset

    -- Signal from the wf_fd_receiver unit
    rx_fss_crc_fes_ok_p_i  : in std_logic; -- indication of a frame with correct FSS, FES & CRC;
                                           -- pulse upon FES detection

    rx_crc_wrong_p_i       : in std_logic; -- indication of a frame with a wrong CRC;
                                           -- pulse upon FES detection

    -- Signals from the wf_consumption unit
    cons_ctrl_byte_i       : in std_logic_vector (7 downto 0); -- received RP_DAT CTRL byte
    cons_lgth_byte_i       : in std_logic_vector (7 downto 0); -- received RP_DAT LGTH byte
    cons_pdu_byte_i        : in std_logic_vector (7 downto 0); -- received RP_DAT PDU_TYPE byte
    cons_var_rst_byte_1_i  : in std_logic_vector (7 downto 0); -- received var_rst RP_DAT, 1st data-byte
    cons_var_rst_byte_2_i  : in std_logic_vector (7 downto 0); -- received var_rst RP_DAT, 2nd data-byte

   -- Signals from the wf_engine_control unit
    cons_bytes_excess_i    : in std_logic;                     -- RP_DAT frame with > 133 bytes
    byte_index_i           : in std_logic_vector (7 downto 0); -- index of byte being received
    var_i                  : in t_var;                  -- variable type that is being treated


  -- OUTPUTS
    -- nanoFIP User Interface, NON-WISHBONE outputs
    var1_rdy_o             : out std_logic; -- signals new data is received and can safely be read
    var2_rdy_o             : out std_logic; -- signals new data is received and can safely be read

    -- Signal to the wf_jtag_controller unit
    jc_start_p_o           : out std_logic; -- pulse upon the end of a new valid var_4

    -- Signal to the wf_status_bytes_gen unit
    nfip_status_r_tler_p_o : out std_logic; -- received PDU_TYPE or LGTH error
                                            -- nanoFIP status byte bit 4

    -- Signals to the wf_reset_unit
    assert_rston_p_o       : out std_logic; -- indicates that a var_rst with its 2nd data-byte
                                            -- containing the station's address has been
                                            -- correctly received

    rst_nfip_and_fd_p_o    : out std_logic);-- indicates that a var_rst with its 1st data-byte
                                            -- containing the station's address has been
                                            -- correctly received
end entity wf_cons_outcome;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of wf_cons_outcome is

  signal s_cons_frame_ok_p                 : std_logic;
  signal s_rst_nfip_and_fd, s_assert_rston : std_logic;


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--                                Consumed RP_DAT frame Validation                               --
---------------------------------------------------------------------------------------------------

-- Sequential process Frame_Validation: validation of a consumed RP_DAT frame, with
-- respect to the CTRL, PDU_TYPE and LGTH bytes as well as to the CRC, FSS & FES.
-- The bytes cons_ctrl_byte_i, cons_pdu_byte_i, cons_lgth_byte_i that
-- arrive at the beginning of a frame, have been registered and keep their values until the end
-- of it. The signal rx_fss_crc_fes_ok_p_i, is a pulse at the end of the FES that combines
-- the checks of the FSS, CRC & FES.
-- To check the correctness of the the RP_DAT.Data.LGTH byte, we compare it to the value of the
-- bytes counter byte_index_i, when the FES is detected (pulse rx_fss_crc_fes_ok_p_i).

-- Note: Upon FES detection the counter byte_index_i should be equal to &cons_lgth_byte_i + 5.
-- This is because the byte_index_i also counts the: CTRL, PDU_TYPE, LGTH, the 2 CRC and
-- the FES bytes (and counting starts from 0!).

  Frame_Validation: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        s_cons_frame_ok_p          <= '0';

      else
                                                                                  -- only consumed RP_DATs
        if (var_i = var_1) or (var_i = var_2) or (var_i = var_rst) or (var_i = var_4) then

          if (rx_fss_crc_fes_ok_p_i = '1')                                  and   -- FSS CRC FES check

             ((cons_ctrl_byte_i(5 downto 0) = c_RP_DAT_CTRL_BYTE)         or      -- CTRL byte check
              (cons_ctrl_byte_i(5 downto 0) = c_RP_DAT_MSG_CTRL_BYTE)     or
              (cons_ctrl_byte_i(5 downto 0) = c_RP_DAT_RQ1_CTRL_BYTE)     or
              (cons_ctrl_byte_i(5 downto 0) = c_RP_DAT_RQ2_CTRL_BYTE)     or
              (cons_ctrl_byte_i(5 downto 0) = c_RP_DAT_RQ1_MSG_CTRL_BYTE) or   
              (cons_ctrl_byte_i(5 downto 0) = c_RP_DAT_RQ2_MSG_CTRL_BYTE))    and  
   
             (cons_pdu_byte_i  = c_PDU_TYPE_BYTE)                             and -- PDU_TYPE byte check

             (unsigned(byte_index_i ) = (unsigned(cons_lgth_byte_i) + 5)) then    -- LGTH byte check

            s_cons_frame_ok_p      <= '1';
          else
            s_cons_frame_ok_p      <= '0';
          end if;

        end if;
      end if;
    end if;
  end process;



---------------------------------------------------------------------------------------------------
--                                       r_tler generation                                       --
---------------------------------------------------------------------------------------------------

-- Gneration of the of the "nanoFIP User Interface, NON_WISHBONE" output signal r_tler_o which
-- indicates a received CTRL or PDU_TYPE byte error or a LGTH byte incoherency.

-- Note: The end of a frame is marked by either the signal rx_fss_crc_fes_ok_p_i or by the
-- rx_crc_wrong_p_i.

  nFIP_statusbyte_bit4: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        nfip_status_r_tler_p_o     <= '0';
      else
                                                                                  -- only consumed RP_DATs
        if (var_i = var_1) or (var_i = var_2) or (var_i = var_rst) or (var_i = var_4) then

           if (cons_bytes_excess_i = '1')                                      or -- excess of bytes (without FES detection)

             (((rx_fss_crc_fes_ok_p_i = '1') or (rx_crc_wrong_p_i = '1'))    and  -- upon FES detection checking of CTRL, PDU_TUPE, LGTH

             ((not ((cons_ctrl_byte_i(5 downto 0) = c_RP_DAT_CTRL_BYTE)       or  -- CTRL byte check
                    (cons_ctrl_byte_i(5 downto 0) = c_RP_DAT_MSG_CTRL_BYTE)   or
                    (cons_ctrl_byte_i(5 downto 0) = c_RP_DAT_RQ1_CTRL_BYTE)   or
                    (cons_ctrl_byte_i(5 downto 0) = c_RP_DAT_RQ2_CTRL_BYTE)   or
                    (cons_ctrl_byte_i(5 downto 0) = c_RP_DAT_RQ1_MSG_CTRL_BYTE)or   
                    (cons_ctrl_byte_i(5 downto 0) = c_RP_DAT_RQ2_MSG_CTRL_BYTE)))or 

             (cons_pdu_byte_i /= c_PDU_TYPE_BYTE)                             or  -- PDU_TYPE byte check

             (unsigned(byte_index_i ) /= (unsigned(cons_lgth_byte_i) + 5)))) then -- LGTH byte check

            nfip_status_r_tler_p_o <= '1';
          else
            nfip_status_r_tler_p_o <= '0';

          end if;
        end if;
      end if;
    end if;
  end process;



---------------------------------------------------------------------------------------------------
--                                        VAR_RDY_Generation                                     --
---------------------------------------------------------------------------------------------------

-- Synchronous process VAR_RDY_Generation:

-- Memory Mode:
  -- Since the three memories (consumed, consumed broadcast, produced) are independent, when a
  -- produced var is being sent, the user can read form the consumed memories; similarly, when a
  -- consumed var is being received the user can read from the consumed broadcast memory.

  -- VAR1_RDY (for consumed vars)          : signals that the user can safely read from the
  -- consumed memory. The signal is asserted only after the reception of a correct var_1 RP_DAT
  -- frame. It is de-asserted after the reception of a correct var_1 ID_DAT frame.

  -- VAR2_RDY (for broadcast consumed vars): signals that the user can safely read from the
  -- consumed broadcast memory. The signal is asserted only after the reception of a correct
  -- consumed broadcast var_2 RP_DAT frame. It is de-asserted after the reception of a correct
  -- var_2 ID_DAT frame.


-- Stand-alone Mode:
  -- Similarly, in stand-alone mode, the DAT_I and DAT_O buses for the produced and the consumed
  -- bytes are independent. Stand-alone mode though does not treat the consumed broadcast variable.

  -- VAR1_RDY (for consumed vars)          : signals that the user can safely retrieve data from
  -- the DAT_O bus. The signal is asserted only after the reception of a correct var_1 RP_DAT frame.
  -- It is de-asserted after the reception of a correct var_1 ID_DAT frame (same as in memory mode).

  -- VAR2_RDY (for broadcast consumed vars): stays always deasserted.

-- Note: A correct consumed RP_DAT frame is signaled by the s_cons_frame_ok_p, which arrives upon
-- FES detection. A correct ID_DAT frame along with the variable it contained is signaled by the
-- var_i. The signal var_i gets its value (var_1, var_2, var_rst) after the reception of a correct
-- ID_DAT and of a correct RP_DAT FSS; var_i retains its value until the FES detection (or the
-- detection of an excess of bytes) of the RP_DAT frame. An example follows:

-- frames          : ___[ID_DAT,var_1]__[......RP_DAT......]______________[ID_DAT,var_1]___[.....RP_DAT..
-- cons_frame_ok_p : ______________________________________|-|___________________________________________
-- var_i           :    var_whatever  > <       var_1      > <        var_whatever        > <   var_1
-- VAR1_RDY        : ______________________________________|--------------------------------|____________

  VAR_RDY_Generation: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        var1_rdy_o   <= '0';
        var2_rdy_o   <= '0';

      else

        -- VAR1_RDY --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  
        if (var_i = var_1) and (s_cons_frame_ok_p = '1') then
                                             -- only if the received var_1 RP_DAT frame is correct
          var1_rdy_o <= '1';                 -- the nanoFIP signals the user to retreive data
                                             -- note: the signal var1_rdy_o remains asserted
                                             -- until the beginning of a new var_1

        elsif (var_i = var_1) then

          var1_rdy_o <= '0';                 -- while consuming a var_1, VAR1_RDY is '0'

        end if;      


        -- VAR2_RDY --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  -- 
        if (var_i = var_2) and (s_cons_frame_ok_p = '1') and (slone_i = '0') then
                                             -- only in memory mode and if the received var_2 
          var2_rdy_o <= '1';                 -- RP_DAT is correct the nanoFIP signals the user
                                             -- to retreive data
                                             -- note: the signal var2_rdy_o remains asserted
                                             -- until the beginning of a new var_2

        elsif (var_i = var_2) then

          var2_rdy_o <= '0';                 -- while consuming a var_2, VAR2_RDY is '0'

        end if;      

      end if;
    end if;
  end process;



---------------------------------------------------------------------------------------------------
--                               var_rst: Reset Signals Generation                               --
---------------------------------------------------------------------------------------------------

-- Generation of the signals rst_nfip_and_fd : signals that the 1st byte of a consumed
--                                             var_rst contains the station address
--                          and assert_rston : signals that the 2nd byte of a consumed
--                                             var_rst contains the station address

  Cons_Reset_Signals: process (uclk_i)
  begin
    if rising_edge (uclk_i) then

      if nfip_rst_i = '1' then
        s_rst_nfip_and_fd     <= '0';
        s_assert_rston        <= '0';

      else

        if var_i = var_rst then

          if (byte_index_i = c_1st_DATA_BYTE_INDEX) and (cons_var_rst_byte_1_i = subs_i) then

            s_rst_nfip_and_fd <= '1'; -- rst_nFIP_and_FD_o stays asserted until
          end if;                     -- the end of the var_rst RP_DAT frame

          if (byte_index_i = c_2nd_DATA_BYTE_INDEX) and (cons_var_rst_byte_2_i = subs_i) then

            s_assert_rston    <= '1'; -- assert_RSTON_o stays asserted until
          end if;                     -- the end of the var_rst RP_DAT frame

        else
          s_rst_nfip_and_fd   <= '0';
          s_assert_rston      <= '0';
        end if;
      end if;
    end if;
  end process;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
  rst_nfip_and_fd_p_o         <= '1' when s_rst_nfip_and_fd = '1' and s_cons_frame_ok_p = '1' else '0';
  assert_rston_p_o            <= '1' when s_assert_rston = '1'    and s_cons_frame_ok_p = '1' else '0';



---------------------------------------------------------------------------------------------------
--                              var_4: JTAG_contoller startup signal                             --
---------------------------------------------------------------------------------------------------

-- Generation of the signal jc_start_p_o that is a 1 uclk-long pulse after the reception of a
-- valid JTAG consumed RP_DAT frame (var_4). The pulse triggers the startup of the wf_jtag_controller
-- state machine. 

  jc_start_p_generation: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
          jc_start_p_o <= '0';

      else
        if (var_i = var_4) and (s_cons_frame_ok_p = '1') then
 
          jc_start_p_o <= '1';

        else
          jc_start_p_o <= '0';
        end if;    

      end if;
    end if;
  end process;


end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------