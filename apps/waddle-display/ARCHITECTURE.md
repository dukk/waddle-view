# waddle_display architecture

This document describes how the TV dashboard is structured at runtime and how major subsystems interact. The **composition root** is [`lib/main.dart`](lib/main.dart); feature code is grouped by responsibility under [`lib/`](lib/).

## Design goals

- **Single process**: Flutter UI, background async loops, and the embedded HTTP server share one isolate unless you add isolates later.
- **Ports and adapters**: abstract boundaries (`IDataProvider`, `DataWriteContext`, `AlertRepository`, `TickerCuratedRepository`, `DashboardCurator`, `BlobStore`, `SecretStore`, `WindowChromeController`) with Drift/filesystem/Linux implementations.
- **No secrets in SQLite**: provider tokens and similar values go through [`SecretStore`](lib/secrets/secret_store.dart); SQLite holds non-secret configuration and operational data.
- **Drift as the hub**: display **screen definitions** (`screen_definitions`), **configuration key–values** (`config_key_values`, including curator program settings and theme/ticker keys), alerts, blob metadata, RSS tables, and provider settings read/write through [`AppDatabase`](lib/persistence/database.dart). **Ticker marquee text is in-memory only** ([`MemoryTickerCuratedRepository`](lib/ticker/memory_ticker_curated_repository.dart)); REST exposes a read-only snapshot.

## Module map

High-level dependency direction (arrows read as “uses” or “writes through”):

```mermaid
flowchart TB
  subgraph composition["Composition root (main.dart)"]
    Main[main / WaddleRoot / WaddleHome]
  end

  subgraph ui["Presentation"]
    Shell[DashboardShell]
    Overlay[AlertOverlayHost]
    Strip[TickerMarquee]
    Rotator[ScreenRotator]
    Chrome[WindowChromeController]
  end

  subgraph async_loops["Background-style async loops"]
    Engine[DataCollectionEngine]
    Curator[DefaultDashboardCurator]
  end

  subgraph api["Embedded HTTP"]
    Server[LocalRestServer + Shelf]
    Handlers[buildRootHandler / routers]
  end

  subgraph ports["Ports (abstract)"]
    IData[IDataProvider]
    DWC[DataWriteContext]
    AR[AlertRepository]
    TCR[TickerCuratedRepository]
    DDA[DashboardDataAccess]
    BS[BlobStore]
    SS[SecretStore]
    Keys[DeploymentApiKeySource]
  end

  subgraph adapters["Adapters (concrete)"]
    Stub[StubDataProvider]
    DAR[DriftAlertRepository]
    MTCR[MemoryTickerCuratedRepository]
    DDAD[DriftDashboardDataAccess]
    FSB[FileSystemBlobStore]
    FSS[FlutterSecureSecretStore]
    FKS[FileDeploymentApiKeySource]
    DB[(AppDatabase / SQLite)]
  end

  Main --> Shell
  Main --> Overlay
  Main --> Strip
  Main --> Rotator
  Main --> Chrome
  Main --> Engine
  Main --> Curator
  Main --> Server

  Shell --> DDA
  Overlay --> AR
  Strip --> TCR

  Server --> Handlers
  Handlers --> DB
  Handlers --> TCR
  Handlers --> AR
  Handlers --> Keys

  Engine --> IData
  Engine --> DWC
  Stub -. implements .-> IData
  Stub --> DWC
  DWC --> DB
  DWC --> BS
  DWC --> SS

  Curator --> TCR
  MTCR -. implements .-> TCR
  DAR -. implements .-> AR
  DDAD -. implements .-> DDA
  FSB -. implements .-> BS
  FSS -. implements .-> SS
  FKS -. implements .-> Keys
  MTCR -. in-memory .-> TCR
  DAR --> DB
  DDAD --> DB
  Engine --> Curator
```

## Composition and lifecycle

At startup, `main()` wires concrete implementations, starts long-running `Future`s with `unawaited`, then calls `runApp`. On `WaddleHome` dispose, the data engine stops, the Shelf server closes, and the database closes.

## Sequence: application startup

From [`lib/main.dart`](lib/main.dart): filesystem prep → database + seed → secrets and data context → **curator initial `refresh()`** → collection engine (with **`onCycleComplete: curator.refresh`**) → alerts + REST (`MemoryTickerCuratedRepository` for **`GET /v1/ticker/items`**) → dashboard access + **`TickerMarquee`** + **`ScreenRotator`** → window policy → `runApp`.

```mermaid
sequenceDiagram
  autonumber
  participant M as main()
  participant FS as OS filesystem
  participant DB as AppDatabase
  participant Seed as ensureInitialSeed
  participant SS as FlutterSecureSecretStore
  participant Res as ProviderConfigResolver
  participant Blob as FileSystemBlobStore
  participant Ctx as DataWriteContextImpl
  participant Eng as DataCollectionEngine
  participant AR as DriftAlertRepository
  participant HTTP as LocalRestServer
  participant DDA as DriftDashboardDataAccess
  participant MTCR as MemoryTickerCuratedRepository
  participant Cur as DefaultDashboardCurator
  participant Win as WindowChromeController
  participant UI as runApp WaddleRoot

  M->>FS: getApplicationSupportDirectory
  M->>FS: ensure waddle_api.key, media/
  M->>DB: open SQLite executor
  M->>Seed: migrations + initial rows
  M->>SS: construct
  M->>Res: ProviderConfigResolver(db, secrets)
  M->>Blob: FileSystemBlobStore(mediaDir)
  M->>Ctx: DataWriteContextImpl(db, blobs, secrets, resolve)
  M->>MTCR: MemoryTickerCuratedRepository()
  M->>Cur: DefaultDashboardCurator(read, tickerStore, clock)
  M->>Cur: await refresh() initial curated rows
  M->>Eng: DataCollectionEngine(..., onCycleComplete: Cur.refresh)
  M-->>Eng: unawaited start() loop
  M->>AR: DriftAlertRepository(db)
  M->>HTTP: bind Shelf handler (db, alerts, key file)
  M->>DDA: DriftDashboardDataAccess(db)
  M->>Win: initialize + applyStartupPolicy
  M->>UI: WaddleRoot(tickerCurated: MTCR, ...)
```

## Sequence: data collection cycle

[`DataCollectionEngine`](lib/data/engine/data_collection_engine.dart) walks the configured [`IDataProvider`](lib/data/data_provider.dart) list in order, awaits each `collect`, then sleeps `idleBetweenCycles` (shorter in debug builds). Providers must not run overlapping collects; the engine enforces one in flight.

```mermaid
sequenceDiagram
  participant Eng as DataCollectionEngine
  participant P as IDataProvider e.g. StubDataProvider
  participant Ctx as DataWriteContext
  participant DB as AppDatabase
  participant Blob as BlobStore
  participant Sec as SecretStore
  participant Res as resolveConfig closure

  loop each cycle
    Eng->>P: collect(ctx)
    P->>DB: read/write rows as needed
    P->>Blob: putBytes / paths
    opt provider needs tokens or URLs
      P->>Ctx: resolveConfig(providerId)
      Ctx->>DB: provider_settings
      Ctx->>Sec: read secret key
      Ctx-->>P: ProviderRuntimeConfig
    end
    P-->>Eng: complete
    Eng->>Eng: onCycleComplete() e.g. DefaultDashboardCurator.refresh
    Eng->>Eng: sleeper.sleep(idleBetweenCycles)
  end
```

The stub provider demonstrates the path: it upserts [`config_key_values`](lib/data/stub_data_provider.dart) (feeds the header title stream) and registers a small blob plus [`blob_metadata`](lib/data/stub_data_provider.dart).

## Sequence: REST alert to on-screen overlay

Shelf runs the [`buildRootHandler`](lib/api/local_rest_server.dart) pipeline: public `GET /v1/health`, then API-key middleware and the protected router. [`DriftAlertRepository.insertAlert`](lib/alerts/drift_alert_repository.dart) inserts a row; Drift’s `watch()` drives [`AlertOverlayHost`](lib/alerts/alert_overlay_host.dart), which uses [`ActiveAlertSelector`](lib/alerts/active_alert_selector.dart) to pick the visible alert by priority, recency, and expiry.

```mermaid
sequenceDiagram
  participant Ext as External client curl
  participant S as HttpServer Shelf
  participant Auth as apiKeyAuth middleware
  participant Keys as FileDeploymentApiKeySource
  participant R as Shelf Router
  participant AR as DriftAlertRepository
  participant DB as SQLite Drift streams
  participant Host as AlertOverlayHost StreamBuilder
  participant Op as TV operator

  Ext->>S: POST /v1/alerts + X-Api-Key
  S->>Auth: pipeline
  Auth->>Keys: load expected key
  Keys-->>Auth: key material
  Auth->>R: forward if valid
  R->>AR: insertAlert(title, body, ...)
  AR->>DB: INSERT dashboard_alerts
  DB-->>AR: new id
  R-->>Ext: 200 JSON id
  DB-->>Host: watch emits rows
  Host->>Host: ActiveAlertSelector.pick
  Host->>Op: overlay Stack if alert non-null
```

`GET` routes for providers, **screen definitions** (`/v1/screens`), **ticker items** (`/v1/ticker/items`, in-process snapshot from `MemoryTickerCuratedRepository`), and alerts follow the same auth middleware; screen and alert rows are read with Drift in [`local_rest_server.dart`](lib/api/local_rest_server.dart).

## Sequence: curated marquee ticker

Providers persist **domain** rows (for example [`config_key_values`](lib/persistence/tables.dart) keys such as `ticker.marquee.*`). [`DefaultDashboardCurator`](lib/curator/default_dashboard_curator.dart) reads them via [`DriftCuratorReadPort`](lib/curator/drift_curator_read_port.dart), maps them through pure [`buildTickerItemsForMarquee`](lib/curator/ticker_curation.dart), and writes the ordered list to [`MemoryTickerCuratedRepository`](lib/ticker/memory_ticker_curated_repository.dart). [`TickerMarquee`](lib/ticker/ticker_marquee.dart) subscribes with `watchOrdered()` and scrolls horizontally at a fixed **pixels per second**. `GET /v1/ticker/items` uses the same repository’s `snapshot()`.

## Sequence: display screen programs

[`ScreenRotator`](lib/display/screen_rotator.dart) loads enabled rows from [`screen_definitions`](lib/persistence/tables.dart) and curator program keys in [`config_key_values`](lib/persistence/tables.dart) (`curator.program.*`), runs [`ScreenProgramCurator.buildProgram`](lib/curator/screen_program_curator.dart) (weighted picks biased by recent slide ids, random photo pools without duplicate assets in one program), then advances slides on a dwell timer with **exit left / enter right** transitions. When a program finishes, a new program is curated using the rolling history of shown screen ids.

```mermaid
sequenceDiagram
  participant Eng as DataCollectionEngine
  participant P as IDataProvider
  participant DB as AppDatabase
  participant Cur as DefaultDashboardCurator
  participant Rep as MemoryTickerCuratedRepository
  participant UI as TickerMarquee

  Eng->>P: collect(ctx)
  P->>DB: upsert config_key_values / facts
  Eng->>Cur: refresh() onCycleComplete
  Cur->>DB: SELECT config_key_values / RSS
  Cur->>Rep: replaceAll(TickerItem list)
  Rep-->>UI: watchOrdered emits
  UI->>UI: measure segment width, AnimationController linear scroll
```

## Related reading

- [`README.md`](README.md) — run modes, build output, REST bind address, Pi pointers.
- [`../../docs/pi/api.md`](../../docs/pi/api.md) — HTTP paths and headers.
- [`../../AGENTS.md`](../../AGENTS.md) — repo conventions for contributors.
