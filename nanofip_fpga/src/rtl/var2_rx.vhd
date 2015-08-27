-------------------------------------------------------------------------------
--! @file      var2_rx.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2013-10-24
--! @brief     NanoFIP VAR2 data receiver.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

--! @brief Entity declaration of var2_rx
--! @details
--! Whenever VAR2 data is received from the NanoFIP field-bus, this component
--! ensures correct handling of the address space within the NanoFIP core.
--! Each FGClite receives 4 bytes of data according to its station ID.

entity var2_rx is
  port (
    --! @name Clock and resets
    --! @{

    --! System clock
    clk_i       : in std_ulogic;
    --! Asynchronous active-low reset
    rst_asy_n_i : in std_ulogic;
    --! Synchronous active-high reset
    rst_syn_i   : in std_ulogic;

    --! @}
    --! @name FGClite interface
    --! @{

    --! The FGClite station ID
    station_id_i : in std_ulogic_vector(4 downto 0);
    --! Signal reception of FGClite command 0
    cmd_0_o      : out std_ulogic;

    --! @}
    --! @name Receiver interface
    --! @{

    --! Data is ready to be received
    rx_rdy_i     : in  std_ulogic;
    --! Read address
    rx_addr_o    : out std_ulogic_vector(6 downto 0);
    --! Read enable
    rx_en_o      : out std_ulogic;
    --! Read data input
    rx_data_i    : in  std_ulogic_vector(7 downto 0);
    --! Read data input enable
    rx_data_en_i : in  std_ulogic;

    --! @}
    --! @name VAR2 interface
    --! @{

    --! Received data for serial transmission
    tx_data_o    : out std_ulogic_vector(39 downto 0);
    --! Received data enable
    tx_data_en_o : out std_ulogic;
    --! Transmitter busy
    tx_bsy_i     : in  std_ulogic;

    --! @}
    --! @name Error flags
    --! @{

    --! Read-write collision
    err_rw_coll_i : in std_ulogic;
    --! Interface busy
    err_bsy_i     : in std_ulogic;
    --! VAR not ready
    err_not_rdy_i : in std_ulogic;
    --! Wishbone bus acknowledge timeout
    err_timeout_i : in std_ulogic);

    --! @}
end entity var2_rx;

--! RTL implementation of var2_rx
architecture rtl of var2_rx is

  ---------------------------------------------------------------------------
  -- Types and Constants
  ---------------------------------------------------------------------------

  --! Base address for data payload
  constant base_addr_c : natural  := 2;
  --! Number of payload bytes for VAR2
  constant num_data_c  : positive := 4;

  --! Data array
  type data_t is array (0 to num_data_c - 1) of std_ulogic_vector(7 downto 0);

  --! FSM states
  type state_t is (IDLE, REQ_CMD, STORE_CMD, REQ_DATA, STORE_DATA, SEND, INIT);

  --! FSM registers
  type reg_t is record
    state   : state_t;
    wb_addr : unsigned(6 downto 0);
    wb_en   : std_ulogic;
    num     : unsigned(integer(ceil(log2(real(num_data_c)))) - 1 downto 0);
    cmd     : std_ulogic_vector(7 downto 0);
    data    : data_t;
    data_en : std_ulogic;
    cmd_0   : std_ulogic;
  end record reg_t;

  --! FSM initial state
  constant init_c : reg_t := (
    state   => IDLE,
    wb_addr => to_unsigned(base_addr_c, 7),
    wb_en   => '0',
    num     => (others => '0'),
    cmd     => (others => '0'),
    data    => (others => (others => '0')),
    data_en => '0',
    cmd_0   => '0');

  ---------------------------------------------------------------------------
  --! @name Internal Registers
  ---------------------------------------------------------------------------
  --! @{

  signal reg : reg_t;

  --! @}
  ---------------------------------------------------------------------------
  --! @name Internal Wires
  ---------------------------------------------------------------------------
  --! @{

  signal next_reg  : reg_t;
  signal wb_if_err : std_ulogic;
  signal data_addr : unsigned(6 downto 0);

  --! @}

begin -- architecture rtl

  ---------------------------------------------------------------------------
  -- Outputs
  ---------------------------------------------------------------------------

  rx_addr_o <= std_ulogic_vector(reg.wb_addr);
  rx_en_o   <= reg.wb_en;

  tx_data_o    <= reg.cmd & reg.data(3) & reg.data(2) & reg.data(1) & reg.data(0);
  tx_data_en_o <= reg.data_en;

  cmd_0_o <= reg.cmd_0;

  ---------------------------------------------------------------------------
  -- Signal Assignments
  ---------------------------------------------------------------------------

  -- Combine errors into one signal
  wb_if_err <= err_rw_coll_i or err_not_rdy_i or err_timeout_i or err_bsy_i;

  -- Calculate memory address based on station ID
  data_addr <= resize(base_addr_c + (unsigned(station_id_i) * num_data_c), data_addr'length);

  ---------------------------------------------------------------------------
  -- Registers
  ---------------------------------------------------------------------------

  regs : process (clk_i, rst_asy_n_i) is
    procedure reset is
    begin
      reg <= init_c;
    end procedure reset;
  begin -- process regs
    if rst_asy_n_i = '0' then
      reset;
    elsif rising_edge(clk_i) then
      if rst_syn_i = '1' then
        reset;
      else
        reg <= next_reg;
      end if;
    end if;
  end process regs;

  ---------------------------------------------------------------------------
  -- Combinatorics
  ---------------------------------------------------------------------------

  comb : process (reg, rx_rdy_i, rx_data_i, rx_data_en_i, wb_if_err, data_addr, tx_bsy_i) is
  begin -- process comb
    -- Defaults
    next_reg <= reg;

    next_reg.wb_en   <= '0';
    next_reg.data_en <= '0';

    case reg.state is
      when IDLE =>
        if rx_rdy_i = '1' then
          next_reg.state <= REQ_CMD;
        end if;

      when REQ_CMD =>
        next_reg.wb_addr <= to_unsigned(base_addr_c, reg.wb_addr'length);
        next_reg.wb_en   <= '1';
        next_reg.state   <= STORE_CMD;

      when STORE_CMD =>
        if rx_data_en_i = '1' then
          next_reg.cmd   <= rx_data_i;

          if rx_data_i = x"00" then
            next_reg.cmd_0 <= '1';
          end if;

          next_reg.state <= REQ_DATA;
        end if;

      when REQ_DATA =>
        next_reg.wb_addr <= data_addr + reg.num;
        next_reg.wb_en   <= '1';
        next_reg.state   <= STORE_DATA;

      when STORE_DATA =>
        if rx_data_en_i = '1' then
          next_reg.data(to_integer(reg.num)) <= rx_data_i;

          if to_integer(reg.num) < num_data_c - 1 then
            next_reg.num   <= reg.num + 1;
            next_reg.state <= REQ_DATA;
          else
            next_reg.state <= SEND;
          end if;
        end if;

      when SEND =>
        if tx_bsy_i = '0' then
          next_reg.data_en <= '1';
          next_reg.state <= INIT;
        end if;

      when INIT =>
        next_reg <= init_c;
    end case;

    -- Reset on error
    if wb_if_err = '1' then
      next_reg <= init_c;
    end if;
  end process comb;

end architecture rtl;
