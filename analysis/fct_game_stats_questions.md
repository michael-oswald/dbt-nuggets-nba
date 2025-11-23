# Business Questions Answered by fct_game_stats

## Current Capabilities

The `fct_game_stats` fact table contains **team-level game data** (one row per Nuggets game):
- `game_id`, `season`, `game_date`
- `matchup` (e.g., "DEN vs. LAL" or "DEN @ BOS")
- `win_loss` ('W' or 'L')
- `team_points` (Nuggets points scored)
- `is_win` (1 or 0 flag)

---

## 📊 Questions You Can Answer NOW

### 1. Season Win/Loss Record
**Question**: What is the Nuggets' overall record this season?

```sql
select
    count(*) as games_played,
    sum(is_win) as wins,
    count(*) - sum(is_win) as losses,
    round(100.0 * sum(is_win) / count(*), 1) as win_pct,
    round(avg(team_points)::numeric, 1) as avg_points_per_game
from analytics.fct_game_stats;
```

**Business Value**: Quick season summary for fans, media, front office

---

### 2. Home vs Away Performance
**Question**: Do the Nuggets perform better at home or on the road?

```sql
select
    case
        when matchup like 'DEN vs.%' then 'Home'
        when matchup like 'DEN @%' then 'Away'
    end as location,
    count(*) as games,
    sum(is_win) as wins,
    round(100.0 * sum(is_win) / count(*), 1) as win_pct,
    round(avg(team_points)::numeric, 1) as avg_points
from analytics.fct_game_stats
group by 1;
```

**Business Value**:
- Understand home court advantage
- Travel impact on performance
- Ticket pricing strategy

---

### 3. Monthly Performance Trends
**Question**: When during the season do the Nuggets play their best?

```sql
select
    to_char(game_date, 'YYYY-MM') as month,
    count(*) as games,
    sum(is_win) as wins,
    round(100.0 * sum(is_win) / count(*), 1) as win_pct,
    round(avg(team_points)::numeric, 1) as avg_points
from analytics.fct_game_stats
group by 1
order by 1;
```

**Business Value**:
- Identify "hot" vs "cold" stretches
- Rest/schedule fatigue analysis
- Playoff momentum tracking

---

### 4. Scoring Consistency
**Question**: How consistent is the Nuggets' offense?

```sql
select
    round(avg(team_points)::numeric, 1) as avg_points,
    round(stddev(team_points)::numeric, 2) as stddev_points,
    round(((stddev(team_points) / avg(team_points)) * 100)::numeric, 1) as cv_percent,
    min(team_points) as lowest_scoring_game,
    max(team_points) as highest_scoring_game
from analytics.fct_game_stats;
```

**Business Value**:
- Offensive reliability
- Game-to-game predictability
- Coaching/strategy insights

---

### 5. High-Scoring vs Low-Scoring Game Outcomes
**Question**: Do the Nuggets win more when they score 120+ points?

```sql
select
    case
        when team_points >= 120 then 'High scoring (120+)'
        when team_points >= 110 then 'Average (110-119)'
        else 'Low scoring (<110)'
    end as scoring_category,
    count(*) as games,
    sum(is_win) as wins,
    round(100.0 * sum(is_win) / count(*), 1) as win_pct
from analytics.fct_game_stats
group by 1
order by
    case
        when scoring_category = 'High scoring (120+)' then 1
        when scoring_category = 'Average (110-119)' then 2
        else 3
    end;
```

**Business Value**:
- Offensive strategy validation
- Pace of play analysis
- "Points needed to win" threshold

---

### 6. Day of Week Performance
**Question**: Do the Nuggets play better on certain days of the week?

```sql
select
    to_char(game_date, 'Day') as day_of_week,
    count(*) as games,
    sum(is_win) as wins,
    round(100.0 * sum(is_win) / count(*), 1) as win_pct,
    round(avg(team_points)::numeric, 1) as avg_points
from analytics.fct_game_stats
group by 1, extract(dow from game_date)
order by extract(dow from game_date);
```

**Business Value**:
- Rest patterns
- Back-to-back game impact
- Schedule optimization

---

### 7. Win/Loss Streaks
**Question**: What is the Nuggets' current win streak (or losing streak)?

```sql
with game_sequence as (
    select
        game_date,
        matchup,
        win_loss,
        lag(win_loss) over (order by game_date) as prev_result,
        case
            when win_loss = lag(win_loss) over (order by game_date) then 0
            else 1
        end as streak_change
    from analytics.fct_game_stats
),

streak_groups as (
    select
        game_date,
        matchup,
        win_loss,
        sum(streak_change) over (order by game_date) as streak_id
    from game_sequence
),

current_streak as (
    select
        win_loss,
        count(*) as streak_length
    from streak_groups
    where streak_id = (select max(streak_id) from streak_groups)
    group by win_loss
)

select
    case when win_loss = 'W' then 'Win Streak' else 'Losing Streak' end as streak_type,
    streak_length
from current_streak;
```

**Business Value**:
- Team momentum tracking
- Media narratives
- Fan engagement

---

### 8. Opponent Analysis (Basic)
**Question**: Which opponents has Denver faced most often?

```sql
select
    case
        when matchup like '%vs.%' then trim(split_part(matchup, 'vs.', 2))
        when matchup like '%@%' then trim(split_part(matchup, '@', 2))
    end as opponent,
    count(*) as games_played,
    sum(is_win) as wins,
    round(100.0 * sum(is_win) / count(*), 1) as win_pct
from analytics.fct_game_stats
group by 1
order by games_played desc, win_pct desc;
```

**Business Value**:
- Head-to-head records
- Divisional performance
- Rivalry tracking

---

### 9. Recent Form (Last N Games)
**Question**: How have the Nuggets performed in their last 10 games?

```sql
select
    game_date,
    matchup,
    team_points,
    win_loss,
    sum(is_win) over (order by game_date rows between 9 preceding and current row) as wins_last_10,
    round(avg(team_points) over (order by game_date rows between 9 preceding and current row)::numeric, 1) as avg_pts_last_10
from analytics.fct_game_stats
order by game_date desc
limit 10;
```

**Business Value**:
- Current form tracking
- Playoff seeding implications
- Power rankings input

---

### 10. Blowout Wins vs Close Games
**Question**: How often do the Nuggets win by 20+ points?

**Note**: This requires opponent points, which we don't have yet. See enhancements below.

---

## 🚀 Enhanced Questions (Require Additional Data)

### Missing Fields to Add:

To unlock more powerful analysis, enhance `fct_game_stats` with:

```sql
-- Proposed enhanced schema
select
    game_id,
    season,
    game_date,

    -- Home/Away (parsed)
    case when matchup like 'DEN vs.%' then 'Home' else 'Away' end as location,

    -- Opponent (parsed)
    case
        when matchup like '%vs.%' then trim(split_part(matchup, 'vs.', 2))
        else trim(split_part(matchup, '@', 2))
    end as opponent,

    -- Scoring
    team_points as nuggets_points,
    opponent_points,  -- ⚠️ MISSING - need to add from raw data
    team_points - opponent_points as point_differential,

    -- Game type
    case
        when abs(team_points - opponent_points) >= 20 then 'Blowout'
        when abs(team_points - opponent_points) <= 5 then 'Close'
        else 'Moderate'
    end as game_closeness,

    -- Result
    win_loss,
    is_win,

    -- Additional team stats (if available from API)
    team_rebounds,
    team_assists,
    team_turnovers,
    team_fg_pct
from ...
```

---

### New Questions Enabled by Enhancements:

#### **1. Margin of Victory Analysis**
```sql
-- Average margin in wins vs losses
select
    win_loss,
    count(*) as games,
    round(avg(point_differential)::numeric, 1) as avg_margin
from analytics.fct_game_stats
group by 1;
```

**Insight**: Are wins convincing or close? Are losses competitive?

---

#### **2. Clutch Performance**
```sql
-- Win rate in close games (≤5 point differential)
select
    count(*) as close_games,
    sum(is_win) as close_wins,
    round(100.0 * sum(is_win) / count(*), 1) as close_game_win_pct
from analytics.fct_game_stats
where game_closeness = 'Close';
```

**Insight**: Are the Nuggets "clutch" in tight games?

---

#### **3. Strength of Schedule**
```sql
-- Performance vs winning teams (requires opponent record lookup)
select
    case
        when opponent_win_pct >= 0.500 then 'vs Winning Teams'
        else 'vs Losing Teams'
    end as opponent_quality,
    count(*) as games,
    sum(is_win) as wins,
    round(100.0 * sum(is_win) / count(*), 1) as win_pct
from analytics.fct_game_stats
join dim_team_records on opponent = team_name  -- hypothetical join
group by 1;
```

**Insight**: Quality wins matter more for playoff seeding

---

#### **4. Offensive Efficiency**
```sql
-- Points per possession (requires possessions calculation)
select
    round(avg(nuggets_points / possessions)::numeric, 2) as offensive_rating,
    round(avg(opponent_points / possessions)::numeric, 2) as defensive_rating,
    round(avg((nuggets_points - opponent_points) / possessions)::numeric, 2) as net_rating
from analytics.fct_game_stats;
```

**Insight**: More advanced than raw points - accounts for pace

---

## 📋 Summary

### Current State
`fct_game_stats` is a **simple team-level fact table** that answers:
- ✅ Win/loss record and percentages
- ✅ Scoring averages and consistency
- ✅ Home vs away splits
- ✅ Monthly/weekly trends
- ✅ Basic opponent analysis

### Enhancement Opportunities
Add these fields to unlock deeper insights:
1. **Opponent points** → margin of victory analysis
2. **Home/away flag** → cleaner location splits
3. **Opponent ID/name** → head-to-head records
4. **Additional team stats** → rebounds, assists, FG%, etc.
5. **Rest days** → fatigue/schedule analysis
6. **Playoff flag** → regular season vs postseason

### Next Steps
1. Enhance raw ingestion to capture opponent stats
2. Add calculated fields in intermediate layer
3. Build new analyses in dbt or BI tool
4. Create dashboard for stakeholder consumption

---

**Bottom Line**: Even with basic fields, `fct_game_stats` provides valuable team-level insights. With enhancements, it becomes a powerful tool for coaching, front office, and media analysis.
