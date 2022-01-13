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


entity tb_axi_stream_to_slv is
end tb_axi_stream_to_slv;

architecture tb of tb_axi_stream_to_slv is

	constant C_PERIOD : time := 10 ns;

	constant C_WIDTH_BYTES : integer := 2;
	constant C_DEPTH       : integer := 16;
	
	-- AXI interface
	signal saxis_aclk, saxis_aresetn, saxis_tvalid, saxis_tready : std_logic;
	signal saxis_tdata : std_logic_vector(8*C_WIDTH_BYTES-1 downto 0);

	-- raw interface
	signal dout_valid : std_logic;
	signal dout : std_logic_vector(8*C_WIDTH_BYTES-1 downto 0);
	
	-- clock procedures
	procedure wait_for_clock_fall is
	begin
		wait until (falling_edge(saxis_aclk'delayed(1 ps)));
	end wait_for_clock_fall;
	
	procedure wait_for_clock_rise is
	begin
		wait until (rising_edge(saxis_aclk'delayed(1 ps)));
	end wait_for_clock_rise;
	
begin
	UUT : entity work.axi_stream_to_slv
	generic map (
		G_WIDTH_BYTES => C_WIDTH_BYTES,
		G_FIFO_DEPTH => C_DEPTH
	)
	port map (
		saxis_aclk => saxis_aclk,
		saxis_aresetn => saxis_aresetn,
		saxis_tvalid => saxis_tvalid,
		saxis_tdata => saxis_tdata,
		saxis_tready => saxis_tready,
		dout => dout,
		dout_valid => dout_valid
	);
		      
	clock : process
	begin
		saxis_aclk <= '1';
		wait for C_PERIOD / 2;
		saxis_aclk <= '0';
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
		saxis_aresetn <= '0';
		saxis_tvalid <= '0';
		saxis_tdata <= (others => '0');
		wait_for_clock_rise;
		wait_for_clock_rise;
		wait_for_clock_rise;

 		-- Ready should be low when in reset
		if not (saxis_tready = '0') then fail; end if;
		if not (dout_valid = '0') then fail; end if;
		
		wait_for_clock_fall;
		saxis_aresetn <= '1';
		wait_for_clock_rise;
		
		-- Ready should be high when no longer reset
		if not (saxis_tready = '1') then fail; end if;
		-- valid output remains low while no data has been clocked in
		if not (dout_valid = '0') then fail; end if;
		wait_for_clock_rise;
		wait_for_clock_rise;
		if not (saxis_tready = '1') then fail; end if;
		if not (dout_valid = '0') then fail; end if;
		
		-- Case 1. Ready high first.
		-- This is the only case, since ready is high immediately
		-- after reset is released, and it isn't possible to
		-- overflow the fifo (it reads every clock)
		wait_for_clock_fall;
		saxis_tdata(7 downto 0) <= x"01";
		saxis_tvalid <= '1';
		wait_for_clock_rise;

		if not (dout_valid = '1') then fail; end if;
		if not (dout(7 downto 0) = x"01") then fail; end if;
		if not (saxis_tready = '1') then fail; end if;
		saxis_tdata(7 downto 0) <= x"02";
		wait_for_clock_rise;

		saxis_tvalid <= '0';
		if not (dout_valid = '1') then fail; end if;
		if not (dout(7 downto 0) = x"02") then fail; end if;
		if not (saxis_tready = '1') then fail; end if;

		wait_for_clock_rise;
		if not (dout_valid = '0') then fail; end if;
		if not (saxis_tready = '1') then fail; end if;

		-- Try to overflow the FIFO (shouldn't be able to)
		for i in 0 to 10*C_DEPTH loop
			saxis_tvalid <= '1';
			saxis_tdata <= std_logic_vector(to_unsigned(i, 8*C_WIDTH_BYTES));
			wait_for_clock_rise;
			if not (dout_valid = '1') then fail; end if;
			if not (dout = std_logic_vector(to_unsigned(i, 8*C_WIDTH_BYTES))) then fail; end if;
			if not (saxis_tready = '1') then fail; end if;
		end loop;

		saxis_tvalid <= '0';
		wait_for_clock_rise;
		if not (dout_valid = '0') then fail; end if;
		wait_for_clock_rise;

		-- Try 50% duty cycle
		for i in 0 to 10*C_DEPTH loop
			for j in 0 to 1 loop
				saxis_tdata <= std_logic_vector(to_unsigned(2*i+j, 8*C_WIDTH_BYTES));
				if (j = 0) then
					saxis_tvalid <= '0';
					wait_for_clock_rise;
					if not (dout_valid = '0') then fail; end if;
				else
					saxis_tvalid <= '1';
					wait_for_clock_rise;
					if not (dout_valid = '1') then fail; end if;
					if not (dout = std_logic_vector(to_unsigned(2*i+j, 8*C_WIDTH_BYTES))) then fail; end if;
				end if;
				if not (saxis_tready = '1') then fail; end if;
			end loop;
		end loop;


		if (tb_fail) then
			report "TEST BENCH FAILED" severity failure;
		else
			report "TEST BENCH PASSED" severity note;
		end if;
		
		finish;
	end process;

end tb;
