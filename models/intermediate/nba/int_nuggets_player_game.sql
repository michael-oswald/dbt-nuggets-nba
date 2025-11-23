{{ config(
    materialized = 'view',
    tags = ['intermediate', 'nba', 'nuggets']
) }}

with box as (
    select *
    from {{ ref('stg_nba_boxscores') }}
),

-- Keep only Nuggets players
nuggets_only as (
    select
        game_id,
        nba_game_id,
        team_id,
        team_city,
        team_name,
        team_tricode,
        team_slug,
        player_id,
        first_name,
        family_name,
        name_i,
        player_slug,
        position,
        comment,
        jersey_num,
        minutes_raw,

        -- convert 'MM:SS' to numeric minutes (e.g. 32.5)
        case
            when minutes_raw is null or minutes_raw = '' or minutes_raw = '00:00' then 0
            else
                split_part(minutes_raw, ':', 1)::int
                + split_part(minutes_raw, ':', 2)::int / 60.0
        end as minutes,

        fgm,
        fga,
        fg_pct,
        tpm,
        tpa,
        tp_pct,
        ftm,
        fta,
        ft_pct,
        oreb,
        dreb,
        treb,
        ast,
        stl,
        blk,
        tov,
        pf,
        pts,
        plus_minus
    from box
    where team_tricode = 'DEN'  -- only Denver Nuggets
)

select * from nuggets_only
