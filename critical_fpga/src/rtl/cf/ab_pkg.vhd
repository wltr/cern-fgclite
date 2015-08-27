-------------------------------------------------------------------------------
--! @file      ab_pkg.vhd
--! @author    Johannes Walter <johannes.walter@cern.ch>
--! @copyright CERN TE-EPC-CCE
--! @date      2014-07-09
--! @brief     Analogue board package.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

--! @brief Package declaration of ab_pkg
--! @details
--! This provides types and constants for the analogue board component.

package ab_pkg is

  ---------------------------------------------------------------------------
  -- Types and Constants
  ---------------------------------------------------------------------------

  type ab_in_t is record
    --! @brief Signals from analogue board
    --! @param adc_vs     ADC V_MEAS bit streams M1 and M0
    --! @param adc_vs_clk ADC V_MEAS bit stream clock
    --! @param adc_a      ADC I_A bit streams M1 and M0
    --! @param adc_a_clk  ADC I_A bit stream clock
    --! @param adc_b      ADC I_B bit streams M1 and M0
    --! @param adc_b_clk  ADC I_B bit stream clock
    adc_vs     : std_ulogic_vector(1 downto 0);
    adc_vs_clk : std_ulogic;
    adc_a      : std_ulogic_vector(1 downto 0);
    adc_a_clk  : std_ulogic;
    adc_b      : std_ulogic_vector(1 downto 0);
    adc_b_clk  : std_ulogic;
  end record ab_in_t;

  type ab_out_t is record
    --! @brief Signals to analogue board
    --! @param temp_stop    Stop temperature control
    --! @param pwr_on_n     Power control (active-low)
    --! @param cal_dac      Set calibration source to DAC
    --! @param cal_offset   Set calibration source to GND
    --! @param cal_vref_p   Set calibration source to +VREF
    --! @param cal_vref_n   Set calibration source to -VREF
    --! @param dac_din      DAC data
    --! @param dac_sclk     DAC clock
    --! @param dac_cs       DAC chip-select
    --! @param adc_vs_rst_n ADC V_MEAS reset (active-low)
    --! @param sw_in_vs     Calibrate ADC V_MEAS
    --! @param adc_a_rst_n  ADC I_A reset (active-low)
    --! @param sw_in_a      Calibrate ADC I_A
    --! @param adc_b_rst_n  ADC I_B reset (active-low)
    --! @param sw_in_b      Calibrate ADC I_B
    temp_stop    : std_ulogic;
    pwr_on_n     : std_ulogic;
    cal_dac      : std_ulogic;
    cal_offset   : std_ulogic;
    cal_vref_p   : std_ulogic;
    cal_vref_n   : std_ulogic;
    dac_din      : std_ulogic;
    dac_sclk     : std_ulogic;
    dac_cs       : std_ulogic;
    adc_vs_rst_n : std_ulogic;
    sw_in_vs     : std_ulogic;
    adc_a_rst_n  : std_ulogic;
    sw_in_a      : std_ulogic;
    adc_b_rst_n  : std_ulogic;
    sw_in_b      : std_ulogic;
  end record ab_out_t;

end package ab_pkg;
