use ipl;
#1 Data Types
SELECT 
    COLUMN_NAME, 
    DATA_TYPE 
FROM 
    INFORMATION_SCHEMA.COLUMNS
WHERE 
    TABLE_NAME = 'Ball_by_Ball' 
    AND TABLE_SCHEMA = 'ipl';
    
#2 Runs scored by RCB in first season    
select t.team_name,s.season_year,sum(runs_scored)+sum(er.extra_runs) as Total_runs_scored
from ball_by_ball byb
join player_match pm on byb.match_id = pm.match_id 
join team t on pm.team_id=t.team_id 
join matches m on byb.match_id = m.match_id 
join season s on m.season_id = s.season_id
join extra_runs er on byb.match_id=er.match_id
and byb.over_id = er.over_id 
and byb.ball_id = er.ball_id 
and byb.innings_no = er.innings_no
where t.team_name ='Royal Challengers Bangalore' 
group by t.team_name,s.season_year
order by s.season_year 
limit 1;

#3 players more than age 25 in 2014 
select 
	count(distinct pm.Player_id ) as Older_Than_25
from  Matches m 
join Player_Match pm on m.Match_ID = pm.Match_ID
join Player p on pm.Player_Id = p.Player_Id
where m.Season_Id = 7
and timestampdiff(Year, p.DOB, m.Match_Date) > 25;


#4 Matches RCB win in 2013
SELECT COUNT(*) AS Matches_Won_By_RCB_2013
FROM Matches m
JOIN Team t ON m.Match_Winner = t.Team_Id
JOIN Season s ON m.Season_Id = s.Season_Id
WHERE t.Team_Name = 'Royal Challengers Bangalore'
  AND s.Season_Year = 2013;
  
#5 Top 10 Batsman according to their strike rate in last 4 season
select * from (select p.player_name,count(*) as total_balls_faced,
sum(b.runs_scored) as total_runs,
round(sum(b.runs_scored)*100/count(*),2) as strike_rate from ball_by_ball b 
join matches m on b.match_id = m.match_id 
join season s on m.season_id = s.season_id 
join player p on b.striker = p.player_id 
where season_year >= (select max(season_year)-3 from season )
group by p.player_name
having total_balls_faced>=10
order by total_balls_faced desc 
limit 10) r 
order by strike_rate desc;

#6 Average runs scored by each batsman considering all season
select p.player_name,sum(b.runs_scored),
count(distinct b.match_id ,b.innings_no) as matches_played,
round(sum(b.runs_scored)/count(distinct b.match_id ,b.innings_no),2) as avg_runs from ball_by_ball b 
join player p on b.striker = p.player_id 
group by p.player_name
having matches_played>0
order by avg_runs desc;

#7 Average wickets taken by bowlers considering all season 
SELECT 
    p.Player_Name,
    COUNT(DISTINCT b.Match_Id, b.Innings_No) AS Innings_Bowled,
    COUNT(*) AS Total_Wickets,
    ROUND(COUNT(*) / COUNT(DISTINCT b.Match_Id, b.Innings_No), 2) AS Average_Wickets
FROM 
    Wicket_Taken wt
JOIN 
    Ball_by_Ball b 
    ON wt.Match_Id = b.Match_Id 
    AND wt.Over_Id = b.Over_Id 
    AND wt.Ball_Id = b.Ball_Id 
    AND wt.Innings_No = b.Innings_No
JOIN 
    Player p ON b.Bowler = p.Player_Id
WHERE 
    wt.Kind_Out IS NOT NULL
GROUP BY 
    p.Player_Name
HAVING 
    Innings_Bowled > 0
ORDER BY 
    Average_Wickets DESC;

#8 Average runs scored greater than overall average and average wickets taken than overall average
WITH BattingStats AS (
    SELECT 
        b.Striker AS Player_Id,
        SUM(b.Runs_Scored) AS Total_Runs,
        COUNT(DISTINCT b.Match_Id, b.Innings_No) AS Innings_Batted,
        ROUND(SUM(b.Runs_Scored) / COUNT(DISTINCT b.Match_Id, b.Innings_No), 2) AS Avg_Runs
    FROM Ball_by_Ball b
    GROUP BY b.Striker
    HAVING Innings_Batted > 0
),
WicketStats AS (
    SELECT 
        b.Bowler AS Player_Id,
        COUNT(*) AS Total_Wickets
    FROM Wicket_Taken wt
    JOIN Ball_by_Ball b 
        ON wt.Match_Id = b.Match_Id 
       AND wt.Over_Id = b.Over_Id 
       AND wt.Ball_Id = b.Ball_Id 
       AND wt.Innings_No = b.Innings_No
    GROUP BY b.Bowler
),
OverallAverages AS (
    SELECT 
        (SELECT ROUND(AVG(Avg_Runs), 2) FROM BattingStats) AS Overall_Batting_Avg,
        (SELECT ROUND(AVG(Total_Wickets), 2) FROM WicketStats) AS Overall_Wicket_Avg
),
QualifiedPlayers AS (
    SELECT 
        bs.Player_Id,
        bs.Avg_Runs,
        ws.Total_Wickets
    FROM BattingStats bs
    JOIN WicketStats ws ON bs.Player_Id = ws.Player_Id
)
SELECT 
    p.Player_Name,
    qp.Avg_Runs,
    qp.Total_Wickets
FROM QualifiedPlayers qp
JOIN Player p ON p.Player_Id = qp.Player_Id
CROSS JOIN OverallAverages oa
WHERE 
    qp.Avg_Runs > oa.Overall_Batting_Avg
    AND qp.Total_Wickets > oa.Overall_Wicket_Avg
ORDER BY 
    qp.Avg_Runs DESC, qp.Total_Wickets DESC;
    
#9 Wins and losses of RCB in individual venue
DROP TABLE IF EXISTS rcb_record;
create table rcb_record(
Venue_Name Varchar(255),
Wins int,
Losses int
);
Insert into rcb_record (Venue_Name,Wins,Losses)
select v.venue_name,
	sum(case when m.match_winner = t.team_id then 1 else 0 end) as Wins,
    sum(case when m.match_winner is not null and m.match_winner!=t.team_id and 
    (team_1 = t.team_id or team_2 = t.team_id) then 1 else 0 end) as Losses
    from matches m 
    join team t on t.team_name = 'Royal Challengers Bangalore'
    join venue v on v.venue_id = m.venue_id
     WHERE 
    (m.Team_1 = t.Team_Id OR m.Team_2 = t.Team_Id)
GROUP BY v.Venue_Name;
select * from rcb_record;

#10 Impact of bowling style on wicket taken 
 select 
	bs.Bowling_skill,
	COUNT(wt.Player_Out) AS Wicket_taken,
ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT p.player_id), 2) AS avg_wickets_per_bowler
from ball_by_ball as bb
join wicket_taken as wt on bb.Match_Id = wt.Match_Id and  bb.Innings_No = wt.Innings_No and bb.Over_Id = wt.Over_Id and bb.Ball_Id = wt.Ball_Id
join player as p on bb.Bowler = p.Player_Id
join bowling_style as bs on p.Bowling_skill = bs.Bowling_Id
group by bs.Bowling_skill
order by Wicket_taken desc;


#11 Performance of team on comparison from previous season based on runs scored and wickets taken
with Team_Performance as (
	select t.team_id,t.team_name,s.season_year,
    sum(b.runs_scored) as total_runs,count(wt.kind_out) as total_wickets
    from matches m 
    join season s on m.season_id=s.season_id 
    join ball_by_ball b on m.match_id = b.match_id
    join team t on b.team_batting = t.team_id 
    left join wicket_taken wt on wt.match_id = b.match_id 
		and wt.over_id = b.over_id
        and wt.ball_id = b.ball_id
        and wt.innings_no = b.innings_no 
        and wt.kind_out is not null
	GROUP BY t.Team_Id, t.Team_Name, s.Season_Year
    ),
ranked_performance as (
	select * ,row_number() over(partition by team_id order by season_year) as rn
		from team_performance
	),
comparison as (
	select curr.team_name,curr.season_year,
    curr.total_runs,curr.total_wickets,
    CASE 
            WHEN curr.total_runs > prev.total_runs AND curr.total_wickets > prev.total_wickets THEN 'Better'
            WHEN curr.total_runs < prev.total_runs AND curr.total_wickets < prev.total_wickets THEN 'Worse'
            ELSE 'Same or Mixed'
        END AS Performance_Status
    FROM ranked_performance curr
    JOIN ranked_performance prev 
        ON curr.team_Id = prev.team_Id 
       AND curr.rn = prev.rn + 1
 )
 SELECT *
FROM comparison
ORDER BY Team_Name, Season_Year;

#13 Average wicket taken by each bowler in each venue
    WITH Bowler_Avg_Wickets AS (
    SELECT 
        p.Player_Id,
        p.Player_Name,
        v.Venue_Name,
        round(COUNT(wt.Player_Out) / COUNT(DISTINCT m.Match_Id),2) AS Avg_Wickets
    FROM ball_by_ball AS bb
    JOIN wicket_taken AS wt 
        ON bb.Match_Id = wt.Match_Id 
        AND bb.Innings_No = wt.Innings_No 
        AND bb.Over_Id = wt.Over_Id 
        AND bb.Ball_Id = wt.Ball_Id
    JOIN player AS p ON bb.Bowler = p.Player_Id
    JOIN matches AS m ON bb.Match_Id = m.Match_Id
    JOIN venue AS v ON m.Venue_Id = v.Venue_Id
    GROUP BY p.Player_Id, p.Player_Name, v.Venue_Name
)
SELECT 
    Player_Id,
    Player_Name,
    Venue_Name,
    Avg_Wickets,
    row_number() OVER (ORDER BY Avg_Wickets DESC) AS Wicket_Rank
FROM Bowler_Avg_Wickets
ORDER BY Wicket_Rank;


#14 Players performed consistenly well in past season
# With bat
with season_wise_runs as (
select b.striker as player_id,p.player_name,
s.season_year,sum(b.runs_scored) as total_runs 
from ball_by_ball b 
join matches m on b.match_id = m.match_id
join season s on m.season_id = s.season_id 
join player p on b.striker = p.player_id
group by b.striker,p.player_name,s.season_year
),
player_avg_runs as (
select player_id,player_name,round(avg(total_runs),2) as avg_runs,
stddev_pop(total_runs) as std_dev_runs,
count(*) as season_played 
from season_wise_runs 
group by player_id,player_name
)
select * from player_avg_runs
where season_played>=3 and std_dev_runs<100
order by avg_runs desc;

#With ball
with season_wise_wickets as (
select b.bowler as player_id,p.player_name,
s.season_year,count(*) as total_wickets 
from wicket_taken wt 
join ball_by_ball b on wt.Match_Id = b.Match_Id 
     AND wt.Over_Id = b.Over_Id 
     AND wt.Ball_Id = b.Ball_Id 
     AND wt.Innings_No = b.Innings_No 
join matches m on b.match_id = m.match_id
join season s on m.season_id = s.season_id 
join player p on b.bowler = p.player_id
group by b.bowler,p.player_name,s.season_year
),
player_avg_wickets as (
select player_id,player_name,round(avg(total_wickets),2) as avg_wicket,
stddev_pop(total_wickets) as std_dev_wickets,
count(*) as season_played 
from season_wise_wickets 
group by player_id,player_name
)
select * from player_avg_wickets
where season_played>=3 and std_dev_wickets<5
order by avg_wicket desc;

#15 Players more suited to specific venue or conditions
SELECT p.player_name,v.venue_name,COUNT(DISTINCT b.Match_Id, b.Innings_No) AS Matches_Played,
round(count(*)/(count(distinct b.match_id,b.innings_no)),2) as avg_wickets
from wicket_taken wt 
join ball_by_ball b on wt.Match_Id = b.Match_Id 
                  AND wt.Over_Id = b.Over_Id 
                  AND wt.Ball_Id = b.Ball_Id 
                  AND wt.Innings_No = b.Innings_No 
join player p on b.bowler = p.player_id 
join matches m on b.match_id = m.match_id 
join venue v on m.venue_id = v.venue_id 
where wt.kind_out is not null
group by p.player_name,v.venue_name 
having matches_played>=3
order by avg_wickets desc;

   
    
# Subjective Questions 
#1 Toss Impact
select toss_decide,count(*) as total_matches,
sum(case when toss_winner=match_winner then 1 else 0 end) as toss_winner_won,
round(sum(case when toss_winner=match_winner then 1 else 0 end)*100/count(*) ,2) as winning_percentage from matches
group by toss_decide;

# Specific to venue
select v.venue_name, toss_name,count(*) as total_matches,
sum(case when toss_winner=match_winner then 1 else 0 end) as toss_winner_match_winner,
round(sum(case when toss_winner=match_winner then 1 else 0 end)*100/count(*) ,2) as winning_percentage from matches m
join toss_decision t on m.toss_decide = t.toss_id
join venue v on m.venue_id = v.venue_id
group by v.venue_name,toss_decide
order by total_matches desc,winning_percentage desc;

#2 Best players fit for the team
# High Strike Rate
select p.player_name ,round(sum(runs_scored)*100/count(*) ,2) as strike_rate ,
count(*) as balls_faced from ball_by_ball b 
join player p on b.striker = p.player_id 
join matches m on b.match_id = m.match_id 
join
(select season_id from season 
order by season_id desc 
limit 4) as recent_season on m.season_id = recent_season.season_id
group by player_name 
having balls_faced>=100
order by strike_rate desc 
limit 10;

# High Avg Wicket
select p.player_name ,
count(*) as total_wicket,round(count(*)/count(distinct b.match_id) ,2) as avg_wicket from wicket_taken wt
join ball_by_ball b on b.match_id = wt.match_id
and b.ball_id = wt.ball_id
and b.over_id = wt.over_id 
and b.innings_no = wt.innings_no 
join player p on b.bowler = p.player_id 
join matches m on b.match_id = m.match_id 
where wt.kind_out is not null
group by player_name 
having count(distinct b.match_id)>=10
order by avg_wicket desc 
limit 10;

#4 All-Rounder Performance
WITH BattingStats AS (
    SELECT 
        b.Striker AS Player_Id,
        SUM(b.Runs_Scored) AS Total_Runs,
        COUNT(DISTINCT b.Match_Id, b.Innings_No) AS Innings_Batted,
        ROUND(SUM(b.Runs_Scored) / COUNT(DISTINCT b.Match_Id, b.Innings_No), 2) AS Avg_Runs
    FROM Ball_by_Ball b
    GROUP BY b.Striker
    HAVING Innings_Batted > 0
),
WicketStats AS (
    SELECT 
        b.Bowler AS Player_Id,
        COUNT(*) AS Total_Wickets
    FROM Wicket_Taken wt
    JOIN Ball_by_Ball b 
        ON wt.Match_Id = b.Match_Id 
       AND wt.Over_Id = b.Over_Id 
       AND wt.Ball_Id = b.Ball_Id 
       AND wt.Innings_No = b.Innings_No
    GROUP BY b.Bowler
),
OverallAverages AS (
    SELECT 
        (SELECT ROUND(AVG(Avg_Runs), 2) FROM BattingStats) AS Overall_Batting_Avg,
        (SELECT ROUND(AVG(Total_Wickets), 2) FROM WicketStats) AS Overall_Wicket_Avg
),
QualifiedPlayers AS (
    SELECT 
        bs.Player_Id,
        bs.Avg_Runs,
        ws.Total_Wickets
    FROM BattingStats bs
    JOIN WicketStats ws ON bs.Player_Id = ws.Player_Id
)
SELECT 
    p.Player_Name,
    qp.Avg_Runs,
    qp.Total_Wickets
FROM QualifiedPlayers qp
JOIN Player p ON p.Player_Id = qp.Player_Id
CROSS JOIN OverallAverages oa
WHERE 
    qp.Avg_Runs > oa.Overall_Batting_Avg
    AND qp.Total_Wickets > oa.Overall_Wicket_Avg
ORDER BY 
    qp.Avg_Runs DESC, qp.Total_Wickets DESC;
    
#5 Players positively infuence morale and performance of team
SELECT 
    p.player_name,
    COUNT(DISTINCT pm.match_id) AS matches_played,
    SUM(CASE WHEN m.match_winner = pm.team_id THEN 1 ELSE 0 END) AS matches_won,
    ROUND(SUM(CASE WHEN m.match_winner = pm.team_id THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT pm.match_id), 2) AS win_percentage
FROM player_match pm
JOIN player p ON pm.player_id = p.player_id
JOIN matches m ON pm.match_id = m.match_id
GROUP BY p.player_name
HAVING COUNT(DISTINCT pm.match_id) > 40
ORDER BY win_percentage DESC
LIMIT 50;

#6 Suggestion for RCB before auction
#Average runs scored by indian batsman
select t.team_name,s.season_year ,round(sum(b.runs_scored)/count(distinct b.match_id),2) as avg_runs from player p 
join country c on p.country_name = c.country_id
join player_match pm on p.player_id = pm.player_id
join team t on pm.team_id=t.team_id
join ball_by_ball b on pm.match_id = b.match_id
join matches m on b.match_id=m.match_id
join season s on m.season_id = s.season_id
where c.country_name = 'India'
group by t.team_name,s.season_year
order by s.season_year desc;

#Bowling Attack on Death overs
SELECT 
    t.team_name,
    round(SUM(b.runs_scored)/count(distinct b.match_id),2) AS total_runs_conceded,
    round(COUNT(wt.kind_out)/count(distinct b.match_id),2) AS total_wickets
FROM ball_by_ball b
JOIN player_match pm 
    ON b.match_id = pm.match_id 
    AND b.bowler = pm.player_id
JOIN team t 
    ON pm.team_id = t.team_id
LEFT JOIN wicket_taken wt 
    ON b.match_id = wt.match_id 
    AND b.over_id = wt.over_id 
    AND b.ball_id = wt.ball_id 
    AND b.innings_no = wt.innings_no
WHERE b.over_id BETWEEN 16 AND 20
GROUP BY t.team_name
ORDER BY total_wickets DESC;

#7 Factors contributing high scoring matches
#Flat pitches and small boundaries
with team_score as (
	select match_id,innings_no,sum(runs_scored) as total_runs 
    from ball_by_ball b 
    group by match_id,innings_no
    ),
high_scoring_match as (
	SELECT match_id
    FROM team_score
    GROUP BY match_id
    HAVING COUNT(*) = 2
       AND MIN(total_runs) > 170
       )
   select m.match_id,v.venue_name,ts1.total_runs as team1_score,
    ts2.total_runs AS team2_score
FROM high_scoring_match hsm
JOIN matches m ON hsm.match_id = m.match_id
join venue v on m.venue_id=v.venue_id
JOIN team_score ts1 ON ts1.match_id = m.match_id AND ts1.innings_no = 1
JOIN team_score ts2 ON ts2.match_id = m.match_id AND ts2.innings_no = 2; 

#Powerplay runs
select t.team_name ,round(avg(powerplay_runs),2) as avg_powerplay_runs from 
(select b.match_id,pm.team_id,sum(b.runs_scored) as powerplay_runs
from ball_by_ball b 
join player_match pm on b.match_id = pm.match_id 
and b.striker = pm.player_id
where b.over_id <=6
group by b.match_id,pm.team_id
) r 
join team t on r.team_id = t.team_id
group by t.team_name;

#8 Home Ground Advantage on team performance
WITH home_grounds AS (
    SELECT 'Royal Challengers Bangalore' AS team_name, 'M Chinnaswamy Stadium' AS home_ground
    UNION ALL
    SELECT 'Mumbai Indians', 'Wankhede Stadium'
    UNION ALL
    SELECT 'Chennai Super Kings', 'MA Chidambaram Stadium, Chepauk'
    UNION ALL
    SELECT 'Kolkata Knight Riders', 'Eden Gardens'
    UNION ALL
    SELECT 'Delhi Daredevils', 'Feroz Shah Kotla'
    UNION ALL
    SELECT 'Sunrisers Hyderabad', 'Rajiv Gandhi International Stadium, Uppal'
    UNION ALL
    SELECT 'Kings XI Punjab', 'Punjab Cricket Association Stadium, Mohali'
),
home_matches AS (
    SELECT 
        m.match_id,
        v.venue_name,
        t.team_id,
        t.team_name,
        m.match_winner
    FROM matches m
    JOIN venue v ON m.venue_id = v.venue_id
    JOIN team t ON m.team_1 = t.team_id OR m.team_2 = t.team_id
),
home_performance AS (
    SELECT 
        hg.team_name,
        COUNT(*) AS total_home_matches,
        SUM(CASE WHEN m.match_winner = m.team_id THEN 1 ELSE 0 END) AS home_wins
    FROM home_matches m
    JOIN home_grounds hg 
        ON m.team_name = hg.team_name AND m.venue_name = hg.home_ground
    GROUP BY hg.team_name
)
SELECT 
    team_name,
    total_home_matches,
    home_wins,
    ROUND((home_wins * 100.0 / total_home_matches), 2) AS win_percentage_at_home
FROM home_performance
ORDER BY win_percentage_at_home DESC;                                              

#9 RCB past season performance
SELECT 
    s.season_year,
    'Royal Challengers Bangalore' AS team_name,
    COUNT(*) AS total_matches,
    SUM(CASE 
        WHEN m.match_winner = rcb.team_id THEN 1 
        ELSE 0 
    END) AS matches_won
FROM matches m
JOIN season s ON m.season_id = s.season_id
JOIN team rcb ON (m.team_1 = rcb.team_id OR m.team_2 = rcb.team_id)
WHERE rcb.team_name = 'Royal Challengers Bangalore'
GROUP BY s.season_year
ORDER BY s.season_year;

#Average runs and strike rate for RCB players
SELECT
    p.player_name,
    COUNT(DISTINCT b.match_id) AS matches_played,
    SUM(b.runs_scored) AS total_runs,
    COUNT(b.ball_id) AS balls_faced,
    COUNT(w.kind_out) AS times_out,
    ROUND(SUM(b.runs_scored) * 1.0 / NULLIF(COUNT(w.kind_out), 0), 2) AS batting_avg,
    ROUND(SUM(b.runs_scored) * 100.0 / COUNT(b.ball_id), 2) AS strike_rate
FROM ball_by_ball b
JOIN player_match pm ON b.match_id = pm.match_id AND b.striker = pm.player_id
JOIN player p ON pm.player_id = p.player_id
JOIN team t ON pm.team_id = t.team_id
LEFT JOIN wicket_taken w ON w.match_id = b.match_id 
    AND w.player_out = pm.player_id 
    AND w.ball_id = b.ball_id 
    AND w.over_id = b.over_id
WHERE t.team_name = 'Royal Challengers Bangalore'
GROUP BY p.player_name
ORDER BY total_runs DESC;

# Replacing Delhi Daredevils with Delhi capitals
UPDATE Match
SET Opponent_Team = 'Delhi_Daredevils'
WHERE Opponent_Team = 'Delhi_Capitals';



