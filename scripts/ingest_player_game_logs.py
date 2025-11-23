from nba_api.stats.endpoints import LeagueGameLog
import pandas as pd
from sqlalchemy import create_engine

SEASON = "2023-24"

print("Fetching player game logs from NBA API...")

logs = LeagueGameLog(
    season=SEASON,
    season_type="Regular Season",
    direction="ASC"
)

df = logs.get_data_frames()[0]

print(f"Fetched {len(df)} rows")

# Clean and rename
df_clean = df.rename(columns={
    "Player_ID": "player_id",
    "Player_Name": "player_name",
    "Team_ID": "team_id",
    "Team_Name": "team_name",
    "Game_ID": "game_id",
})

# Connect to Postgres
engine = create_engine("postgresql+psycopg2://nuggets:nuggets@localhost:5432/nuggets_db")

df_clean.to_sql(
    "raw_nba_player_game_logs",
    engine,
    schema="public",
    if_exists="replace",
    index=False
)

print("Done loading raw_nba_player_game_logs into Postgres.")
