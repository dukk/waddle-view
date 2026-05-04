import 'data_write_context.dart';

abstract class IDataProvider {
  String get id;

  Future<void> collect(DataWriteContext ctx);
}
