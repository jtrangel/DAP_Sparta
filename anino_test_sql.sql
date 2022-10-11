CREATE TABLE game_data(
	event_user VARCHAR(200),
	install_date timestamp,
	event_name VARCHAR(200),
	event_time timestamp,
	slotmachine_id VARCHAR(200),
	current_level int,
	session_id VARCHAR(200),
	session_token VARCHAR(200),
	total_bet_amount BIGINT,
	max_bet_amount BIGINT,
	amount BIGINT,
	spin_type VARCHAR(100),
	win_type VARCHAR(100)
);

COPY game_data
FROM 'D:\Users\MSI\Desktop\Sparta\datascientist-test-data.csv'
DELIMITER ','
CSV HEADER;

-- Checking imported data
SELECT * FROM game_data LIMIT 10;

-- How many unique players exist in the data?
-- 1275

SELECT count(sub.unique_users)
FROM
(
	SELECT DISTINCT event_user as unique_users, count(*) FROM game_data
	GROUP BY event_user 
) sub;

-- What is the Day 0 to 3 Retention of the players? (What percentage of players who installed
-- returned X days from install)
-- Day 0: 1261/1275 = 98.9%.
-- Day 1: 341/1275 = 26.75%
-- Day 2: 235/1275 = 18.4%
-- Day 3: 223/1275 = 17.5%

SELECT COUNT(event_user) as retained_users
FROM
(
	SELECT DISTINCT event_user, count(*)
	FROM
	(
		SELECT *, EXTRACT(epoch FROM sub.day_diff)/86400 as converted_diff_days
		FROM
		(
			SELECT event_user, install_date, event_time, 
			(event_time - install_date) as day_diff 
			FROM game_data
			ORDER BY install_date
		) sub
	) sub2
	WHERE sub2.converted_diff_days > 0 AND sub2.converted_diff_days <= 1
	--WHERE sub2.converted_diff_days > 1 AND sub2.converted_diff_days <= 2
	--WHERE sub2.converted_diff_days > 2 AND sub2.converted_diff_days <= 3
	--WHERE sub2.converted_diff_days > 3 AND sub2.converted_diff_days <= 4
	GROUP BY event_user
) sub3;

-- What is the average number of slot machines a player plays in a session? What is the
-- average number of spins played in each machine session? 
-- 2.786 avg slot machines played per session.
-- 107.54 avg spins per machine session.

--SELECT slots_played_per_session, count(*) ---- For visualization
SELECT avg(sub2.slots_played_per_session) as avg_slots
FROM
(
	SELECT session_id, count(*) as slots_played_per_session
	FROM
	(
		SELECT session_id, session_token, spin_type
		FROM game_data
		GROUP BY session_id, session_token, spin_type
		ORDER BY session_id
	) sub
	GROUP BY session_id
) sub2
-- GROUP BY slots_played_per_session----For visualization
;

SELECT avg(sub2.spins_per_machine) as avg_spins
FROM
(
	SELECT slotmachine_id, session_token, count(*) as spins_per_machine
	FROM
	(
		SELECT slotmachine_id, session_token, spin_type
		FROM game_data
		ORDER BY session_token
	) sub
	GROUP BY slotmachine_id, session_token
	ORDER BY spins_per_machine DESC
) sub2 ;

-- Additional query for visualization
SELECT slotmachine_id, count(*) as spin_count
FROM
(
	SELECT slotmachine_id, session_token, count(*) as spins_per_machine
	FROM
	(
		SELECT slotmachine_id, session_token, spin_type
		FROM game_data
		ORDER BY session_token
	) sub
	GROUP BY session_token, slotmachine_id 
) sub2
GROUP BY slotmachine_id 
ORDER BY spin_count DESC;

-- What is the average RTP (Return to Player) for each slot machine? RTP is calculated using
-- the formula below.

CREATE TABLE avg_rtp_per_slot
AS
SELECT slotmachine_id, sum(amount) as total_winnings, sum(total_bet_amount) as total_bettings, 
(sum(amount::float)/sum(total_bet_amount::float)) as average_rtp
FROM game_data
GROUP BY slotmachine_id
;

SELECT slotmachine_id, average_rtp FROM avg_rtp_per_slot
ORDER BY average_rtp DESC;

--  What is the probability of hitting the various win_types in any given round?
-- 	0.776 or roughly 78%.
SELECT (
	SELECT SUM(sub.wins)
	FROM
	(
		SELECT win_type, count(*) as wins 
		FROM game_data
		WHERE win_type != 'none'
		GROUP BY win_type
	) sub
)/(
SELECT no_wins
FROM(
	SELECT win_type, count(*) as no_wins 
	FROM game_data
	WHERE win_type = 'none'
	GROUP BY win_type
	) sub
) as probability
;


-- Plot the distribution of NetPay for all spins with a bet amount of 5000 on the Cleopatra slot
-- machine. The formula for NetPay is total winnings / total bettings.

CREATE TABLE netpay_table 
AS
SELECT netpay, count(*)
FROM
(
	SELECT slotmachine_id, amount, total_bet_amount, amount::float/total_bet_amount::float as NetPay
	FROM game_data 
	WHERE slotmachine_id = 'Cleopatra' and total_bet_amount = 5000
) sub
GROUP BY netpay
ORDER BY netpay;

SELECT * FROM netpay_table ORDER BY count, netpay;

-- What is the average number of times a player will change their bet size in a slot machine
-- session? Do players only tend to adjust their bet upwards?
-- 2.514 avg changes

SELECT avg_bet_changes, count(*) --avg(sub2.avg_bet_changes)
FROM
(
	SELECT session_token, count(*) as avg_bet_changes 
	FROM
	(
		SELECT count(event_user), session_token, total_bet_amount 
		FROM game_data
		GROUP BY session_token, total_bet_amount
	) sub
	GROUP BY session_token
) sub2
GROUP BY avg_bet_changes
;




