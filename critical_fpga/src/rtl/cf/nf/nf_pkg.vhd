-------------------------------------------------------------------------------
--! @file      nf_pkg.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-07-11
--! @brief     NanoFIP package.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

--! @brief Package declaration of nf_pkg
--! @details
--! This provides types and constants for the NanoFIP component.

package nf_pkg is

  ---------------------------------------------------------------------------
  -- Types and Constants
  ---------------------------------------------------------------------------

  type nf_in_t is record
    --! @brief Signals from NanoFIP
    --! @param cmd_0     NF received FGClite CMD 0
    --! @param tx_rdy    NF transmitter ready
    --! @param r_fcser   NanoFIP status byte - bit 5
    --! @param r_tler    NanoFIP status byte - bit 4
    --! @param u_cacer   NanoFIP status byte - bit 2
    --! @param u_pacer   NanoFIP status byte - bit 3
    --! @param rx_frame  NF serial frame
    --! @param rx_bit_en NF serial bit enable
    --! @param rx        NF serial data
    cmd_0     : std_ulogic;
    tx_rdy    : std_ulogic;
    r_fcser   : std_ulogic;
    r_tler    : std_ulogic;
    u_cacer   : std_ulogic;
    u_pacer   : std_ulogic;
    rx_frame  : std_ulogic;
    rx_bit_en : std_ulogic;
    rx        : std_ulogic;
  end record nf_in_t;

  type nf_out_t is record
    --! @brief Signals to NanoFIP
    --! @param tx_frame  NF serial frame
    --! @param tx_bit_en NF serial bit enable
    --! @param tx        NF serial data
    tx_frame  : std_ulogic;
    tx_bit_en : std_ulogic;
    tx        : std_ulogic;
  end record nf_out_t;

  type nf_command_t is record
    --! @brief Commands received from gateway

    -- Command 0
    sefi_test_vs_m0 : std_ulogic_vector(1 downto 0);
    sefi_test_vs_m1 : std_ulogic_vector(1 downto 0);
    sefi_test_ia_m0 : std_ulogic_vector(1 downto 0);
    sefi_test_ia_m1 : std_ulogic_vector(1 downto 0);
    sefi_test_ib_m0 : std_ulogic_vector(1 downto 0);
    sefi_test_ib_m1 : std_ulogic_vector(1 downto 0);
    ms_period       : std_ulogic_vector(15 downto 0);

    -- Command 1
    serial_data     : std_ulogic_vector(31 downto 0);
    serial_data_en  : std_ulogic;

    -- Command 2
    index           : std_ulogic_vector(14 downto 0);
    index_type      : std_ulogic_vector(2 downto 0);
    adc_log_freeze  : std_ulogic;
    dim_log_freeze  : std_ulogic;
    dim_reset       : std_ulogic;
    ow_scan         : std_ulogic;
    ow_bus_select   : std_ulogic_vector(2 downto 0);

    -- Command 3
    v_ref           : std_ulogic_vector(15 downto 0);
    cal_source      : std_ulogic_vector(1 downto 0);
    cal_vs_en       : std_ulogic;
    cal_ia_en       : std_ulogic;
    cal_ib_en       : std_ulogic;
    adc_vs_reset_n  : std_ulogic;
    adc_ia_reset_n  : std_ulogic;
    adc_ib_reset_n  : std_ulogic;
    vs_cmd          : std_ulogic_vector(7 downto 0);
  end record nf_command_t;

  type nf_status_t is record
    --! @brief Status transmitted to gateway
    adc_acc_vs_0      : std_ulogic_vector(31 downto 0);
    adc_acc_vs_0_en   : std_ulogic;

    adc_acc_vs_1      : std_ulogic_vector(31 downto 0);
    adc_acc_vs_1_en   : std_ulogic;

    adc_acc_ia_0      : std_ulogic_vector(31 downto 0);
    adc_acc_ia_0_en   : std_ulogic;

    adc_acc_ia_1      : std_ulogic_vector(31 downto 0);
    adc_acc_ia_1_en   : std_ulogic;

    adc_acc_ib_0      : std_ulogic_vector(31 downto 0);
    adc_acc_ib_0_en   : std_ulogic;

    adc_acc_ib_1      : std_ulogic_vector(31 downto 0);
    adc_acc_ib_1_en   : std_ulogic;

    dim_a_trig_lat    : std_ulogic_vector(15 downto 0);
    dim_a_trig_lat_en : std_ulogic;

    dim_a_trig_unl    : std_ulogic_vector(15 downto 0);
    dim_a_trig_unl_en : std_ulogic;

    dim_a1_ana_0      : std_ulogic_vector(15 downto 0);
    dim_a1_ana_0_en   : std_ulogic;

    dim_a1_ana_1      : std_ulogic_vector(15 downto 0);
    dim_a1_ana_1_en   : std_ulogic;

    dim_a1_ana_2      : std_ulogic_vector(15 downto 0);
    dim_a1_ana_2_en   : std_ulogic;

    dim_a1_ana_3      : std_ulogic_vector(15 downto 0);
    dim_a1_ana_3_en   : std_ulogic;

    cycle_period      : std_ulogic_vector(31 downto 0);
    cycle_period_en   : std_ulogic;

    version_cfnf      : std_ulogic_vector(7 downto 0);
    version_cfnf_en   : std_ulogic;

    version_xfpf      : std_ulogic_vector(7 downto 0);
    version_xfpf_en   : std_ulogic;

    adc_log_idx       : std_ulogic_vector(15 downto 0);
    adc_log_idx_en    : std_ulogic;

    dim_log_idx       : std_ulogic_vector(15 downto 0);
    dim_log_idx_en    : std_ulogic;

    vs_dig_in         : std_ulogic_vector(15 downto 0);
    vs_dig_in_en      : std_ulogic;

    vs_dig_out        : std_ulogic_vector(7 downto 0);
    vs_dig_out_en     : std_ulogic;

    seu_count         : std_ulogic_vector(7 downto 0);
    seu_count_en      : std_ulogic;

    fgc_status        : std_ulogic_vector(15 downto 0);
    fgc_status_en     : std_ulogic;

    backplane         : std_ulogic_vector(7 downto 0);
    backplane_en      : std_ulogic;

    serial_data       : std_ulogic_vector(7 downto 0);
    serial_num        : std_ulogic_vector(3 downto 0);
    serial_data_en    : std_ulogic;
  end record nf_status_t;

end package nf_pkg;
