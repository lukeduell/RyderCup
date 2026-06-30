# RyderCup

iOS scoring app for an 8-player, 4-round Ryder-Cup-style golf trip. Live multi-device
sync through a C# (ASP.NET Core) backend on Railway, backed by Neon Postgres.

> **The actual tournament:** 2026-07-08. Build for *this* trip first, generalize later.

## Tournament format

| Round | Day            | Format                    | Max pts |
|-------|----------------|---------------------------|---------|
| R1    | Thursday       | Individual stroke play    | 8       |
| R2    | Friday         | 2-man best ball (matchup) | 7       |
| R3    | Saturday AM    | 2-man scramble            | 8       |
| R4    | Saturday PM    | Individual net stroke play| 8       |
| —     | Across 72 holes| Birdies (1) / Eagles (3)  | open    |
| —     | Side games     | CTP, LD, putting contest  | open    |

Each round's format is editable (Settings → Rounds → tap round). Teams auto-pair after R1
(1/8, 2/7, 3/6, 4/5) and re-seed before R3 from running points — or override manually.
R4 handicaps default to "best R1 score = scratch, others get the difference, capped at 18,"
or use GHIN, or use a manual handicap override.

## Repo layout

```
RyderCup/
├── RyderCup.xcodeproj/      ← regenerate with `xcodegen generate`
├── RyderCup/                ← iOS SwiftUI app
│   ├── Models/              ← Player, Course, Round, Score, Team, SideGame, Tournament
│   ├── Services/            ← APIClient (REST), ScoringEngine (pure-Swift math)
│   ├── ViewModels/          ← TournamentViewModel (Observable, polling, writes)
│   └── Views/               ← SwiftUI views (one per screen, plus ScoringSubviews)
├── RyderCupTests/           ← scoring engine unit tests (14 tests)
├── backend/                 ← ASP.NET Core 9 Web API
│   ├── Program.cs           ← bootstrap, DI, endpoint mapping, Neon URL parsing
│   ├── Models/              ← EF entities + DTOs
│   ├── Endpoints/           ← Tournament / Score / SideGame minimal-API endpoints
│   ├── Data/                ← EF Core DbContext + JSONB conversions
│   ├── Migrations/          ← EF Core auto-generated migrations
│   ├── Dockerfile
│   └── railway.toml
└── project.yml              ← xcodegen spec
```

## Backend setup (Neon + Railway)

### 1. Create the Neon project

1. Sign in at https://console.neon.tech and create a new project named **RyderCup**.
   (You can repeat for a separate "non-prod" project if you want two environments —
   same recipe, separate connection strings.)
2. Copy the connection string. It looks like:
   `postgresql://user:pass@ep-xxx.neon.tech/neondb?sslmode=require`
3. Keep it handy for the next step.

### 2. Deploy the API to Railway

1. Push this repo to GitHub.
2. In Railway, **New Project → Deploy from GitHub Repo** and pick this repo.
3. Set the service **Root Directory** to `backend/`.
4. Add an env var: `DATABASE_URL` = the Neon connection string from step 1.
5. Deploy. Railway will build the Dockerfile, run the EF Core migrations on boot
   (`db.Database.Migrate()` runs at startup in `Program.cs`), and expose a public URL.
6. Hit `https://<your-url>/health` — should return `{"ok":true}`.

### 3. Run the backend locally

Either set the `DATABASE_URL` env var, or paste your Neon string into `backend/appsettings.Development.json`:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "postgresql://user:pass@ep-xxx.neon.tech/neondb?sslmode=require"
  }
}
```

The file is gitignored — your password stays local. Then:

```bash
cd backend
dotnet run
```

You should see `[startup] env=Development | DB from: ConnectionStrings:DefaultConnection in appsettings`
then `Now listening on: http://localhost:5050`. The first connection after Neon's compute suspends
can take 10–30s while it wakes; the startup retry loop handles that automatically.

> ⚠️ Some corporate networks / VPNs silently break Postgres traffic to Neon (TCP handshake succeeds
> but data never flows). Symptom: `psql` times out from every Neon endpoint in the region. If this
> happens, switch off the VPN or tether to a phone hotspot to confirm. For pure local development
> you can also use Postgres.app (`localhost`) and avoid the cloud entirely.

## iOS app setup

### 1. Regenerate the Xcode project (if needed)

```bash
brew install xcodegen   # one-time
xcodegen generate       # if you've added files outside Xcode or edited project.yml
```

### 2. Open and run

```bash
open RyderCup.xcodeproj
```

- Pick a development team in **Signing & Capabilities** (project.yml has a placeholder team ID — change to yours).
- Build to a simulator or device.

### 3. Configure inside the app

1. First launch: paste the Railway URL (e.g. `https://rydercup-production.up.railway.app`).
2. Tap **Create New** — the app returns a 6-character code.
3. Share that code with the other 7 phones; they paste the same URL and **Join Tournament**.
4. **Settings → Players**: enter 8 names (plus GHIN handicaps if using GHIN, or manual handicap overrides).
5. **Settings → Course**: par + HCP index per hole.
6. Start scoring R1. After R1, **Teams** tab → **Seed from R1**.
7. After R2, **Teams** tab → **Seed from running standings** (for R3).

## Distributing to the group

For 8 phones at a tournament:

- **Easiest:** TestFlight. Internal TestFlight slots are free; build appears in everyone's TestFlight app via email invite.
- **Manual:** connect each phone to Xcode and run the debug build directly (works but each install expires every 7 days for free accounts).

## Running tests

```bash
xcodebuild -project RyderCup.xcodeproj -scheme RyderCup \
  -destination "platform=iOS Simulator,name=iPhone 17" test
```

---

## Context for AI agents

This section is meant to bring a fresh agent (or human collaborator) up to speed
without having to re-derive design decisions. Keep it current as the project evolves.

### Project goal

Live-synced tournament scoring app for a specific 8-player Ryder-Cup-style trip
(2026-07-08). Built to handle 4 rounds with mixed formats, team play, individual
play, and a cumulative points leaderboard that mathematically keeps everyone alive
until the final round.

### Tech stack and *why*

- **iOS / SwiftUI**: native, no cross-platform overhead. iOS 17.0+.
- **MVVM with one `TournamentViewModel`**: keeps state in one place; all views observe.
- **ASP.NET Core 9 Minimal API**: smallest possible footprint, fast to deploy. C# was the user's preference.
- **Neon Postgres**: serverless, free tier sufficient, JSONB support for the mixed-shape document data.
- **Railway**: simplest Docker-based deploy with auto-build from GitHub.
- **Polling (~4s) over WebSockets/SSE**: golf has long gaps between updates; complexity not worth it.
- **xcodegen**: the `.xcodeproj` is regenerable from `project.yml`. Never hand-edit the pbxproj.

### Key design rules

- **`Services/ScoringEngine.swift` is the only place tournament math lives.** Both the leaderboard and per-round views call into it. Pure-Swift, no side effects. Read this file first if you're trying to understand the app.
- **Single source of truth is the backend.** The iOS in-memory `Tournament` is rebuilt from each polled snapshot. Local persistence is limited to UserDefaults (API URL + join code + active round).
- **Concurrent writes don't collide on scores.** Each `ScoreEntry` is its own Postgres row keyed by `playerId_r{round}_h{hole}`. Two phones entering different scores simultaneously is fine. Tournament metadata edits (players, course, settings) are last-write-wins (rare contention).
- **Override hierarchy** (tested, important):
  - **Handicap source**: `tournament.handicapOverrides[pid]` > `player.ghinHandicap` (if GHIN toggle on) > derived-from-R1 (best gross = scratch, others = diff, capped at 18)
  - **Round points**: `round.pointsOverride[pid]` > computed via `round.format` (which itself respects `round.grossOverride` / `round.teamScoreOverride`)
- **No real auth.** A 6-character tournament code is the only credential. Fine for 8 friends; do not expose to general public.

### Data model summary

- `Tournament` (Postgres row, JSONB for course/players/rounds + new `HandicapOverrides`)
  - `players: [Player]`, `course: Course`, `rounds: [Round]`
  - `handicapOverrides: { playerId → int }`
  - `useGhinHandicaps: bool`, `birdieEagleBonusEnabled: bool`
- `Round` (inside the JSONB list)
  - `index, name, format, status`
  - `teams: [Team]`, `matchups: [Matchup]` (for best ball)
  - `pointsOverride: { playerId → double }` (final point override)
  - `grossOverride: { playerId → int }` (skip hole-by-hole)
  - `teamScoreOverride: { teamId → int }` (scramble only)
- `ScoreEntry` (separate Postgres row): `(playerId, roundIndex, holeNumber, strokes)`
- `TeamScoreEntry` (separate row, scramble only): `(teamId, roundIndex, holeNumber, strokes)`
- `SideGameEntry` (separate row): `(type, playerId, roundIndex?, holeNumber?, points, note?)`

### Known gaps / open decisions

- **>4 rounds isn't supported** despite `rounds: [Round]` being arbitrary-length. Hardcoded spots:
  - `TournamentViewModel.activeRoundIndex` clamps to `0...3`
  - `RoundView` segmented picker hardcodes "Thu (R1) / Fri (R2) / Sat AM (R3) / Sat PM (R4)"
  - `LeaderboardView` pips hardcode `roundPoints[0..3]` and labels T/F/SA/SP
  - `ScoringEngine.leaderboard` builds the per-player dict with fixed keys 0,1,2,3
  - `ScoringEngine.derivedHandicaps` uses `roundIndex: 0` (assumes Thursday sets handicaps)
  - `ScoringEngine.birdieEaglePoints` excludes `roundIndex == 2` (should be: skip any round with `format == .scramble`)
  - `autoSeedR2Teams` writes to round index 1; `autoSeedR3Teams` writes to index 2

  To support arbitrary rounds, drive logic off `tournament.rounds` and `round.format` instead of indices. ~30-45 min refactor. The user has acknowledged this gap and explicitly deferred.

- **EF Core warnings** about value comparers on JSONB collections — harmless because we always replace the whole list/dict server-side. Don't suppress without understanding.

- **No App Icon yet** (`Assets.xcassets/AppIcon.appiconset` is empty).

- **Signing not set up for distribution** — `project.yml` has a placeholder `DEVELOPMENT_TEAM`. Change it before archiving.

### Repo conventions

- iOS folder layout matches the user's existing projects (SwingSync, GrassMeterXcode): `Models/`, `Services/`, `ViewModels/`, `Views/`.
- Combined-view files where it kept file count manageable (`ScoringSubviews.swift` holds all 4 per-format score-entry views).
- No narrative comments. Only comment when the *why* is non-obvious. Don't comment on what code does — well-named identifiers do that.
- C#: file-scoped namespaces, EF entities in `Models/Models.cs`, request/response DTOs in `Models/Dtos.cs`.

### Working on this project

- **Regenerate Xcode project after adding files outside Xcode**: `xcodegen generate`
- **Build iOS**: `xcodebuild -project RyderCup.xcodeproj -scheme RyderCup -destination "generic/platform=iOS Simulator" -sdk iphonesimulator build`
- **Run iOS tests**: `xcodebuild -project RyderCup.xcodeproj -scheme RyderCup -destination "platform=iOS Simulator,name=iPhone 17" test`
- **Build backend**: `cd backend && dotnet build`
- **Run backend locally**: `cd backend && DATABASE_URL="..." dotnet run`
- **New EF migration**: `cd backend && DATABASE_URL="<any-valid-string>" dotnet ef migrations add YourMigrationName`
- **Migrations on deploy**: handled automatically in `Program.cs` via `db.Database.Migrate()` at startup. No manual step.

### User preferences (durable)

- The user does git/GitHub operations on a separate machine. Do **not** run `git`, `gh`, or push code from this environment. Hand off via files + a checklist.
- The user does not want over-engineering or speculative abstractions. Implement what's asked, no more.
- Keep responses tight. No trailing summaries of obvious work.

### Architecture notes (one-paragraph version)

iOS SwiftUI app → polls REST API on Railway every 4s → ASP.NET Core Minimal API → EF Core → Neon Postgres. Tournament metadata (players, course, rounds, settings) is one row with JSONB columns; per-hole scores live in their own normalized table so 8 phones writing simultaneously never collide. The `ScoringEngine` is the only place tournament math lives — pure-Swift, side-effect-free, unit-tested. Manual overrides exist at three layers (handicap, gross total, final points) for cases where the engine's computation needs to be corrected by hand. There's no real auth: a 6-character tournament code is the only credential.
