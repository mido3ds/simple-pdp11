library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity alu_tb is
    generic (runner_cfg: string);
end entity; 

architecture tb of alu_tb is
    constant CLK_FREQ: integer := 100e6; -- 100 MHz
    constant CLK_PERD: time    := 1000 ms / CLK_FREQ;

    signal clk: std_logic := '0';

    -- alu
    signal temp0, B: std_logic_vector(16-1 downto 0); --in
    signal en: std_logic; --in
    signal flagIn: std_logic_vector(4 downto 0); --in

    signal F: std_logic_vector(15 downto 0); --out
    signal flagOut: std_logic_vector(4 downto 0); --out

    -- alu_decoder
    signal IR_SUB: std_logic_vector(7 downto 0); --in
    signal ALU_MODE: std_logic_vector(3 downto 0);

    function parity(n: integer) return std_logic is
        variable v: std_logic_vector(15 downto 0);
        variable tmp: std_logic := '0';
    begin
        v := to_vec(n, 16);
        for i in 0 to 15 loop
            tmp := tmp xor v(i);
        end loop;
        return tmp;
    end function;

    function overflow_add(a, bb, c: integer) return std_logic is
        variable tmp: unsigned(15 downto 0);
    begin
        if a < 0 and bb < 0 then
            tmp := not to_unsigned(-a, 16) + 1;
            tmp := tmp + not to_unsigned(-bb, 16) + 1 + to_unsigned(c, 16);
            return not tmp(15);
        end if;

        if a > 0 and bb > 0 then    
            tmp := to_unsigned(a, 16) + to_unsigned(bb, 16) + to_unsigned(c, 16);
            return tmp(15);
        end if;

        return '0';
    end function;

    function overflow_sub(a, bb, c: integer) return std_logic is
        variable tmp: unsigned(15 downto 0);
    begin
        if a < 0 and bb < 0 then
            tmp := not to_unsigned(-a, 16) + 1;
            tmp := tmp - (not to_unsigned(-bb, 16) + 1) - to_unsigned(c, 16);
            return not tmp(15);
        end if;

        if a > 0 and bb > 0 then    
            tmp := to_unsigned(a, 16) - to_unsigned(bb, 16) - to_unsigned(c, 16);
            return tmp(15);
        end if;

        return '0';
    end function;
begin
    clk <= not clk after CLK_PERD / 2;

    alu: entity work.alu port map (
        temp0 => temp0, B => B, mode => ALU_MODE, 
        clk => clk, en => en, flagIn => flagIn, F => F, flagOut => flagOut
    );

    alu_decoder: entity work.alu_decoder port map (
        IR_SUB => IR_SUB, ALU_MODE => ALU_MODE
    );

    main: process
    begin
        test_runner_setup(runner, runner_cfg);

        B <= (others => '0');
        temp0 <= (others => '0');
        IR_SUB <= (others => '0');

        flagIn <= (others => '0');
        en <= '1';

        if run("no_enable") then
            en <= '0';

            wait for CLK_PERD;

            check_equal(F, to_vec('Z', 16));
            check_equal(flagOut, to_vec('Z', 5));
        end if;

        if run("enable") then
            en <= '1';

            wait for CLK_PERD;

            check(F /= to_vec('Z', 16));
            check(flagOut /= to_vec('Z', 5));
        end if;

        if run("add_carry0") then
            IR_SUB(7 downto 4) <= "0010";
            B <= to_vec(5, 16);
            temp0 <= to_vec(10, 16);
            flagIn(CARRY_FLAG) <= '0';

            wait for CLK_PERD;

            check_equal(F, to_vec(15, 16));
            check_equal(flagOut(CARRY_FLAG),  '0');
            check_equal(flagOut(ZERO_FLAG),   '0');
            check_equal(flagOut(NEG_FLAG),    '0');
            check_equal(flagOut(OVERFL_FLAG), overflow_add(5, 10, 0));
            check_equal(flagOut(PARITY_FLAG), parity(15));
        end if;

        if run("add_carry0_out0") then
            IR_SUB(7 downto 4) <= "0010";
            B <= to_vec(0, 16);
            temp0 <= to_vec(0, 16);
            flagIn(CARRY_FLAG) <= '0';

            wait for CLK_PERD;

            check_equal(F, to_vec(0, 16));
            check_equal(flagOut(CARRY_FLAG),  '0');
            check_equal(flagOut(ZERO_FLAG),   '1');
            check_equal(flagOut(NEG_FLAG),    '0');
            check_equal(flagOut(OVERFL_FLAG), overflow_add(0,0, 0));
            check_equal(flagOut(PARITY_FLAG), parity(15));
        end if;

        if run("add_carry1") then
            IR_SUB(7 downto 4) <= "0010";
            B <= to_vec(5, 16);
            temp0 <= to_vec(10, 16);
            flagIn(CARRY_FLAG) <= '1';

            wait for CLK_PERD;

            check_equal(F, to_vec(15, 16));
            check_equal(flagOut(CARRY_FLAG),  '0');
            check_equal(flagOut(ZERO_FLAG),   '0');
            check_equal(flagOut(NEG_FLAG),    '0');
            check_equal(flagOut(OVERFL_FLAG), overflow_add(5,10,0));
            check_equal(flagOut(PARITY_FLAG), parity(15));
        end if;

        if run("add_overflows") then
            IR_SUB(7 downto 4) <= "0010";
            B <= to_vec('1', 16);
            temp0 <= to_vec(1, 16);
            flagIn(CARRY_FLAG) <= '0';

            wait for CLK_PERD;

            check_equal(F, to_vec(0, 16));
            check_equal(flagOut(CARRY_FLAG),  '1');
            check_equal(flagOut(ZERO_FLAG),   '1');
            check_equal(flagOut(NEG_FLAG),    '0');
            check_equal(flagOut(OVERFL_FLAG), overflow_add(1, to_integer(unsigned(to_vec('1',16))),0));
            check_equal(flagOut(PARITY_FLAG), parity(0));
        end if;

        if run("adc_carry0") then
            IR_SUB(7 downto 4) <= "0011";
            B <= to_vec(5, 16);
            temp0 <= to_vec(10, 16);
            flagIn(CARRY_FLAG) <= '0';

            wait for CLK_PERD;

            check_equal(F, to_vec(15, 16));
            check_equal(flagOut(CARRY_FLAG),  '0');
            check_equal(flagOut(ZERO_FLAG),   '0');
            check_equal(flagOut(NEG_FLAG),    '0');
            check_equal(flagOut(OVERFL_FLAG), overflow_add(5, 10,0));
            check_equal(flagOut(PARITY_FLAG), parity(15));
        end if;

        if run("adc_carry1") then
            IR_SUB(7 downto 4) <= "0011";
            B <= to_vec(5, 16);
            temp0 <= to_vec(10, 16);
            flagIn(CARRY_FLAG) <= '1';

            wait for CLK_PERD;

            check_equal(F, to_vec(16, 16));
            check_equal(flagOut(CARRY_FLAG),  '0');
            check_equal(flagOut(ZERO_FLAG),   '0');
            check_equal(flagOut(NEG_FLAG),    '0');
            check_equal(flagOut(OVERFL_FLAG), overflow_add(5,10,1));
            check_equal(flagOut(PARITY_FLAG), parity(16));
        end if;

        if run("sub_carry0") then
            IR_SUB(7 downto 4) <= "0100";
            B <= to_vec(31, 16);
            temp0 <= to_vec(5, 16);
            flagIn(CARRY_FLAG) <= '0';

            wait for CLK_PERD;

            check_equal(F, to_vec(26, 16));
            check_equal(flagOut(CARRY_FLAG),  '0');
            check_equal(flagOut(ZERO_FLAG),   '0');
            check_equal(flagOut(NEG_FLAG),    '0');
            check_equal(flagOut(OVERFL_FLAG), overflow_sub(31,5,0));
            check_equal(flagOut(PARITY_FLAG), parity(26));
        end if;

        if run("sub_carry1") then
            IR_SUB(7 downto 4) <= "0100";
            B <= to_vec(31, 16);
            temp0 <= to_vec(5, 16);
            flagIn(CARRY_FLAG) <= '1';

            wait for CLK_PERD;

            check_equal(F, to_vec(26, 16));
            check_equal(flagOut(CARRY_FLAG),  '0');
            check_equal(flagOut(ZERO_FLAG),   '0');
            check_equal(flagOut(NEG_FLAG),    '0');
            check_equal(flagOut(OVERFL_FLAG), overflow_sub(31,5,0));
            check_equal(flagOut(PARITY_FLAG), parity(26));
        end if;

        if run("sub_carry0_outNegative") then
            IR_SUB(7 downto 4) <= "0100";
            B <= to_vec(5, 16);
            temp0 <= to_vec(31, 16);
            flagIn(CARRY_FLAG) <= '0';

            wait for CLK_PERD;

            check_equal(F, to_vec(-26, 16));
            check_equal(flagOut(CARRY_FLAG),  '0');
            check_equal(flagOut(ZERO_FLAG),   '0');
            check_equal(flagOut(NEG_FLAG),    '1');
            check_equal(flagOut(OVERFL_FLAG), overflow_sub(5,31,0));
            check_equal(flagOut(PARITY_FLAG), parity(-26));
        end if;

        if run("subc_carry0") then
            IR_SUB(7 downto 4) <= "0100";
            B <= to_vec(31, 16);
            temp0 <= to_vec(5, 16);
            flagIn(CARRY_FLAG) <= '0';

            wait for CLK_PERD;

            check_equal(F, to_vec(26, 16));
            check_equal(flagOut(CARRY_FLAG),  '0');
            check_equal(flagOut(ZERO_FLAG),   '0');
            check_equal(flagOut(NEG_FLAG),    '0');
            check_equal(flagOut(OVERFL_FLAG), overflow_sub(31,5,0));
            check_equal(flagOut(PARITY_FLAG), parity(26));
        end if;

        if run("subc_carry1") then
            IR_SUB(7 downto 4) <= "0100";
            B <= to_vec(31, 16);
            temp0 <= to_vec(5, 16);
            flagIn(CARRY_FLAG) <= '1';

            wait for CLK_PERD;

            check_equal(F, to_vec(25, 16));
            check_equal(flagOut(CARRY_FLAG),  '0');
            check_equal(flagOut(ZERO_FLAG),   '0');
            check_equal(flagOut(NEG_FLAG),    '0');
            check_equal(flagOut(OVERFL_FLAG), overflow_sub(31,5,1));
            check_equal(flagOut(PARITY_FLAG), parity(25));
        end if;

        if run("and") then
            IR_SUB(7 downto 4) <= "0110";
            B <= x"0F0F";
            temp0 <= x"00FF";

            wait for CLK_PERD;

            check_equal(F, to_vec(x"000F", 16));
            check_equal(flagOut(ZERO_FLAG),   '0');
            check_equal(flagOut(NEG_FLAG),    '1');
            check_equal(flagOut(OVERFL_FLAG), '0');
            check_equal(flagOut(PARITY_FLAG), parity(15));
        end if;

        if run("or") then
            IR_SUB(7 downto 4) <= "0111";
            B <= x"0F0F";
            temp0 <= x"00FF";

            wait for CLK_PERD;

            check_equal(F, to_vec(x"0FFF", 16));
            check_equal(flagOut(ZERO_FLAG),   '0');
            check_equal(flagOut(NEG_FLAG),    '1');
            check_equal(flagOut(OVERFL_FLAG), '0');
            check_equal(flagOut(PARITY_FLAG), parity(4095));
        end if;

        if run("xnor") then
            IR_SUB(7 downto 4) <= "1000";
            B <= x"0F0F";
            temp0 <= x"00FF";

            wait for CLK_PERD;

            check_equal(F, to_vec(x"000F", 16));
            check_equal(flagOut(ZERO_FLAG),   '0');
            check_equal(flagOut(NEG_FLAG),    '1');
            check_equal(flagOut(OVERFL_FLAG), '0');
            check_equal(flagOut(PARITY_FLAG), parity(15));
        end if;

        if run("cmp_bigger") then
            IR_SUB(7 downto 4) <= "1001";
            B <= to_vec(200, 16);
            temp0 <= to_vec(30, 16);

            wait for CLK_PERD;

            check_equal(F, to_vec(200-30, 16));
            check_equal(flagOut(ZERO_FLAG),   '0');
            check_equal(flagOut(NEG_FLAG),    '0');
            check_equal(flagOut(OVERFL_FLAG), '0');
            check_equal(flagOut(PARITY_FLAG), parity(200-30));
        end if;

        if run("cmp_smaller") then
            IR_SUB(7 downto 4) <= "1001";
            B <= to_vec(20, 16);
            temp0 <= to_vec(30, 16);

            wait for CLK_PERD;

            check_equal(F, to_vec(20-30, 16));
            check_equal(flagOut(ZERO_FLAG),   '0');
            check_equal(flagOut(NEG_FLAG),    '1');
            check_equal(flagOut(OVERFL_FLAG), '0');
            check_equal(flagOut(PARITY_FLAG), parity(20-30));
        end if;

        if run("cmp_equal") then
            IR_SUB(7 downto 4) <= "1001";
            B <= to_vec(200, 16);
            temp0 <= to_vec(200, 16);

            wait for CLK_PERD;

            check_equal(F, to_vec(200-200, 16));
            check_equal(flagOut(ZERO_FLAG),   '1');
            check_equal(flagOut(NEG_FLAG),    '0');
            check_equal(flagOut(OVERFL_FLAG), '0');
            check_equal(flagOut(PARITY_FLAG), parity(200-200));
        end if;

        test_runner_cleanup(runner);
        wait;
    end process;
end architecture;
