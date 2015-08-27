import struct
import binascii
import time
import os
import sys, getopt
import re

def args(argv):
   try:
      opts, args = getopt.getopt(argv,"hi:o:",["ifile="])
   except getopt.GetoptError:
      print 'test.py -i <inputfile>'
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print 'Use: cf-nf_data.py -i <inputfile>'
         sys.exit()
      elif opt in ("-i", "--ifile"):
         inputfile = arg
   return inputfile

inputfile = args(sys.argv[1:])
f = open(inputfile, 'r')
s = re.search("(\w+/?\w+)\.(\w+)", inputfile)
if s:
   d = s.group(1)
if not os.path.exists(d):
    os.makedirs(d)

lines = ''.join(f.readlines())
lines = lines.split('AAFF')

def adc_int(hex_value):
    int_value = int(hex_value, 16)
    if int_value > 0x7FFFFFFF:
        int_value -= 0x100000000
    return str(int_value)

f_log               = open(d+'/log.txt', 'w')
f_debug_seq_cnt     = open(d+'/debug_seq_cnt.txt', 'w')
f_serial_data       = open(d+'/serial_data.txt', 'w')
f_backplane_type    = open(d+'/backplane_type.txt', 'w')
f_controller_status = open(d+'/controller_status.txt', 'w')
f_seu_count         = open(d+'/seu_count.txt', 'w')
f_converter_output  = open(d+'/converter_output.txt', 'w')
f_converter_input   = open(d+'/converter_input.txt', 'w')
f_dim_log_index     = open(d+'/dim_log_index.txt', 'w')
f_adc_log_index     = open(d+'/adc_log_index.txt', 'w')
f_version           = open(d+'/version.txt', 'w')
f_cycle_period      = open(d+'/cycle_period .txt', 'w')
f_dim_a_1_ana       = open(d+'/dim_a_1_ana.txt', 'w')
f_dim_a_1_ana_3     = open(d+'/dim_a_1_ana_3.txt', 'w')
f_dim_a_1_ana_2     = open(d+'/dim_a_1_ana_2.txt', 'w')
f_dim_a_1_ana_1     = open(d+'/dim_a_1_ana_1.txt', 'w')
f_dim_a_1_ana_0     = open(d+'/dim_a_1_ana_0.txt', 'w')
f_dim_a_trig_unl    = open(d+'/dim_a_trig_unl.txt', 'w')
f_dim_a_trig_lat    = open(d+'/dim_a_trig_lat.txt', 'w')
f_i_b_10_19         = open(d+'/i_b_10_19.txt', 'w')
f_i_b_0_9           = open(d+'/i_b_0_9.txt', 'w')
f_i_a_10_19         = open(d+'/i_a_10_19.txt', 'w')
f_i_a_0_9           = open(d+'/i_a_0_9.txt', 'w')
f_v_meas_10_19      = open(d+'/v_meas_10_19.txt', 'w')
f_v_meas_0_9        = open(d+'/v_meas_0_9.txt', 'w')

for line in lines:
    if len(line) != 244:
        continue

    line = [line[i-2:i] for i in range(len(line), 0, -2)]

    paged = line[-64:]
    critical = line[:58]

    debug_seq_cnt     = ''.join(critical[0:2])
    serial_data       = ''.join(critical[2:5])
    backplane_type    = critical[5]
    controller_status = ''.join(critical[6:8])
    seu_count         = critical[8]
    converter_output  = critical[9]
    converter_input   = ''.join(critical[10:12])
    dim_log_index     = ''.join(critical[12:14])
    adc_log_index     = ''.join(critical[14:16])
    version           = ''.join(critical[16:18])
    cycle_period      = ''.join(critical[18:22])
    dim_a_1_ana_3     = ''.join(critical[22:24])
    dim_a_1_ana_2     = ''.join(critical[24:26])
    dim_a_1_ana_1     = ''.join(critical[26:28])
    dim_a_1_ana_0     = ''.join(critical[28:30])
    dim_a_trig_unl    = ''.join(critical[30:32])
    dim_a_trig_lat    = ''.join(critical[32:34])
    i_b_10_19         = ''.join(critical[34:38])
    i_b_0_9           = ''.join(critical[38:42])
    i_a_10_19         = ''.join(critical[42:46])
    i_a_0_9           = ''.join(critical[46:50])
    v_meas_10_19      = ''.join(critical[50:54])
    v_meas_0_9        = ''.join(critical[54:58])

    dim_a_1_ana_0 =  hex(int (dim_a_1_ana_0, 16) & int("0FFF", 16))
    dim_a_1_ana_1 =  hex(int (dim_a_1_ana_1, 16) & int("0FFF", 16))
    dim_a_1_ana_2 =  hex(int (dim_a_1_ana_2, 16) & int("0FFF", 16))
    dim_a_1_ana_3 =  hex(int (dim_a_1_ana_3, 16) & int("0FFF", 16))

    f_dim_a_1_ana    .write("%s\t" % str(int(dim_a_1_ana_0, 16)))
    f_dim_a_1_ana    .write("%s\t" % str(int(dim_a_1_ana_1, 16)))
    f_dim_a_1_ana    .write("%s\t" % str(int(dim_a_1_ana_2, 16)))
    f_dim_a_1_ana    .write("%s\n" % str(int(dim_a_1_ana_3, 16)))

    f_debug_seq_cnt    .write("%s\n" % str(int(debug_seq_cnt, 16)))
    f_serial_data      .write("%s\n" % serial_data)
    f_backplane_type   .write("%s\n" % bin(int(backplane_type, 16))[2:].zfill(8))
    f_controller_status.write("%s\n" % bin(int(controller_status, 16))[2:].zfill(16))
    f_seu_count        .write("%s\n" % str(int(seu_count, 16)))
    f_converter_output .write("%s\n" % bin(int(converter_output, 16))[2:].zfill(8))
    f_converter_input  .write("%s\n" % bin(int(converter_input, 16))[2:].zfill(16))
    f_dim_log_index    .write("%s\n" % str(int(dim_log_index, 16)))
    f_adc_log_index    .write("%s\n" % str(int(adc_log_index, 16)))
    f_version          .write("%s\n" % bin(int(version, 16))[2:].zfill(16))
    f_cycle_period     .write("%s\n" % str(int(cycle_period, 16)))
    f_dim_a_1_ana_3    .write("%s\n" % str(int(dim_a_1_ana_3, 16)))
    f_dim_a_1_ana_2    .write("%s\n" % str(int(dim_a_1_ana_2, 16)))
    f_dim_a_1_ana_1    .write("%s\n" % str(int(dim_a_1_ana_1, 16)))
    f_dim_a_1_ana_0    .write("%s\n" % str(int(dim_a_1_ana_0, 16)))
    f_dim_a_trig_unl   .write("%s\n" % bin(int(dim_a_trig_unl, 16))[2:].zfill(16))
    f_dim_a_trig_lat   .write("%s\n" % bin(int(dim_a_trig_lat, 16))[2:].zfill(16))
    f_i_b_10_19        .write("%s\n" % adc_int(i_b_10_19))
    f_i_b_0_9          .write("%s\n" % adc_int(i_b_0_9))
    f_i_a_10_19        .write("%s\n" % adc_int(i_a_10_19))
    f_i_a_0_9          .write("%s\n" % adc_int(i_a_0_9))
    f_v_meas_10_19     .write("%s\n" % adc_int(v_meas_10_19))
    f_v_meas_0_9       .write("%s\n" % adc_int(v_meas_0_9))    

    print >>f_log, 'V_MEAS_0_9     :\t' + adc_int(v_meas_0_9)                           + ' (int)'
    print >>f_log, 'V_MEAS_10_19   :\t' + adc_int(v_meas_10_19)                         + ' (int)'
    print >>f_log, 'I_A_0_9        :\t' + adc_int(i_a_0_9)                              + ' (int)'
    print >>f_log, 'I_A_10_19      :\t' + adc_int(i_a_10_19)                            + ' (int)'
    print >>f_log, 'I_B_0_9        :\t' + adc_int(i_b_0_9)                              + ' (int)'
    print >>f_log, 'I_B_10_19      :\t' + adc_int(i_b_10_19)                            + ' (int)'
    print >>f_log, 'DIM_A_TRIG_LAT :\t' + bin(int(dim_a_trig_lat, 16))[2:].zfill(16)    + ' (bin)'
    print >>f_log, 'DIM_A_TRIG_UNL :\t' + bin(int(dim_a_trig_unl, 16))[2:].zfill(16)    + ' (bin)'
    print >>f_log, 'DIM_A_1_ANA_0  :\t' + str(int(dim_a_1_ana_0, 16))                   + ' (int)'
    print >>f_log, 'DIM_A_1_ANA_1  :\t' + str(int(dim_a_1_ana_1, 16))                   + ' (int)'
    print >>f_log, 'DIM_A_1_ANA_2  :\t' + str(int(dim_a_1_ana_2, 16))                   + ' (int)'
    print >>f_log, 'DIM_A_1_ANA_3  :\t' + str(int(dim_a_1_ana_3, 16))                   + ' (int)'
    print >>f_log, 'CYCLE_PERIOD   :\t' + str(int(cycle_period, 16))                    + ' (int)'
    print >>f_log, 'VERSION        :\t' + bin(int(version, 16))[2:].zfill(16)           + ' (bin)'
    print >>f_log, 'ADC_LOG_INDEX  :\t' + str(int(adc_log_index, 16))                   + ' (int)'
    print >>f_log, 'DIM_LOG_INDEX  :\t' + str(int(dim_log_index, 16))                   + ' (int)'
    print >>f_log, 'CONVERTER_IN   :\t' + bin(int(converter_input, 16))[2:].zfill(16)   + ' (bin)'
    print >>f_log, 'CONVERTER_OUT  :\t' + bin(int(converter_output, 16))[2:].zfill(8)   + ' (bin)'
    print >>f_log, 'SEU_COUNT      :\t' + str(int(seu_count, 16))                       + ' (int)'
    print >>f_log, 'FGC_STATUS     :\t' + bin(int(controller_status, 16))[2:].zfill(16) + ' (bin)'
    print >>f_log, 'BACKPLANE_TYPE :\t' + bin(int(backplane_type, 16))[2:].zfill(8)     + ' (bin)'
    print >>f_log, 'SERIAL_DATA    :\t' + serial_data                                   + ' (hex)'
    print >>f_log, 'DEBUG_SEQUENCE :\t' + str(int(debug_seq_cnt, 16))                   + ' (int)'
    print >>f_log, '--------------------------------------------------------------------------------'

#    time.sleep(0.5)
