{{ config(
    materialized = 'view',
    tags = ['staging', 'nba']
) }}

with source as (
    select * from {{ source('nba_raw', 'raw_nba_boxscores') }}
),

renamed as (
    select
        -- ids & keys
        game_id::text                 as game_id,          -- your added key
        "gameId"::text                as nba_game_id,      -- original NBA game id
        "teamId"::bigint              as team_id,
        "teamCity"::text              as team_city,
        "teamName"::text              as team_name,
        "teamTricode"::text           as team_tricode,
        "teamSlug"::text              as team_slug,

        -- player identity
        "personId"::bigint            as player_id,
        "firstName"::text             as first_name,
        "familyName"::text            as family_name,
        "nameI"::text                 as name_i,
        "playerSlug"::text            as player_slug,
        position::text                as position,
        comment::text                 as comment,
        "jerseyNum"::text             as jersey_num,

        -- minutes as raw string (e.g. '32:15')
        minutes::text                 as minutes_raw,

        -- shooting
        "fieldGoalsMade"::int         as fgm,
        "fieldGoalsAttempted"::int    as fga,
        "fieldGoalsPercentage"::float as fg_pct,
        "threePointersMade"::int      as tpm,
        "threePointersAttempted"::int as tpa,
        "threePointersPercentage"::float as tp_pct,
        "freeThrowsMade"::int         as ftm,
        "freeThrowsAttempted"::int    as fta,
        "freeThrowsPercentage"::float as ft_pct,

        -- boards
        "reboundsOffensive"::int      as oreb,
        "reboundsDefensive"::int      as dreb,
        "reboundsTotal"::int          as treb,

        -- other box score stats
        assists::int                  as ast,
        steals::int                   as stl,
        blocks::int                   as blk,
        turnovers::int                as tov,
        "foulsPersonal"::int          as pf,
        points::int                   as pts,
        "plusMinusPoints"::float      as plus_minus
    from source
)

select * from renamed
