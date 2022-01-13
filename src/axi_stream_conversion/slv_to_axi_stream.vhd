library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity slv_to_axi_stream is
	generic (
		-- Number of bytes in input vector and output AXI data stream.
		G_WIDTH_BYTES	: integer	:= 4;
		-- Number of FIFO. Used to tolerate back pressure on AXI TREADY
		G_FIFO_DEPTH	: integer	:= 16
	);
	port (
		-- Input vector
		din             : in std_logic_vector(8*G_WIDTH_BYTES - 1 downto 0);
		din_valid       : in std_logic;
		-- AXI Master Bus Interface MAXIS
		maxis_aclk      : in std_logic;
		maxis_aresetn   : in std_logic;
		maxis_tready    : in std_logic;
		maxis_tvalid    : out std_logic;
		maxis_tdata     : out std_logic_vector(8*G_WIDTH_BYTES - 1 downto 0)
	);
end slv_to_axi_stream;

architecture behav of slv_to_axi_stream is

	component basic_fifo is
		generic (
			G_WIDTH_BYTES   : integer;
			G_DEPTH	      : integer
		);
		port (
			clk             : in std_logic;
			reset           : in std_logic;
			din             : in std_logic_vector(8*G_WIDTH_BYTES - 1 downto 0);
			we              : in std_logic;
			re              : in std_logic;
			dout            : out std_logic_vector(8*G_WIDTH_BYTES - 1 downto 0);
			full            : out std_logic;
			empty           : out std_logic
		);
	end component;
	
	signal fifo_empty : std_logic;
	signal fifo_full  : std_logic;
	signal fifo_re    : std_logic;
	signal maxis_tvalid_int : std_logic;
	signal maxis_areset : std_logic;

begin

	maxis_areset <= not maxis_aresetn;

	maxis_tvalid <= maxis_tvalid_int;
 	maxis_tvalid_int <= not fifo_empty;           -- VALID goes high as soon as data is available, regardless of READY
 	fifo_re <= maxis_tready and maxis_tvalid_int; -- Transaction only occurs on READY and VALID

	basic_fifo_inst : basic_fifo
		generic map (
			G_WIDTH_BYTES => G_WIDTH_BYTES,
			G_DEPTH => G_FIFO_DEPTH
		)
		port map (
			clk => maxis_aclk,
			reset => maxis_areset,
			din => din,
			we => din_valid,
			re => fifo_re,
			dout => maxis_tdata,
			full => fifo_full,
			empty => fifo_empty
		);

end behav;
