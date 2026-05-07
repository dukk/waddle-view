import 'package:flutter/material.dart';

class PexelsAttributionOverlay extends StatelessWidget {
  const PexelsAttributionOverlay({
    super.key,
    required this.photographerName,
    required this.photographerUrl,
    required this.altText,
    required this.theme,
    required this.scale,
    required this.onOpenUrl,
  });

  final String photographerName;
  final String photographerUrl;
  final String altText;
  final ThemeData theme;
  final double scale;
  final Future<void> Function(String url) onOpenUrl;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 10 * scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photographerName.isNotEmpty)
              Text(
                photographerName,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (photographerUrl.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 4 * scale),
                child: InkWell(
                  onTap: () => onOpenUrl(photographerUrl),
                  child: Text(
                    photographerUrl,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.lightBlueAccent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            if (altText.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 6 * scale),
                child: Text(
                  altText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
