library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reg is
    generic (WORD_WIDTH: integer := 16);

    port (
        data_in: in std_logic_vector(WORD_WIDTH-1 downto 0);
        enable_in, enable_out, clk, clr: in std_logic;

        data_out: out std_logic_vector(WORD_WIDTH-1 downto 0)
    );
end entity; 

architecture rtl of reg is
    signal data: std_logic_vector(WORD_WIDTH-1 downto 0) := (others => '0');
begin
    process (enable_in, clk, data_in, clr) 
    begin
        if enable_in = '1' and clk = '1' then
            data <= data_in;
        end if;

        if clr = '1' and clk = '1' then
            data <= (others => '0');
        end if;
    end process;

    process (enable_out, clk) 
    begin
        if enable_out = '1' then
            if rising_edge(clk) then
                data_out <= data;
            end if;
        else 
            data_out <= (others => 'Z');
        end if;
    end process;
end architecture;
