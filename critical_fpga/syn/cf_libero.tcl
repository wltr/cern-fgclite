new_project \
  -location {c:/build/cf} \
  -name {cf} \
  -project_description {} \
  -block_mode 0 \
  -hdl {VHDL} \
  -family {ProASIC3E} \
  -die {A3PE1500} \
  -package {208 PQFP} \
  -speed {STD} \
  -die_voltage {1.5} \
  -adv_options {IO_DEFT_STD:LVTTL} \
  -adv_options {RESTRICTPROBEPINS:1} \
  -adv_options {TEMPR:COM} \
  -adv_options {VCCI_1.5_VOLTR:COM} \
  -adv_options {VCCI_1.8_VOLTR:COM} \
  -adv_options {VCCI_2.5_VOLTR:COM} \
  -adv_options {VCCI_3.3_VOLTR:COM} \
  -adv_options {VOLTR:COM}

create_links \
  -sdc {./cf.sdc} \
  -sdc {./cf_syn.sdc} \
  -pdc {./cf.pdc}

create_links \
  -hdl_source {../src/rtl/cf_top.vhd} \
  -hdl_source {../src/rtl/cf.vhd} \
  -hdl_source {../src/rtl/cf/ab.vhd} \
  -hdl_source {../src/rtl/cf/pf.vhd} \
  -hdl_source {../src/rtl/cf/ab_pkg.vhd} \
  -hdl_source {../src/rtl/cf/cf_pkg.vhd} \
  -hdl_source {../src/rtl/cf/fetch_page.vhd} \
  -hdl_source {../src/rtl/cf/fetch_page/fetch_page_dim.vhd} \
  -hdl_source {../src/rtl/cf/fetch_page/fetch_page_ow.vhd} \
  -hdl_source {../src/rtl/cf/fetch_page/fetch_page_sram_adc.vhd} \
  -hdl_source {../src/rtl/cf/fetch_page/fetch_page_sram_dim.vhd} \
  -hdl_source {../src/rtl/cf/debug_serial.vhd} \
  -hdl_source {../src/rtl/cf/field_bus_serial.vhd} \
  -hdl_source {../src/rtl/cf/field_bus_timing.vhd} \
  -hdl_source {../src/rtl/cf/nf.vhd} \
  -hdl_source {../src/rtl/cf/sefi_detector.vhd} \
  -hdl_source {../src/rtl/cf/sefi_detector_test.vhd} \
  -hdl_source {../src/rtl/cf/sram.vhd} \
  -hdl_source {../src/rtl/cf/sram_pkg.vhd} \
  -hdl_source {../src/rtl/cf/xf.vhd} \
  -hdl_source {../src/rtl/cf/xf_pkg.vhd} \
  -hdl_source {../src/rtl/cf/nf/nf_pkg.vhd} \
  -hdl_source {../src/rtl/cf/nf/nf_rx_registers.vhd} \
  -hdl_source {../src/rtl/cf/nf/nf_tx_registers.vhd} \
  -hdl_source {../src/rtl/cf/nf/nf_transmitter.vhd}

create_links \
  -hdl_source {../../../../common/vhd/communication/serial_3wire_transceiver/src/rtl/serial_3wire_rx.vhd} \
  -hdl_source {../../../../common/vhd/communication/serial_3wire_transceiver/src/rtl/serial_3wire_tx.vhd} \
  -hdl_source {../../../../common/vhd/communication/uart/src/rtl/uart_rx.vhd} \
  -hdl_source {../../../../common/vhd/communication/uart/src/rtl/uart_tx.vhd} \
  -hdl_source {../../../../common/vhd/interfaces/sram_interface/src/rtl/sram_interface.vhd} \
  -hdl_source {../../../../common/vhd/interfaces/max5541_interface/src/rtl/max5541_interface.vhd} \
  -hdl_source {../../../../common/vhd/generic/external_inputs/src/rtl/external_inputs.vhd} \
  -hdl_source {../../../../common/vhd/generic/array_transmitter/src/rtl/array_tx.vhd} \
  -hdl_source {../../../../common/vhd/generic/microsemi_reset_generator/src/rtl/microsemi_reset_generator.vhd} \
  -hdl_source {../../../../common/vhd/generic/reset_generator/src/rtl/reset_generator.vhd} \
  -hdl_source {../../../../common/vhd/generic/delay/src/rtl/delay.vhd} \
  -hdl_source {../../../../common/vhd/generic/glitch_filter/src/rtl/glitch_filter.vhd} \
  -hdl_source {../../../../common/vhd/generic/bit_clock_recovery/src/rtl/bit_clock_recovery.vhd} \
  -hdl_source {../../../../common/vhd/generic/edge_detector/src/rtl/edge_detector.vhd} \
  -hdl_source {../../../../common/vhd/generic/lfsr_strobe_generator/src/rtl/lfsr_strobe_generator.vhd} \
  -hdl_source {../../../../common/vhd/generic/strobe_generator/src/rtl/strobe_generator.vhd} \
  -hdl_source {../../../../common/vhd/generic/stop_watch/src/rtl/stop_watch.vhd} \
  -hdl_source {../../../../common/vhd/packages/lfsr/src/rtl/lfsr_pkg.vhd} \
  -hdl_source {../../../../common/vhd/ads1281_filter/src/rtl/ads1281_result_accumulator.vhd} \
  -hdl_source {../../../../common/vhd/ads1281_filter/src/rtl/ads1281_filter.vhd} \
  -hdl_source {../../../../common/vhd/ads1281_filter/src/rtl/ads1281_filter/ads1281_filter_accumulator.vhd} \
  -hdl_source {../../../../common/vhd/ads1281_filter/src/rtl/ads1281_filter/ads1281_filter_channel.vhd} \
  -hdl_source {../../../../common/vhd/ads1281_filter/src/rtl/ads1281_filter/ads1281_filter_coefficients.vhd} \
  -hdl_source {../../../../common/vhd/ads1281_filter/src/rtl/ads1281_filter/ads1281_filter_decoder.vhd} \
  -hdl_source {../../../../common/vhd/ads1281_filter/src/rtl/ads1281_filter/ads1281_filter_fifo.vhd} \
  -hdl_source {../../../../common/vhd/ads1281_filter/src/rtl/ads1281_filter/ads1281_filter_mac.vhd} \
  -hdl_source {../../../../common/vhd/ads1281_filter/src/rtl/ads1281_filter/ads1281_filter_multiplier.vhd} \
  -hdl_source {../../../../common/vhd/ads1281_filter/src/rtl/ads1281_filter/ads1281_filter_output.vhd} \
  -hdl_source {../../../../common/vhd/ads1281_filter/src/rtl/ads1281_filter/ads1281_filter_pkg.vhd} \
  -hdl_source {../../../../common/vhd/ads1281_filter/src/rtl/ads1281_filter/ads1281_filter_roots.vhd} \
  -hdl_source {../../../../common/vhd/ads1281_filter/src/rtl/ads1281_filter/ads1281_filter_sampling.vhd} \
  -hdl_source {../../../../common/vhd/ads1281_filter/src/rtl/ads1281_filter/ads1281_filter_select.vhd} \
  -hdl_source {../../../../common/vhd/generic/mem_data_triplicator/src/rtl/mem_data_triplicator.vhd} \
  -hdl_source {../../../../common/vhd/generic/mem_data_triplicator/src/rtl/mem_data_triplicator/mem_data_triplicator_addr.vhd} \
  -hdl_source {../../../../common/vhd/generic/mem_data_triplicator/src/rtl/mem_data_triplicator/mem_data_triplicator_rd.vhd} \
  -hdl_source {../../../../common/vhd/generic/mem_data_triplicator/src/rtl/mem_data_triplicator/mem_data_triplicator_wr.vhd} \
  -hdl_source {../../../../common/vhd/generic/mem_data_triplicator/src/rtl/mem_data_triplicator_rd_only.vhd} \
  -hdl_source {../../../../common/vhd/generic/mem_data_triplicator/src/rtl/mem_data_triplicator_wr_only.vhd} \
  -hdl_source {../../../../common/vhd/memory/fifo/src/rtl/fifo.vhd} \
  -hdl_source {../../../../common/vhd/memory/fifo/src/rtl/fifo_tmr.vhd} \
  -hdl_source {../../../../common/vhd/memory/two_port_ram/src/rtl/two_port_ram.vhd} \
  -hdl_source {../../../../common/vhd/memory/two_port_ram/src/rtl/two_port_ram_tmr.vhd}

set_root -module {cf_top::work}

organize_tool_files \
  -tool {SYNTHESIZE} \
  -file {./cf_syn.sdc} \
  -module {cf_top::work} \
  -input_type {constraint}

organize_tool_files \
  -tool {COMPILE} \
  -file {./cf.sdc} \
  -file {./cf.pdc} \
  -module {cf_top::work} \
  -input_type {constraint}

save_project
