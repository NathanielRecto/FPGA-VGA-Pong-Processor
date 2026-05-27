library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity VGAController is
    Port (
        Switches : in STD_LOGIC_VECTOR(3 downto 0);
        DAC_Clk  : out STD_LOGIC;
        Clk      : in STD_LOGIC; -- 50 MHz Input
        Rout     : out STD_LOGIC_VECTOR(7 downto 0);
        Gout     : out STD_LOGIC_VECTOR(7 downto 0);
        Bout     : out STD_LOGIC_VECTOR(7 downto 0);
        Vsync    : out STD_LOGIC;
        Hsync    : out STD_LOGIC
    );
end VGAController;

architecture Behavioral of VGAController is

    -- Position Counters 
    signal HorizontalPosCounter, VerticalPosCounter : integer := 0;
    signal x, y : integer := 0; -- Simplified x and y coordinates
	 
	 signal last_scorer : integer := 0; -- +1 = left scored, -1 = right scored

    -- Vertical Position Counter Constants 
    constant VD  : integer := 480;
    constant VFP : integer := 10;
    constant VBP : integer := 33;
    constant VSP : integer := 2;
	 
	 -- Horizontal Position Counter Constants 
    constant HD  : integer := 640;
    constant HFP : integer := 16;
    constant HBP : integer := 48;
    constant HSP : integer := 96;

    -- Video control signal 
    signal Video_On   : STD_LOGIC:= '0';
    signal counter    : integer := 0;
    signal Pixel_Clk  : STD_LOGIC := '0';
    signal Vsync_internal : STD_LOGIC;
    signal Hsync_internal : STD_LOGIC;
    signal R, G, B : STD_LOGIC_VECTOR(7 downto 0);

    -- External Devices (ILA and ICON) 
    signal control0 : std_logic_vector(35 downto 0);
    signal ila_data : std_logic_vector(127 downto 0);
    signal trig0 : std_logic_vector(7 downto 0);

    -- Player and Ball Positions
    signal ball_x_velocity, ball_y_velocity : integer := 1;
    signal ball_x, ball_y : integer := 0;
    signal player1_y, player2_y : integer := 240; -- Start at center of screen (paddle positions)
    
    signal pause_counter : integer := 0;
    constant pause_delay : integer := 20; -- 400 ns score delay

    signal input_delay_counter : integer := 0;
    constant input_delay : integer := 300000; -- 6 ms input delay

    signal ball_delay_counter : integer := 0;
    constant ball_delay : integer := 150000; -- 3 ms ball delay

component icon
  PORT (
    CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0));

end component;

component ila
  PORT (
    CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
    CLK : IN STD_LOGIC;
    DATA : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    TRIG0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0));

end component;

begin

-- External Device Instances
system_icon : icon
  port map (
    CONTROL0 => CONTROL0);
	 
system_ila : ila
  port map (
    CONTROL => CONTROL0,
    CLK => CLK,
    DATA => ila_data,
    TRIG0 => trig0);

-- Generate Pixel Clock (25 MHz from 50 MHz input) - 640x480 at 60 Hz
process (Clk)
begin
    if rising_edge(Clk) then
	     counter <= counter + 1;
        if counter mod 2 = 0 then
            Pixel_Clk <= not Pixel_Clk;
            counter <= 0;
        end if;
    end if;
end process;

-- Horizontal and Vertical Position Counters
process (Pixel_Clk)
begin
    if rising_edge(Pixel_Clk) then
        if HorizontalPosCounter < (HD + HFP + HBP + HSP - 1) then
				HorizontalPosCounter <= HorizontalPosCounter + 1;
		  else
            HorizontalPosCounter <= 0;
            if VerticalPosCounter < (VD + VFP + VBP + VSP - 1) then
					VerticalPosCounter <= VerticalPosCounter + 1;
            else
					VerticalPosCounter <= 0;
            end if;
        end if;
    end if;
end process;

-- Horizontal Synchronization 
process (Pixel_Clk)
begin
    if rising_edge(Pixel_Clk) then
        if HorizontalPosCounter < (HD + HFP) or HorizontalPosCounter > (HD + HFP + HSP) then
            Hsync_internal <= '1';
        else
            Hsync_internal <= '0';
        end if;
    end if;
end process;

-- Vertical Synchronization 
process (Pixel_Clk)
begin
    if rising_edge(Pixel_Clk) then
        if VerticalPosCounter < (VD + VFP) or VerticalPosCounter > (VD + VFP + VSP) then
            Vsync_internal <= '1';
        else
            Vsync_internal <= '0';
        end if;
    end if;
end process;

-- Video On
process (Pixel_Clk)
begin
    if rising_edge(Pixel_Clk) then
        if HorizontalPosCounter < HD and VerticalPosCounter < VD then
            Video_On <= '1';
        else
            Video_On <= '0';
        end if;
    end if;
end process;

-- Draw (static and dynamic)
process (Pixel_Clk)
begin
    if rising_edge(Pixel_Clk) then
        if Video_On = '1' then
				if (y < 10 or y > 470) then
					R <= "00000000";
					G <= "11111111";
					B <= "00000000";

                -- Game Border (White) 
                elsif (((y > 15 AND y < 30) AND (x > 30 AND x < 610)) OR
                      ((y < 465 AND y > 450) AND (x > 30 AND x < 610)) OR
                      (((y > 15 AND y < 160) OR (y > 320 AND y < 465)) AND (x > 30 AND x < 45)) OR
                      (((y > 15 AND y < 160) OR (y > 320 AND y < 465)) AND (x > 595 AND x < 610))) then
                    
                    R <= "11111111";
                    G <= "11111111";
                    B <= "11111111";

                -- Centerline (center = 640/2 +-2) 5 lines
                elsif ((x > 318 AND x < 322) AND ((y > 60 AND y < 100) OR
                      (y > 140 AND y < 180) OR (y > 220 AND y < 260) OR
                      (y > 300 AND y < 340) OR (y > 380 AND y < 420))) then
                    
                    R <= "00000000";
                    G <= "00000000";
                    B <= "00000000";

                -- Draw Paddle 1 (Blue)
                elsif ((y > (player1_y - 30) AND y < (player1_y + 30)) AND
                      (x > 60 AND x < 70)) then
                    R <= "00000000";
                    G <= "00000000";
                    B <= "11111111";

                -- Draw Paddle 2 (Pink)
                elsif ((y > (player2_y - 30) AND y < (player2_y + 30)) AND
                      (x > 570 AND x < 580)) then
                    R <= "11111111";
                    G <= "00000000";
                    B <= "11111111";
                    
                -- Draw Ball (Yellow)
                elsif (((y > (ball_y - 6)) AND (y < (ball_y + 6)) AND (x > (ball_x - 6)) AND (x < (ball_x + 6)))) then
                    if (pause_counter > 0) then -- Goal was recently scored (Red)
                        R <= "11111111";
                        G <= "00000000";
                        B <= "00000000";
                    else
                        R <= "11111111";
                        G <= "11111111";
                        B <= "00000000";
                    end if;
                        
                -- Make all else green 
                else
                    R <= "00000000";
                    G <= "11111111";
                    B <= "00000000";
				end if;
        else -- When the screen is off (easier to debug)
            R <= "00000000";
            G <= "00000000";
            B <= "00000000";
        end if;
    end if;
end process;

-- Pong Game Logic 
process (Pixel_Clk)
begin
    if rising_edge(Pixel_Clk) then
        ball_delay_counter <= ball_delay_counter + 1;
        if (ball_delay_counter > ball_delay) then
            ball_delay_counter <= 0;

            ball_x <= ball_x + ball_x_velocity;
            ball_y <= ball_y + ball_y_velocity;

            -- Check if player 1 scored a goal (Goal position 160<y<320)
            if (((ball_x + ball_x_velocity - 4) < 20) AND ((ball_y + ball_y_velocity - 4) > 160) AND
                ((ball_y + ball_y_velocity + 4) < 320)) then
               
					 last_scorer <= +1;
                pause_counter <= pause_counter + 1;
                ball_x_velocity <= 0;
                ball_y_velocity <= 0;
				end if;

            -- Check if player 2 scored a goal (Goal position 160<y<320) 
            if (((ball_x + ball_x_velocity + 4) >= 620) AND ((ball_y + ball_y_velocity - 4) > 160) AND
                ((ball_y + ball_y_velocity + 4) < 320)) then
                
					 last_scorer <= -1;
                pause_counter <= pause_counter + 1;
                ball_x_velocity <= 0;
                ball_y_velocity <= 0;
            end if;
				
				
				-- keep pause ticking every frame while paused
				if (pause_counter > 0) then
					 pause_counter   <= pause_counter + 1;
					 ball_x_velocity <= 0;  -- stay frozen during pause
					 ball_y_velocity <= 0;
				end if;

				-- single respawn
				if (pause_counter = pause_delay) then
					 pause_counter <= 0;
					 ball_x <= 320;
					 ball_y <= 240;

					 if (last_scorer = +1) then       -- left scored → serve to the right
						  ball_x_velocity <= +1;
					 else                             -- right scored → serve to the left
						  ball_x_velocity <= -1;
					 end if;

					 ball_y_velocity <= 1;            -- pick up or down as you prefer
				end if;
            
				if (pause_counter = 0) then
					-- Check if the ball hits player 1's paddle (paddle height = 30)
					if (ball_y >= (player1_y - 30)) AND (ball_y <= (player1_y + 30)) then
							  if (ball_x < 66 AND ball_x >= 59) then
									ball_x_velocity <= -1;
							  elsif (ball_x >= 66 AND ball_x <= 71) then
									ball_x_velocity <= 1;
							  end if;
					end if;

					-- Check if the ball hits player 2's paddle
					if (ball_y >= (player2_y - 30)) AND (ball_y <= (player2_y + 30)) then
							  if (ball_x > 576 AND ball_x <= 581 ) then
									ball_x_velocity <= 1;
							  elsif (ball_x <= 576 AND ball_x >= 569) then
									ball_x_velocity <= -1;
							  end if;
					end if;

					-- Check if the ball hits the borders of the screen
					-- Top and bottom borders
					if (ball_y <= 160 OR ball_y >= 320) then
						 if ((ball_x + ball_x_velocity + 4) > 600) then
							  ball_x_velocity <= -1;
						 elsif ((ball_x + ball_x_velocity - 4) < 40) then
							  ball_x_velocity <= 1;
						 end if;
					end if;
					
					-- Left and right borders
					if ((ball_y + ball_y_velocity + 4) > 450) then
						 ball_y_velocity <= -1;
					elsif ((ball_y + ball_y_velocity - 4) < 30) then
						 ball_y_velocity <= 1;
					end if;
			  end if;
		 end if;
	end if;
end process;

-- Player Paddle Logic
process (Pixel_Clk)
begin
    if rising_edge(Pixel_Clk) then
        input_delay_counter <= input_delay_counter + 1;
        if (input_delay_counter > input_delay) then
            input_delay_counter <= 0;

            -- Player 1 Paddle Movement
				 if (Switches(0) = '0') then -- 0 to fix inversion issues
					  player1_y <= player1_y + 2;
				 else
					  player1_y <= player1_y - 2;
				 end if;

            -- Player 2 Paddle Movement
				 if (Switches(2) = '0') then -- 0 to fix inversion issues
					  player2_y <= player2_y + 2;
				 else
					  player2_y <= player2_y - 2;
				 end if;

            -- If Players are at the top or bottom of the screen, stop them
            if(player1_y > 420) then player1_y <= 420; end if;
            if(player1_y < 60) then player1_y <= 60; end if;
            if(player2_y > 420) then player2_y <= 420; end if;
            if(player2_y < 60) then player2_y <= 60; end if;
        end if;
    end if;
end process;

-- Output Internal Signals 
DAC_Clk <= Pixel_Clk;

Vsync <= Vsync_internal;
Hsync <= Hsync_internal;

Rout <= R;
Gout <= G;
Bout <= B;

-- Route Internal Signals 
x <= HorizontalPosCounter;
y <= VerticalPosCounter;

-- Route Internal Signals to ILA

ila_data(0) <= Pixel_Clk;
ila_data(10 downto 1) <= std_logic_vector(to_unsigned(HorizontalPosCounter, 10));
ila_data(20 downto 11) <= std_logic_vector(to_unsigned(VerticalPosCounter, 10));
ila_data(21) <= Hsync_internal;
ila_data(22) <= Vsync_internal;
ila_data(23) <= Video_On;
ila_data(31 downto 24) <= R;
ila_data(39 downto 32) <= G;
ila_data(47 downto 40) <= B;

end Behavioral;
