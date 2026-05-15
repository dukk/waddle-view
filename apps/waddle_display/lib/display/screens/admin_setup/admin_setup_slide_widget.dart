import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:waddle_shared/layout/screen_layout_parse.dart';
import '../../dashboard_viewport_scope.dart';

class AdminSetupSlideWidget extends StatelessWidget {
  const AdminSetupSlideWidget({
    super.key,
    required this.adminBaseUrl,
    required this.instanceIdFile,
    required this.spec,
    required this.theme,
  });

  final String adminBaseUrl;
  final File instanceIdFile;
  final ParsedWidgetSpec spec;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final headline =
        spec.config['headline'] as String? ?? 'Operator setup';
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
            '1) Open waddle_controller and add this display URL\n'
            '2) Sign in as user display with the instance id below\n'
            '3) Create a named operator account (disables bootstrap login)',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16 * s),
          SelectableText(
            adminBaseUrl,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16 * s),
          if (showLoginQr)
            Container(
              color: Colors.white,
              padding: EdgeInsets.all(12 * s),
              child: QrImageView(
                data: adminBaseUrl,
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
          SizedBox(height: 16 * s),
          _InstanceIdView(
            instanceIdFile: instanceIdFile,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _InstanceIdView extends StatefulWidget {
  const _InstanceIdView({
    required this.instanceIdFile,
    required this.theme,
  });

  final File instanceIdFile;
  final ThemeData theme;

  @override
  State<_InstanceIdView> createState() => _InstanceIdViewState();
}

class _InstanceIdViewState extends State<_InstanceIdView> {
  String? _instanceId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await widget.instanceIdFile.readAsString();
      if (!mounted) {
        return;
      }
      setState(() {
        _instanceId = raw.trim();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _instanceId = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = DashboardViewportScope.scaleOf(context);
    return Column(
      children: [
        Text(
          'Instance id (bootstrap user display password):',
          style: widget.theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8 * s),
        SelectableText(
          (_instanceId == null || _instanceId!.isEmpty)
              ? 'Unavailable'
              : _instanceId!,
          style: widget.theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
