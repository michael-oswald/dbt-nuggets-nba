{{ config(
    materialized = 'view',
    tags = ['intermediate', 'nba', 'nuggets']
) }}

with games as (
    select * from {{ ref('stg_nba_games') }}
),

parsed as (
    select
        game_id,
        season,
        game_date,
        matchup,
        win_loss,
        team_points,
        -- derived fields you can use later
        split_part(matchup, ' ', 1) as home_away_token,  -- '@' or 'vs.'
        split_part(matchup, ' ', 3) as opponent_code      -- e.g. 'LAL'
    from games
)

select * from parsed