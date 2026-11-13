# Changelog

## 0.1.0

First release.

- `GameClock` (alias `TrustedClock`): injectable device clock, server offset,
  10 minute rollback guard, skew with `holdClaims` above 2 hours, dev time
  travel offset.
- Day keys: `dayKey`, `tryParseDayKey`, `daysBetween`, `addDaysToKey`,
  `yesterdayKey`, `weekStartKey`, all DST safe.
- `SaveStore`: schema envelope, migrations, backup of the last good save,
  quarantine of unreadable saves, legacy key import.
- `KeyValueStore` with `MemoryKeyValueStore` and the
  `SharedPreferencesKeyValueStore` adapter.
- `Lives`, `Daily`, `SeasonPass`, `SkyClock` and `SyncClient` with
  `FunctionSyncTransport`.
