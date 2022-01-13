-- Turn a 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_stream_to_slv is
	generic (
		-- Number of bytes in input vector and output AXI data stream.
		G_WIDTH_BYTES	: integer	:= 4;
		-- Number of FIFO. Used to tolerate back pressure on AXI TREADY
		G_FIFO_DEPTH	: integer	:= 16
	);
	port (
		-- Output vector
		dout            : out std_logic_vector(8*G_WIDTH_BYTES - 1 downto 0);
		dout_valid      : out std_logic;
		-- AXI Slave Bus Interface SAXIS
		saxis_aclk	    : in std_logic;
		saxis_aresetn	  : in std_logic;
		saxis_tvalid	  : in std_logic;
		saxis_tdata	    : in std_logic_vector(8*G_WIDTH_BYTES - 1 downto 0);
		saxis_tready	  : out std_logic
	);
end axi_stream_to_slv;

architecture behav of axi_stream_to_slv is

	component basic_fifo is
		generic (
			G_WIDTH_BYTES   : integer;
			G_DEPTH         : integer
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
	
	signal fifo_empty   : std_logic;
	signal fifo_full    : std_logic;
	signal re           : std_logic;
	signal we           : std_logic;
	signal ready        : std_logic;
	signal saxis_areset : std_logic;


begin

	saxis_areset <= not saxis_aresetn;

	-- read-enable: output whenever FIFO contains data
	re <= not fifo_empty;
	
	-- AXI handshake
	ready <= not fifo_full and not saxis_areset;
	we <= ready and saxis_tvalid; -- Transaction only occurs on READY and VALID
	saxis_tready <= ready;        -- Receiver can control ready independently of VALID
	
	basic_fifo_inst : basic_fifo
		generic map (
			G_WIDTH_BYTES => G_WIDTH_BYTES,
			G_DEPTH => G_FIFO_DEPTH
		)
		port map (
			clk => saxis_aclk,
			reset => saxis_areset,
			din => saxis_tdata,
			we => we,
			re => re,
			dout => dout,
			full => fifo_full,
			empty => fifo_empty
		);

	dout_valid <= not fifo_empty;

end behav;
