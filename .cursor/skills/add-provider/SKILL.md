# Add IDataProvider

## Steps

1. Implement `IDataProvider` in `lib/data/providers/<provider_id>/` (one folder per provider; shared helpers in `lib/data/providers/shared/` or `lib/data/providers/microsoft_graph/` as appropriate).
2. Register in composition root; add unit tests with fake `DataWriteContext`.
3. Ensure `collect` does not overlap (engine contract).

## Tests

- `flutter test test/data/`
