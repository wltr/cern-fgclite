--_________________________________________________________________________________________________
--                                                                                                |
--                                         |The nanoFIP|                                          |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                     wf_cons_bytes_processor                                    |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         wf_cons_bytes_processor.vhd                                                       |
--                                                                                                |
-- Description  The unit is consuming the RP_DAT data bytes that are arriving from the            |
--              wf_fd_receiver, according to the following:                                       |
--                                                                                                |
--              o If the variable identifier of the preceded ID_DAT was:                          |
--                                                                                                |
--               var_1 or var_2                                                                   |
--                - If the operation is in memory mode    : the unit is registering the           |
--                  application-data bytes along with the PDU_TYPE, LGTH and MPS bytes in the     |
--                  Consumed or Broadcast Consumed memories                                       |
--                - If the operation is in stand-alone mode: the unit is transferring the 2 appli-|
--                  cation-data bytes to the "nanoFIP User Interface, NON_WISHBONE" data bus DAT_O|
--                                                                                                |
--              o var_rst                                                                         |
--                 the two application-data bytes are identified and sent to the wf_reset_unit.   |
--                                                                                                |
--              o var_5                                                                           |
--                 regardless of the operational mode (memory or slone) the unit is registering   |
--                 the application-data bytes along with the PDU_TYPE, LGTH and MPS bytes in the  |
--                 JC_consumed memory.                                                            |
--                                                                                                |
--              Note: The validity of the consumed bytes (stored in the memories or transfered    |
--              to DATO or transfered to the wf_reset_unit) is indicated by the "nanoFIP User     |
--              Interface, NON_WISHBONE" signals VAR1_RDY/ VAR2_RDY or the nanoFIP internal       |
--              signals rst_nFIP_and_FD_p/ assert_RSTON_p/ start_jc_i, which are treated in       |
--              the wf_cons_outcome unit and are assessed after the end of the reception of a     |
--              complete frame.                                                                   |
--                                                                                                |
--              Reminder:                                                                         |
--                                                                                                |
--              Consumed RP_DAT frame structure :                                                 |
--       ___________ ______  _______ ________ __________________ _______  ___________ _______     |
--      |____FSS____|_CTRL_||__PDU__|__LGTH__|__..ApplicData..__|__MPS__||____FCS____|__FES__|    |
--                                                                                                |
--                                           |--------&LGTH bytes-------|                         |
--                          |--------write to Consumed memories---------|                         |
--                                           |-----to DAT_O-----|                                 |
--                                           |---to Reset Unit--|                                 |
--                                                                                                |
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)                             |
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)                                 |
-- Date         15/12/2010                                                                        |
-- Version      v0.03                                                                             |
-- Depends on   wf_reset_unit                                                                     |
--              wf_fd_receiver                                                                    |
--              wf_engine_control                                                                 |
----------------                                                                                  |
-- Last changes                                                                                   |
--     11/09/2009  v0.01  EB  First version                                                       |
--        09/2010  v0.02  EG  Treatment of reset variable added; Bytes_Transfer_To_DATO unit      |
--                            creation for simplification; Signals renamed;                       |
--                            CTRL, PDU_TYPE, LGTH bytes registered;                              |
--                            Code cleaned-up & commented.                                        |
--     15/12/2010  v0.03  EG  Unit renamed from wf_cons_bytes_from_rx to wf_cons_bytes_processor  |
--                            byte_ready_p comes from the rx_deserializer (no need to pass from   |
--                            the engine) Code cleaned-up & commented (more!)                     |
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
--                               GNU LESSER GENERAL PUBLIC LICENSE                                |
--                             -------------------------------------                              |
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
--                            Entity declaration for wf_cons_bytes_processor
--=================================================================================================
entity wf_cons_bytes_processor is port(
  -- INPUTS
    -- nanoFIP User Interface, General signals
    uclk_i                : in std_logic;                       -- 40 MHz clock
    slone_i               : in  std_logic;                      -- stand-alone mode (active high)

    -- Signal from the wf_reset_unit
    nfip_rst_i            : in std_logic;                       -- nanoFIP internal reset

    -- nanoFIP User Interface, WISHBONE Slave
    wb_clk_i              : in std_logic;                       -- WISHBONE clock
    wb_adr_i              : in  std_logic_vector (8 downto 0);  -- WISHBONE address to memory

    -- Signals from the wf_fd_receiver unit
    byte_i                : in std_logic_vector (7 downto 0);   -- input byte
    byte_ready_p_i        : in std_logic;                       -- indication of a new input byte

    -- Signals from the wf_engine_control unit
    byte_index_i          : in std_logic_vector (7 downto 0);   -- index of a byte inside the frame;
                                                                -- starting from 0, it counts all the
                                                                -- bytes after the FSS&before the FES

    var_i                 : in t_var;                           -- variable type that is being treated


    -- Signals from the wf_jtag_controller unit
    jc_mem_adr_rd_i       : in std_logic_vector (8 downto 0);   -- address of byte to be read and
                                                                -- transferred to the wf_jtag _controller

  -- OUTPUTS
    -- nanoFIP User Interface, WISHBONE Slave output
-- MODIFIED was (15 downto 0)
    data_o                : out std_logic_vector (7 downto 0); -- data out bus

    -- Signals to the wf_jtag_controller unit
    jc_mem_data_o         : out std_logic_vector (7 downto 0);  -- byte to be transferred to the wf_jtag _controller

    -- Signals to the wf_cons_outcome unit
    cons_ctrl_byte_o      : out std_logic_vector (7 downto 0);  -- received RP_DAT CTRL byte
    cons_lgth_byte_o      : out std_logic_vector (7 downto 0);  -- received RP_DAT LGTH byte
    cons_pdu_byte_o       : out std_logic_vector (7 downto 0);  -- received RP_DAT PDY_TYPE byte
    cons_var_rst_byte_1_o : out std_logic_vector (7 downto 0);  -- received var_rst RP_DAT, 1st data byte
    cons_var_rst_byte_2_o : out std_logic_vector (7 downto 0)); -- received var_rst RP_DAT, 2nd data byte

end entity wf_cons_bytes_processor;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of wf_cons_bytes_processor is

  -- addressing the memory
  signal s_base_adr       : unsigned (8 downto 0);
  signal s_adr            : std_logic_vector (8 downto 0);
  -- bus/ memories write enable
  signal s_slone_wr_en_p  : std_logic_vector (1 downto 0);
  signal s_mem_wr_en_p    : std_logic;
  signal s_jc_mem_wr_en_p : std_logic;
  -- data bytes
  signal s_slone_data_out : std_logic_vector (15 downto 0);
  signal s_mem_data_out   : std_logic_vector (7 downto 0);
  -- Length byte
  signal s_cons_lgth_byte : std_logic_vector (7 downto 0);


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--                         Memory mode Consumed & Consumed Broadcast RAM                         --
--               Storage (by the unit) & retrieval (by the user) of consumed bytes               --
---------------------------------------------------------------------------------------------------
-- Instantiation of a 512 x 8  Dual Port RAM, for both the consumed and consumed broadcast vars
-- Port A is connected to the WISHBONE interface for the readings from the user
-- Port B is used by the nanoFIP for the writings into the memory

  Consumption_RAM : wf_dualram_512x8_clka_rd_clkb_wr
  port map(
    clk_porta_i      => wb_clk_i,	        -- WISHBONE clock
    addr_porta_i     => wb_adr_i,           -- address of byte to be read
    clk_portb_i      => uclk_i,             -- 40 MHz clock
    addr_portb_i     => s_adr,              -- address of byte to be written
    data_portb_i     => byte_i,             -- byte to be written
    write_en_portb_i => s_mem_wr_en_p,      -- write enable
   --------------------------------------------
    data_porta_o     => s_mem_data_out);    -- output byte read
   --------------------------------------------



---------------------------------------------------------------------------------------------------
--                                      JTAG Consumed  RAM                                       --
--         Storage (by this unit) & retrieval (by the JTAG_controller unit) of consumed bytes    --
---------------------------------------------------------------------------------------------------
-- Instantiation of a 512 x 8 Dual Port RAM for the storage of var_4 variables.
-- nanoFIP's user clock uclk is connected to both ports of the memory; the writing of the
-- consumed data and the reading of them (by the wf_jtag_controller) take place internally.
-- Note: only 127 bytes are used.

  Consumption_JTAG_RAM : wf_dualram_512x8_clka_rd_clkb_wr
  port map(
    clk_porta_i      => uclk_i,	            -- user clock
    addr_porta_i     => jc_mem_adr_rd_i,    -- address of byte to be read
    clk_portb_i      => uclk_i,             -- 40 MHz clock
    addr_portb_i     => s_adr,              -- address of byte to be written
    data_portb_i     => byte_i,             -- byte to be written
    write_en_portb_i => s_jc_mem_wr_en_p,   -- write enable
   --------------------------------------------
    data_porta_o     => jc_mem_data_o);     -- output byte read
   --------------------------------------------



---------------------------------------------------------------------------------------------------
--                         Slone mode Storage of consumed bytes to DATO                          --
---------------------------------------------------------------------------------------------------
-- Synchronous process Data_Transfer_To_Dat_o: In stand-alone mode, according to the signal
-- s_slone_wr_en_p, the first or second byte of the "User Interface, NON WISHBONE" bus DAT_O
-- takes the byte byte_i.

  Data_Transfer_To_Dat_o: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then                     -- bus initialization
        s_slone_data_out                <= (others => '0');

      else

        if s_slone_wr_en_p(0) = '1' then           -- the 1st byte is transfered in the lsb of the bus

          s_slone_data_out(7 downto 0)  <= byte_i; -- it stays there until a new cons. var arrives
                                                   -- (or until a reset!)
        end if;


        if s_slone_wr_en_p(1) = '1' then           -- the 2nd byte is transfered in the msb of the bus

          s_slone_data_out(15 downto 8) <= byte_i; -- it stays there until a new cons. var arrives
                                                   -- (or until a reset!)
        end if;
      end if;
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- -- -- --
  -- In stand-alone mode the 16 bits DAT_O fills up with the s_slone_data_out.
  -- In memory mode,the lsb of DAT_O contains the output of the reading of the consumed memory

-- MODIFIED
--  data_o <= s_slone_data_out when slone_i = '1' else "00000000" & s_mem_data_out;
    data_o <= s_mem_data_out;



---------------------------------------------------------------------------------------------------
--                                        Bytes Processing                                       --
---------------------------------------------------------------------------------------------------
-- Combinatorial process Bytes_Processing: Data bytes are consumed according to the
-- variable type (var_1, var_2, var_rst, var_4) they belong to.

-- In memory and in stand-alone mode, bytes are consumed even if any of the CTRL, PDU_TYPE,
-- LGTH, CRC or FES bytes of the consumed RP_DAT frame are incorrect.
-- It is the VAR_RDY signal that signals the user for the validity of the consumed data.

-- The treatment of a var_1 or a var_2 in memory mode is identical to the treatment of a var_5;
-- it is only the addresses of the memories that differ. The incoming bytes (byte_i) after the CTRL
-- byte and before the CRC bytes, are written in the memory one by one as they arrive, on the
-- moments indicated by the byte_ready_p_i pulses.
-- To distinguish the CTRL and the CRC bytes from the rest, the signals byte_index_i and LGTH
-- (s_cons_lgth_byte) are used:
--   o the CTRL byte arrives when byte_index_i = 0
--   o the CRC bytes arrive &LGTH bytes after the LGTH byte.

-- Note: the byte_index_i signal coming from the wf_engine_control is counting each byte after the
--       FSS and before the FES.
--       the LGTH byte (s_cons_lgth_byte) is received when byte_index_i is equal to 3 and
--       indicates the amount of bytes in the frame after the CTRL, PDU_TYPE and itself and
--       before the CRC.

-- In stand-alone mode, in total two bytes of data have to be transferred to the DAT_O bus. The
-- process manages the signal slone_write_byte_p which indicates on which one of the bytes of the
-- bus (msb: 15 downto 8 or lsb: 7 downto 0) the new incoming byte has to be written.

-- In memory and in stand-alone mode, if the consumed variable is the var_rst the process latches
-- the first and second data bytes.


  s_adr <= std_logic_vector (unsigned(byte_index_i)+s_base_adr - 1);      -- memory address of
                                                                          -- the byte to be written
                                                                          -- (-1 bc the CTRL
                                                                          -- byte is not written)

  Bytes_Processing: process (var_i,byte_index_i,slone_i, byte_i, byte_ready_p_i,s_cons_lgth_byte)


  begin


    case var_i is

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --

      when var_1 =>

            cons_var_rst_byte_1_o  <= (others => '0');
            cons_var_rst_byte_2_o  <= (others => '0');
            s_jc_mem_wr_en_p       <= '0';
            s_base_adr             <= c_VARS_ARRAY(c_VAR_1_INDEX).base_addr;-- base address
                                                                            -- from WF_PACKAGE
            --  --  --  --  --  --  --  --  --  --  --  --
            -- in memory mode
            if slone_i = '0' then

              s_slone_wr_en_p      <= (others => '0');

              if (unsigned(byte_index_i)> 0 and  unsigned(byte_index_i)< 127) then -- memory limits

                if byte_index_i > c_LGTH_BYTE_INDEX then                    -- after the reception
                                                                            -- of the LGTH byte
                  if unsigned(byte_index_i) <= unsigned(s_cons_lgth_byte) + 2  then -- less or eq
                    s_mem_wr_en_p  <= byte_ready_p_i;                       -- &LGTH amount of
                                                                            -- bytes are written
                                                                            --(to avoid writing CRC!)
                  else
                    s_mem_wr_en_p  <= '0';
                  end if;

                else                                                        -- before the reception
                  s_mem_wr_en_p    <= byte_ready_p_i;                       -- of the LGTH byte
                end if;                                                     -- all the bytes (after
                                                                            -- CTRL) are written
              else
                s_mem_wr_en_p      <= '0';
              end if;

            --  --  --  --  --  --  --  --  --  --  --  --
            -- in stand-alone mode

            else -- slone_i = '1' then

              s_mem_wr_en_p        <= '0';

              if byte_index_i = c_1st_DATA_BYTE_INDEX then        -- 1st byte to be transferred
                s_slone_wr_en_p    <= '0'& byte_ready_p_i;

              elsif byte_index_i = c_2nd_DATA_BYTE_INDEX then     -- 2nd byte to be transferred
                s_slone_wr_en_p    <= byte_ready_p_i & '0';

              else
                s_slone_wr_en_p    <= (others=>'0');
              end if;
            end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --

      when var_2 =>
            -- same treatment as var 1 on a different memory location (base_addr)
            cons_var_rst_byte_1_o  <= (others => '0');
            cons_var_rst_byte_2_o  <= (others => '0');
            s_jc_mem_wr_en_p       <= '0';
            s_base_adr             <= c_VARS_ARRAY(c_VAR_2_INDEX).base_addr;

            --  --  --  --  --  --  --  --  --  --  --  --
            -- in memory mode
            if slone_i = '0' then

              s_slone_wr_en_p      <= (others => '0');

              if (unsigned(byte_index_i)> 0 and  unsigned(byte_index_i)< 127) then

                if byte_index_i > c_LGTH_BYTE_INDEX then

                  if unsigned(byte_index_i) <= unsigned(s_cons_lgth_byte) + 2  then
                    s_mem_wr_en_p  <= byte_ready_p_i;

                  else
                    s_mem_wr_en_p  <= '0';
                  end if;

                else
                  s_mem_wr_en_p    <= byte_ready_p_i;
                end if;

              else
                s_mem_wr_en_p      <= '0';
              end if;

            --  --  --  --  --  --  --  --  --  --  --  --
            -- stand-alone mode does not treat consumed broadcast vars
            else
              s_mem_wr_en_p        <= '0';
              s_slone_wr_en_p      <= (others => '0');
            end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --

      when var_rst =>

            s_mem_wr_en_p          <= '0';   -- no writing in memory or DAT_O for the var_rst
            s_jc_mem_wr_en_p       <= '0';
            s_slone_wr_en_p        <= (others => '0');
            s_base_adr             <= (others => '0');

            if (byte_ready_p_i = '1') and (byte_index_i = c_1st_DATA_BYTE_INDEX) then  -- 1st byte

              cons_var_rst_byte_1_o <= byte_i;
              cons_var_rst_byte_2_o <= (others => '0');


            elsif (byte_ready_p_i='1') and (byte_index_i = c_2nd_DATA_BYTE_INDEX) then -- 2nd byte

              cons_var_rst_byte_2_o <= byte_i;
              cons_var_rst_byte_1_o <= (others => '0');

            else
              cons_var_rst_byte_1_o <= (others => '0');
              cons_var_rst_byte_2_o <= (others => '0');


            end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --

      when var_4 =>

            cons_var_rst_byte_1_o   <= (others => '0');
            cons_var_rst_byte_2_o   <= (others => '0');
            s_slone_wr_en_p         <= (others => '0');
            s_mem_wr_en_p           <= '0';
            s_base_adr              <= c_VARS_ARRAY(c_VAR_4_INDEX).base_addr;-- base address
                                                                             -- from WF_PACKAGE
            --  --  --  --  --  --  --  --  --  --  --  --

            if (unsigned(byte_index_i)> 0 and  unsigned(byte_index_i)< 127) then -- memory limits

              if byte_index_i > c_LGTH_BYTE_INDEX then                    -- after the reception
                                                                          -- of the LGTH byte
                if unsigned(byte_index_i) <= unsigned(s_cons_lgth_byte) + 2  then -- less or eq
                  s_jc_mem_wr_en_p  <= byte_ready_p_i;                    -- &LGTH amount of
                                                                          -- bytes are written
                                                                          --(to avoid writing CRC!)
                else
                  s_jc_mem_wr_en_p  <= '0';
                end if;

              else                                                        -- before the reception
                s_jc_mem_wr_en_p    <= byte_ready_p_i;                    -- of the LGTH byte
              end if;                                                     -- all the bytes (after
                                                                          -- CTRL) are written
            else
              s_jc_mem_wr_en_p      <= '0';
            end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --

      when others =>

            s_base_adr              <= (others => '0');
            s_mem_wr_en_p           <= '0';
            s_jc_mem_wr_en_p        <= '0';
            s_slone_wr_en_p         <= (others => '0');
            cons_var_rst_byte_1_o   <= (others => '0');
            cons_var_rst_byte_2_o   <= (others => '0');

      end case;

end process;



---------------------------------------------------------------------------------------------------
--                                    CTRL, PDU_TYPE, LGTH bytes                                 --
---------------------------------------------------------------------------------------------------
-- Synchronous process Register_CTRL_PDU_LGTH_bytes: Storage of the CTRL, PDU_TYPE
-- and LGTH bytes of an incoming RP_DAT frame. The bytes are sent to the wf_cons_outcome
-- unit that validates them and accordingly activates the:
-- VAR1_RDY, for a var_1,
-- VAR2_RDY, for a var_2,
-- assert_rston_p & rst_nfip_and_fd_p, for a var_rst,
-- jc_start_p, for a var_4.

  Register_CTRL_PDU_LGTH_bytes: process (uclk_i)
  begin

    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        cons_ctrl_byte_o     <= (others => '0');
        cons_pdu_byte_o      <= (others => '0');
        s_cons_lgth_byte     <= (others => '0');

      else

        if (var_i = var_1) or (var_i = var_2) or (var_i = var_rst) or (var_i = var_4)then  -- only for consumed vars

          if (byte_index_i = c_CTRL_BYTE_INDEX) and (byte_ready_p_i='1') then
            cons_ctrl_byte_o <= byte_i;

          elsif (byte_index_i = c_PDU_BYTE_INDEX) and (byte_ready_p_i ='1') then
            cons_pdu_byte_o  <= byte_i;

          elsif (byte_index_i = c_LGTH_BYTE_INDEX) and (byte_ready_p_i ='1') then
            s_cons_lgth_byte <= byte_i;
          end if;

        else
          cons_ctrl_byte_o   <= (others => '0');
          cons_pdu_byte_o    <= (others => '0');
          s_cons_lgth_byte   <= (others => '0');
        end if;
      end if;
    end if;
  end process;

  --  --  --  --  --  --  --  --  --  --  --  --
  cons_lgth_byte_o         <= s_cons_lgth_byte;


end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------
