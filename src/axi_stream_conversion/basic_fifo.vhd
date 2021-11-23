----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/23/2021 01:33:52 PM
-- Design Name: 
-- Module Name: basic_fifo - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity basic_fifo is
	generic (
		G_WIDTH_BYTES	: integer	:= 4;
		G_DEPTH	        : integer	:= 16
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
end basic_fifo;

architecture behav of basic_fifo is

	-- function called clogb2 that returns an integer which has the
	-- value of the ceiling of the log base 2.
	function clogb2 (bit_depth : integer) return integer is
		variable depth  : integer := bit_depth;
		variable count  : integer := 1;
	begin
		for clogb2 in 1 to bit_depth loop  -- Works for up to 32 bit integers
			if (bit_depth <= 2) then
				count := 1;
			else
	        		if(depth <= 1) then
					count := count;
				else
					depth := depth / 2;
					count := count + 1;
				end if;
			end if;
		end loop;
		return(count);
	end;

	constant C_FIFO_DEPTH_BITS : integer := clogb2(G_DEPTH);

	type memory_type is array (0 to G_DEPTH-1) of std_logic_vector(8*G_WIDTH_BYTES - 1 downto 0);
	signal memory : memory_type := (others => (others => '0'));
	signal writeptr : integer := 0;
	signal readptr : integer := 0;
	signal fifo_full : std_logic := '0';
	signal fifo_empty : std_logic := '0';
	signal word_count : unsigned(C_FIFO_DEPTH_BITS-1 downto 0) := (others => '0');

begin

	empty <= fifo_empty;
	full <= fifo_full;
		
	process(clk, reset)
	begin
		if(reset = '1') then
			word_count <= (others => '0');
			readptr <= 0;
			writeptr <= 0;
		elsif(rising_edge(clk)) then
			-- Write side
			if(we = '1' and fifo_full = '0') then
				memory(writeptr) <= din;
				word_count <= word_count + 1;
				if (writeptr = G_DEPTH-1) then
					writeptr <= 0;
				else
					writeptr <= writeptr + 1;
				end if;
			end if;
			-- Read side
			if(re = '1' and fifo_empty = '0') then
				dout <= memory(readptr);
				word_count <= word_count - 1;
				if (readptr = G_DEPTH-1) then
					readptr <= 0;
				else
					readptr <= readptr + 1;
				end if;
			end if;
			-- Special case. If read and write both occur occupancy doesn't change
			if (re = '1' and fifo_empty = '0' and we = '1' and fifo_full = '0') then
				word_count <= word_count;
			end if;
		end if;
	end process;
	
	process(word_count) begin
		if(word_count = 0) then
			fifo_empty <= '1';
		else
			fifo_empty <= '0';
		end if;
		if(word_count = G_DEPTH) then
			fifo_full <= '1';
		else
			fifo_full <= '0';
		end if;
	end process;

end behav;
