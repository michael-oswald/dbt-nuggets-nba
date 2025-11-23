# Denver Nuggets dbt Analytics Project

A complete dbt Core project demonstrating analytics engineering best practices using real NBA data from the Denver Nuggets. This project showcases how to build a dimensional data model from raw NBA API data to answer interesting basketball analytics questions.

## Project Overview

This project uses the [nba_api](https://github.com/swar/nba-api) Python library to ingest Denver Nuggets game and player data, then transforms it using dbt into a star schema optimized for analytics.

**Key Analytics Questions:**
- Which Nuggets players are most consistent game-to-game?
- How do players perform in different game situations?
- What are the team's performance trends across the season?

## Tech Stack

- **Data Warehouse:** PostgreSQL 16 (Docker)
- **Transformation:** dbt Core with dbt-postgres adapter
- **Data Source:** NBA Stats API via nba_api Python library
- **Language:** Python 3.11

## Project Structure

```
nuggets_nba/
├── models/
│   ├── staging/          # Cleaned, typed source data
│   │   └── nba/
│   │       ├── _sources.yml
│   │       ├── stg_nba_games.sql
│   │       └── stg_nba_boxscores.sql
│   ├── intermediate/     # Business logic transformations
│   │   └── nba/
│   │       ├── int_nuggets_games.sql
│   │       └── int_nuggets_player_game.sql
│   └── marts/           # Analytics-ready fact tables
│       └── nba_nuggets/
│           ├── fct_game_stats.sql
│           ├── fct_player_game.sql
│           └── schema.yml
├── scripts/             # Python ingestion scripts
│   ├── ingest_games.py
│   ├── ingest_boxscores.py
│   └── ingest_player_game_logs.py
├── analysis/            # Ad-hoc analysis queries
└── dbt_project.yml
```

## Setup

### 1. Start PostgreSQL Database

```bash
docker run --name nuggets-postgres \
  -e POSTGRES_USER=nuggets \
  -e POSTGRES_PASSWORD=nuggets \
  -e POSTGRES_DB=nuggets_db \
  -p 5432:5432 \
  -d postgres:16
```

### 2. Create Python Virtual Environment

```bash
python3.11 -m venv dbt-env
source dbt-env/bin/activate  # On Windows: dbt-env\Scripts\activate
```

### 3. Install Dependencies

```bash
pip install dbt-postgres nba-api pandas sqlalchemy psycopg2-binary
```

### 4. Configure dbt Profile

Create or update `~/.dbt/profiles.yml`:

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

### 5. Ingest Raw Data

```bash
# Ingest Nuggets game logs
python scripts/ingest_games.py

# Ingest player box scores
python scripts/ingest_boxscores.py
```

### 6. Run dbt Models

```bash
# Test connection
dbt debug

# Build all models
dbt run

# Run tests
dbt test

# Generate documentation
dbt docs generate
dbt docs serve
```

## Data Model

### Sources (Raw Layer)
- `raw_nba_games`: Team game logs from NBA API
- `raw_nba_boxscores`: Player box scores per game

### Staging Layer
- `stg_nba_games`: Cleaned and typed game data
- `stg_nba_boxscores`: Cleaned and typed box score data

### Intermediate Layer
- `int_nuggets_games`: Nuggets-specific game transformations
- `int_nuggets_player_game`: Player-level game aggregations

### Marts Layer (Facts)
- `fct_game_stats`: One row per Nuggets game with team-level metrics
- `fct_player_game`: One row per player per game with individual stats

## Example Queries

See the `analysis/` directory for example analytical queries:
- `fct_game_stats_questions.md`: Team performance analysis
- `player_consistency_queries.sql`: Player consistency metrics
- `rotation_player_consistency.sql`: Rotation player analysis

## Development Notes

**Database Credentials:** The ingestion scripts use hardcoded credentials for local development (`nuggets:nuggets@localhost:5432`). For production use, these should be replaced with environment variables or a secrets management solution.

**Season Data:** Currently configured for the 2023-24 NBA season. Update the `SEASON` variable in ingestion scripts to pull different seasons.

**API Deprecation:** The project currently uses `BoxScoreTraditionalV2` which is deprecated. Future versions should migrate to `BoxScoreTraditionalV3`.

## Resources

- [dbt Documentation](https://docs.getdbt.com/docs/introduction)
- [nba_api Documentation](https://github.com/swar/nba-api)
- [dbt Discourse](https://discourse.getdbt.com/) for questions
- [dbt Slack Community](https://community.getdbt.com/)
