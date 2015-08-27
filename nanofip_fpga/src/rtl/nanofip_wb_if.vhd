-------------------------------------------------------------------------------
--! @file      nanofip_wb_if.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2013-10-24
--! @brief     NanoFIP Wishbone bus interface.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

--! @brief Entity declaration of nanofip_wb_if
--! @details
--! This component provides an interface for the NanoFIP Wishbone bus and
--! performs error detection for read and write cycles.

entity nanofip_wb_if is
  generic (
    --! Number of clock cycles before watchdog times out
    watchdog_max_g : positive := 32);
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
    --! @name NanoFIP packet control signals
    --! @{

    --! VAR1_RDY from NanoFIP
    var1_rdy_i : in  std_ulogic;
    --! VAR1_ACC to NanoFIP
    var1_acc_o : out std_ulogic;
    --! VAR2_RDY from NanoFIP
    var2_rdy_i : in  std_ulogic;
    --! VAR2_ACC to NanoFIP
    var2_acc_o : out std_ulogic;
    --! VAR3_RDY from NanoFIP
    var3_rdy_i : in  std_ulogic;
    --! VAR3_ACC to NanoFIP
    var3_acc_o : out std_ulogic;

    --! @}
    --! @name NanoFIP Wishbone bus
    --! @{

    --! Clock
    wb_clk_o  : out std_ulogic;
    --! Reset (active-high)
    wb_rst_o  : out std_ulogic;
    --! Address
    wb_addr_o : out std_ulogic_vector(9 downto 0);
    --! Data input
    wb_data_i : in  std_ulogic_vector(7 downto 0);
    --! Data output
    wb_data_o : out std_ulogic_vector(7 downto 0);
    --! Write enable
    wb_we_o   : out std_ulogic;
    --! Strobe
    wb_stb_o  : out std_ulogic;
    --! Cycle
    wb_cyc_o  : out std_ulogic;
    --! Acknowledge
    wb_ack_i  : in  std_ulogic;

    --! @}
    --! @name Receiver interface
    --! @{

    --! Signal that a VAR1 has been received
    rx_var1_rdy_o : out std_ulogic;
    --! Signal that a VAR2 has been received
    rx_var2_rdy_o : out std_ulogic;
    --! Select which VAR to access, 0 = VAR1, 1 = VAR2
    rx_var_sel_i  : in  std_ulogic;
    --! Read address
    rx_addr_i     : in  std_ulogic_vector(6 downto 0);
    --! Read enable
    rx_en_i       : in  std_ulogic;
    --! Read data output
    rx_data_o     : out std_ulogic_vector(7 downto 0);
    --! Read data output enable
    rx_data_en_o  : out std_ulogic;

    --! @}
    --! @name Transmitter interface
    --! @{

    --! Indicate if VAR3 can be written
    tx_rdy_o  : out std_ulogic;
    --! Write address
    tx_addr_i : in  std_ulogic_vector(6 downto 0);
    --! Write enable
    tx_en_i   : in  std_ulogic;
    --! Write data input
    tx_data_i : in  std_ulogic_vector(7 downto 0);
    --! Signal end of write operation
    tx_done_o : out std_ulogic;

    --! @}
    --! @name Error flags
    --! @{

    --! Read-write collision
    err_rw_coll_o : out std_ulogic;
    --! Interface busy
    err_bsy_o     : out std_ulogic;
    --! VAR not ready
    err_not_rdy_o : out std_ulogic;
    --! Wishbone bus acknowledge timeout
    err_timeout_o : out std_ulogic);

    --! @}
end entity nanofip_wb_if;

--! RTL implementation of nanofip_wb_if
architecture rtl of nanofip_wb_if is

  ---------------------------------------------------------------------------
  -- Types and Constants
  ---------------------------------------------------------------------------

  --! Most significant address bits for VAR1 and VAR2
  constant var1_var2_addr_msbs_c : std_ulogic_vector(1 downto 0) := "00";
  --! Most significant address bits for VAR3
  constant var3_addr_msbs_c      : std_ulogic_vector(2 downto 0) := "010";

  ---------------------------------------------------------------------------
  --! @name Internal Registers
  ---------------------------------------------------------------------------
  --! @{

  signal var1_acc : std_ulogic;
  signal var2_acc : std_ulogic;
  signal var3_acc : std_ulogic;

  signal addr    : std_ulogic_vector(9 downto 0);
  signal we      : std_ulogic;
  signal stb_cyc : std_ulogic;

  signal rx_data    : std_ulogic_vector(7 downto 0);
  signal rx_data_en : std_ulogic;

  signal tx_rdy  : std_ulogic;
  signal tx_data : std_ulogic_vector(7 downto 0);
  signal tx_done : std_ulogic;

  signal err_rw_coll : std_ulogic;
  signal err_bsy     : std_ulogic;
  signal err_not_rdy : std_ulogic;
  signal err_timeout : std_ulogic;

  signal watchdog : unsigned(integer(ceil(log2(real(watchdog_max_g)))) - 1 downto 0);

  --! @}
  ---------------------------------------------------------------------------
  --! @name Internal Wires
  ---------------------------------------------------------------------------
  --! @{

  signal var1_rdy : std_ulogic;
  signal var2_rdy : std_ulogic;

  signal rx_not_rdy : std_ulogic;
  signal tx_not_rdy : std_ulogic;

  signal rx_en : std_ulogic;
  signal tx_en : std_ulogic;

  --! @}

begin -- architecture rtl

  ---------------------------------------------------------------------------
  -- Outputs
  ---------------------------------------------------------------------------

  var1_acc_o <= var1_acc;
  var2_acc_o <= var2_acc;
  var3_acc_o <= var3_acc;

  wb_clk_o  <= clk_i;
  wb_rst_o  <= rst_syn_i;
  wb_addr_o <= addr;
  wb_data_o <= tx_data;
  wb_we_o   <= we;
  wb_stb_o  <= stb_cyc;
  wb_cyc_o  <= stb_cyc;

  rx_var1_rdy_o <= var1_rdy;
  rx_var2_rdy_o <= var2_rdy;
  rx_data_o     <= rx_data;
  rx_data_en_o  <= rx_data_en;

  tx_rdy_o  <= tx_rdy;
  tx_done_o <= tx_done;

  err_rw_coll_o <= err_rw_coll;
  err_bsy_o     <= err_bsy;
  err_not_rdy_o <= err_not_rdy;
  err_timeout_o <= err_timeout;

  ---------------------------------------------------------------------------
  -- Signal Assignments
  ---------------------------------------------------------------------------

  -- Check for errors when variable is read
  rx_not_rdy <= rx_en_i and (not var1_rdy_i) when rx_var_sel_i = '0' else
         rx_en_i and (not var2_rdy_i) when rx_var_sel_i = '1' else
         '0';

  -- Check for errors when variable is written
  tx_not_rdy <= tx_en_i and (not var3_rdy_i);

  -- Check if variable to be read is ready
  rx_en <= rx_en_i and var1_rdy_i and (not tx_en_i) when rx_var_sel_i = '0' else
       rx_en_i and var2_rdy_i and (not tx_en_i) when rx_var_sel_i = '1' else
       '0';

  -- Check if variable to be written is ready
  tx_en <= tx_en_i and var3_rdy_i and (not rx_en_i);

  ---------------------------------------------------------------------------
  -- Instances
  ---------------------------------------------------------------------------

  --! Detect rising edge of VAR1_RDY flag
  var1_edge_detect_inst : entity work.edge_detector
    generic map (
      init_value_g => '0',
      edge_type_g  => 0,
      hold_flag_g  => false)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,
      en_i        => '1',
      ack_i       => '1',
      sig_i       => var1_rdy_i,
      edge_o      => var1_rdy);

  --! Detect rising edge of VAR2_RDY flag
  var2_edge_detect_inst : entity work.edge_detector
    generic map (
      init_value_g => '0',
      edge_type_g  => 0,
      hold_flag_g  => false)
    port map (
      clk_i       => clk_i,
      rst_asy_n_i => rst_asy_n_i,
      rst_syn_i   => rst_syn_i,
      en_i        => '1',
      ack_i       => '1',
      sig_i       => var2_rdy_i,
      edge_o      => var2_rdy);

  ---------------------------------------------------------------------------
  -- Registering
  ---------------------------------------------------------------------------

  intf : process (clk_i, rst_asy_n_i) is
    procedure reset is
    begin
      var1_acc <= '0';
      var2_acc <= '0';
      var3_acc <= '0';

      addr    <= (others => '0');
      we      <= '0';
      stb_cyc <= '0';

      rx_data    <= (others => '0');
      rx_data_en <= '0';

      tx_rdy  <= '0';
      tx_data <= (others => '0');
      tx_done <= '0';

      err_rw_coll <= '0';
      err_bsy     <= '0';
      err_not_rdy <= '0';
      err_timeout <= '0';

      watchdog <= to_unsigned(0, watchdog'length);
    end procedure reset;
  begin -- process intf
    if rst_asy_n_i = '0' then
      reset;
    elsif rising_edge(clk_i) then
      if rst_syn_i = '1' then
        reset;
      else
        -- Default values for enable flags
        rx_data_en <= '0';
        tx_done    <= '0';

        -- Signal if VAR3 can be written
        tx_rdy <= var3_rdy_i and (not stb_cyc);

        -- Detect read-write collision
        err_rw_coll <= rx_en_i and tx_en_i;

        -- Detect access attempts during running cycle
        err_bsy <= stb_cyc and (rx_en_i or tx_en_i);

        -- Detect access attempt when NanoFIP is not ready
        err_not_rdy <= rx_not_rdy or tx_not_rdy;

        -- Default value for timeout error
        err_timeout <= '0';

        if stb_cyc = '0' then
          -- Wishbone cycle is idle
          if rx_en = '1' then
            -- Read operation
            addr     <= var1_var2_addr_msbs_c & rx_var_sel_i & rx_addr_i;
            we       <= '0';
            stb_cyc  <= '1';
            var1_acc <= not rx_var_sel_i;
            var2_acc <= rx_var_sel_i;
          elsif tx_en = '1' then
            -- Write operation
            addr     <= var3_addr_msbs_c & tx_addr_i;
            tx_data  <= tx_data_i;
            we       <= '1';
            stb_cyc  <= '1';
            var3_acc <= '1';
          end if;
        else
          -- Wishbone cycle is running
          -- Increment watchdog
          watchdog <= watchdog + 1;

          if wb_ack_i = '1' then
            -- Received acknowledge
            if we = '0' then
              -- Save data after a read cycle
              rx_data    <= wb_data_i;
              rx_data_en <= '1';
            else
              -- Signal success after a write cycle
              tx_done <= '1';
            end if;

            -- Stop cycle
            stb_cyc  <= '0';
            we       <= '0';
            var1_acc <= '0';
            var2_acc <= '0';
            var3_acc <= '0';
            watchdog <= to_unsigned(0, watchdog'length);
          elsif to_integer(watchdog) = watchdog_max_g - 1 then
            -- Watchdog timed out
            err_timeout <= '1';
            stb_cyc     <= '0';
            we          <= '0';
            var1_acc    <= '0';
            var2_acc    <= '0';
            var3_acc    <= '0';
            watchdog    <= to_unsigned(0, watchdog'length);
          end if;
        end if;
      end if;
    end if;
  end process intf;

end architecture rtl;
