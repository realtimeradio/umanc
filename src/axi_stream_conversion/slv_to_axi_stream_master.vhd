-- Turn a 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity slv_to_axi_stream_master is
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
		maxis_tvalid    : out std_logic;
		maxis_tdata     : out std_logic_vector(8*G_WIDTH_BYTES - 1 downto 0);
		maxis_tready    : in std_logic
	);
end slv_to_axi_stream_master;

architecture behav of slv_to_axi_stream_master is

	component basic_fifo is
		generic (
			G_WIDTH_BYTES	: integer;
			G_DEPTH	        : integer
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

begin

	basic_fifo_inst : basic_fifo
		generic map (
			G_WIDTH_BYTES => G_WIDTH_BYTES,
			G_DEPTH => G_FIFO_DEPTH
		)
		port map (
			clk => maxis_aclk,
			reset => maxis_aresetn,
			din => din,
			we => din_valid,
			re => maxis_tready,
			dout => maxis_tdata,
			full => fifo_full,
			empty => fifo_empty
		);
		
	process(maxis_aclk)
	begin
		maxis_tvalid <= fifo_empty and maxis_tready;
	end process;

end behav;
