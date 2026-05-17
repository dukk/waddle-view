import '../persistence/database.dart';
import 'adoption_allowed_roles.dart';

/// Whether any unauthenticated adoption challenge requests are accepted.
///
/// Prefer [isAdoptionRoleAllowed] when the requested role is known.
Future<bool> readAdoptionAllowNewRequests(AppDatabase db) async {
  final allowed = await readAdoptionAllowedRoles(db);
  return allowed.isNotEmpty;
}
