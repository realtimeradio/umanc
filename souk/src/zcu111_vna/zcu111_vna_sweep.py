#! /usr/bin/env python

import os
import time
import struct
import argparse
import casperfpga
from matplotlib import pyplot as plt
import numpy as np

LMK_FILE = "122M88_PL_122M88_SYSREF_7M68_clk5_12M8.txt"
LMX_FILE = "LMX_REF_122M88_OUT_245M76.txt"

DEFAULT_ACC_LEN = 200000
SAMPLE_HZ = 3932160000
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

def make_cw(npoint, sample_hz, wave_hz):
    sample_period = 1./sample_hz
    t = np.arange(npoint) * sample_period
    s = np.sin(2 * np.pi * wave_hz * t)
    c = np.cos(2 * np.pi * wave_hz * t)
    return c + 1j*s

class Zcu111Vna:
    def __init__(self, host, fpgfile, lmk_file=LMK_FILE, lmx_file=LMX_FILE):
        self.host = host
        print('Connecting to board: %s' % host)
        self.fpga = casperfpga.CasperFpga(host, transport=casperfpga.KatcpTransport)
        self._parse_fpg(fpgfile)
        try:
            self._get_firmware_config()
        except:
            pass # Probably not programmed

    def _get_firmware_config(self):
        devlist = self.fpga.listdev()
        if 'n_samples' in devlist:
            self.n_samples = self.fpga.read_uint('n_samples')
        else:
            self.n_samples = 0
        if 'n_parallel' in devlist:
            self.n_parallel = self.fpga.read_uint('n_parallel')
        else:
            self.n_parallel = FPGA_DEMUX_FACTOR
        self.sample_hz = SAMPLE_HZ // 8 * self.n_parallel // 2
        self.fpga_clk_mhz = self.sample_hz / self.n_parallel / 1e6
        print('Firmware config detected: %d sample RAM buffer' % self.n_samples)
        print('Firmware config detected: %d ADC/DAC demux' % self.n_parallel)
        print('Firmware config detected: %.2f MHz FPGA clock' % self.fpga_clk_mhz)
        print('Firmware config detected: %.2f MHz ADC clock' % (self.sample_hz / 1e6))

    def _parse_fpg(self, fpgfile):
        self.fpgfile = fpgfile
        print('Parsing %s' % fpgfile)
        self.fpga.get_system_information(fpgfile)
        self.rfdc = self.fpga.adcs['rfdc']

    def program(self, fpgfile=None):
        fpgfile = fpgfile or self.fpgfile
        print('Programming with %s' % fpgfile)
        self.fpga.upload_to_ram_and_program(fpgfile)
        print('Initializing RFDC')
        self.fpga.adcs['rfdc'].init(lmk_file=LMK_FILE, lmx_file=LMX_FILE)
        self._parse_fpg(fpgfile)
        self._get_firmware_config()
        if self.n_parallel > 2:
            self.fpga.write_int('phase_inc_rst', 1)

    def enable_loopback(self):
        print('Enabling DAC->ADC internal loopback')
        self.fpga.write_int('adc_dac_loopback', 1)

    def disable_loopback(self):
        print('Disabling DAC->ADC internal loopback')
        self.fpga.write_int('adc_dac_loopback', 0)

    def get_fpga_clk(self):
        fpga_clk_mhz = self.fpga.estimate_fpga_clock()
        print('FPGA board clock: %.2f MHz' % fpga_clk_mhz)
        return fpga_clk_mhz

    def get_rfdc_status(self):
        self.rfdc.status()

    def get_acc_len(self):
        return self.fpga.read_uint('acc_len')

    def set_acc_len_spectra(self, acc_len=DEFAULT_ACC_LEN):
        print('Setting accumulation length to %d samples' % acc_len)
        print('%d samples ~= %.2f ms' % (acc_len, acc_len / self.fpga_clk_mhz / 1e3))
        self.fpga.write_int('acc_len', acc_len)

    def set_acc_len_ms(self, acc_len=100):
        fpga_period_hz = 1./(self.fpga_clk_mhz * 1e6)
        acc_len_spectra = int(acc_len*1e-3 / fpga_period_hz)
        self.set_acc_len_spectra(acc_len_spectra)

    def wait_for_acc(self, timeout=5):
        t0 = time.time()
        while not self.fpga.read_uint('acc_ready'):
            if time.time() > t0 + timeout:
                print("Timed out waiting for new accumulation!")
                break
            time.sleep(0.0002)

    def _read_acc(self, name='acc_r0'):
        a = 0
        n_reg = ACC_OUT_BITS // 32
        for i in range(n_reg):
            a += (self.fpga.read_uint('%s_out%d' % (name, i)) << (32*i))
        max_val = 2**(ACC_OUT_BITS - 1) - 1
        if a > max_val:
            a -= 2**ACC_OUT_BITS
        return a

    def trigger_acc(self):
        self.fpga.write_int('new_acc_trig', 0)
        self.fpga.write_int('new_acc_trig', 1)

    def get_new_acc(self, man_trig=None):
        t0 = time.time()
        if man_trig:
            self.trigger_acc()
        elif man_trig is None and self.n_parallel <=2:
            self.trigger_acc()
        self.wait_for_acc()
        re = 0
        im = 0
        if self.n_parallel > 2:
            n_reg = 1
            d = self.fpga.read('acc_d', 2*8)
            re, im = struct.unpack('>2q', d)
            #for i in range(n_reg):
            #    re += self._read_acc(name='acc_r%d' % i)
            #    im += self._read_acc(name='acc_i%d' % i)
        else:
            n_reg = self.n_parallel
            for i in range(n_reg):
                re += self._read_acc(name='acc_r%d' % i)
                im += self._read_acc(name='acc_i%d' % i)
        t1 = time.time()
        #print('Integration took %.2f ms' % ((t1 - t0) * 1000))
        return re + 1j*im

class Zcu111VnaLut(Zcu111Vna):
    def load_dac(self, I, Q):
        I = np.array(I, dtype='>h')
        Q = np.array(Q, dtype='>h')
        self.fpga.write('dac_wave_i', I.tobytes())
        self.fpga.write('dac_wave_q', Q.tobytes())

    def set_freq_by_index(self, i, npoint=NPOINT):
        wave_hz = self.sample_hz / npoint * i
        print('Uploading CW at %.3f MHz' % (wave_hz / 1e6))
        wave = make_cw(npoint, sample_hz, wave_hz)
        I, Q = norm_wave(wave)
        self.load_dac(I, Q)

class Zcu111VnaCordic(Zcu111Vna):
    def set_freq(self, freq_hz):
        assert freq_hz < self.sample_hz/2. # This probably isn't quite the right test
        samples_per_cycle = self.sample_hz / freq_hz
        phase_inc = 1./samples_per_cycle * 2 # units of PI
        #print('phase_inc: %.2f' % phase_inc)
        self.fpga.write_int('phase_inc', int(phase_inc * 2**23))

def main():
    parser = argparse.ArgumentParser(
        description='Perform an RF sweep using a ZCU111 board',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument('--loopback', action='store_true',
                        help ='Use internal DAC->ADC loopback')
    parser.add_argument('--lut', dest='lut', action='store_true',
                        help ='Use LUT version of firmware')
    parser.add_argument('-p','--program', action='store_true',
                        help='Program FPGAs')
    parser.add_argument('-f','--fpgfile', type=str, default=None,
                        help='Path to .fpg firmware file')
    parser.add_argument('-a','--acc_len', type=float, default=100,
                        help='Accumulation length in milliseconds')
    parser.add_argument('--host', type=str, default='zcu111',
                        help='IP / hostname of ZCU111 board')
    parser.add_argument('--sweep', type=str, default=None,
                        help='sweep_start_hz,sweep_stop_hz,sweep_step_hz')
    parser.add_argument('--plot', action='store_true',
                        help='If set, and sweep parameters given, plot results')
    parser.add_argument('--outfile', type=str, default=None,
                        help='If set, save output to a CSV file with the given name (plus timestamp)')
    args = parser.parse_args()

    if args.lut:
        z = Zcu111VnaLut(args.host, args.fpgfile)
    else:
        z = Zcu111VnaCordic(args.host, args.fpgfile)

    if args.program:
        z.program()

    if args.loopback:
        z.enable_loopback()
    else:
        z.disable_loopback()

    z.set_acc_len_ms(args.acc_len)

    if args.sweep is not None:
        if args.lut:
            raise NotImplementedError('Sweep mode only supported for CORDIC firmware')
        start, stop, step = map(int, args.sweep.split(','))
        print('Seeping from %d Hz to %d Hz in steps of %d Hz' % (start, stop, step))
        freqs = np.arange(start, stop, step, dtype=int)
        n_freqs = freqs.shape[0]
        v = np.zeros(n_freqs, dtype=complex)
        for ff, freq in enumerate(freqs):
            print('Setting DAC to %d kHz' % (freq / 1000.))
            z.set_freq(freq)
            #time.sleep(0.0005) # Probably not necessary
            v[ff] = z.get_new_acc()
        if args.plot:
            plt.subplot(2,1,1)
            plt.plot(freqs/1e6, np.abs(v))
            plt.xlabel('Frequency [MHz]')
            plt.ylabel('Abs(S12)')
            plt.subplot(2,1,2)
            plt.plot(freqs/1e6, np.angle(v))
            plt.xlabel('Frequency [MHz]')
            plt.ylabel('Angle(S12)')
            plt.show()
        if args.outfile is not None:
            fname = args.outfile + '_%s.csv' % time.ctime().replace(' ', '_')
            if os.path.exists(fname):
                print('Path %s exists! Not saving output' % fname)
            else:
                with open(fname, 'w') as fh:
                    fh.write('#Frequency [Hz], S12\n')
                    for i in range(n_freqs):
                        fh.write('%d,%d%+dj\n' % (freqs[i], v[i].real, v[i].imag))

if __name__ == '__main__':
    main()
