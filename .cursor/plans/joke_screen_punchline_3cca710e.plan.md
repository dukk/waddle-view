---
name: Joke screen punchline
overview: Add a new layout widget type `joke` that loads a random joke from Drift, shows the setup immediately, and reveals the punchline after half of the slide’s `dwellMs` using a cancellable timer. Register a seeded `screen_definitions` row so the joke screen participates in the existing `ScreenRotator` program.
todos:
  - id: delay-helper-tests
    content: Add failing unit tests for dwellMs/2 punchline delay edge cases (and optional pure helper)
    status: completed
  - id: joke-slide-widget
    content: "Implement JokeSlideWidget: DB random joke, setup + Timer + punchline reveal + empty state"
    status: completed
  - id: wire-rotator
    content: Pass AppDatabase into _SlideContent; add layout type joke → JokeSlideWidget
    status: completed
  - id: seed-screen
    content: Add _ensureJokeScreen in initial_seed with layoutJson for joke widget
    status: completed
  - id: widget-tests
    content: fake_async widget tests with memory DB (setup then punchline after half dwell)
    status: completed
isProject: false
---

# Joke screen with timed punchline reveal

## Behavior

- **Timing**: Use [`ResolvedSlide.dwellMs`](apps/waddle_view/lib/curator/screen_program_curator.dart) (the same value [`ScreenRotator`](apps/waddle_view/lib/dashboard/screen_rotator.dart) uses for `_dwellTimer`). Punchline delay = **`dwellMs ~/ 2`**. If that is `0` (e.g. very short truncated dwell), reveal on the next frame or immediately so the UI stays consistent.
- **Content**: Read `setup` / `punchline` from the existing [`Jokes`](apps/waddle_view/lib/persistence/tables.dart) table (populated by [`JokeDataProvider`](apps/waddle_view/lib/data/providers/joke_data_provider.dart)). Pick **one random row** per slide appearance (`ORDER BY RANDOM() LIMIT 1` via Drift, optionally filtered by optional layout `config.categoryId` if present).
- **Lifecycle**: `StatefulWidget` + `Timer`; cancel in `dispose`. Async load must guard with `mounted` before `setState`.
- **Empty DB**: Show a short placeholder (e.g. “No jokes yet”) and skip the punchline timer or show nothing for punchline.

## UI wiring

1. **Pass DB into slide content** — [`ScreenRotator`](apps/waddle_view/lib/dashboard/screen_rotator.dart) already holds `widget.db`. Thread `AppDatabase` into `_SlideContent` and its `_buildWidgets` helper so a new branch can query jokes (today `_SlideContent` only receives `slide` + `theme`).

2. **New widget type** — Extend the `switch (w.type)` in `_buildWidgets` (same file, ~lines 242–271) with e.g. `'joke'`:
   - Delegate to a dedicated widget in a new library file, e.g. [`apps/waddle_view/lib/dashboard/joke_slide_widget.dart`](apps/waddle_view/lib/dashboard/joke_slide_widget.dart), to keep `screen_rotator.dart` from growing and to isolate timer/async logic for tests.
   - Presentation: large centered setup text; after delay, show punchline (subtle **fade-in** via `AnimatedOpacity` or `AnimatedSwitcher` is enough for “reveal” without new dependencies).

3. **Layout JSON** — Example widget entry:

   `{"type":"joke","slot":"main","config":{}}`  
   Optional: `"config":{"categoryId":"dad"}` to restrict the random pick.

## Seed

- In [`initial_seed.dart`](apps/waddle_view/lib/seed/initial_seed.dart), add something like `_ensureJokeScreen` (mirror `_ensureWelcomeScreen`): insert if missing a [`screen_definitions`](apps/waddle_view/lib/persistence/tables.dart) row with `id` (e.g. `jokes`), `layoutJson` containing the `joke` widget, and a sensible `dwellMs` (e.g. same 10000 ms as welcome, or slightly longer so setup + punchline both get airtime).

## Tests (TDD)

- **Pure helper** (optional but coverage-friendly): e.g. `int punchlineDelayMs(int dwellMs)` implementing `dwellMs ~/ 2` with documented edge cases — unit-tested in a small `test/..._test.dart`.
- **Widget test** — [`fake_async`](apps/waddle_view/pubspec.yaml) (already a dev dependency) + [`openMemoryDatabase`](apps/waddle_view/test/helpers/memory_database.dart): insert one `Jokes` row + required `JokeCategories` FK, pump `JokeSlideWidget` (or a thin test wrapper with `MaterialApp`) with fixed `dwellMs`, assert setup visible, advance time by `dwellMs/2`, assert punchline visible. Verify timer cancellation does not throw when widget is disposed mid-wait (optional second test).

## Files to touch (concise)

| Area | File |
|------|------|
| UI + switch case + pass-through `db` | [`apps/waddle_view/lib/dashboard/screen_rotator.dart`](apps/waddle_view/lib/dashboard/screen_rotator.dart) |
| New joke slide widget | `apps/waddle_view/lib/dashboard/joke_slide_widget.dart` (new) |
| Optional delay helper | same file or tiny `joke_slide_timing.dart` |
| Seed | [`apps/waddle_view/lib/seed/initial_seed.dart`](apps/waddle_view/lib/seed/initial_seed.dart) |
| Tests | `apps/waddle_view/test/dashboard/joke_slide_widget_test.dart` (+ timing test if split) |

## Out of scope

- Changing the rotator’s title line (still shows `slide.screenId`; seed id `jokes` will display as that string unless you later add a display name to `ResolvedSlide`).
- REST routes or curator changes beyond what’s needed for random selection.
