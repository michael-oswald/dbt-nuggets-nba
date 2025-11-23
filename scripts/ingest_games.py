from nba_api.stats.endpoints import TeamGameLog
import pandas as pd
from sqlalchemy import create_engine

NUGGETS_TEAM_ID = "1610612743"
SEASON = "2023-24"  # or "2024-25" when available

print("Fetching game logs from NBA API...")
gamelog = TeamGameLog(team_id=NUGGETS_TEAM_ID, season=SEASON)
df = gamelog.get_data_frames()[0]

print(f"Fetched {len(df)} games")

df_clean = df.rename(columns={
    "Game_ID": "game_id",
    "GAME_DATE": "game_date",
    "MATCHUP": "matchup",
    "WL": "win_loss",
    "PTS": "team_points"
})

df_clean["season"] = SEASON

engine = create_engine("postgresql+psycopg2://nuggets:nuggets@localhost:5432/nuggets_db")

print("Writing to Postgres table raw_nba_games...")
df_clean.to_sql(
    "raw_nba_games",
    engine,
    schema="public",
    if_exists="replace",
    index=False,
)

print("Done.")