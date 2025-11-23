{{ config(
    materialized = 'table',
    unique_key = 'player_game_key',
    tags = ['mart', 'fact', 'nba', 'nuggets']
) }}

with base as (
    select
        game_id,
        player_id,
        concat(game_id, '_', player_id) as player_game_key,

        -- player identity
        first_name,
        family_name,

        -- stats
        minutes,
        pts,
        ast,
        treb as rebounds,
        fgm,
        fga,
        tpm,
        tpa,
        ftm,
        fta,
        plus_minus
    from {{ ref('int_nuggets_player_game') }}
),

with_efficiency as (
    select
        *,
        case when fga > 0
            then (fgm::float / fga)
            else null
        end as fg_pct,

        case when tpa > 0
            then (tpm::float / tpa)
            else null
        end as three_pct,

        case when fta > 0
            then (ftm::float / fta)
            else null
        end as ft_pct
    from base
)

select * from with_efficiency
