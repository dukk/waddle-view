import 'package:drift/drift.dart';

import '../persistence/database.dart';
import '../persistence/tables.dart';
import 'password_hash.dart';
import 'role_permissions.dart';

/// Operator user row exposed to REST (no password fields).
class OperatorUserView {
  const OperatorUserView({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.isBootstrap,
    required this.disabled,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String id;
  final String username;
  final String displayName;
  final String role;
  final bool isBootstrap;
  final bool disabled;
  final int createdAtMs;
  final int updatedAtMs;

  Map<String, Object?> toJson() => {
    'id': id,
    'username': username,
    'display_name': displayName,
    'role': role,
    'is_bootstrap': isBootstrap,
    'disabled': disabled,
    'created_at_ms': createdAtMs,
    'updated_at_ms': updatedAtMs,
  };
}

class UserRepository {
  UserRepository(this._db);

  final AppDatabase _db;

  Future<int> countNamedUsers() async {
    final row = await _db.customSelect(
      'SELECT COUNT(*) AS n FROM users WHERE is_bootstrap = 0;',
    ).getSingle();
    return row.read<int>('n');
  }

  Future<bool> bootstrapLoginAllowed() async {
    return (await countNamedUsers()) == 0;
  }

  Future<User?> findByUsername(String username) async {
    final lower = username.trim().toLowerCase();
    return (_db.select(_db.users)
          ..where((t) => t.usernameLower.equals(lower)))
        .getSingleOrNull();
  }

  Future<User?> findById(String id) async {
    return (_db.select(_db.users)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  OperatorUserView toView(User row) => OperatorUserView(
    id: row.id,
    username: row.username,
    displayName: row.displayName,
    role: row.role,
    isBootstrap: row.isBootstrap,
    disabled: row.disabledAtMs != null,
    createdAtMs: row.createdAtMs,
    updatedAtMs: row.updatedAtMs,
  );

  Future<List<OperatorUserView>> listUsers() async {
    final rows = await (_db.select(_db.users)
          ..orderBy([(t) => OrderingTerm.asc(t.usernameLower)]))
        .get();
    return rows.map(toView).toList();
  }

  Future<User> ensureBootstrapUser({required String instanceIdPassword}) async {
    final existing = await findByUsername(kBootstrapUsername);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (existing != null) {
      final hash = hashPassword(instanceIdPassword);
      await (_db.update(_db.users)..where((t) => t.id.equals(existing.id)))
          .write(
        UsersCompanion(
          passwordHash: Value(hash),
          updatedAtMs: Value(now),
        ),
      );
      return (await findById(existing.id))!;
    }
    final id = 'user_bootstrap_display';
    await _db.into(_db.users).insert(
      UsersCompanion.insert(
        id: id,
        username: kBootstrapUsername,
        usernameLower: kBootstrapUsername,
        displayName: 'Display bootstrap',
        role: kUserRoleAdmin,
        passwordHash: Value(hashPassword(instanceIdPassword)),
        isBootstrap: const Value(true),
        createdAtMs: now,
        updatedAtMs: now,
      ),
    );
    return (await findById(id))!;
  }

  Future<void> disableBootstrapUser() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.users)
          ..where((t) => t.isBootstrap.equals(true)))
        .write(UsersCompanion(disabledAtMs: Value(now), updatedAtMs: Value(now)));
  }

  Future<User> createNamedUser({
    required String username,
    required String password,
    required String role,
    String? displayName,
  }) async {
    if (!isValidUserRole(role)) {
      throw ArgumentError('invalid role');
    }
    final trimmed = username.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == kBootstrapUsername) {
      throw ArgumentError('invalid username');
    }
    if (password.isEmpty) {
      throw ArgumentError('password required');
    }
    final existing = await findByUsername(trimmed);
    if (existing != null) {
      throw StateError('username_taken');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'user_${now}_${trimmed.hashCode.abs()}';
    await _db.into(_db.users).insert(
      UsersCompanion.insert(
        id: id,
        username: trimmed,
        usernameLower: trimmed.toLowerCase(),
        displayName: displayName?.trim().isNotEmpty == true
            ? displayName!.trim()
            : trimmed,
        role: role,
        passwordHash: Value(hashPassword(password)),
        isBootstrap: const Value(false),
        createdAtMs: now,
        updatedAtMs: now,
      ),
    );
    final hadNamed = await countNamedUsers();
    if (hadNamed == 1) {
      await disableBootstrapUser();
    }
    return (await findById(id))!;
  }

  Future<User?> updateUser({
    required String id,
    String? role,
    String? displayName,
    bool? disabled,
  }) async {
    final row = await findById(id);
    if (row == null) {
      return null;
    }
    if (row.isBootstrap) {
      throw StateError('cannot_modify_bootstrap');
    }
    if (role != null && !isValidUserRole(role)) {
      throw ArgumentError('invalid role');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.users)..where((t) => t.id.equals(id))).write(
      UsersCompanion(
        role: role != null ? Value(role) : const Value.absent(),
        displayName: displayName != null
            ? Value(displayName.trim().isEmpty ? row.username : displayName.trim())
            : const Value.absent(),
        disabledAtMs: disabled == null
            ? const Value.absent()
            : Value(disabled ? now : null),
        updatedAtMs: Value(now),
      ),
    );
    return findById(id);
  }

  Future<bool> setPassword({
    required String id,
    required String newPassword,
  }) async {
    if (newPassword.isEmpty) {
      return false;
    }
    final row = await findById(id);
    if (row == null) {
      return false;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.users)..where((t) => t.id.equals(id))).write(
      UsersCompanion(
        passwordHash: Value(hashPassword(newPassword)),
        updatedAtMs: Value(now),
      ),
    );
    return true;
  }

  Future<bool> verifyLoginPassword(User user, String password) async {
    if (user.disabledAtMs != null) {
      return false;
    }
    if (user.isBootstrap) {
      if (!(await bootstrapLoginAllowed())) {
        return false;
      }
    }
    final hash = user.passwordHash;
    if (hash == null || hash.isEmpty) {
      return false;
    }
    return verifyPassword(password, hash);
  }

  Future<String> createSession({
    required String userId,
    required String token,
    required int expiresAtMs,
    String? clientLabel,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.userSessions).insert(
      UserSessionsCompanion.insert(
        id: token,
        userId: userId,
        createdAtMs: now,
        expiresAtMs: expiresAtMs,
        clientLabel: Value(clientLabel),
      ),
    );
    return token;
  }

  Future<User?> userForSessionToken(String token) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final session = await (_db.select(_db.userSessions)
          ..where((t) => t.id.equals(token)))
        .getSingleOrNull();
    if (session == null || session.expiresAtMs <= now) {
      if (session != null) {
        await deleteSession(token);
      }
      return null;
    }
    final user = await findById(session.userId);
    if (user == null || user.disabledAtMs != null) {
      await deleteSession(token);
      return null;
    }
    if (user.isBootstrap && !(await bootstrapLoginAllowed())) {
      await deleteSession(token);
      return null;
    }
    return user;
  }

  Future<void> deleteSession(String token) async {
    await (_db.delete(_db.userSessions)..where((t) => t.id.equals(token))).go();
  }

  Future<void> deleteSessionsForUser(String userId) async {
    await (_db.delete(_db.userSessions)..where((t) => t.userId.equals(userId)))
        .go();
  }
}
