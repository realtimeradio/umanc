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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity basic_fifo_tb is
end basic_fifo_tb;

architecture tb of basic_fifo_tb is

	constant C_PERIOD : time := 10 ns;

	constant C_WIDTH_BYTES : integer := 1;
	constant C_DEPTH       : integer := 16;
	
	signal clk, reset, we, re, full, empty : std_logic;
	signal din, dout : std_logic_vector(8*C_WIDTH_BYTES-1 downto 0);
	
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
		clk <= '1';
		wait for C_PERIOD / 2;
		clk <= '0';
		wait for C_PERIOD / 2;
	end process;
	
	
	
-- *** Test Bench - User Defined Section ***
   testbench : process
   begin
        reset <= '1';
        re <= '0';
        we <= '0';
        din <= (others => '0');

        wait for 4 * C_PERIOD;
        wait for C_PERIOD / 2;

        reset <= '0';

        WAIT FOR 4 * C_PERIOD;

        we <= '1';
        din <= x"ff";
        wait for 10*C_PERIOD; 

        we <= '0';
        wait for C_PERIOD; 

        we <='1';
        din <= x"ee";

        wait for C_PERIOD;

        we <= '0';

		wait for C_PERIOD;

        -- write to fifo
        for test_vec in 0 to 7 loop
            WAIT FOR C_PERIOD;
            we <= '1';
            din <= std_logic_vector(to_unsigned(test_vec, 8*C_WIDTH_BYTES));   
        end loop;   

        wait for C_PERIOD;

        re <= '1';
        
        wait for C_PERIOD;
        
        re <= '0';

        wait for 3*C_PERIOD;


        -- read from fifo   
        for test_vec in 0 to 8 loop
            wait for C_PERIOD;
            re <= '1';     
        end loop;   

        -- write to fifo        
        for test_vec in 0 to 7 loop
            wait for C_PERIOD;
            we <= '1';
            din <= std_logic_vector(to_unsigned(test_vec, 8*C_WIDTH_BYTES));
            wait for C_PERIOD;
            we <= '0';       
        end loop;       

        -- read from fifo   
        for test_vec in 0 to 11 loop
            wait for C_PERIOD;
            re <= '1';
            wait for C_PERIOD;
            re <= '0';       
        end loop;   

        wait for 3*C_PERIOD;


        -- read and write to fifo       
        for test_vec in 0 to 3 loop
            wait for C_PERIOD;
            we <= '1';
            re <= '1';
            din <= std_logic_vector(to_unsigned(test_vec, 8*C_WIDTH_BYTES));
            wait for C_PERIOD;
            we <= '0';
            re <= '0';           
        end loop;           

        -- read from fifo
        for test_vec in 0 to 7 loop
            wait for C_PERIOD;
            re <= '1';   
        end loop;       

        -- write to fifo    
        for test_vec in 0 to 6 loop
            wait for C_PERIOD;
            we <= '1';
            din <= std_logic_vector(to_unsigned(test_vec, 8*C_WIDTH_BYTES));
            wait for C_PERIOD;
            we <= '0';       
        end loop;           

      wait; -- will wait forever
   END PROCESS;
-- *** End Test Bench - User Defined Section ***
	
end tb;
