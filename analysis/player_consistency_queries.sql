-- Player Consistency Analysis Queries
-- Question: "Which Nuggets player has the lowest game-to-game variance?"

-- ============================================================================
-- 1. Basic Standard Deviation (Raw Variance)
-- ============================================================================
-- Shows absolute variance in points and minutes
-- Problem: Players with higher averages naturally have higher variance

select
    first_name || ' ' || family_name as player_name,
    count(*) as games_played,
    round(avg(pts)::numeric, 1) as avg_points,
    round(stddev(pts)::numeric, 2) as stddev_points,
    round(avg(minutes)::numeric, 1) as avg_minutes,
    round(stddev(minutes)::numeric, 2) as stddev_minutes
from analytics.fct_player_game
group by 1
having count(*) >= 10  -- min 10 games to avoid small sample size
order by stddev_points asc;


-- ============================================================================
-- 2. Coefficient of Variation (CV) - Better for Consistency
-- ============================================================================
-- CV = (stddev / mean) * 100
-- Normalizes variance by the mean, making it comparable across players
-- Lower CV = more consistent

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

    round(avg(fg_pct)::numeric, 3) as avg_fg_pct,
    round(stddev(fg_pct)::numeric, 3) as stddev_fg_pct
from analytics.fct_player_game
group by 1
having count(*) >= 10
order by cv_points asc;


-- ============================================================================
-- 3. Efficiency Consistency
-- ============================================================================
-- Which players have the most consistent shooting?

select
    first_name || ' ' || family_name as player_name,
    count(*) as games_played,

    -- FG% consistency
    round(avg(fg_pct)::numeric, 3) as avg_fg_pct,
    round(stddev(fg_pct)::numeric, 3) as stddev_fg_pct,
    round(((stddev(fg_pct) / nullif(avg(fg_pct), 0)) * 100)::numeric, 1) as cv_fg_pct,

    -- 3P% consistency
    round(avg(three_pct)::numeric, 3) as avg_three_pct,
    round(stddev(three_pct)::numeric, 3) as stddev_three_pct,

    -- FT% consistency
    round(avg(ft_pct)::numeric, 3) as avg_ft_pct,
    round(stddev(ft_pct)::numeric, 3) as stddev_ft_pct

from analytics.fct_player_game
where fga >= 5  -- only games where they attempted at least 5 FG
group by 1
having count(*) >= 10
order by stddev_fg_pct asc;


-- ============================================================================
-- 4. Plus/Minus Consistency (Impact on Team)
-- ============================================================================
-- Who consistently helps the team when on the floor?

select
    first_name || ' ' || family_name as player_name,
    count(*) as games_played,
    round(avg(plus_minus)::numeric, 1) as avg_plus_minus,
    round(stddev(plus_minus)::numeric, 2) as stddev_plus_minus,
    round(((stddev(plus_minus) / nullif(abs(avg(plus_minus)), 0)) * 100)::numeric, 1) as cv_plus_minus,
    round(avg(minutes)::numeric, 1) as avg_minutes
from analytics.fct_player_game
group by 1
having count(*) >= 10
order by avg_plus_minus desc, stddev_plus_minus asc;


-- ============================================================================
-- 5. Composite Consistency Score
-- ============================================================================
-- Combines multiple dimensions of consistency
-- Lower score = more consistent across all metrics

with player_variance as (
    select
        first_name || ' ' || family_name as player_name,
        count(*) as games_played,

        -- Calculate CV for each metric
        (stddev(pts) / nullif(avg(pts), 0)) as cv_points,
        (stddev(ast) / nullif(avg(ast), 0)) as cv_assists,
        (stddev(rebounds) / nullif(avg(rebounds), 0)) as cv_rebounds,
        (stddev(fg_pct) / nullif(avg(fg_pct), 0)) as cv_fg_pct,

        -- Averages for context
        avg(pts) as avg_points,
        avg(minutes) as avg_minutes
    from analytics.fct_player_game
    group by 1
    having count(*) >= 10
)

select
    player_name,
    games_played,
    round(avg_points::numeric, 1) as avg_points,
    round(avg_minutes::numeric, 1) as avg_minutes,

    -- Individual CVs
    round((cv_points * 100)::numeric, 1) as cv_points_pct,
    round((cv_assists * 100)::numeric, 1) as cv_assists_pct,
    round((cv_rebounds * 100)::numeric, 1) as cv_rebounds_pct,

    -- Composite consistency score (average of CVs)
    round((((cv_points + cv_assists + cv_rebounds + coalesce(cv_fg_pct, 0)) / 4) * 100)::numeric, 1) as composite_consistency_score

from player_variance
order by composite_consistency_score asc;


-- ============================================================================
-- 6. Rolling Standard Deviation (Advanced)
-- ============================================================================
-- Shows how consistency changes over time
-- Using a 5-game rolling window

with game_stats as (
    select
        first_name || ' ' || family_name as player_name,
        game_id,
        pts,
        row_number() over (partition by player_id order by game_id) as game_number
    from analytics.fct_player_game
),

rolling_stats as (
    select
        player_name,
        game_id,
        game_number,
        pts,
        avg(pts) over (
            partition by player_name
            order by game_number
            rows between 4 preceding and current row
        ) as rolling_avg_5game,
        stddev(pts) over (
            partition by player_name
            order by game_number
            rows between 4 preceding and current row
        ) as rolling_stddev_5game
    from game_stats
)

select
    player_name,
    game_number,
    pts,
    round(rolling_avg_5game::numeric, 1) as rolling_avg_5game,
    round(rolling_stddev_5game::numeric, 2) as rolling_stddev_5game
from rolling_stats
where game_number >= 5  -- only show after we have 5 games
order by player_name, game_number;


-- ============================================================================
-- 7. Z-Score Analysis (Statistical Outliers)
-- ============================================================================
-- Shows which games were statistical outliers for each player
-- Z-score > 2 or < -2 indicates unusual performance (top/bottom ~5%)

with player_stats as (
    select
        first_name || ' ' || family_name as player_name,
        game_id,
        pts,
        avg(pts) over (partition by player_id) as player_avg_pts,
        stddev(pts) over (partition by player_id) as player_stddev_pts
    from analytics.fct_player_game
),

z_scores as (
    select
        player_name,
        game_id,
        pts,
        round(player_avg_pts::numeric, 1) as avg_pts,
        round(
            ((pts - player_avg_pts) / nullif(player_stddev_pts, 0))::numeric,
            2
        ) as z_score
    from player_stats
)

select
    player_name,
    count(*) as total_games,
    count(case when abs(z_score) > 2 then 1 end) as outlier_games,
    round((100.0 * count(case when abs(z_score) > 2 then 1 end) / count(*))::numeric, 1) as pct_outliers,
    round(avg(pts)::numeric, 1) as avg_points
from z_scores
group by player_name
having count(*) >= 10
order by pct_outliers asc;
