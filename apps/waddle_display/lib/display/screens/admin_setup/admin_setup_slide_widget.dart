import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import '../../dashboard_viewport_scope.dart';

class AdminSetupSlideWidget extends StatelessWidget {
  const AdminSetupSlideWidget({
    super.key,
    required this.db,
    required this.adminBaseUrl,
    required this.setupPasswordFile,
    required this.spec,
    required this.theme,
  });

  final AppDatabase db;
  final String adminBaseUrl;
  final File setupPasswordFile;
  final ParsedWidgetSpec spec;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final loginUrl = '$adminBaseUrl/admin/login';
    return StreamBuilder<List<ConfigKeyValue>>(
      stream: db.select(db.configKeyValues).watch(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <ConfigKeyValue>[];
        final kv = {for (final row in rows) row.key: row.value};
        final bootstrapPending = kv[kAdminBootstrapDoneKvKey] == '0';
        final headline =
            spec.config['headline'] as String? ?? 'Complete device setup';
        final showLoginQr = spec.config['showLoginQr'] != false;
        final s = DashboardViewportScope.scaleOf(context);
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                headline,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12 * s),
              Text(
                '1) Scan QR from your phone\n'
                '2) Sign in with install password\n'
                '3) Change password immediately',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16 * s),
              SelectableText(
                loginUrl,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16 * s),
              if (showLoginQr)
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(12 * s),
                  child: QrImageView(
                    data: loginUrl,
                    size: 220 * s,
                    padding: EdgeInsets.all(4 * s),
                  ),
                )
              else
                Text(
                  '(QR hidden)',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              if (bootstrapPending) ...[
                SizedBox(height: 16 * s),
                _BootstrapPasswordView(
                  setupPasswordFile: setupPasswordFile,
                  theme: theme,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BootstrapPasswordView extends StatefulWidget {
  const _BootstrapPasswordView({
    required this.setupPasswordFile,
    required this.theme,
  });

  final File setupPasswordFile;
  final ThemeData theme;

  @override
  State<_BootstrapPasswordView> createState() => _BootstrapPasswordViewState();
}

class _BootstrapPasswordViewState extends State<_BootstrapPasswordView> {
  String? _password;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await widget.setupPasswordFile.readAsString();
      if (!mounted) {
        return;
      }
      setState(() {
        _password = raw.trim();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _password = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = DashboardViewportScope.scaleOf(context);
    return Column(
      children: [
        Text(
          'Install password (change after login):',
          style: widget.theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8 * s),
        SelectableText(
          (_password == null || _password!.isEmpty) ? 'Unavailable' : _password!,
          style: widget.theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
