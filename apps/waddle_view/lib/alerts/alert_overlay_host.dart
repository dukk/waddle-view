import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../clock.dart';
import '../persistence/database.dart';
import 'alert_repository.dart';

/// Dimmed overlay for the highest-priority active alert.
class AlertOverlayHost extends StatelessWidget {
  const AlertOverlayHost({
    super.key,
    required this.repository,
    required this.clock,
    required this.child,
  });

  final AlertRepository repository;
  final Clock clock;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DashboardAlert?>(
      stream: repository.watchActive(clock),
      builder: (context, snap) {
        final alert = snap.data;
        return Stack(
          children: [
            child,
            if (alert != null)
              Positioned.fill(
                child: Material(
                  color: Colors.black54,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Card(
                        color: Theme.of(context).colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alert.title,
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                alert.body,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              if ((alert.qrPayload ?? '').isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Center(
                                  child: QrImageView(
                                    data: alert.qrPayload!,
                                    size: 180,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
