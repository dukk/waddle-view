import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'news_config.dart';

/// Article-link QR with white chrome for phone cameras.
Widget newsArticleLinkQr({
  required ThemeData theme,
  required double scale,
  required String link,
  required double qrLogical,
  Key? qrKey,
  EdgeInsetsGeometry? outerPadding,
}) {
  final url = link.trim();
  if (url.isEmpty) {
    return const SizedBox.shrink();
  }
  final s = scale;
  return Padding(
    padding: outerPadding ?? EdgeInsets.all(6 * s),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8 * s),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(8 * s),
        child: QrImageView(
          key: qrKey ?? const Key('rss_article_link_qr'),
          data: url,
          version: QrVersions.auto,
          size: qrLogical * s,
          padding: EdgeInsets.all(4 * s),
          gapless: true,
        ),
      ),
    ),
  );
}

/// Fills a clipped panel with [imageBytes] and optional image-overlay QR.
Widget newsImageWithOptionalQrOverlay({
  required ThemeData theme,
  required double scale,
  required Uint8List? imageBytes,
  required BoxFit imageFit,
  required Alignment imageAlignment,
  required String qrMode,
  required String link,
  required double qrLogical,
  required Widget Function({required bool blobReadFailed}) placeholder,
  bool blobReadFailed = false,
  double overlayInset = 8,
  Key? qrKey,
}) {
  final overlay = newsQrImageOverlayAlignment(qrMode);
  final showOverlayQr =
      overlay != null && newsQrVisible(qrMode) && link.trim().isNotEmpty;

  Widget imageChild;
  if (imageBytes != null) {
    imageChild = Image.memory(
      imageBytes,
      fit: imageFit,
      alignment: imageAlignment,
      gaplessPlayback: true,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) =>
          placeholder(blobReadFailed: false),
    );
  } else {
    imageChild = placeholder(blobReadFailed: blobReadFailed);
  }

  if (!showOverlayQr) {
    return imageChild;
  }

  final inset = overlayInset * scale;
  return Stack(
    fit: StackFit.expand,
    children: [
      imageChild,
      Positioned(
        left: inset,
        right: inset,
        top: inset,
        bottom: inset,
        child: Align(
          alignment: overlay,
          child: newsArticleLinkQr(
            theme: theme,
            scale: scale,
            link: link,
            qrLogical: qrLogical,
            qrKey: qrKey,
            outerPadding: EdgeInsets.zero,
          ),
        ),
      ),
    ],
  );
}
