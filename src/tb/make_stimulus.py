G_WIDTH_BYTES = 1
G_DEPTH       = 16
SIM_LENGTH = 1024

from random import randint

fh_in  = open('input.txt','w')
fh_out = open('output.txt','w')

fh_in.write('# Columns: reset, din, we, re\n')
fh_out.write('# Columns: dout, empty, full\n')


reset = [0 for _ in range(SIM_LENGTH)]
din   = [0 for _ in range(SIM_LENGTH)]
we    = [0 for _ in range(SIM_LENGTH)]
re    = [0 for _ in range(SIM_LENGTH)]

reset[0:4] = [1]*4
din = [randint(0,2**(8*G_WIDTH_BYTES)-1) for _ in range(SIM_LENGTH)]
we  = [randint(0,1) for _ in range(SIM_LENGTH)]
re  = [randint(0,1) for _ in range(SIM_LENGTH)]

for i in range(SIM_LENGTH):
    fh_in.write('%d %s %d %d\n' % (reset[i], format(din[i], '0%db'%(8*G_WIDTH_BYTES)), we[i], re[i]))
fh_in.close()

# A simple behavioural model of the FIFO, to generate the expected output.
# Output values
dout   = [0 for _ in range(SIM_LENGTH+1)]
full   = [0 for _ in range(SIM_LENGTH+1)]
empty  = [0 for _ in range(SIM_LENGTH+1)]

# Simulated FIFO
class FifoFwft():
    def __init__(self, depth):
        self.depth = depth
        self.occupancy = 0
        self.read_pointer = 0
        self.write_pointer = 0
        self.buffer = [0 for _ in range(self.depth)]
    def reset(self):
        self.occupancy = 0
        self.read_pointer = 0
        self.write_pointer = 0
        self.buffer = [0 for _ in range(self.depth)]
    def empty(self):
        return self.occupancy == 0
    def full(self):
        return self.occupancy == self.depth
    def get_output(self):
        return self.buffer[self.read_pointer]
    def read(self):
        if not self.empty():
            self.read_pointer = (self.read_pointer + 1) % self.depth
            self.occupancy -= 1
            assert self.occupancy >= 0
    def write(self, data):
        if not self.full():
            self.buffer[self.write_pointer] = data
            self.write_pointer = (self.write_pointer + 1) % self.depth
            self.occupancy += 1
            assert self.occupancy <= self.depth
        
fifo = FifoFwft(G_DEPTH)
for i in range(SIM_LENGTH):
    # if FIFO is reset, next clock everything goes low
    if reset[i]:
        dout[i+1] = 0
        empty[i+1] = 1
        full[i+1] = 0
        fifo.reset()
        continue
    # If not in reset....

    # Get initial state of fifo
    start_empty = fifo.empty()

    # First write
    if we[i]:
        fifo.write(din[i])

    if re[i] and not start_empty:
        fifo.read()

    dout[i+1] = fifo.get_output()
    # Lastly update full and empty flags
    empty[i+1] = fifo.empty()
    full[i+1] = fifo.full()

for i in range(SIM_LENGTH+1):
    fh_out.write('%s %d %d\n' % (format(dout[i], '0%db'%(8*G_WIDTH_BYTES)), empty[i], full[i]))
fh_out.close()
