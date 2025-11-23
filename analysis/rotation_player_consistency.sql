-- Coefficient of Variation - ROTATION PLAYERS ONLY
-- Filters for players who actually get significant minutes
-- This gives more meaningful consistency comparisons

select
    first_name || ' ' || family_name as player_name,
    count(*) as games_played,
    round(avg(pts)::numeric, 1) as avg_points,
    round(stddev(pts)::numeric, 2) as stddev_points,
    round(((stddev(pts) / nullif(avg(pts), 0)) * 100)::numeric, 1) as cv_points,

    round(avg(ast)::numeric, 1) as avg_assists,
    round(((stddev(ast) / nullif(avg(ast), 0)) * 100)::numeric, 1) as cv_assists,

    round(avg(rebounds)::numeric, 1) as avg_rebounds,
    round(((stddev(rebounds) / nullif(avg(rebounds), 0)) * 100)::numeric, 1) as cv_rebounds,

    round(avg(minutes)::numeric, 1) as avg_minutes,

    round(avg(fg_pct)::numeric, 3) as avg_fg_pct,
    round(stddev(fg_pct)::numeric, 3) as stddev_fg_pct
from analytics.fct_player_game
group by 1
having
    count(*) >= 20  -- played at least 20 games
    and avg(minutes) >= 15  -- averaged at least 15 mins per game
    and avg(pts) >= 5  -- averaged at least 5 points per game
order by cv_points asc;
