--_________________________________________________________________________________________________
--                                                                                                |
--                                         |The nanoFIP|                                          |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                    wf_prod_bytes_retriever                                     |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         wf_prod_bytes_retriever.vhd                                                       |
--                                                                                                |
-- Description  After an ID_DAT frame requesting for a variable to be produced, the unit provides |
--              to the wf_tx_serializer unit one by one, all the bytes of data needed for the     |
--              RP_DAT frame (apart from the  FSS, FCS and FES bytes). The coordination of the    |
--              retrieval is done through the wf_engine_control and the signal byte_index_i.      |
--                                                                                                |
--              General structure of a produced RP_DAT frame:                                     |
--    ___________ ______  _______ ______ _________________ _______ _______  ___________ _______   |
--   |____FSS____|_CTRL_||__PDU__|_LGTH_|_...User-Data..._|_nstat_|__MPS__||____FCS____|__FES__|  |
--                                                                                                |
--              Data provided by the this unit:                                                   |
--                ______  _______ ______ _________________ _______ _______                        |
--               |_CTRL_||__PDU__|_LGTH_|_...User-Data..._|_nstat_|__MPS__||                      |
--                                                                                                |
--              If the variable to be produced is the                                             |
--                o presence      : The unit retreives the bytes from the WF_PACKAGE.             |
--                                  No MPS & no nanoFIP status are associated with this variable. |
--                ______  _______ ______ ______ ______ ______ ______ ______                       |
--               |_CTRL_||__PDU__|__05__|__80__|__03__|__00__|__F0__|__00__||                     |
--                                                                                                |
--                                                                                                |
--                o identification: The unit retreives the Constructor & Model bytes from the     |
--                                  wf_model_constr_decoder, & all the rest from the WF_PACKAGE.  |
--                                  No MPS & no nanoFIP status are associated with this variable. |
--        ______  _______ ______ ______ ______ ______ ______ _______ ______ ______ ______         |
--       |_CTRL_||__PDU__|__08__|__01__|__00__|__00__|_cons_|__mod__|__00__|__00__|__00__||       |
--                                                                                                |
--                                                                                                |
--                o var_3         : If the operation is in stand-alone mode, the unit retreives   |
--                                  the user-data bytes from the "nanoFIP User Interface, NON-    |
--                                  WISHBONE" bus DAT_I.                                          |
--                                  If it is in memory mode,it retreives them from the Produced RAM
--                                  The MPS and the nanoFIP status bytes are retrieved from the   |
--                                  wf_status_bytes_gen.                                          |
--                                  The LGTH byte is retrieved from the wf_prod_data_lgth_calc.   |
--                                  The rest of the bytes (CTRL & PDU) come from the WF_PACKAGE.  |
--        ______  _______ ______ ________________________________________ _______ _______         |
--       |_CTRL_||__PDU__|_LGTH_|_____________..User-Data..______________|_nstat_|__MPS__||       |
--                                                                                                |
--                                                                                                |
--                o var_5         : Regardless of the operational mode or the P3_LGTH, the unit   |
--                                  sends 1 user-data byte coming from the wf_jtag_controller.    |
--                                  The nanoFIP status is always sent regardless of the NOSTAT    |
--                                  input. The MPS, LGTH, CTRL, PDU_TYPE bytes are retrived in    |
--                                  the same way as for a var_3.                                  |
--                                                                                                |
--                ______  _______ ______ ________ _______ _______                                 |
--               |_CTRL_||__PDU__|_LGTH_|_jc_tdo_|_nstat_|__MPS__||                               |
--                                                                                                |
--                                                                                                |
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)                             |
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)                                 |
-- Date         04/01/2011                                                                        |
-- Version      v0.05                                                                             |
-- Depends on   wf_reset_unit                                                                     |
--              wf_wb_controller                                                                  |
--              wf_engine_control                                                                 |
--              wf_prod_permit                                                                    |
--              wf_status_bytes_gen                                                               |
--              wf_model_constr_dec                                                               |
--              wf_jtag_controller                                                                |
----------------                                                                                  |
-- Last changes                                                                                   |
--     06/2010  v0.02  EG  subs_i is not sent in the RP_DAT frames                                |
--                         signal s_wb_we includes the wb_stb_r_edge_p_i                          |
--                         cleaner structure                                                      |
--     06/2010  v0.03  EG  signal s_mem_byte was not in sensitivity list in v0.01! by adding it   |
--                         changes were essential in the timing of the tx (wf_osc, wf_tx,         |
--                         wf_engine_control and the configuration of the memory needed changes)  |
--     11/2010  v0.04  EG  for simplification, new unit Slone_Data_Sampler created                |
--     4/1/2011 v0.05  EG  unit renamed from wf_prod_bytes_to_tx to wf_prod_bytes_retriever;      |
--                         input byte_being_sent_p_i added, so that the reseting of status bytes  |
--                         does not pass from the engine; clening-up+commenting                   |
--       2/2011 v0.051 EG  wf_prod_bytes_from_dati unit removed.                                  |
--       6/2011 v0.051 EG  added jc var treatment.                                                |
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
--                           Entity declaration for wf_prod_bytes_retriever
--=================================================================================================

entity wf_prod_bytes_retriever is port(
  -- INPUTS
    -- nanoFIP User Interface, General signals
    uclk_i               : in std_logic;                      -- 40 MHz clock
    nostat_i             : in std_logic;                      -- if negated, nFIP status is sent
    slone_i              : in std_logic;                      -- stand-alone mode

    -- Signal from the wf_reset_unit
    nfip_rst_i           : in std_logic;                      -- nanoFIP internal reset

    -- nanoFIP User Interface, WISHBONE Slave
    wb_clk_i             : in std_logic;                      -- WISHBONE clock
    wb_adr_i             : in std_logic_vector (8 downto 0);  -- WISHBONE address to memory
    wb_data_i            : in std_logic_vector (7 downto 0);  -- WISHBONE data bus

    -- Signal from the wf_wb_controller
    wb_ack_prod_p_i      : in std_logic;                      -- WISHBONE acknowledge
                                                              -- latching moment of wb_data_i

    -- nanoFIP User Interface, NON WISHBONE
    slone_data_i         : in std_logic_vector (15 downto 0); -- input data bus for slone mode

    -- Signals from the wf_engine_control unit
    byte_index_i         : in std_logic_vector (7 downto 0);  --index of the byte to be retrieved

    byte_being_sent_p_i  : in std_logic;                      -- pulse on the beginning of the
                                                              -- delivery of a new byte

    data_lgth_i          : in std_logic_vector (7 downto 0);  -- # bytes of the Conrol&Data fields
                                                              -- of the RP_DAT frame; includes:
                                                              -- 1 byte RP_DAT.CTRL,
                                                              -- 1 byte RP_DAT.Data.PDU_type,
                                                              -- 1 byte RP_DAT.Data.LGTH
                                                              -- several bytes of RP_DAT.Data, and
                                                              -- if applicable 1 byte RP_DAT.Data.MPS_status &
                                                              --               1 byte RP_DAT.Data.nanoFIP_status



    var_i                : in t_var;                          --variable type that is being treated

    -- Signals from the wf_prod_permit
    var3_rdy_i           : in std_logic;                      -- nanoFIP output VAR3_RDY

    -- Signals from the wf_status_bytes_gen
    mps_status_byte_i    : in std_logic_vector (7 downto 0);  -- MPS status byte
    nFIP_status_byte_i   : in std_logic_vector (7 downto 0);  -- nanoFIP status byte

    -- Signals from the wf_model_constr_dec unit
    constr_id_dec_i      : in  std_logic_vector (7 downto 0); -- decoded constructor id settings
    model_id_dec_i       : in  std_logic_vector (7 downto 0); -- decoded model id settings

    -- Signals from the wf_jtag_controller unit
    jc_tdo_byte_i        : in std_logic_vector (7 downto 0);  -- sampled JC_TDO


  -- OUTPUTS
    -- Signal to the wf_status_bytes_gen
    rst_status_bytes_p_o : out std_logic;                     -- reset for the nanoFIP&MPS status
                                                              -- status bytes.It is activated after
                                                              -- the delivery of the last one (MPS)

    -- Signal to the wf_tx_serializer
    byte_o               : out std_logic_vector (7 downto 0));-- output byte to be serialized
    
end entity wf_prod_bytes_retriever;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of wf_prod_bytes_retriever is

  -- addressing the memory
  signal s_base_addr, s_mem_addr_offset : unsigned (8 downto 0);
  signal s_mem_addr_A                   : std_logic_vector (8 downto 0);
  -- index of byte to be sent
  signal s_byte_index_d1                : std_logic_vector (7 downto 0);
  signal s_byte_index_d_aux             : integer range 0 to 15;
  -- data bytes
  signal s_mem_byte, s_slone_byte       : std_logic_vector (7 downto 0);
  signal s_slone_bytes                  : std_logic_vector (15 downto 0);
  -- Length byte
  signal s_lgth_byte                    : std_logic_vector (7 downto 0);


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--                                    Memory mode Produced RAM                                   --
--               Storage (by the user) & retrieval (by the unit) of produced bytes               --
---------------------------------------------------------------------------------------------------
-- Instantiation of a 512 x 8 Produced Dual Port RAM.
-- Port A is used by the nanoFIP for the readings from the Produced RAM;
-- Port B is connected to the WISHBONE interface for the writings from the user.
-- Note: only 124 bytes are used.

  Produced_Bytes_From_RAM:  wf_dualram_512x8_clka_rd_clkb_wr
  port map(
    clk_porta_i      => uclk_i,	               -- 40 MHz clock
    addr_porta_i     => s_mem_addr_A,          -- address of byte to be read from memory
    clk_portb_i      => wb_clk_i,              -- WISHBONE clock
    addr_portb_i     => wb_adr_i,              -- address of byte to be written
    data_portb_i     => wb_data_i,             -- byte to be written
    write_en_portb_i => wb_ack_prod_p_i,       -- WISHBONE write enable
   -----------------------------------------
    data_porta_o     => s_mem_byte);           -- output byte read
   -----------------------------------------


---------------------------------------------------------------------------------------------------
--                                 Slone mode DAT_I bus Sampling                                 --
--                           retrieval of the two bytes to be produced                           --
---------------------------------------------------------------------------------------------------
-- Sampling of the input data bus DAT_I(15:0) for the operation in stand-alone mode.
-- The sampling takes place on the 1st clock cycle after the VAR3_RDY has been de-asserted.

  Sample_DAT_I_bus: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        s_slone_bytes   <= (others=>'0');

     else
        if var3_rdy_i = '1' then   -- data latching
          s_slone_bytes <= slone_data_i;
        end if;

      end if;
    end if;
  end process;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  s_slone_byte          <= s_slone_bytes(7 downto 0) when byte_index_i = c_1st_DATA_BYTE_INDEX
                      else s_slone_bytes(15 downto 8);



---------------------------------------------------------------------------------------------------
--                                        Bytes Generation                                       --
---------------------------------------------------------------------------------------------------
-- Combinatorial process Bytes_Generation: Generation of bytes for the CTRL and Data fields of an
-- RP_DAT frame: If the variable requested in the ID_DAT is of "produced" type (identification/
-- presence/ var3/ var5) the process prepares accordingly, one by one, bytes of data to be sent.
-- The pointer "s_byte_index_d1" (or "s_byte_index_d_aux") indicates which byte of the frame is to be sent.
-- Some of the bytes are defined in the WF_PACKAGE,
-- the rest come either from the memory (if slone = 0) or from the the input bus DAT_I (if slone = 1),
-- or from the  wf_status_bytes_gen or the wf_model_constr_decoder units.
-- The output byte "byte_o" is sent to the wf_tx_serializer unit for manchester encoding and serialization.

  Bytes_Generation: process (var_i, s_byte_index_d1, data_lgth_i, constr_id_dec_i, model_id_dec_i,
                             nFIP_status_byte_i, mps_status_byte_i, s_slone_byte, s_byte_index_d_aux,
                             s_mem_byte, nostat_i, byte_being_sent_p_i, s_lgth_byte, slone_i, jc_tdo_byte_i)

  begin

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- generation of bytes according to the type of produced var:
    case var_i is


	-- case: presence variable
    -- all the bytes for the RP_DAT.CTRL and RP_DAT.Data fields are predefined
    -- in the c_VARS_ARRAY matrix.
    when var_presence =>

      byte_o                   <= c_VARS_ARRAY(c_VAR_PRESENCE_INDEX).byte_array(s_byte_index_d_aux);

      s_base_addr              <= (others => '0');
      rst_status_bytes_p_o     <= '0';

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --


	-- case: identification variable
    -- The Constructor and Model bytes of the identification variable arrive from the
    -- wf_model_constr_decoder, wereas all the rest are predefined in the c_VARS_ARRAY matrix.
    when var_identif =>

      if s_byte_index_d1 = c_CONSTR_BYTE_INDEX then
        byte_o                 <= constr_id_dec_i;

      elsif s_byte_index_d1 = c_MODEL_BYTE_INDEX then
        byte_o                 <= model_id_dec_i;

      else
        byte_o                 <= c_VARS_ARRAY(c_VAR_IDENTIF_INDEX).byte_array(s_byte_index_d_aux);
      end if;

      s_base_addr              <= (others => '0');
      rst_status_bytes_p_o     <= '0';

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --


    -- case: variable 3
    -- For a var_3 there is a separation according to the operational mode (stand-alone or memory)
    -- In general, few of the bytes are predefined in the c_VARS_ARRAY matrix, whereas the rest come
    -- either from the memory/ DAT_I bus or from wf_status_bytes_generator unit.
    when var_3 =>

      ---------------------------------------------------------------------------------------------
      -- In memory mode:
      if slone_i = '0' then

        -- retrieval of base address info for the memory from the WF_PACKAGE
        s_base_addr            <= c_VARS_ARRAY(c_VAR_3_INDEX).base_addr;


        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The first (CTRL) and second (PDU_TYPE) bytes to be sent
        -- are predefined in the c_VARS_ARRAY matrix of the WF_PACKAGE

        if unsigned(s_byte_index_d1) <= c_VARS_ARRAY(c_VAR_3_INDEX).array_lgth  then  -- less or eq
          byte_o               <= c_VARS_ARRAY(c_VAR_3_INDEX).byte_array(s_byte_index_d_aux);
          rst_status_bytes_p_o <= '0';

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The &c_LGTH_BYTE_INDEX byte is the Length

        elsif s_byte_index_d1 = c_LGTH_BYTE_INDEX then
          byte_o               <= s_lgth_byte;
          rst_status_bytes_p_o <= '0';

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- If the nostat_i is negated, the one but last byte is the nanoFIP status byte

        elsif (unsigned(s_byte_index_d1) = (unsigned(data_lgth_i)-1 )) and nostat_i = '0' then
          byte_o               <= nFIP_status_byte_i;
          rst_status_bytes_p_o <= '0';

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The last byte is the MPS status
        elsif s_byte_index_d1 = (data_lgth_i)  then
          byte_o               <= mps_status_byte_i;
          rst_status_bytes_p_o <= byte_being_sent_p_i; -- reset signal for both status bytes;
                                                       -- the reset arrives after the delivery
                                                       -- of the MPS byte to the wf_tx_serializer

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      -- The rest of the bytes come from the memory
        else
          byte_o               <= s_mem_byte;
          rst_status_bytes_p_o <= '0';

        end if;

      ---------------------------------------------------------------------------------------------
      -- In stand-alone mode:
      else

        s_base_addr            <= (others => '0');            -- no memory access needed

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The first (CTRL) and second (PDU_TYPE) bytes to be sent
        -- are predefined in the c_VARS_ARRAY matrix of the WF_PACKAGE

        if unsigned(s_byte_index_d1) <= c_VARS_ARRAY(c_VAR_3_INDEX).array_lgth then -- less or eq
          byte_o               <= c_VARS_ARRAY(c_VAR_3_INDEX).byte_array(s_byte_index_d_aux);
          rst_status_bytes_p_o <= '0';

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The &c_LGTH_BYTE_INDEX byte is the Length

        elsif s_byte_index_d1 = c_LGTH_BYTE_INDEX then
          byte_o               <= s_lgth_byte;
          rst_status_bytes_p_o <= '0';

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- If the nostat_i is negated, the one but last byte is the nanoFIP status byte

        elsif unsigned(s_byte_index_d1) = (unsigned(data_lgth_i)-1 ) and nostat_i = '0' then
          byte_o               <= nFIP_status_byte_i;
          rst_status_bytes_p_o <= '0';

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The last byte is the MPS status
        elsif s_byte_index_d1 = data_lgth_i then
          byte_o               <= mps_status_byte_i;
          rst_status_bytes_p_o <= byte_being_sent_p_i; -- reset signal for both status bytes.
                                                       -- The reset arrives after having sent the
                                                       -- MPS byte to the wf_tx_serializer.

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The rest of the bytes come from the input bus DAT_I(15:0)
        else
          byte_o               <= s_slone_byte;
          rst_status_bytes_p_o <= '0';

        end if;
      end if;

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --


    -- case: jtag produced variable var_5
    -- For a var_5 the 1 user-data byte comes from the wf_jtag_controller unit.
    -- The nanoFIP status byte comes from the wf_status_bytes_gen and it is always sent, regardless
    -- of the NOSTAT input. The MPS byte is also coming from the wf_status_bytes_gen.
    -- The rest of the bytes come from the WF_PACKAGE.
    when var_5 =>

        s_base_addr            <= (others => '0');            -- no memory access needed

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The &c_LGTH_BYTE_INDEX byte is the Length
        if s_byte_index_d1 = c_LGTH_BYTE_INDEX then
          byte_o               <= s_lgth_byte;
          rst_status_bytes_p_o <= '0';

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The first and only data byte comes from the JATG_controller
        elsif s_byte_index_d1 = c_1st_DATA_BYTE_INDEX then
          byte_o               <= jc_tdo_byte_i;
          rst_status_bytes_p_o <= '0';

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The one but last byte is the nanoFIP status byte
        elsif unsigned(s_byte_index_d1) = (unsigned(data_lgth_i)-1 ) then
          byte_o               <= nFIP_status_byte_i;
          rst_status_bytes_p_o <= '0';

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The last byte is the MPS status
        elsif s_byte_index_d1 = data_lgth_i then
          byte_o               <= mps_status_byte_i;
          rst_status_bytes_p_o <= byte_being_sent_p_i; -- reset signal for both status bytes.
                                                       -- The reset arrives after having sent the
                                                       -- MPS byte to the wf_tx_serializer.

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The rest of the bytes (the very first one, CTRL, and the second one, PDU_TYPE) are 
        -- predefined in the c_VARS_ARRAY matrix of the WF_PACKAGE
        else 
          byte_o               <= c_VARS_ARRAY(c_VAR_5_INDEX).byte_array(s_byte_index_d_aux);
          rst_status_bytes_p_o <= '0';
        end if;

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --

    when others =>
      rst_status_bytes_p_o     <= '0';
      byte_o                   <= (others => '0');
      s_base_addr              <= (others => '0');

    end case;
  end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Synchronous process Delay_byte_index_i: in the combinatorial process Bytes_Generation,
-- according to the value of the signal s_byte_index_d1, a byte is retrieved either from the memory,
-- or from the WF_PACKAGE or from the wf_status_bytes_gen or wf_model_constr_decoder units.
-- Since the memory needs one clock cycle to output its data (as opposed to the other units that
-- have them ready) the signal s_byte_index_d1 has to be a delayed version of the byte_index_i
-- (byte_index_i is the signal used as address for the mem; s_byte_index_d1 is the delayed one
-- used for the other units).

  Delay_byte_index_i: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        s_byte_index_d1 <= (others => '0');
      else

        s_byte_index_d1 <= byte_index_i;   -- index of byte to be sent
      end if;
    end if;
  end process;



---------------------------------------------------------------------------------------------------
--                                       Auxiliary signals                                       --
---------------------------------------------------------------------------------------------------

  s_mem_addr_A       <= std_logic_vector (s_base_addr + s_mem_addr_offset - 1);
  -- address of the byte to be read from memory: base_address(from WF_PACKAGE) + byte_index_i - 1
  -- (the -1 is because the byte_index_i counts also the CTRL byte, that is not part of the
  -- memory; for example when byte_index_i is 3 which means that the CTRL, PDU_TYPE and LGTH
  -- bytes have preceded and a byte from the memory is now requested, the byte from the memory cell
  -- 2 (00000010) has to be retrieved).

  s_mem_addr_offset  <= (resize((unsigned(byte_index_i)), s_mem_addr_offset'length));

  s_byte_index_d_aux <= (to_integer(unsigned(s_byte_index_d1(3 downto 0))));
                                                      -- index of byte to be sent(range restricted)
                                                      -- used to retreive bytes from the matrix
                                                      -- c_VARS_ARRAY.byte_array, with a predefined
                                                      -- width of 15 bytes

  s_lgth_byte        <= std_logic_vector (resize((unsigned(data_lgth_i)-2),byte_o'length));
                                                      -- represents the RP_DAT.Data.LGTH byte
                                                      -- it includes the # bytes of user-data
                                                      -- (P3_LGTH) plus 1 byte of MPS_status
                                                      -- plus 1 byte of nanoFIP_status, if
                                                      -- applicable. It does not include the
                                                      -- CTRL byte and itself.


end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------