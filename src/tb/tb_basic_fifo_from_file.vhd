----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/23/2021 02:56:03 PM
-- Design Name: 
-- Module Name: tb_basic_fifo_from_file - tb
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

use std.textio.all;
use std.env.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity tb_basic_fifo_from_file is
end tb_basic_fifo_from_file;

architecture tb of tb_basic_fifo_from_file is

	constant C_PERIOD : time := 10 ns;
	constant C_STIMULUS_FILE : string := "/home/jackh/src/umanc/src/tb/input.txt";
	constant C_OUTPUT_FILE : string := "/home/jackh/src/umanc/src/tb/output.txt";

	constant C_WIDTH_BYTES : integer := 1;
	constant C_DEPTH       : integer := 16;
	
	signal clk, reset, we, re, full, empty : std_logic;
	signal din, dout : std_logic_vector(8*C_WIDTH_BYTES-1 downto 0);
	signal dout_expected: std_logic_vector(8*C_WIDTH_BYTES-1 downto 0);
	signal full_expected, empty_expected : std_logic;
	

	
begin

	UUT : entity work.basic_fifo
	generic map (
		G_WIDTH_BYTES => C_WIDTH_BYTES,
		G_DEPTH => C_DEPTH
	)
	port map (
		clk => clk,
	    reset => reset,
	    din => din,
	    we => we,
	    re => re,
	    dout => dout,
	    full => full,
	    empty => empty
	);
	
	clock : process
	begin
		clk <= '0';
		wait for C_PERIOD / 2;
		clk <= '1';
		wait for C_PERIOD / 2;
	end process;
	
  PROC_SEQUENCER : process(clk)
    file in_file : text open read_mode is C_STIMULUS_FILE;
    file out_file : text open read_mode is C_OUTPUT_FILE;
    variable in_line : line;
    variable out_line : line;
    variable ok : boolean;
    variable v_reset : bit_vector(0 downto 0);
    variable v_din: bit_vector(8*C_WIDTH_BYTES-1 downto 0);
    variable v_re: bit_vector(0 downto 0);
    variable v_we: bit_vector(0 downto 0);
    variable v_dout: bit_vector(8*C_WIDTH_BYTES-1 downto 0);
    variable v_empty: bit_vector(0 downto 0);
    variable v_full: bit_vector(0 downto 0);
    variable tb_fail : boolean := false;
	variable step_counter : integer := 0;
  begin	
    if(rising_edge(clk)) then
      step_counter := step_counter + 1;
      -- input parsing
      if endfile(in_file) then
        report "Finishing simulation";
        if (tb_fail) then
          report "TEST BENCH FAILED" severity failure;
        else
          report "TEST BENCH PASSED" severity note;
        end if;
        finish;
      end if;
      readline(in_file, in_line);

      if in_line.all'length = 0 or in_line.all(1) = '#' then
        --skip;
      else
		  read(in_line, v_reset, ok);
		  assert ok;
		  reset <= to_stdlogicvector(v_reset)(0);
	
		  read(in_line, v_din, ok);
		  assert ok;
		  din <= to_stdlogicvector(v_din);
	
		  read(in_line, v_we, ok);
		  assert ok;
		  we <= to_stdlogicvector(v_we)(0);
	
		  read(in_line, v_re, ok);
		  assert ok;
		  re <= to_stdlogicvector(v_re)(0);
	  end if;
	  
	  --output parsing
	  readline(out_file, out_line);

      if out_line.all'length = 0 or out_line.all(1) = '#' then
        --skip;
      else
		  read(out_line, v_dout, ok);
		  assert ok;
		  dout_expected <= to_stdlogicvector(v_dout);
		  if not (dout = dout_expected) then
		  	report "dout match fail!";
		  	if (step_counter > 3) then
		  	    tb_fail := true;
		  	end if;
		  end if;
	
		  read(out_line, v_empty, ok);
		  assert ok;
		  empty_expected <= to_stdlogicvector(v_empty)(0);
		  if not (empty = empty_expected) then
		  	report "empty match fail";
		  	if (step_counter > 3) then
		  	    tb_fail := true;
		  	end if;
		  end if;
	
		  read(out_line, v_full, ok);
		  assert ok;
		  full_expected <= to_stdlogicvector(v_full)(0);
		  if not (full = full_expected) then
		  	report "full match fail";
		  	if (step_counter > 3) then
		  	    tb_fail := true;
		  	end if;
		  end if;
	  end if;
    end if;
  end process;
  
end tb;
