#
# Synthesis Parameters
#

# Clock
define_clock {clk_i} -name {clk_i} -period 25.0

# Enable TMR
define_attribute {v:work.nf_top} syn_radhardlevel {tmr}

# FSM encoding
define_attribute {i:*.reg\.state[*]} syn_encoding {safe, onehot}
define_attribute {i:*.*.reg\.state[*]} syn_encoding {safe, onehot}
define_attribute {i:*.*.*.reg\.state[*]} syn_encoding {safe, onehot}
define_attribute {i:*.*.*.*.reg\.state[*]} syn_encoding {safe, onehot}
define_attribute {i:*.*.*.*.*.reg\.state[*]} syn_encoding {safe, onehot}
define_attribute {i:*.*.*.*.*.*.reg\.state[*]} syn_encoding {safe, onehot}

define_attribute {i:nanofip_inst.reset_unit.rstin_st[*]} syn_encoding {safe, onehot}
define_attribute {i:nanofip_inst.reset_unit.var_rst_st[*]} syn_encoding {safe, onehot}
define_attribute {i:nanofip_inst.FIELDRIVE_Receiver.FIELDRIVE_Receiver_Deserializer.rx_st[*]} syn_encoding {safe, onehot}
define_attribute {i:nanofip_inst.FIELDRIVE_Transmitter.tx_serializer.tx_st[*]} syn_encoding {safe, onehot}
define_attribute {i:nanofip_inst.JTAG_controller.jc_st[*]} syn_encoding {safe, onehot}
define_attribute {i:nanofip_inst.engine_control.control_st[*]} syn_encoding {safe, onehot}

# Compile points
define_compile_point {v:work.nanofip} -type {hard}
