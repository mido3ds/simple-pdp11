library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity it_dec_tb is
    generic (runner_cfg: string);
end entity;

architecture tb of it_dec_tb is
    constant CLK_FREQ: integer := 100e6; -- 100 MHz
    constant CLK_PERD: time    := 1000 ms / CLK_FREQ;

    signal clk: std_logic := '1';
    signal ir: std_logic_vector(15 downto 0);
    signal flags: std_logic_vector(4 downto 0);
    signal address: std_logic_vector(5 downto 0);
    signal hlt : std_logic;
    signal naf: std_logic_vector(5 downto 0);
    signal c_signal: std_logic_vector(37 downto 0);
begin
    clk <= not clk after CLK_PERD / 2;

    id: entity work.it_dec port map (clk, ir, flags, address, hlt, c_signal, naf);

    main: process
    begin
        test_runner_setup(runner, runner_cfg);

        address <= ("100011");
        ir <= ("1101100000000000");
        flags <= (others => '0');

        if run("dummy_test") then
            address <= ("100011");
            ir <= ("1101100000000000");
            flags <= (others => '0');

            wait for CLK_PERD;
            wait for CLK_PERD;

        end if;

        wait for CLK_PERD/2;
        test_runner_cleanup(runner);
        wait;
    end process;
end architecture;