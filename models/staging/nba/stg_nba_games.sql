{{ config(
    materialized = 'view',
    tags = ['staging', 'nba']
) }}

-- 1. Pull data from the raw table
with source as (
    select * from {{ source('nba_raw', 'raw_nba_games') }}
),

-- 2. Clean column names and types
renamed as (
    select
        game_id::text                          as game_id,
        season::text                           as season,
        to_date(game_date, 'MON DD, YYYY')     as game_date,
        matchup::text                          as matchup,
        win_loss::text                         as win_loss,
        team_points::int                       as team_points
    from source
)

-- 3. Final cleaned output
select * from renamed