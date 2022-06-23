#! /usr/bin/env python

import time
import argparse
import casperfpga
from matplotlib import pyplot as plt
import numpy as np

LMK_FILE = "122M88_PL_122M88_SYSREF_7M68_clk5_12M8.txt"
LMX_FILE = "LMX_REF_122M88_OUT_245M76.txt"

DEFAULT_ACC_LEN = 200000
SAMPLE_HZ = 3932160000 // 8
NPOINT = 2**18
FPGA_DEMUX_FACTOR = 2 # ADC samples per FPGA clock tick
ACC_OUT_BITS = 64

def norm_wave(ts, max_amp=2**15-1):
    """
     Re-scale generated data values to fit LUT
    """
    norm = max(abs(ts)) # abs to get magnitude of complex vector
    dacI = ((ts.real/norm)*max_amp).astype("int16")
    dacQ = ((ts.imag/norm)*max_amp).astype("int16")
    return dacI, dacQ

def load_dac(fpga, I, Q):
    I = np.array(I, dtype='>h')
    Q = np.array(Q, dtype='>h')
    fpga.write('dac_wave_i', I.tobytes())
    fpga.write('dac_wave_q', Q.tobytes())

def make_cw(npoint, sample_hz, wave_hz):
    sample_period = 1./sample_hz
    t = np.arange(npoint) * sample_period
    s = np.sin(2 * np.pi * wave_hz * t)
    c = np.cos(2 * np.pi * wave_hz * t)
    return c + 1j*s

def set_freq_by_index(fpga, i, sample_hz=SAMPLE_HZ, npoint=NPOINT):
    wave_hz = sample_hz / npoint * i
    print('Uploading CW at %.3f MHz' % (wave_hz / 1e6))
    wave = make_cw(npoint, sample_hz, wave_hz)
    I, Q = norm_wave(wave)
    load_dac(fpga, I, Q)

def wait_for_acc(fpga):
    time.sleep(0.2) # placeholder
    return

def read_acc(fpga, name='acc_r0'):
    a = 0
    n_reg = ACC_OUT_BITS // 32
    for i in range(n_reg):
        a += (fpga.read_uint('%s_out%d' % (name, i)) << (32*i))
    max_val = 2**(ACC_OUT_BITS - 1) - 1
    if a > max_val:
        a -= 2**ACC_OUT_BITS
    return a

def trigger_acc(fpga):
    fpga.write_int('new_acc_trig', 0)
    fpga.write_int('new_acc_trig', 1)
    fpga.write_int('new_acc_trig', 0)

def get_new_acc(fpga):
    trigger_acc(fpga)
    wait_for_acc(fpga)
    re = 0
    im = 0
    for i in range(FPGA_DEMUX_FACTOR):
        re += read_acc(fpga, name='acc_r%d' % i)
        im += read_acc(fpga, name='acc_i%d' % i)
    return re + 1j*im

def init(host='', program=False, fpgfile=None, loopback=False, acc_len=DEFAULT_ACC_LEN):
    if fpgfile is None:
        print('Must supply a .fpg file with the --fpgfile flag')
        exit()

    print('Connecting to board: %s' % host)
    fpga = casperfpga.CasperFpga(host, transport=casperfpga.KatcpTransport)

    if program:
        print('Programming with %s' % fpgfile)
        fpga.upload_to_ram_and_program(fpgfile)
        print('Initializing RFDC')
        fpga.adcs['rfdc'].init(lmk_file=LMK_FILE, lmx_file=LMX_FILE)

    print('Parsing %s' % fpgfile)
    fpga.get_system_information(fpgfile)
    rfdc = fpga.adcs['rfdc']

    fpga_clk_mhz = fpga.estimate_fpga_clock()
    print('FPGA board clock: %.2f MHz' % fpga_clk_mhz)
    rfdc.status()

    print('Setting loopback mode:', loopback)
    fpga.write_int('adc_dac_loopback', int(loopback))

    print('Setting accumulation length to %d samples' % acc_len)
    print('%d samples ~= %.2f ms' % (acc_len, acc_len / fpga_clk_mhz / 1e3))
    fpga.write_int('acc_len', acc_len)

    return fpga

def main():
    parser = argparse.ArgumentParser(
        description='Perform an RF sweep using a ZCU111 board',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument('-l', dest='loopback', action='store_true',
                        help ='Use internal DAC->ADC loopback')
    parser.add_argument('-p','--program', action='store_true',
                        help='Program FPGAs')
    parser.add_argument('-f','--fpgfile', type=str, default=None,
                        help='Path to .fpg firmware file')
    parser.add_argument('-a','--acc_len', type=int, default=DEFAULT_ACC_LEN,
                        help='Accumulation length in FPGA clocks')
    parser.add_argument('--host', type=str, default='zcu111',
                        help='IP / hostname of ZCU111 board')
    args = parser.parse_args()

    init(
        host = args.host,
        program = args.program,
        fpgfile = args.fpgfile,
        loopback = args.loopback,
        acc_len = args.acc_len,
    )

if __name__ == '__main__':
    main()
