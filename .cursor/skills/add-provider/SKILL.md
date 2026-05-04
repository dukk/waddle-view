# Add IDataProvider

## Steps

1. Implement `IDataProvider` in `lib/data/providers/`.
2. Register in composition root; add unit tests with fake `DataWriteContext`.
3. Ensure `collect` does not overlap (engine contract).

## Tests

- `flutter test test/data/`
