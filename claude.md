# 🏀 Nuggets dbt Tutorial – Claude Code Context

This file gives Claude Code all the context it needs about this project so it can help extend / refactor / debug.

---

## 1. Project Goal

Build a **dbt Core** project that uses **real Denver Nuggets NBA data** to teach:

- dbt basics (sources, staging, marts, tests, docs)
- Analytics engineering patterns (staging → intermediate → marts)
- Star schema + player/game fact tables
- How to answer interesting questions like:
  - "Which Nuggets players improve the team the most when they're on the floor?"
  - "Who is the Nuggets' most consistent player game-to-game?"
  - "How do players perform in clutch moments?" (future extension)

Right now we're focusing on **team-level game facts** and **player-level box score facts** for the Nuggets, for use in a blog tutorial.

---

## 2. Tech Stack

- **Language:** Python 3.11 (env name: `dbt-env`)
- **Warehouse:** Postgres (Docker)
  - image: `postgres:16`
  - host: `localhost`
  - port: `5432`
  - user: `nuggets`
  - password: `nuggets`
  - database: `nuggets_db`
  - dbt target schema: `analytics`
- **Transformation:** dbt Core (`dbt-postgres`)
- **Ingestion:** Python scripts using `nba_api`, `pandas`, `sqlalchemy`
- **Client:** Local SQL client connected to `nuggets_db`

---

## 3. Docker / DB Setup

Docker command used to start Postgres:

```bash
docker run --name nuggets-postgres \
  -e POSTGRES_USER=nuggets \
  -e POSTGRES_PASSWORD=nuggets \
  -e POSTGRES_DB=nuggets_db \
  -p 5432:5432 \
  -d postgres:16
```

Connection string (Python):

```python
postgres_url = "postgresql+psycopg2://nuggets:nuggets@localhost:5432/nuggets_db"
```

## 4. Project Structure (High Level)

Root folder:

```text
nuggets_dbt_tutorial/
  dbt-env/                 # virtual env (Python 3.11)
  nuggets_nba/             # dbt project root
    dbt_project.yml
    profiles.yml (in ~/.dbt, not in repo)
    models/
      staging/
        nba/
          _sources.yml
          stg_nba_games.sql
          stg_nba_boxscores.sql
      intermediate/
        nba/
          int_nuggets_games.sql
          int_nuggets_player_game.sql
      marts/
        nba_nuggets/
          fct_game_stats.sql
          fct_player_game.sql
          schema.yml
    scripts/
      ingest_games.py
      ingest_boxscores.py
```

## 5. Python Ingestion Scripts

### 5.1 scripts/ingest_games.py

**Purpose:**
Ingest Nuggets team game logs into Postgres as `public.raw_nba_games`.

**Key behavior:**

- Uses `nba_api.stats.endpoints.TeamGameLog`
- Filters by Nuggets team ID: `1610612743`
- Uses a season string like `"2023-24"`
- Renames columns: `Game_ID` → `game_id`, `GAME_DATE` → `game_date`, `MATCHUP`, `WL`, `PTS`
- Writes to Postgres:

```python
df_clean.to_sql(
    "raw_nba_games",
    engine,
    schema="public",
    if_exists="replace",
    index=False,
)
```

**Resulting table:** `public.raw_nba_games`

**Columns (simplified):**

- `game_id`
- `game_date`
- `matchup`
- `win_loss` ('W' / 'L')
- `team_points`
- `season`

### 5.2 scripts/ingest_boxscores.py

**Purpose:**
Ingest Nuggets player box score data per game into Postgres as `public.raw_nba_boxscores`.

**High-level flow:**

1. Read all `game_id` values from `public.raw_nba_games`.
2. For each game:
   - Use `nba_api` box score endpoint (`BoxScoreTraditionalV2` originally; should migrate to `BoxScoreTraditionalV3` later).
   - Extract player stats for that game.
3. Append all rows into a single DataFrame.
4. Write to Postgres table: `public.raw_nba_boxscores`.

**Important:**
After ingestion, we manually ensured the schema is aligned and then reloaded the table. The current canonical columns in `raw_nba_boxscores` are:

```text
gameId
teamId
teamCity
teamName
teamTricode
teamSlug
personId
firstName
familyName
nameI
playerSlug
position
comment
jerseyNum
minutes
fieldGoalsMade
fieldGoalsAttempted
fieldGoalsPercentage
threePointersMade
threePointersAttempted
threePointersPercentage
freeThrowsMade
freeThrowsAttempted
freeThrowsPercentage
reboundsOffensive
reboundsDefensive
reboundsTotal
assists
steals
blocks
turnovers
foulsPersonal
points
plusMinusPoints
game_id   # derived/added for join
```

Then the staging model renames + casts these into snake_case / dbt-friendly names.

## 6. dbt Models

### 6.1 Sources (models/staging/nba/_sources.yml)

We defined two sources in schema `public`:

- `nba_raw.raw_nba_games`
- `nba_raw.raw_nba_boxscores`

Example snippet (conceptual):

```yaml
version: 2

sources:
  - name: nba_raw
    schema: public
    tables:
      - name: raw_nba_games
        description: "Raw game logs for Denver Nuggets from NBA API."
      - name: raw_nba_boxscores
        description: "Raw player box scores for each Nuggets game from NBA API."
```

### 6.2 Staging Models

#### 6.2.1 stg_nba_games.sql

**Purpose:** cleaned view over `raw_nba_games`.

- Materialized as `VIEW`
- Uses `source('nba_raw', 'raw_nba_games')`
- Renames / casts:

```sql
select
    game_id::text                    as game_id,
    season::text                     as season,
    to_date(game_date, 'MM/DD/YYYY') as game_date,
    matchup::text                    as matchup,
    win_loss::text                   as win_loss,
    team_points::int                 as team_points
from {{ source('nba_raw', 'raw_nba_games') }}
```

#### 6.2.2 stg_nba_boxscores.sql

**Purpose:** cleaned view over `raw_nba_boxscores`.

- Materialized as `VIEW`
- Reads from: `source('nba_raw', 'raw_nba_boxscores')`
- Renames/normalizes all the JSON-style / camelCase columns into snake_case.

**Current canonical columns in `stg_nba_boxscores`:**

```text
game_id
nba_game_id
team_id
team_city
team_name
team_tricode
team_slug
player_id
first_name
family_name
name_i
player_slug
position
comment
jersey_num
minutes_raw      # string like '34:21'
fgm
fga
fg_pct
tpm
tpa
tp_pct
ftm
fta
ft_pct
oreb
dreb
treb
ast
stl
blk
tov
pf
pts
plus_minus
```

**Note:** `minutes_raw` will later be converted to a numeric representation (e.g., minutes as float) in the intermediate or mart model.

### 6.3 Intermediate Models

#### 6.3.1 int_nuggets_games.sql

**Purpose:** build a Nuggets-focused games view from staged games.

- Materialized as `VIEW`
- Reads from `ref('stg_nba_games')`
- Adds simple derived fields (like opponent info) and sets up data for the `fct_game_stats` fact.

Rough shape:

```sql
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
        team_points
        -- (we may derive opponent, home/away later)
    from games
)

select * from parsed
```

#### 6.3.2 int_nuggets_player_game.sql

**Purpose:** aggregate per-player per-game metrics for the Nuggets from `stg_nba_boxscores`.

- Materialized as `VIEW`
- Reads from `ref('stg_nba_boxscores')`
- Filters to Nuggets games (usually by `team_tricode = 'DEN'` or `team_id = 1610612743`)
- Renames and parses fields, including:
  - `minutes_raw` → something usable (`minutes_float` or similar)
  - counting FGA, FGM, points, etc.

This is the upstream model for `fct_player_game`.

**Status:**
We had some column-name mismatches during dev (e.g., referencing `minutes` instead of `minutes_raw`, or `family_name` when it wasn't in staging yet). The staging model is now aligned; `int_nuggets_player_game` should reference the current `stg_nba_boxscores` columns shown above.

### 6.4 Mart Models (Facts)

All mart models are materialized as `TABLE` in schema `analytics`.

#### 6.4.1 fct_game_stats.sql

**Purpose:** team-level game fact table (one row per Nuggets game).

- Reads from `ref('int_nuggets_games')`
- Adds `is_win` flag and basic metrics.

Example logic:

```sql
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
```

**Status:** working
Command used:

```bash
dbt run --select +fct_game_stats
```

This builds:

- `analytics.stg_nba_games`
- `analytics.int_nuggets_games`
- `analytics.fct_game_stats`

#### 6.4.2 fct_player_game.sql

**Purpose:** player-level fact table (one row per player per game for Nuggets).

- Reads from `ref('int_nuggets_player_game')`
- Summarizes / standardizes player-level metrics:
  - points, rebounds, assists, FGA, FGM, 3PA, 3PM, FT attempts/makes, etc.
  - plus/minus, maybe TS%, etc.

This will be the starting point for answering:

- "Who is most consistent game-to-game?"
- "Who helps the team most when on the floor?" (once we join lineups / on/off later)

**Status:** in progress
`dbt run --select +fct_player_game` currently fails if `int_nuggets_player_game.sql` references non-existent columns. Once the intermediate is aligned with `stg_nba_boxscores`, `fct_player_game` will build.

### 6.5 Mart Schema / Tests (models/marts/nba_nuggets/schema.yml)

**Purpose:**
Add tests + docs for mart models like `fct_game_stats` and `fct_player_game`.

Example snippet:

```yaml
version: 2

models:
  - name: fct_game_stats
    description: "Fact table with one row per Nuggets game."
    columns:
      - name: game_id
        tests:
          - not_null
          - unique
      - name: game_date
        tests:
          - not_null
      - name: is_win
        description: "1 if Nuggets won, 0 otherwise."
```

There are also tests for the boxscore staging model (e.g. basic `not_null` checks).

## 7. dbt Commands Used So Far

From dbt project root (`nuggets_nba/`):

```bash
# Check connectivity
dbt debug

# Run only the staging games model
dbt run --select stg_nba_games

# Build fct_game_stats + its upstream dependencies
dbt run --select +fct_game_stats

# Run only boxscore staging model
dbt run --select stg_nba_boxscores

# Build player fact + its upstream deps (once fixed)
dbt run --select +fct_player_game

# Run tests defined in schema.yml
dbt test --select fct_game_stats
dbt test --select stg_nba_boxscores
```

## 8. Open Issues / Next Steps (for Claude)

These are good targets for Claude Code to help with:

1. **Finalize `int_nuggets_player_game.sql`**
   - Align column names strictly with `stg_nba_boxscores`:
     - use `minutes_raw` instead of `minutes`
     - confirm `first_name`, `family_name`, `team_id`, `team_tricode`, etc.
   - Derive a numeric `minutes` field, e.g. `minutes_float` from `"MM:SS"`.

2. **Finish `fct_player_game.sql`**
   - Define clear grain: 1 row per `player_id` + `game_id`
   - Include key metrics:
     - points, rebounds, assists, steals, blocks, turnovers, FGA, FGM, 3PA, 3PM, FT attempts/makes, plus/minus, etc.
   - Optionally compute advanced stats:
     - points per 36, simple TS ratio, etc.

3. **Add tests for player fact**
   - `not_null` and `unique` on a `player_game_key` (e.g., `concat(game_id, '-', player_id)`).
   - Basic sanity checks (`pts >= 0`, `minutes not null`, etc. if desired).

4. **Analytics questions to aim for (later)**
   - Who is the most consistent player game-to-game by points, or by some composite metric?
   - Simple on/off impact: compare team scoring when a player is in vs. out (would require play-by-play or lineup data later).
   - Clutch performance: filter to 4th quarter or last 5 minutes of close games (future extension, probably using PBP).

5. **Migration to `BoxScoreTraditionalV3`**
   - The ingestion script currently uses `BoxScoreTraditionalV2` and logs a deprecation warning.
   - Eventually switch to `BoxScoreTraditionalV3` and update the ingestion script + staging to reflect any column changes.

## 9. How to Think About the Project

From a data engineering / analytics engineering standpoint:

- **Raw:** `raw_nba_games`, `raw_nba_boxscores` are our bronze/raw layer.
- **Staging:** `stg_nba_games`, `stg_nba_boxscores` clean/normalize them.
- **Intermediate:** `int_nuggets_games`, `int_nuggets_player_game` reshape + derive for Nuggets-specific analytics.
- **Marts:** `fct_game_stats`, `fct_player_game` are facts ready for BI, metrics, and further modeling.

The blog content will walk through:

- hooking dbt to a warehouse
- ingesting real NBA data
- defining sources
- staging models
- building marts
- connecting everything back to interesting basketball questions.