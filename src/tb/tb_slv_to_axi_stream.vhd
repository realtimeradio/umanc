----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/23/2021 02:56:03 PM
-- Design Name: 
-- Module Name: basic_fifo_tb - tb
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

use std.env.all;


entity tb_slv_to_axi_stream is
end tb_slv_to_axi_stream;

architecture tb of tb_slv_to_axi_stream is

	constant C_PERIOD : time := 10 ns;

	constant C_WIDTH_BYTES : integer := 2;
	constant C_DEPTH       : integer := 16;
	
	-- AXI interface
	signal maxis_aclk, maxis_aresetn, maxis_tvalid, maxis_tready : std_logic;
	signal maxis_tdata : std_logic_vector(8*C_WIDTH_BYTES-1 downto 0);

	-- raw interface
	signal din_valid : std_logic;
	signal din : std_logic_vector(8*C_WIDTH_BYTES-1 downto 0);
	
	-- clock procedures
	procedure wait_for_clock_fall is
	begin
		wait until (falling_edge(maxis_aclk'delayed(1 ps)));
	end wait_for_clock_fall;
	
	procedure wait_for_clock_rise is
	begin
		wait until (rising_edge(maxis_aclk'delayed(1 ps)));
	end wait_for_clock_rise;

begin
	UUT : entity work.slv_to_axi_stream
	generic map (
		G_WIDTH_BYTES => C_WIDTH_BYTES,
		G_FIFO_DEPTH => C_DEPTH
	)
	port map (
		maxis_aclk => maxis_aclk,
		maxis_aresetn => maxis_aresetn,
		maxis_tvalid => maxis_tvalid,
		maxis_tdata => maxis_tdata,
		maxis_tready => maxis_tready,
		din => din,
		din_valid => din_valid
	);
		      
	clock : process
	begin
		maxis_aclk <= '1';
		wait for C_PERIOD / 2;
		maxis_aclk <= '0';
		wait for C_PERIOD / 2;
	end process;

	testbench : process
		variable tb_fail : boolean := false;
		procedure fail is
		begin
			report "Testbench output mismatch" severity error;
			tb_fail := true;
		end;
	begin
		wait_for_clock_fall;
		maxis_aresetn <= '0';
		maxis_tready <= '0';
		din <= (others => '0');
		din_valid <= '0';
		wait_for_clock_rise;
		wait_for_clock_rise;
		wait_for_clock_rise;
		
		wait_for_clock_fall;
		maxis_aresetn <= '1';
		wait_for_clock_rise;
		
		--out of reset
		
		-- Case 1. Valid goes high first, then ready
		-- clock some data into the FIFO
		wait_for_clock_fall;
		din_valid <= '1';
		din(7 downto 0) <= x"01";
		wait_for_clock_rise;
		din(7 downto 0) <= x"02";
		wait_for_clock_rise;
		din(7 downto 0) <= x"03";
		wait_for_clock_rise;
		din(7 downto 0) <= x"04";
		wait_for_clock_rise;
		din(7 downto 0) <= x"05";
		wait_for_clock_rise;
		din_valid <= '0';

		if not (maxis_tvalid = '1') then fail; end if;
		if not (maxis_tdata(7 downto 0) = x"01") then fail; end if;
		
		-- Raise ready and clock out data
		wait_for_clock_fall;
		maxis_tready <= '1';
		wait_for_clock_rise;
		if not (maxis_tdata(7 downto 0) = x"02") then fail; end if;
		if not (maxis_tvalid = '1') then fail; end if;
		        
		wait_for_clock_rise;
		if not (maxis_tdata(7 downto 0) = x"03") then fail; end if;
		if not (maxis_tvalid = '1') then fail; end if;
		        
		wait_for_clock_rise;
		if not (maxis_tdata(7 downto 0) = x"04") then fail; end if; 
		if not (maxis_tvalid = '1') then fail; end if;
		wait_for_clock_rise;
		if not (maxis_tdata(7 downto 0) = x"05") then fail; end if; 
		if not (maxis_tvalid = '1') then fail; end if;
		wait_for_clock_rise;
		if not (maxis_tvalid = '0') then fail; end if;
		
		wait_for_clock_rise;
		
		-- Case 2. Ready high first
		wait_for_clock_fall;
		maxis_tready <= '1';
		wait_for_clock_rise;
		if not (maxis_tvalid = '0') then fail; end if;
		wait_for_clock_rise;
		if not (maxis_tvalid = '0') then fail; end if;
		-- write in some data
		wait_for_clock_fall;
		din_valid <= '1';
		din(7 downto 0) <= x"06";
		if not (maxis_tvalid = '0') then fail; end if;
		wait_for_clock_rise;
		din_valid <= '0';
		-- transaction occurs here
		if not (maxis_tvalid = '1') then fail; end if;
		if not (maxis_tdata(7 downto 0) = x"06") then fail; end if;
		if not (maxis_tvalid = '1') then fail; end if;
		wait_for_clock_rise;
		if not (maxis_tvalid = '0') then fail; end if;
		wait_for_clock_rise;
		wait_for_clock_rise;
		wait_for_clock_rise;
		
		-- Case 3. Both signals rise together
		wait_for_clock_fall;
		maxis_tready <= '0';
		if not (maxis_tvalid = '0') then fail; end if;
		wait_for_clock_rise;
		wait_for_clock_fall;
		din_valid <= '1';
		din(7 downto 0) <= x"07";
		maxis_tready <= '1';
		if not (maxis_tvalid = '0') then fail; end if;
		wait_for_clock_rise;
		din_valid <= '0';
		if not (maxis_tvalid = '1') then fail; end if;
		if not (maxis_tdata(7 downto 0) = x"07") then fail; end if;
		wait_for_clock_rise;
		if not (maxis_tvalid = '0') then fail; end if;

		if (tb_fail) then
			report "TEST BENCH FAILED" severity failure;
		else
			report "TEST BENCH PASSED" severity note;
		end if;
		
		finish;
	end process;

end tb;
