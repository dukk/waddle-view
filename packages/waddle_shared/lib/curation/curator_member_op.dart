import 'package:waddle_shared/persistence/tables.dart';

/// One add/remove catalog membership operation on a curator configuration.
class CuratorMemberOp {
  const CuratorMemberOp({required this.entityId, required this.op});

  final String entityId;
  final String op;

  bool get isAdd => op == kCuratorMemberOpAdd;
}

/// Normalizes persisted or API member op strings.
String normalizeCuratorMemberOp(String? raw) {
  final v = raw?.trim().toLowerCase();
  if (v == kCuratorMemberOpRemove) {
    return kCuratorMemberOpRemove;
  }
  return kCuratorMemberOpAdd;
}

bool isValidCuratorMemberOp(String op) => kCuratorMemberOps.contains(op);
