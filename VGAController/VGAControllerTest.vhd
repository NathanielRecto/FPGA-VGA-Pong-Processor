--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   19:24:51 11/11/2024
-- Design Name:   
-- Module Name:   /home/student1/r2sagu/COE758/VGAController/VGAControllerTest.vhd
-- Project Name:  VGAController
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: VGAController
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY VGAControllerTest IS
END VGAControllerTest;
 
ARCHITECTURE behavior OF VGAControllerTest IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT VGAController
    PORT(
         Switches : IN  std_logic_vector(3 downto 0);
         DAC_Clk : OUT  std_logic;
         Clk : IN  std_logic;
         Rout : OUT  std_logic_vector(7 downto 0);
         Gout : OUT  std_logic_vector(7 downto 0);
         Bout : OUT  std_logic_vector(7 downto 0);
         Vsync : OUT  std_logic;
         Hsync : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal Switches : std_logic_vector(3 downto 0) := (others => '0');
   signal Clk : std_logic := '0';

 	--Outputs
   signal DAC_Clk : std_logic;
   signal Rout : std_logic_vector(7 downto 0);
   signal Gout : std_logic_vector(7 downto 0);
   signal Bout : std_logic_vector(7 downto 0);
   signal Vsync : std_logic;
   signal Hsync : std_logic;

   -- Clock period definitions
   constant Clk_period : time := 20 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: VGAController PORT MAP (
          Switches => Switches,
          DAC_Clk => DAC_Clk,
          Clk => Clk,
          Rout => Rout,
          Gout => Gout,
          Bout => Bout,
          Vsync => Vsync,
          Hsync => Hsync
        );

   Clk_process :process
   begin
		Clk <= '0';
		wait for Clk_period/2;
		Clk <= '1';
		wait for Clk_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      --wait for 10000 ns;	

      wait for Clk_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
