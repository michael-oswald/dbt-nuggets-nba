# Building an NBA Player Stats Pipeline with dbt: A Complete Tutorial

**Goal**: Learn dbt fundamentals by building a real analytics pipeline using Denver Nuggets NBA data to answer: *"Which Nuggets player is the most consistent game-to-game?"*

**What we'll build**:
- A Postgres data warehouse (Docker)
- Python ingestion scripts using the NBA API
- A dbt project with staging → intermediate → marts layers
- Player-level fact table for consistency analysis

**Time commitment**: ~2-3 hours

---

## Prerequisites

Install these before starting:
- **Python 3.11+**
- **Docker Desktop**
- **Git**
- **SQL client** (DBeaver, pgAdmin, or DataGrip)

---

## Part 1: Environment Setup

### 1.1 Create Project Directory

```bash
mkdir -p nuggets_dbt_tutorial
cd nuggets_dbt_tutorial
```

### 1.2 Create Python Virtual Environment

```bash
# Create virtual environment
python3.11 -m venv dbt-env

# Activate it
source dbt-env/bin/activate  # macOS/Linux
# OR
dbt-env\Scripts\activate     # Windows
```

### 1.3 Install Python Dependencies

```bash
pip install \
  dbt-postgres \
  nba_api \
  pandas \
  sqlalchemy \
  psycopg2-binary
```

**Expected output**:
```
Successfully installed dbt-core-1.x.x dbt-postgres-1.x.x ...
```

---

## Part 2: Spin Up Postgres Database

### 2.1 Start Postgres in Docker

```bash
docker run --name nuggets-postgres \
  -e POSTGRES_USER=nuggets \
  -e POSTGRES_PASSWORD=nuggets \
  -e POSTGRES_DB=nuggets_db \
  -p 5432:5432 \
  -d postgres:16
```

**What this does**:
- Creates a Postgres 16 container named `nuggets-postgres`
- Sets up user `nuggets` with password `nuggets`
- Creates database `nuggets_db`
- Maps port 5432 (container) → 5432 (localhost)
- Runs in detached mode (`-d`)

### 2.2 Verify Postgres is Running

```bash
docker ps
```

**Expected output**:
```
CONTAINER ID   IMAGE         STATUS         PORTS                    NAMES
abc123...      postgres:16   Up 10 seconds  0.0.0.0:5432->5432/tcp   nuggets-postgres
```

### 2.3 Test Connection

```bash
docker exec -it nuggets-postgres psql -U nuggets -d nuggets_db
```

**You should see**:
```
psql (16.x)
nuggets_db=#
```

Type `\q` to exit.

---

## Part 3: Ingest NBA Data

### 3.1 Create Scripts Directory

```bash
mkdir -p nuggets_nba/scripts
cd nuggets_nba
```

### 3.2 Create `scripts/ingest_games.py`

Create this file with the following content:

```python
from nba_api.stats.endpoints import TeamGameLog
import pandas as pd
from sqlalchemy import create_engine

# Configuration
NUGGETS_TEAM_ID = "1610612743"
SEASON = "2023-24"
DB_URL = "postgresql+psycopg2://nuggets:nuggets@localhost:5432/nuggets_db"

# Fetch Nuggets game logs
print(f"Fetching Nuggets games for {SEASON} season...")
game_log = TeamGameLog(team_id=NUGGETS_TEAM_ID, season=SEASON)
df = game_log.get_data_frames()[0]

# Clean column names
df_clean = df.rename(columns={
    'Game_ID': 'game_id',
    'GAME_DATE': 'game_date',
    'MATCHUP': 'matchup',
    'WL': 'win_loss',
    'PTS': 'team_points'
})

# Add season column
df_clean['season'] = SEASON

# Select relevant columns
df_clean = df_clean[[
    'game_id', 'season', 'game_date',
    'matchup', 'win_loss', 'team_points'
]]

# Write to Postgres
print(f"Writing {len(df_clean)} games to database...")
engine = create_engine(DB_URL)
df_clean.to_sql(
    'raw_nba_games',
    engine,
    schema='public',
    if_exists='replace',
    index=False
)

print("✅ Done! Games loaded into public.raw_nba_games")
print(f"Sample: {df_clean.head(3).to_dict('records')}")
```

### 3.3 Run Game Ingestion

```bash
python scripts/ingest_games.py
```

**Expected output**:
```
Fetching Nuggets games for 2023-24 season...
Writing 82 games to database...
✅ Done! Games loaded into public.raw_nba_games
```

**Runtime**: ~5-10 seconds

---

### 3.4 Create `scripts/ingest_boxscores.py`

```python
from nba_api.stats.endpoints import BoxScoreTraditionalV3
import pandas as pd
from sqlalchemy import create_engine
import time

# Configuration
DB_URL = "postgresql+psycopg2://nuggets:nuggets@localhost:5432/nuggets_db"

# Read games from database
print("Reading game IDs from database...")
engine = create_engine(DB_URL)
games_df = pd.read_sql("SELECT game_id FROM public.raw_nba_games", engine)
game_ids = games_df['game_id'].tolist()

print(f"Found {len(game_ids)} games to process...")

# Fetch box scores for each game
all_boxscores = []
for i, game_id in enumerate(game_ids, 1):
    print(f"[{i}/{len(game_ids)}] Fetching game {game_id}...")

    try:
        boxscore = BoxScoreTraditionalV3(game_id=game_id)
        df = boxscore.get_data_frames()[0]  # Player stats
        df['game_id'] = game_id
        all_boxscores.append(df)

        # Be nice to the API
        time.sleep(0.6)

    except Exception as e:
        print(f"   ⚠️  Error: {e}")
        continue

# Combine all box scores
print("\nCombining all box scores...")
df_all = pd.concat(all_boxscores, ignore_index=True)

# Rename columns to snake_case
column_mapping = {
    'gameId': 'gameid',
    'teamId': 'teamid',
    'teamCity': 'teamcity',
    'teamName': 'teamname',
    'teamTricode': 'teamtricode',
    'teamSlug': 'teamslug',
    'personId': 'personid',
    'firstName': 'firstname',
    'familyName': 'familyname',
    'nameI': 'namei',
    'playerSlug': 'playerslug',
    'position': 'position',
    'comment': 'comment',
    'jerseyNum': 'jerseynum',
    'minutes': 'minutes',
    'fieldGoalsMade': 'fieldgoalsmade',
    'fieldGoalsAttempted': 'fieldgoalsattempted',
    'fieldGoalsPercentage': 'fieldgoalspercentage',
    'threePointersMade': 'threepointersmade',
    'threePointersAttempted': 'threepointersattempted',
    'threePointersPercentage': 'threepointerspercentage',
    'freeThrowsMade': 'freethrowsmade',
    'freeThrowsAttempted': 'freethrowsattempted',
    'freeThrowsPercentage': 'freethrowspercentage',
    'reboundsOffensive': 'reboundsoffensive',
    'reboundsDefensive': 'reboundsdefensive',
    'reboundsTotal': 'reboundstotal',
    'assists': 'assists',
    'steals': 'steals',
    'blocks': 'blocks',
    'turnovers': 'turnovers',
    'foulsPersonal': 'foulspersonal',
    'points': 'points',
    'plusMinusPoints': 'plusminuspoints'
}

df_all = df_all.rename(columns=column_mapping)

# Write to database
print(f"Writing {len(df_all)} player-game records to database...")
df_all.to_sql(
    'raw_nba_boxscores',
    engine,
    schema='public',
    if_exists='replace',
    index=False
)

print("✅ Done! Box scores loaded into public.raw_nba_boxscores")
print(f"Total records: {len(df_all)}")
```

### 3.5 Run Box Score Ingestion

```bash
python scripts/ingest_boxscores.py
```

**Expected output**:
```
Reading game IDs from database...
Found 82 games to process...
[1/82] Fetching game 0022300001...
[2/82] Fetching game 0022300015...
...
✅ Done! Box scores loaded into public.raw_nba_boxscores
Total records: ~2,050
```

**Runtime**: ~1-2 minutes (0.6s per game × 82 games)

---

## Part 4: Initialize dbt Project

### 4.1 Create dbt Project

```bash
dbt init nuggets_nba
```

**Prompts**:
- Database: `postgres`
- Host: `localhost`
- Port: `5432`
- User: `nuggets`
- Password: `nuggets`
- Database: `nuggets_db`
- Schema: `analytics`
- Threads: `4`

**OR** skip prompts and configure manually (next step).

### 4.2 Configure `~/.dbt/profiles.yml`

Create or edit `~/.dbt/profiles.yml`:

```yaml
nuggets_nba:
  target: dev
  outputs:
    dev:
      type: postgres
      host: localhost
      port: 5432
      user: nuggets
      password: nuggets
      dbname: nuggets_db
      schema: analytics
      threads: 4
```

### 4.3 Test dbt Connection

```bash
cd nuggets_nba
dbt debug
```

**Expected output**:
```
Running with dbt=1.10.x
Configuration:
  profiles.yml file [OK found and valid]
  dbt_project.yml file [OK found and valid]
Connection:
  host: localhost
  port: 5432
  user: nuggets
  database: nuggets_db
  schema: analytics
  Connection test: [OK connection ok]

All checks passed!
```

---

## Part 5: Build dbt Models

### 5.1 Define Sources

Create `models/staging/nba/_sources.yml`:

```yaml
version: 2

sources:
  - name: nba_raw
    description: "Raw NBA data ingested from nba_api"
    schema: public
    tables:
      - name: raw_nba_games
        description: "Nuggets team game logs from NBA API"
        columns:
          - name: game_id
            description: "Unique game identifier"

      - name: raw_nba_boxscores
        description: "Player box scores for each Nuggets game"
        columns:
          - name: gameid
            description: "Game identifier (links to raw_nba_games)"
          - name: personid
            description: "Unique player identifier"
```

**Test sources**:

```bash
dbt run-operation source --help  # Just to verify syntax
```

---

### 5.2 Create Staging Model: `stg_nba_games`

Create `models/staging/nba/stg_nba_games.sql`:

```sql
{{ config(
    materialized = 'view',
    tags = ['staging', 'nba']
) }}

select
    game_id::text                    as game_id,
    season::text                     as season,
    to_date(game_date, 'MM/DD/YYYY') as game_date,
    matchup::text                    as matchup,
    win_loss::text                   as win_loss,
    team_points::int                 as team_points
from {{ source('nba_raw', 'raw_nba_games') }}
```

**Build it**:

```bash
dbt run --select stg_nba_games
```

**Expected output**:
```
1 of 1 START sql view model analytics.stg_nba_games ........ [RUN]
1 of 1 OK created sql view model analytics.stg_nba_games ... [CREATE VIEW in 0.05s]
```

---

### 5.3 Create Staging Model: `stg_nba_boxscores`

Create `models/staging/nba/stg_nba_boxscores.sql`:

```sql
{{ config(
    materialized = 'view',
    tags = ['staging', 'nba']
) }}

select
    gameid::text        as game_id,
    gameid::text        as nba_game_id,
    teamid::bigint      as team_id,
    teamcity::text      as team_city,
    teamname::text      as team_name,
    teamtricode::text   as team_tricode,
    teamslug::text      as team_slug,

    personid::bigint    as player_id,
    firstname::text     as first_name,
    familyname::text    as family_name,
    namei::text         as name_i,
    playerslug::text    as player_slug,
    position::text      as position,
    comment::text       as comment,
    jerseynum::text     as jersey_num,

    minutes::text       as minutes_raw,

    fieldgoalsmade::int               as fgm,
    fieldgoalsattempted::int          as fga,
    fieldgoalspercentage::float       as fg_pct,
    threepointersmade::int            as tpm,
    threepointersattempted::int       as tpa,
    threepointerspercentage::float    as tp_pct,
    freethrowsmade::int               as ftm,
    freethrowsattempted::int          as fta,
    freethrowspercentage::float       as ft_pct,

    reboundsoffensive::int  as oreb,
    reboundsdefensive::int  as dreb,
    reboundstotal::int      as treb,
    assists::int            as ast,
    steals::int             as stl,
    blocks::int             as blk,
    turnovers::int          as tov,
    foulspersonal::int      as pf,
    points::int             as pts,
    plusminuspoints::int    as plus_minus

from {{ source('nba_raw', 'raw_nba_boxscores') }}
```

**Build it**:

```bash
dbt run --select stg_nba_boxscores
```

---

### 5.4 Create Intermediate Model: `int_nuggets_player_game`

Create `models/intermediate/nba/int_nuggets_player_game.sql`:

```sql
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
```

**Build it**:

```bash
dbt run --select int_nuggets_player_game
```

---

### 5.5 Create Mart Model: `fct_player_game`

Create `models/marts/nba_nuggets/fct_player_game.sql`:

```sql
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
```

**Build the entire lineage**:

```bash
dbt run --select +fct_player_game
```

**Expected output**:
```
1 of 3 START sql view model analytics.stg_nba_boxscores ........... [RUN]
1 of 3 OK created sql view model analytics.stg_nba_boxscores ...... [CREATE VIEW in 0.06s]
2 of 3 START sql view model analytics.int_nuggets_player_game ..... [RUN]
2 of 3 OK created sql view model analytics.int_nuggets_player_game  [CREATE VIEW in 0.02s]
3 of 3 START sql table model analytics.fct_player_game ............ [RUN]
3 of 3 OK created sql table model analytics.fct_player_game ....... [SELECT 1847 in 0.15s]
```

🎉 **You now have a player-game fact table!**

---

### 5.6 Add Tests

Create `models/marts/nba_nuggets/schema.yml`:

```yaml
version: 2

models:
  - name: fct_player_game
    description: "Player-level fact table with one row per player per game"
    columns:
      - name: player_game_key
        description: "Unique key: game_id + player_id"
        tests:
          - not_null
          - unique

      - name: game_id
        tests:
          - not_null

      - name: player_id
        tests:
          - not_null

      - name: pts
        description: "Points scored"
        tests:
          - not_null
```

**Run tests**:

```bash
dbt test --select fct_player_game
```

**Expected output**:
```
1 of 4 START test not_null_fct_player_game_player_game_key .... [RUN]
1 of 4 PASS not_null_fct_player_game_player_game_key .......... [PASS in 0.05s]
2 of 4 START test unique_fct_player_game_player_game_key ...... [RUN]
2 of 4 PASS unique_fct_player_game_player_game_key ............ [PASS in 0.06s]
...
```

---

## Part 6: Query Your Data!

### 6.1 Connect SQL Client to Postgres

**Connection details**:
- Host: `localhost`
- Port: `5432`
- Database: `nuggets_db`
- User: `nuggets`
- Password: `nuggets`
- Schema: `analytics`

---

### 6.2 Basic Query: Player Averages

```sql
select
    first_name || ' ' || family_name as player_name,
    count(*) as games_played,
    round(avg(pts)::numeric, 1) as avg_points,
    round(avg(ast)::numeric, 1) as avg_assists,
    round(avg(rebounds)::numeric, 1) as avg_rebounds,
    round(avg(minutes)::numeric, 1) as avg_minutes
from analytics.fct_player_game
group by 1
having count(*) >= 10
order by avg_points desc;
```

**Sample results**:
```
player_name         | games | avg_pts | avg_ast | avg_reb | avg_min
--------------------|-------|---------|---------|---------|--------
Nikola Jokić        | 79    | 26.4    | 9.0     | 12.4    | 34.6
Jamal Murray        | 59    | 21.2    | 6.5     | 4.1     | 31.5
Michael Porter Jr.  | 82    | 16.5    | 1.5     | 6.9     | 31.3
Aaron Gordon        | 73    | 13.9    | 3.5     | 6.5     | 31.5
```

---

### 6.3 Consistency Analysis: Coefficient of Variation

**Question**: *Who is the most consistent scorer?*

```sql
select
    first_name || ' ' || family_name as player_name,
    count(*) as games_played,
    round(avg(pts)::numeric, 1) as avg_points,
    round(stddev(pts)::numeric, 2) as stddev_points,
    round(((stddev(pts) / nullif(avg(pts), 0)) * 100)::numeric, 1) as cv_points
from analytics.fct_player_game
group by 1
having
    count(*) >= 20
    and avg(minutes) >= 15
    and avg(pts) >= 5
order by cv_points asc;
```

**Results**:
```
player_name         | games | avg_pts | stddev | cv_points
--------------------|-------|---------|--------|----------
Nikola Jokić        | 79    | 26.4    | 8.16   | 30.9%    ← Most consistent!
Jamal Murray        | 59    | 21.2    | 7.83   | 36.9%
Aaron Gordon        | 73    | 13.9    | 5.27   | 38.0%
Michael Porter Jr.  | 82    | 16.5    | 6.97   | 42.2%
```

**Interpretation**:
- **Lower CV = more consistent**
- Jokić has a 30.9% coefficient of variation - remarkably consistent for 26.4 PPG
- Murray and Gordon are also very steady
- MPJ is more "feast or famine" at 42.2% CV

---

### 6.4 Advanced: Plus/Minus Impact

**Question**: *Who consistently helps the team when on the floor?*

```sql
select
    first_name || ' ' || family_name as player_name,
    count(*) as games_played,
    round(avg(plus_minus)::numeric, 1) as avg_plus_minus,
    round(stddev(plus_minus)::numeric, 2) as stddev_plus_minus,
    round(avg(minutes)::numeric, 1) as avg_minutes
from analytics.fct_player_game
group by 1
having count(*) >= 20 and avg(minutes) >= 15
order by avg_plus_minus desc;
```

**Results show**: Jokić and Murray have the highest average plus/minus, meaning the team performs best when they're on the floor.

---

## Part 7: What We Built

### Architecture Overview

```
┌─────────────────────────────────────┐
│   Python Ingestion Scripts         │
│   (nba_api → Postgres)              │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│   Raw Tables (public schema)        │
│   - raw_nba_games                   │
│   - raw_nba_boxscores               │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│   dbt Staging (analytics schema)    │
│   - stg_nba_games (VIEW)            │
│   - stg_nba_boxscores (VIEW)        │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│   dbt Intermediate                  │
│   - int_nuggets_player_game (VIEW)  │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│   dbt Marts                         │
│   - fct_player_game (TABLE) ✨      │
└─────────────────────────────────────┘
```

---

## Key Takeaways

### About dbt
✅ **Modularity**: Each model has a single responsibility
✅ **Lineage**: Dependencies flow cleanly (staging → intermediate → marts)
✅ **Testing**: Built-in data quality checks
✅ **Documentation**: Self-documenting with schema.yml files
✅ **Incremental development**: Build and test one layer at a time

### About the Nuggets
🏀 **Nikola Jokić** is absurdly consistent - lowest variance among starters
🏀 Top 4 players (Jokić, Murray, Gordon, MPJ) all have <43% CV
🏀 Bench players have higher variance (50-72% CV) - expected for role players

### What You Learned
- Real-world data pipeline architecture
- Python → Database ingestion
- dbt's medallion architecture (bronze/silver/gold or raw/staging/marts)
- Statistical analysis of sports data
- How to answer business questions with data

---

## Next Steps

**Expand the analysis**:
1. Add more seasons for historical trends
2. Calculate advanced stats (True Shooting %, PER)
3. Add game context (home/away, opponent strength)
4. Build a Streamlit dashboard
5. Expand to all 30 NBA teams

**Extend the pipeline**:
1. Add incremental models for performance
2. Set up dbt snapshots for slowly changing dimensions
3. Add dbt macros for reusable logic
4. Implement CI/CD with GitHub Actions
5. Deploy dbt to dbt Cloud

---

## Troubleshooting

### Common Issues

**Problem**: `dbt debug` fails with "could not connect to server"
- **Solution**: Ensure Docker container is running: `docker ps`

**Problem**: Ingestion script fails with rate limit error
- **Solution**: Increase sleep time in `ingest_boxscores.py` to 1-2 seconds

**Problem**: `fct_player_game` has duplicate player_game_keys
- **Solution**: Check for duplicate games in `raw_nba_games` - deduplicate at ingestion

**Problem**: Player minutes show as 0 or null
- **Solution**: Verify `minutes_raw` format in raw table - should be "MM:SS"

---

## Resources

- **dbt Docs**: https://docs.getdbt.com
- **nba_api GitHub**: https://github.com/swar/nba_api
- **Postgres Docs**: https://www.postgresql.org/docs/

---

## Acknowledgments

- Data provided by **NBA.com** via the unofficial `nba_api` library
- This tutorial is for educational purposes demonstrating dbt and analytics engineering concepts
- Not affiliated with or endorsed by the NBA

---

**You did it!** 🎉

You've built a production-quality analytics pipeline from scratch. This same pattern (ingest → stage → transform → mart) scales to enterprise data warehouses.

Now go analyze some basketball! 🏀
