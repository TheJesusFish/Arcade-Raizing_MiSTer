-- T80 synchronous bus wrapper with architectural state access.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use work.T80_Pack.all;

entity raizing_t80s_ss is
	generic(
		Mode    : integer := 0;
		T2Write : integer := 1;
		IOWait  : integer := 1
	);
	port(
		RESET_n        : in  std_logic;
		CLK            : in  std_logic;
		CEN            : in  std_logic := '1';
		WAIT_n         : in  std_logic := '1';
		INT_n          : in  std_logic := '1';
		NMI_n          : in  std_logic := '1';
		BUSRQ_n        : in  std_logic := '1';
		M1_n           : out std_logic;
		MREQ_n         : out std_logic;
		IORQ_n         : out std_logic;
		RD_n           : out std_logic;
		WR_n           : out std_logic;
		RFSH_n         : out std_logic;
		HALT_n         : out std_logic;
		BUSAK_n        : out std_logic;
		OUT0           : in  std_logic := '0';
		A              : out std_logic_vector(15 downto 0);
		DI             : in  std_logic_vector(7 downto 0);
		DO             : out std_logic_vector(7 downto 0);
		STATE_REG      : out std_logic_vector(211 downto 0);
		STATE_SET      : in  std_logic := '0';
		STATE_DIR      : in  std_logic_vector(211 downto 0) := (others => '0');
		STATE_EXT      : out std_logic_vector(16 downto 0);
		STATE_EXT_DIR  : in  std_logic_vector(16 downto 0) := (others => '0');
		STATE_BOUNDARY : out std_logic;
		MC_OUT         : out std_logic_vector(2 downto 0);
		TS_OUT         : out std_logic_vector(2 downto 0)
	);
end raizing_t80s_ss;

architecture rtl of raizing_t80s_ss is
	signal IntCycle_n : std_logic;
	signal NoRead     : std_logic;
	signal Write      : std_logic;
	signal IORQ       : std_logic;
	signal DI_Reg     : std_logic_vector(7 downto 0);
	signal MCycle     : std_logic_vector(2 downto 0);
	signal TState     : std_logic_vector(2 downto 0);
begin
	MC_OUT <= MCycle;
	TS_OUT <= TState;

	u0 : T80
	generic map(
		Mode => Mode,
		IOWait => IOWait)
	port map(
		CEN => CEN,
		M1_n => M1_n,
		IORQ => IORQ,
		NoRead => NoRead,
		Write => Write,
		RFSH_n => RFSH_n,
		HALT_n => HALT_n,
		WAIT_n => WAIT_n,
		INT_n => INT_n,
		NMI_n => NMI_n,
		RESET_n => RESET_n,
		BUSRQ_n => BUSRQ_n,
		BUSAK_n => BUSAK_n,
		CLK_n => CLK,
		A => A,
		DInst => DI,
		DI => DI_Reg,
		DO => DO,
		MC => MCycle,
		TS => TState,
		OUT0 => OUT0,
		IntCycle_n => IntCycle_n,
		REG => STATE_REG,
		DIRSet => STATE_SET,
		DIR => STATE_DIR,
		SS_REG => STATE_EXT,
		SS_DIR => STATE_EXT_DIR,
		SS_BOUNDARY => STATE_BOUNDARY
	);

	process (RESET_n, CLK)
	begin
		if RESET_n = '0' then
			RD_n <= '1';
			WR_n <= '1';
			IORQ_n <= '1';
			MREQ_n <= '1';
			DI_Reg <= (others => '0');
		elsif rising_edge(CLK) then
			if CEN = '1' then
				RD_n <= '1';
				WR_n <= '1';
				IORQ_n <= '1';
				MREQ_n <= '1';
				if MCycle = 1 then
					if TState = 1 or (TState = 2 and WAIT_n = '0') then
						RD_n <= not IntCycle_n;
						MREQ_n <= not IntCycle_n;
						IORQ_n <= IntCycle_n;
					end if;
					if TState = 3 then
						MREQ_n <= '0';
					end if;
				else
					if (TState = 1 or (TState = 2 and WAIT_n = '0')) and NoRead = '0' and Write = '0' then
						RD_n <= '0';
						IORQ_n <= not IORQ;
						MREQ_n <= IORQ;
					end if;
					if T2Write = 0 then
						if TState = 2 and Write = '1' then
							WR_n <= '0';
							IORQ_n <= not IORQ;
							MREQ_n <= IORQ;
						end if;
					else
						if (TState = 1 or (TState = 2 and WAIT_n = '0')) and Write = '1' then
							WR_n <= '0';
							IORQ_n <= not IORQ;
							MREQ_n <= IORQ;
						end if;
					end if;
				end if;
				if TState = 2 and WAIT_n = '1' then
					DI_Reg <= DI;
				end if;
			end if;
		end if;
	end process;
end;
