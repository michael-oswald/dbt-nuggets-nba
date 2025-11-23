"""
Ingest Nuggets player box score stats for each game in raw_nba_games
using the BoxScoreTraditionalV3 endpoint, and write them to Postgres
as public.raw_nba_boxscores.
"""

from nba_api.stats.endpoints import BoxScoreTraditionalV3
import pandas as pd
from sqlalchemy import create_engine, text
import time

# --- CONFIG ---
PG_USER = "nuggets"
PG_PASSWORD = "nuggets"
PG_HOST = "localhost"
PG_PORT = 5432
PG_DB = "nuggets_db"
PG_SCHEMA = "public"
RAW_GAMES_TABLE = "raw_nba_games"
RAW_BOXSCORES_TABLE = "raw_nba_boxscores"

CONNECTION_STRING = f"postgresql+psycopg2://{PG_USER}:{PG_PASSWORD}@{PG_HOST}:{PG_PORT}/{PG_DB}"


def main():
    print("Connecting to Postgres...")
    engine = create_engine(CONNECTION_STRING)

    # 1) Load game_ids from raw_nba_games
    print("Loading game_ids from raw_nba_games...")
    with engine.connect() as conn:
        game_ids_df = pd.read_sql(
            text(f"SELECT DISTINCT game_id FROM {PG_SCHEMA}.{RAW_GAMES_TABLE} ORDER BY game_id"),
            conn,
        )

    game_ids = game_ids_df["game_id"].tolist()
    print(f"Found {len(game_ids)} games.")

    all_rows = []

    # 2) Loop over games and fetch box score (player-level)
    for idx, game_id in enumerate(game_ids, start=1):
        print(f"[{idx}/{len(game_ids)}] Fetching box score for game {game_id}...")

        try:
            box = BoxScoreTraditionalV3(game_id=game_id)
            dfs = box.get_data_frames()

            if not dfs:
                print(f"  ⚠ No data frames returned for game {game_id}, skipping.")
                continue

            # First dataframe contains player stats
            player_stats_df = dfs[0].copy()

            # Attach game_id explicitly (sometimes present, but we enforce it)
            if "GAME_ID" not in player_stats_df.columns:
                player_stats_df["GAME_ID"] = game_id

            all_rows.append(player_stats_df)

        except Exception as e:
            print(f"  ❌ Error fetching box score for game {game_id}: {e}")
            continue

        # Be nice to the NBA stats API
        time.sleep(0.6)

    if not all_rows:
        print("No box score data collected. Exiting.")
        return

    # 3) Concatenate all box score rows into a single DataFrame
    full_df = pd.concat(all_rows, ignore_index=True)
    print(f"Total player box score rows collected: {len(full_df)}")

    # 4) Normalize/rename a few useful columns (optional but nice for dbt later)
    # Keep the raw columns but you can select/rename here if you want.
    # For now, just ensure GAME_ID is called game_id for consistency.
    if "GAME_ID" in full_df.columns:
        full_df = full_df.rename(columns={"GAME_ID": "game_id"})

    # 5) Write to Postgres as public.raw_nba_boxscores (replace each time for now)
    print(f"Writing to Postgres table {PG_SCHEMA}.{RAW_BOXSCORES_TABLE}...")
    with engine.begin() as conn:
        full_df.to_sql(
            RAW_BOXSCORES_TABLE,
            conn,
            schema=PG_SCHEMA,
            if_exists="replace",
            index=False,
        )

    print("Done! ✅ Box scores written to Postgres.")


if __name__ == "__main__":
    main()
