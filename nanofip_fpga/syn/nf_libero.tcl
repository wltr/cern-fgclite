new_project \
  -location {c:/build/nf} \
  -name {nf} \
  -project_description {} \
  -block_mode 0 \
  -hdl {VHDL} \
  -family {ProASIC3} \
  -die {A3P400} \
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
  -sdc {./nf.sdc} \
  -sdc {./nf_syn.sdc} \
  -pdc {./nf.pdc}

create_links \
  -hdl_source {../src/rtl/nf_top.vhd} \
  -hdl_source {../src/rtl/nf_pkg.vhd} \
  -hdl_source {../src/rtl/nanofip_wb_if.vhd} \
  -hdl_source {../src/rtl/nanofip.vhd} \
  -hdl_source {../src/rtl/rx_var_select.vhd} \
  -hdl_source {../src/rtl/var1_rx.vhd} \
  -hdl_source {../src/rtl/var2_rx.vhd} \
  -hdl_source {../src/rtl/nanofip/dualram_512x8.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_cons_bytes_processor.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_cons_outcome.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_consumption.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_crc.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_decr_counter.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_dualram_512x8_clka_rd_clkb_wr.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_engine_control.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_fd_receiver.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_fd_transmitter.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_incr_counter.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_jtag_controller.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_model_constr_decoder.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_package.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_prod_bytes_retriever.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_prod_data_lgth_calc.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_prod_permit.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_production.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_reset_unit.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_rx_deglitcher.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_rx_deserializer.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_rx_osc.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_status_bytes_gen.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_tx_osc.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_tx_serializer.vhd} \
  -hdl_source {../src/rtl/nanofip/wf_wb_controller.vhd}

create_links \
  -hdl_source {../../../../common/vhd/communication/serial_3wire_transceiver/src/rtl/serial_3wire_rx.vhd} \
  -hdl_source {../../../../common/vhd/communication/serial_3wire_transceiver/src/rtl/serial_3wire_tx.vhd} \
  -hdl_source {../../../../common/vhd/communication/uart/src/rtl/uart_rx.vhd} \
  -hdl_source {../../../../common/vhd/communication/uart/src/rtl/uart_tx.vhd} \
  -hdl_source {../../../../common/vhd/generic/external_inputs/src/rtl/external_inputs.vhd} \
  -hdl_source {../../../../common/vhd/generic/array_transmitter/src/rtl/array_tx.vhd} \
  -hdl_source {../../../../common/vhd/generic/microsemi_reset_generator/src/rtl/microsemi_reset_generator.vhd} \
  -hdl_source {../../../../common/vhd/generic/reset_generator/src/rtl/reset_generator.vhd} \
  -hdl_source {../../../../common/vhd/generic/delay/src/rtl/delay.vhd} \
  -hdl_source {../../../../common/vhd/generic/glitch_filter/src/rtl/glitch_filter.vhd} \
  -hdl_source {../../../../common/vhd/generic/bit_clock_recovery/src/rtl/bit_clock_recovery.vhd} \
  -hdl_source {../../../../common/vhd/generic/edge_detector/src/rtl/edge_detector.vhd} \
  -hdl_source {../../../../common/vhd/generic/lfsr_strobe_generator/src/rtl/lfsr_strobe_generator.vhd} \
  -hdl_source {../../../../common/vhd/packages/lfsr/src/rtl/lfsr_pkg.vhd}

set_root -module {nf_top::work}

organize_tool_files \
  -tool {SYNTHESIZE} \
  -file {./nf_syn.sdc} \
  -module {nf_top::work} \
  -input_type {constraint}

organize_tool_files \
  -tool {COMPILE} \
  -file {./nf.sdc} \
  -file {./nf.pdc} \
  -module {nf_top::work} \
  -input_type {constraint}

save_project
