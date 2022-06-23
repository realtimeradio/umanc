import time
import argparse
import casperfpga
from matplotlib import pyplot as plt
import numpy as np

def run(host='', program=False, fpgfile=None, loopback=False):
    if fpgfile is None:
        print('Must supply a .fpg file with the --fpgfile flag')
        exit()

    print('Connecting to board: %s' % host)
    fpga = casperfpga.CasperFpga(host, transport=casperfpga.KatcpTransport)
    print('FPGA at %s is connected?' % host, fpga.is_connected())

    if program:
        print('Programming with %s' % fpgfile)
        fpga.upload_to_ram_and_program(fpgfile)
    else:
        print('Parsing %s' % fpgfile)
        fpga.get_system_information(fpgfile)
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
    parser.add_argument('--host', type=str, default='zcu111',
                        help='IP / hostname of ZCU111 board')
    args = parser.parse_args()

    run(
        host=args.host,
        program=args.program,
        fpgfile=args.fpgfile,
        loopback=args.loopback,
    )

