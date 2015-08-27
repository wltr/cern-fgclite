--_________________________________________________________________________________________________
--                                                                                                |
--                                         |The nanoFIP|                                          |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                      wf_status_bytes_gen                                       |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         wf_status_bytes_gen.vhd                                                           |
--                                                                                                |
-- Description  Generation of the nanoFIP status and MPS status bytes.                            |
--              The unit is also responsible for outputting the "nanoFIP User Interface,          |
--              NON_WISHBONE" signals U_CACER, U_PACER, R_TLER, R_FCSER, that correspond to       |
--              nanoFIP status bits 2 to 5.                                                       |
--                                                                                                |
--              The information contained in the nanoFIP status byte is coming from :             |
--                o the wf_consumption unit, for the bits 4 and 5                                 |
--                o the "nanoFIP FIELDRIVE" inputs FD_WDGN and FD_TXER, for the bits 6 and 7      |
--                o the "nanoFIP User Interface, NON_WISHBONE" inputs (VAR_ACC) and outputs       |
--                  (VAR_RDY), for the bits 2 and 3.                                              |
--                                                                                                |
--              For the MPS byte, in memory mode, the refreshment and significance bits are set to|
--              1 if the user has updated the produced variable var3 since its last transmission; |
--              the signal "nanoFIP User Interface, NON_WISHBONE" input VAR3_ACC,is used for this.|
--              In stand-alone mode the MPS status byte has the refreshment and significance set  |
--              to 1. The same happens for the JTAG produced variable var_5, regardless of the    |
--              mode.                                                                             |
--                                                                                                |
--              The MPS and the nanoFIP status byte are reset after having been sent or after a   |
--              nanoFIP internal reset.                                                           |
--                                                                                                |
--              Reminder:                                                                         |
--           ______________________ __________ ____________________________________________       |
--          |  nanoFIP STATUS BIT  |   NAME   |                 CONTENTS                   |      |
--          |______________________|__________|____________________________________________|      |
--          |          0           |    r1    |                 reserved                   |      |
--          |______________________|__________|____________________________________________|      |
--          |          1           |    r2    |                 reserved                   |      |
--          |______________________|__________|____________________________________________|      |
--          |          2           |  u_cacer |          user cons var access error        |      |
--          |______________________|__________|____________________________________________|      |
--          |          3           |  u_pacer |          user prod var access error        |      |
--          |______________________|__________|____________________________________________|      |
--          |          4           |  r_tler  |    received CTRL, PDU_TYPE or LGTH error   |      |
--          |______________________|__________|____________________________________________|      |
--          |          5           |  r_fcser |      received FCS or bit number error      |      |
--          |______________________|__________|____________________________________________|      |
--          |          6           |  t_txer  |         transmit error (FIELDRIVE)         |      |
--          |______________________|__________|____________________________________________|      |
--          |          7           |  t_wder  |         watchdog error (FIELDRIVE)         |      |
--          |______________________|__________|____________________________________________|      |
--                                                                                                |
--            ---------------------------------------------------------------------------         |
--                    __________________ ______________ ______________                            |
--                   |  MPS STATUS BIT  |     NAME     |   CONTENTS   |                           |
--                   |__________________|______________|______________|                           |
--                   |        0         | refreshment  |     1/0      |                           |
--                   |__________________|______________|______________|                           |
--                   |        1         |              |      0       |                           |
--                   |__________________|______________|______________|                           |
--                   |        2         | significance |     1/0      |                           |
--                   |__________________|______________|______________|                           |
--                   |        3         |              |      0       |                           |
--                   |__________________|_____________ |______________|                           |
--                   |       4-7        |              |     000      |                           |
--                   |__________________|_____________ |______________|                           |
--                                                                                                |
--                                                                                                |
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)                             |
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)                                 |
-- Date         06/2011                                                                           |
-- Version      v0.04                                                                             |
-- Depends on   wf_reset_unit                                                                     |
--              wf_consumption                                                                    |
--              wf_prod_bytes_retriever                                                           |
--              wf_prod_permit                                                                    |
----------------                                                                                  |
-- Last changes                                                                                   |
--     07/07/2009  v0.01  PA  First version                                                       |
--        08/2010  v0.02  EG  Internal extention of the var_rdy signals to avoid nanoFIP status   |
--                            errors few cycles after var_rdy deactivation                        |
--        01/2011  v0.03  EG  u_cacer,pacer etc outputs added; new input nfip_status_r_tler_p_i   |
--                            for nanoFIP status bit 4; var_i input not needed as the signals     |
--                            nfip_status_r_fcser_p_i and nfip_status_r_tler_p_i check the var    |
--        06/2011  v0.04  EG  all bits of nanoFIP status byte are reset upon rst_status_bytes_p_i |
--                            var_i added for the jtag_var1 treatment;                            |
--                            r_fcser, r_tler_o considered only for a cons variable (bf a wrong   |
--                            crc on an id-dat could give r_fcser)                                |
--        11/2011  v0.042 EG  the var3_acc_a_i and not the s_var3_acc_synch(3) was used for       |
--                            the refreshment:s                                                    |
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
--                          Entity declaration for wf_status_bytes_gen
--=================================================================================================
entity wf_status_bytes_gen is port(
  -- INPUTS
    -- nanoFIP User Interface, General signals
    uclk_i                  : in std_logic;  -- 40 MHz Clock
    slone_i                 : in std_logic;  -- stand-alone mode

    -- Signal from the wf_reset_unit
    nfip_rst_i              : in std_logic;  -- nanaoFIP internal reset

    -- nanoFIP FIELDRIVE
    fd_txer_a_i             : in std_logic;  -- transmitter error
    fd_wdgn_a_i             : in std_logic;  -- watchdog on transmitter

    -- nanoFIP User Interface, NON-WISHBONE
    var1_acc_a_i            : in std_logic;  -- variable 1 access
    var2_acc_a_i            : in std_logic;  -- variable 2 access
    var3_acc_a_i            : in std_logic;  -- variable 3 access

   -- Signals from the wf_consumption unit
    nfip_status_r_fcser_p_i : in std_logic;  -- wrong CRC bytes received
    nfip_status_r_tler_p_i  : in std_logic;  -- wrong PDU_TYPE, CTRL or LGTH bytes received
    var1_rdy_i              : in std_logic;  -- variable 1 ready
    var2_rdy_i              : in std_logic;  -- variable 2 ready

   -- Signals from the wf_prod_bytes_retriever unit
    rst_status_bytes_p_i    : in std_logic;  -- reset for both status bytes;
                                             -- they are reset right after having been delivered

   -- Signals from the wf_prod_permit unit
    var3_rdy_i              : in std_logic;  -- variable 3 ready

    -- Signal from the wf_engine_control unit
    var_i                   : in t_var;      -- variable type that is being treated

  -- OUTPUTS
    -- nanoFIP User Interface, NON-WISHBONE outputs
    r_fcser_o               : out std_logic; -- nanoFIP status byte, bit 5
    r_tler_o                : out std_logic; -- nanoFIP status byte, bit 4
    u_cacer_o               : out std_logic; -- nanoFIP status byte, bit 2
    u_pacer_o               : out std_logic; -- nanoFIP status byte, bit 3

    -- Signal to the wf_prod_bytes_retriever
    mps_status_byte_o       : out std_logic_vector (7 downto 0); -- MPS status byte
    nFIP_status_byte_o      : out std_logic_vector (7 downto 0));-- nanoFIP status byte

end entity wf_status_bytes_gen;

--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of wf_status_bytes_gen is

  -- synchronizers
  signal s_fd_txer_synch, s_fd_wdg_synch, s_var1_acc_synch         : std_logic_vector (2 downto 0);
  signal s_var2_acc_synch, s_var3_acc_synch                        : std_logic_vector (2 downto 0);
  -- MPS refreshment/ significance bit
  signal s_refreshment                                             : std_logic;
  -- nanoFIP status byte
  signal s_nFIP_status_byte                                        : std_logic_vector (7 downto 0);
  -- extension of var_rdy signals
  signal s_var1_rdy_c, s_var2_rdy_c, s_var3_rdy_c                  : unsigned (3 downto 0);
  signal s_var1_rdy_c_incr,s_var1_rdy_c_reinit,s_var1_rdy_extended : std_logic;
  signal s_var2_rdy_c_incr,s_var2_rdy_c_reinit,s_var2_rdy_extended : std_logic;
  signal s_var3_rdy_c_incr,s_var3_rdy_c_reinit,s_var3_rdy_extended : std_logic;


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--                            FD_TXER, FD_WDGN, VARx_ACC Synchronizers                           --
---------------------------------------------------------------------------------------------------

  FIELDRIVE_inputs_synchronizer: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
       s_fd_wdg_synch  <= (others => '0');
       s_fd_txer_synch <= (others => '0');

      else
       s_fd_wdg_synch  <= s_fd_wdg_synch (1 downto 0)  & not fd_wdgn_a_i;
       s_fd_txer_synch <= s_fd_txer_synch (1 downto 0) & fd_txer_a_i;
      end if;
    end if;
  end process;


---------------------------------------------------------------------------------------------------
  VAR_ACC_synchronizer: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        s_var1_acc_synch <= (others => '0');
        s_var2_acc_synch <= (others => '0');
        s_var3_acc_synch <= (others => '0');

      else
        s_var1_acc_synch <= s_var1_acc_synch(1 downto 0) & var1_acc_a_i;
        s_var2_acc_synch <= s_var2_acc_synch(1 downto 0) & var2_acc_a_i;
        s_var3_acc_synch <= s_var3_acc_synch(1 downto 0) & var3_acc_a_i;

      end if;
    end if;
  end process;



---------------------------------------------------------------------------------------------------
--                                        MPS status byte                                        --
---------------------------------------------------------------------------------------------------

-- Synchronous process Refreshment_bit_Creation: Creation of the refreshment bit (used in
-- the MPS status byte). The bit is set to 1 if the user has updated the produced variable since
-- its last transmission. The process is checking if the signal VAR3_ACC has been asserted since
-- the last production of a variable.

  Refreshment_bit_Creation: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        s_refreshment   <= '0';
      else

        if rst_status_bytes_p_i = '1' then          -- bit reinitialized after a production
          s_refreshment <= '0';

        elsif s_var3_acc_synch(2) = '1' then        -- indication that the memory has been accessed
          s_refreshment <= '1';
        end if;

      end if;
    end if;
  end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process MPS_byte_Generation: Creation of the MPS byte (Table 2, functional specs)

  MPS_byte_Generation: process (slone_i, s_refreshment, var_i)

  begin                                     -- var_5, regardless of the mode, has signif. & refresh. set to 1
    if slone_i = '1' or var_i = var_5 then  -- stand-alone mode has signif. & refresh. set to 1
      mps_status_byte_o (7 downto 3)           <= (others => '0');
      mps_status_byte_o (c_SIGNIFICANCE_INDEX) <= '1';
      mps_status_byte_o (1)                    <= '0';
      mps_status_byte_o (c_REFRESHMENT_INDEX)  <= '1';


    else
      mps_status_byte_o (7 downto 3)           <= (others => '0');
      mps_status_byte_o (c_REFRESHMENT_INDEX)  <= s_refreshment;
      mps_status_byte_o (1)                    <= '0';
      mps_status_byte_o (c_SIGNIFICANCE_INDEX) <= s_refreshment;
    end if;
  end process;


---------------------------------------------------------------------------------------------------
--                                     nanoFIP status byte                                       --
---------------------------------------------------------------------------------------------------

-- Synchronous process nFIP_status_byte_Generation: Creation of the nanoFIP status byte (Table 8,
-- functional specs)

  nFIP_status_byte_Generation: process (uclk_i)
  begin

    if rising_edge (uclk_i) then

      if nfip_rst_i = '1' then
        s_nFIP_status_byte                      <= (others => '0');

      else
        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- reinitialization after the transmission of a produced variable
        if rst_status_bytes_p_i = '1' then 
          s_nFIP_status_byte                    <= (others => '0');

        else

          --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
          -- u_cacer
          if ((s_var1_rdy_extended = '0' and s_var1_acc_synch(2) = '1') or
              (s_var2_rdy_extended = '0' and s_var2_acc_synch(2) = '1')) then
                                                                 -- since the last time the status
                                                                 -- byte was delivered,
            s_nFIP_status_byte(c_U_CACER_INDEX) <= '1';          -- the user logic accessed a cons.
                                                                 -- var. when it was not ready
          end if;


          --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
          -- u_pacer
          if (s_var3_rdy_extended = '0' and s_var3_acc_synch(2) = '1') then
                                                                 -- since the last time the status
            s_nFIP_status_byte(c_U_PACER_INDEX) <= '1';          -- byte was delivered,
                                                                 -- the user logic accessed a prod.
                                                                 -- var. when it was not ready
          end if;


          --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
          -- t_wder
          if (s_fd_wdg_synch(2) = '1') then                      -- FIELDRIVE transmission error
            s_nFIP_status_byte(c_T_WDER_INDEX)  <= '1';
          end if;


          --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
          -- t_rxer
          if (s_fd_txer_synch(2) = '1') then                     -- FIELDRIVE watchdog timer problem
            s_nFIP_status_byte(c_T_TXER_INDEX)  <= '1';
          end if;


          --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
          --r_tler                                               -- PDU_TYPE or LGTH error on a consumed var
          if (nfip_status_r_tler_p_i = '1' and ((var_i = var_1) or (var_i = var_2) or (var_i = var_4) or (var_i = var_rst))) then
            s_nFIP_status_byte(c_R_TLER_INDEX)  <= '1';
          end if;

           --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --
          --r_fcser                                               -- CRC or bit number error on a consumed var
          if (nfip_status_r_fcser_p_i = '1' and ((var_i = var_1) or (var_i = var_2) or (var_i = var_4) or (var_i = var_rst))) then
            s_nFIP_status_byte(c_R_FCSER_INDEX) <= '1';
          end if;

          --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  --

        end if;
      end if;
    end if;
  end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Instantiation of 3 wf_incr_counters used for the internal extension of each one of the
-- signals VAR1_RDY, VAR2_RDY, VAR3_RDY for 15 uclk cycles.
-- Enabled VAR_ACC during this period will not trigger a nanoFIP status byte error.

-- Note: actually it is the var_acc_synch(2) rather than the VAR_ACC used to check for access errors;
-- var_acc_synch(2) is 3 cycles later than VAR_ACC and therefore enabled VAR_ACC is ignored up to 12
-- uclk cycles (not 15 uclk cycles!) after the deassertion of the VAR_RDY. 

  Extend_VAR1_RDY: wf_incr_counter        -- VAR1_RDY           : __|---...---|___________________
  generic map(g_counter_lgth => 4)        -- s_var1_rdy_extended: __|---...------------------|____
  port map(                               --                      -->   VAR_ACC here is OK!   <--             
    uclk_i              => uclk_i,
    counter_reinit_i    => s_var1_rdy_c_reinit,
    counter_incr_i      => s_var1_rdy_c_incr,
    counter_is_full_o   => open,
    ------------------------------------------
    counter_o           => s_var1_rdy_c);
    ------------------------------------------

    s_var1_rdy_c_reinit <= var1_rdy_i or nfip_rst_i;
    s_var1_rdy_c_incr   <= '1' when s_var1_rdy_c < "1111" else '0';
    s_var1_rdy_extended <= '1' when var1_rdy_i= '1' or s_var1_rdy_c_incr = '1' else '0';

 --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  Extend_VAR2_RDY: wf_incr_counter
  generic map(g_counter_lgth => 4)
  port map(
    uclk_i              => uclk_i,
    counter_reinit_i    => s_var2_rdy_c_reinit,
    counter_incr_i      => s_var2_rdy_c_incr,
    counter_is_full_o   => open,
    ------------------------------------------
    counter_o           => s_var2_rdy_c);
    ------------------------------------------

    s_var2_rdy_c_reinit <= var2_rdy_i or nfip_rst_i;
    s_var2_rdy_c_incr   <= '1' when s_var2_rdy_c < "1111" else '0';
    s_var2_rdy_extended <= '1' when var2_rdy_i= '1' or s_var2_rdy_c_incr = '1' else '0';

 --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  Extend_VAR3_RDY: wf_incr_counter
  generic map(g_counter_lgth => 4)
  port map(
    uclk_i              => uclk_i,
    counter_reinit_i    => s_var3_rdy_c_reinit,
    counter_incr_i      => s_var3_rdy_c_incr,
    counter_is_full_o   => open,
    ------------------------------------------
    counter_o           => s_var3_rdy_c);
    ------------------------------------------

    s_var3_rdy_c_reinit <= var3_rdy_i or nfip_rst_i;
    s_var3_rdy_c_incr   <= '1' when s_var3_rdy_c < "1111" else '0';
    s_var3_rdy_extended <= '1' when VAR3_RDY_i= '1' or s_var3_rdy_c_incr = '1' else '0';



---------------------------------------------------------------------------------------------------
--                                            Outputs                                            --
---------------------------------------------------------------------------------------------------

  nFIP_status_byte_o <= s_nFIP_status_byte;
  u_cacer_o          <= s_nFIP_status_byte(c_U_CACER_INDEX);
  u_pacer_o          <= s_nFIP_status_byte(c_U_PACER_INDEX);
  r_tler_o           <= s_nFIP_status_byte(c_R_TLER_INDEX);
  r_fcser_o          <= s_nFIP_status_byte(c_R_FCSER_INDEX);


end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------