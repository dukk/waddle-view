import 'package:flutter/widgets.dart';

/// Named slot in the shell layout (OCP: add slots without rewriting shell).
@immutable
class DashboardSlotDescriptor {
  const DashboardSlotDescriptor({required this.id, required this.label});

  final String id;
  final String label;
}
