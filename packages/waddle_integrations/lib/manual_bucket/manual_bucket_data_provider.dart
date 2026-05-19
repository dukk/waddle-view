import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/persistence/tables.dart';

/// Collectors for operator-managed bucket integrations (no external fetch).
class ManualBucketDataProvider implements IDataProvider {
  const ManualBucketDataProvider(this._integrationType);

  final String _integrationType;

  @override
  String get id => _integrationType;

  @override
  Future<void> collect(DataWriteContext ctx) async {
    ctx.diagnostics.provider('$id: manual bucket (no collect)');
  }
}

const photoBucketDataProvider =
    ManualBucketDataProvider(kPhotoBucketIntegrationType);

const videoBucketDataProvider =
    ManualBucketDataProvider(kVideoBucketIntegrationType);

const calendarBucketDataProvider =
    ManualBucketDataProvider(kCalendarBucketIntegrationType);

const jokeBucketDataProvider =
    ManualBucketDataProvider(kJokeBucketIntegrationType);

const triviaBucketDataProvider =
    ManualBucketDataProvider(kTriviaBucketIntegrationType);
