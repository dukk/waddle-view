# waddle_view architecture

This document describes how the TV dashboard is structured at runtime and how major subsystems interact. The **composition root** is [`lib/main.dart`](lib/main.dart); feature code is grouped by responsibility under [`lib/`](lib/).

## Design goals

- **Single process**: Flutter UI, background async loops, and the embedded HTTP server share one isolate unless you add isolates later.
- **Ports and adapters**: abstract boundaries (`IDataProvider`, `DataWriteContext`, `AlertRepository`, `TickerScheduleRepository`, `BlobStore`, `SecretStore`, `WindowChromeController`) with Drift/filesystem/Linux implementations.
- **No secrets in SQLite**: provider tokens and similar values go through [`SecretStore`](lib/secrets/secret_store.dart); SQLite holds non-secret configuration and operational data.
- **Drift as the hub**: ticker schedule, dashboard key–value fields, alerts, blob metadata, and provider settings all read/write through [`AppDatabase`](lib/persistence/database.dart).

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
    Strip[TickerStrip]
    Chrome[WindowChromeController]
  end

  subgraph async_loops["Background-style async loops"]
    Engine[DataCollectionEngine]
    Ticker[TickerRotationController]
  end

  subgraph api["Embedded HTTP"]
    Server[LocalRestServer + Shelf]
    Handlers[buildRootHandler / routers]
  end

  subgraph ports["Ports (abstract)"]
    IData[IDataProvider]
    DWC[DataWriteContext]
    AR[AlertRepository]
    TSR[TickerScheduleRepository]
    DDA[DashboardDataAccess]
    BS[BlobStore]
    SS[SecretStore]
    Keys[DeploymentApiKeySource]
  end

  subgraph adapters["Adapters (concrete)"]
    Stub[StubDataProvider]
    DAR[DriftAlertRepository]
    DTR[DriftTickerScheduleRepository]
    DDAD[DriftDashboardDataAccess]
    FSB[FileSystemBlobStore]
    FSS[FlutterSecureSecretStore]
    FKS[FileDeploymentApiKeySource]
    DB[(AppDatabase / SQLite)]
  end

  Main --> Shell
  Main --> Overlay
  Main --> Strip
  Main --> Chrome
  Main --> Engine
  Main --> Ticker
  Main --> Server

  Shell --> DDA
  Overlay --> AR
  Strip --> Ticker

  Server --> Handlers
  Handlers --> DB
  Handlers --> AR
  Handlers --> Keys

  Engine --> IData
  Engine --> DWC
  Stub -. implements .-> IData
  Stub --> DWC
  DWC --> DB
  DWC --> BS
  DWC --> SS

  Ticker --> TSR
  DTR -. implements .-> TSR
  DAR -. implements .-> AR
  DDAD -. implements .-> DDA
  FSB -. implements .-> BS
  FSS -. implements .-> SS
  FKS -. implements .-> Keys
  DTR --> DB
  DAR --> DB
  DDAD --> DB
```

## Composition and lifecycle

At startup, `main()` wires concrete implementations, starts long-running `Future`s with `unawaited`, then calls `runApp`. On `WaddleHome` dispose, the data engine and ticker stop, the Shelf server closes, and the database closes.

## Sequence: application startup

From [`lib/main.dart`](lib/main.dart): filesystem prep → database + seed → secrets and data context → collection engine → alerts + REST → dashboard access + ticker → window policy → `runApp`.

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
  participant TRep as DriftTickerScheduleRepository
  participant Tic as TickerRotationController
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
  M->>Eng: DataCollectionEngine(providers, ctx, ...)
  M-->>Eng: unawaited start() loop
  M->>AR: DriftAlertRepository(db)
  M->>HTTP: bind Shelf handler (db, alerts, key file)
  M->>DDA: DriftDashboardDataAccess(db)
  M->>TRep: DriftTickerScheduleRepository(db)
  M->>Tic: TickerRotationController(repo, evaluator, clock, sleeper)
  M-->>Tic: unawaited start() loop
  M->>Win: initialize + applyStartupPolicy
  M->>UI: WaddleRoot(...)
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
    Eng->>Eng: sleeper.sleep(idleBetweenCycles)
  end
```

The stub provider demonstrates the path: it upserts [`dashboard_kv`](lib/data/stub_data_provider.dart) (feeds the header title stream) and registers a small blob plus [`blob_metadata`](lib/data/stub_data_provider.dart).

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

`GET` routes for providers, ticker screens, and alerts follow the same auth middleware and read directly from `AppDatabase` via generated Drift APIs in [`local_rest_server.dart`](lib/api/local_rest_server.dart).

## Sequence: ticker rotation and strip

[`TickerRotationController`](lib/ticker/ticker_rotation_controller.dart) loads eligible screens from the repository, applies [`TickerConditionEvaluator`](lib/ticker/ticker_condition_evaluator.dart), updates `currentLabel`, calls `notifyListeners()`, dwells for `dwellMs`, then persists show telemetry via `onShowStart` / `onShowEnd`. [`TickerStrip`](lib/ticker/ticker_strip.dart) is an `AnimatedBuilder` on that controller.

```mermaid
sequenceDiagram
  participant Tic as TickerRotationController
  participant Rep as DriftTickerScheduleRepository
  participant DB as AppDatabase
  participant Ev as TickerConditionEvaluator
  participant UI as TickerStrip AnimatedBuilder

  loop while running
    Tic->>Rep: loadBundles()
    Rep->>DB: SELECT ticker screens, groups, conditions, runtimes
    Rep-->>Tic: sorted bundles
    Tic->>Ev: isEligible(now, bundle) per screen
    Ev-->>Tic: filtered list
    alt no eligible screens
      Tic->>Tic: sleep 1s
    else show screen
      Tic->>Tic: notifyListeners currentLabel
      UI-->>Tic: rebuild frame
      Tic->>Rep: onShowStart(screenId, now)
      Rep->>DB: upsert ticker_screen_runtimes
      Tic->>Tic: sleep(dwellMs)
      Tic->>Rep: onShowEnd(screenId, now)
      Rep->>DB: upsert runtimes + day counters
    end
  end
```

## Related reading

- [`README.md`](README.md) — run modes, build output, REST bind address, Pi pointers.
- [`../../docs/pi/api.md`](../../docs/pi/api.md) — HTTP paths and headers.
- [`../../AGENTS.md`](../../AGENTS.md) — repo conventions for contributors.
