# threefold_game_kit

Shared game systems for Threefold Studio's Flutter + Flame puzzle games
(SOP TFS-SOP-001 Section 15, Appendix C). It holds the parts every game
copies today: the clock, the save, lives, daily rewards and streaks, the
season pass, the sky clock and the sync client. Each game keeps its rules
engine, board, art, shop catalog, reward tables and copy.

Nothing in the kit knows a game's name, currency, colours or words. The game
passes in every number and every reward. Rewards are generic: `Daily<R>` and
`Season<R>` work with the game's own `Reward` class.

## Install

```yaml
dependencies:
  threefold_game_kit:
    git:
      url: https://github.com/Threefold-Studio/threefoldpackages.git
      path: packages/threefold_game_kit
      ref: v0.1.0
```

```dart
import 'package:threefold_game_kit/threefold_game_kit.dart';            // pure Dart
import 'package:threefold_game_kit/shared_preferences_store.dart';     // the adapter
```

The main library imports no Flutter or plugin code (a test checks it). Only
`shared_preferences_store.dart` imports SharedPreferences.

## The pieces

| Piece | File | What it does | SOP |
|---|---|---|---|
| `KeyValueStore` | `src/storage/key_value_store.dart` | String storage with sync reads and async writes. `MemoryKeyValueStore` for tests; `SharedPreferencesKeyValueStore` for the app. | R15.9 |
| `GameClock` (alias `TrustedClock`) | `src/time/game_clock.dart` | The one clock: device time, plus the server offset, plus a rollback guard, plus dev time travel. Reports skew and `holdClaims`. | R15.8, R15.10, R9.3, R9.12, R5.7 |
| Day keys | `src/time/day_key.dart` | `dayKey`, `tryParseDayKey`, `daysBetween`, `addDaysToKey`, `yesterdayKey`, `weekStartKey`. Calendar math on UTC dates, so DST never adds or loses a day. | R9.4, R9.12, R9.14 |
| `SaveStore` | `src/save/save_store.dart` | Envelope `{"schema": N, "savedAt": ms, "data": {...}}`, migrations by schema number, a backup of the last good save, quarantine of an unreadable save. | R15.9 |
| `Lives` | `src/economy/lives.dart` | Regenerating hearts, apples or lollipops: max, refill interval, cap above max, unlimited-until window. | R15.11 |
| `Daily` | `src/economy/daily.dart` | Welcome week, repeating calendar, streak, milestones (2, 3, 5, 7, 10, 14, 21, 30, then every 15 by default), streak saver by currency or ad. | R15.12 |
| `SeasonPass` | `src/economy/season_pass.dart` | `PassProgress`, `Season` loader, tiers from XP, free and premium claims. | R15.13 |
| `SkyClock` | `src/sky/sky_clock.dart` | Sunrise, day, sunset, night from NOAA sunrise math and the phone's time zone. No location permission. | Section 15 |
| `SyncClient` | `src/sync/sync_client.dart` | Sends progress plus deltas since the last acknowledged sync, reads `serverTime`, feeds the clock. Transport is an interface; no Supabase import. | R15.14, R9.12 |

### GameClock

```dart
final clock = GameClock(
  store: kv,                 // keeps the server offset and last seen time
  devTools: Env.devTools,    // time travel only works when true
);
clock.now();                 // every timer reads this, nothing else
clock.onServerTime(t);       // from bootstrap; SyncClient calls it for you
clock.holdClaims;            // true when the phone was more than 2 hours off
clock.advanceForDev(const Duration(days: 1)); // DEV-ONLY time travel
```

- The server offset corrects a phone clock that is set wrong.
- If the result steps back more than 10 minutes from the latest time already
  seen, the latest time is used, so winding the clock back cannot freeze
  hearts or reopen a day.
- A server time resets that guard, because the server is the truth.
- The dev offset sits on top and is never stored, so resetting it is not a
  rollback.
- While `holdClaims` is true, pass `hold: true` to daily, pass and lives
  calls. They refuse claims and refill catch-up until the clock is fixed.

### SaveStore

```dart
final save = SaveStore(kv, 'harborjam.save',
    schema: 1,
    legacyKey: 'harborjam.player.v1',    // read once if the new key is empty
    migrations: {0: fromLegacy},         // schema 0 is the bare old save
    clock: clock.now);
final loaded = await save.load(PlayerState.fromJson,
    onError: (e, st) => analytics.error(e, st));
state = loaded.value ?? PlayerState();   // null only when nothing was readable
await save.write(state.toJson());
```

On load it tries `<key>`, then `<key>.backup`, then `legacyKey`. Each step
parses, runs `migrations[from]` up to `schema`, then calls the game's decoder.
If any of that throws (bad JSON, a cast error in `fromJson`, a migration
failure, a save from a newer app), the raw string is kept under
`<key>.corrupt.<ms>` and the next copy is tried. A write never makes an
unreadable save the backup. At most `maxQuarantined` (5) copies are kept.

Keep the sync edit counter inside `data` (call it `editCount`); `schema` is
the format number only. Add a frozen JSON fixture for every migration under
the game's `test/fixtures/saves/`.

### Lives

```dart
const lives = Lives(LivesConfig(max: 5, refill: Duration(minutes: 15), cap: 10));
lives.refill(state.lives, clock.nowMs(), hold: clock.holdClaims);
lives.lose(state.lives, clock.nowMs());
lives.fullAt(state.lives, clock.nowMs());   // for the "full" reminder
```

`LivesState.toJson` and `fromJson` take the game's key names, so Island
Pickup keeps `apples`, `applesUpdatedAt` and `unlimitedUntil`. A timer stamp
in the future is clamped to now. Lives count epoch milliseconds, so DST does
nothing to them.

### Daily

```dart
final daily = Daily<Reward>(DailyConfig(
  welcome: welcomeTable, calendar: calendarTable,
  milestoneReward: milestoneReward, saverCost: 100));
daily.onOpen(state.daily, clock.now());           // true: offer the saver
daily.claim(state.daily, clock.now(), hold: clock.holdClaims);
final cost = daily.saveStreak(state.daily, clock.now(),
    payment: StreakSaverPayment.currency, balance: state.coins);
```

Days reset on the local calendar day. The westward flight rule stays: a last
claim dated tomorrow blocks a second claim. `DailyState` JSON keys are the
same as the games use today. Ad doubling stays in the game, since what
doubles (cosmetics or not) is a game decision.

### SeasonPass

```dart
final season = Season<Reward>.fromJson(json, Reward.fromJson);
final pass = SeasonPass(season);
pass.adopt(state.pass);                      // new season: start over
pass.addXp(state.pass, xp, clock.now());     // only while active
pass.claim(state.pass, tier, premium: false, hold: clock.holdClaims);
```

Tiers are 1-based as in the season JSON. Premium is only set from the
purchase webhook through sync; the server re-checks every claim in
`claim-pass-reward`.

### SkyClock

```dart
final sky = SkyClock(timeZone: await FlutterTimezone.getLocalTimezone());
sky.phaseAt(clock.now());   // SkyPhase.sunrise / day / sunset / night
phase.isTwilight;           // for games with one dusk picture
```

It checks the day before, of and after the instant, so a place far from UTC
is never read on the wrong day, and it is correct whether the time passed is
local or UTC. Midnight sun reads as day and polar night as night. With no
known zone it uses the fixed schedule the games use today.

### SyncClient

```dart
final sync = SyncClient(
  transport: FunctionSyncTransport('sync-progress', (name, body) async =>
      (await Supabase.instance.client.functions.invoke(name, body: body)).data),
  clock: clock,
  store: kv,
);
final r = await sync.sync(
  progress: state.toJson(),
  counters: {'level': state.level, 'coins': state.coins, 'xp': state.pass.xp},
  results: pending.map((e) => e.toJson()).toList(),
);
```

The body carries `progress` (as today), `counters`, `delta` (each counter
minus the last value the server acknowledged), `results` and `mode`. The
acknowledged counters are stored only after the server answers. If the
response has `serverTime` (ISO string or epoch ms), the clock gets it,
measured at the middle of the round trip, and `r.holdClaims` reports skew
over 2 hours.

## Adopting the kit in a game

1. Add the git dependency pinned by tag. Never copy a kit file into `lib/`.
2. In `main.dart`, create one `SharedPreferencesKeyValueStore`, one
   `GameClock(store: kv, devTools: Env.devTools)` and pass `clock.now` to
   `PlayerController` and `GameController`.
3. Replace `load()` and `_persist()` with `SaveStore` (example above). Start
   a new player only when `loaded.value` is null. Log `loaded.errors`.
4. Replace the hearts code with `Lives`, `Daily` with `Daily<Reward>`, and
   `PassProgress` and `Season` with the kit's. Keep the reward tables in
   `lib/data/` of the game.
5. Make `bootstrap` call `clock.onServerTime` and send sync through
   `SyncClient`. Add `serverTime` to the `sync-progress` response.
6. Pass `hold: clock.holdClaims` to daily, pass and refill calls, and show the
   game's own "check your phone's clock" message while it is true.
7. Wire the Dev screen's time travel to `clock.advanceForDev`.
8. Keep the kit's behaviour tested in the game too: the daily tests in the
   game call the kit with the game's real tables.

### Harbor Jam

- Save key `harborjam.player.v1` becomes `legacyKey`; the new key is
  `harborjam.save`, schema 1. Migration 0 to 1 renames `version` to
  `editCount` if you rename it (the server field can stay `version`).
- `PlayerState.kMaxLives`, `kLifeCap`, `kRefillMs` become
  `LivesConfig(max: 5, cap: 10, refill: Duration(minutes: 15))`. Keys
  `lives`, `livesUpdatedAt`, `infiniteUntil` are the kit defaults.
- `Daily.welcome`, `Daily.calendar`, `Daily.milestoneReward` move into a
  `DailyConfig<Reward>`; `Daily.streakSaverCoins` becomes `saverCost`.
  `Daily.doubled` stays in the game.
- `lib/game/sky_clock.dart` and `lib/data/tz_places.dart` are deleted;
  `HarborBackdrop` holds a `SkyClock` built from the zone in `main.dart`.
- `Season.isActive` read `DateTime.now()`; the kit's takes the clock.

### Kaiju Kandy

- Same as Harbor Jam with key `kaijukandy.player.v1` and lollipops for
  lives (same JSON keys). Kaiju Kandy has no sky clock today; it can adopt
  `SkyClock` later or not at all.
- `SyncService.promos()` is game data and stays in the game.

### Island Pickup

- Key `islandpickup.player.v1`. Apples use custom JSON keys:
  `LivesState.fromJson(j, livesKey: 'apples', updatedKey: 'applesUpdatedAt', unlimitedKey: 'unlimitedUntil', ...)`.
- `Daily.streakSaverStars` becomes `saverCost`.
- `Scene.at` maps `SkyPhase.isTwilight` to `Scene.dusk`.
- Weekly goals (`goals.dart`) are not in the kit yet; use `weekStartKey` for
  the Monday reset.

## Changes from the games' code

- A corrupt save is quarantined and the backup is loaded, instead of a new
  player being written over it (SOP 15.3 finding 2).
- The save has a real schema number, separate from the sync counter
  (finding 1).
- Timers read a clock with a server offset, a rollback guard and skew
  holding (finding 3).
- `SkyClock` no longer depends on the device zone matching the zone name,
  works out the day of year on UTC dates (the old local date math was a day
  short between the March and November clock changes), and shows midnight
  sun and polar night as day and night rather than the fixed schedule.
- Lives clamp a future `updatedAt` to now.

## Develop

```
flutter pub get
dart format lib test
dart analyze --fatal-infos
flutter test
TZ=America/New_York flutter test   # runs the DST cases on a US zone
```
