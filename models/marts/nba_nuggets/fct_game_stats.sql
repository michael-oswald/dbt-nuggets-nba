{{ config(
    materialized = 'table',
    tags = ['mart', 'fact', 'nba', 'nuggets']
) }}

with base as (
    select
        game_id,
        season,
        game_date,
        matchup,
        win_loss,
        team_points,
        case when win_loss = 'W' then 1 else 0 end as is_win
    from {{ ref('int_nuggets_games') }}
)

select * from base