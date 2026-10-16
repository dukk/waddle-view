import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Algorithm version stored in [cropHintsJson] for backfill freshness.
const int kBlobCropHintsVersion = 1;

/// Optional provider-side hints that bias or short-circuit analysis.
final class BlobCropProviderHints {
  const BlobCropProviderHints({
    this.altText,
    this.preferFace = false,
    this.skipAnalyze = false,
    this.pixelWidth,
    this.pixelHeight,
  });

  final String? altText;
  final bool preferFace;
  final bool skipAnalyze;
  final int? pixelWidth;
  final int? pixelHeight;
}

/// Result of smart-crop / face-text heuristics for a decoded image.
final class BlobCropAnalysis {
  const BlobCropAnalysis({
    required this.pixelWidth,
    required this.pixelHeight,
    required this.focalX,
    required this.focalY,
    required this.hasFace,
    required this.hasText,
    required this.cropHintsJson,
  });

  final int pixelWidth;
  final int pixelHeight;
  final double focalX;
  final double focalY;
  final bool hasFace;
  final bool hasText;
  final String cropHintsJson;
}

/// Analyzes image [bytes] for smart-crop focal point and face/text hints.
///
/// Returns null when decode fails or [BlobCropProviderHints.skipAnalyze] is set
/// without known pixels.
BlobCropAnalysis? analyzeBlobCropMetadata(
  Uint8List bytes, {
  BlobCropProviderHints hints = const BlobCropProviderHints(),
}) {
  if (hints.skipAnalyze) {
    final w = hints.pixelWidth;
    final h = hints.pixelHeight;
    if (w == null || h == null || w <= 0 || h <= 0) {
      return null;
    }
    return BlobCropAnalysis(
      pixelWidth: w,
      pixelHeight: h,
      focalX: 0.5,
      focalY: hints.preferFace ? 0.35 : 0.5,
      hasFace: hints.preferFace,
      hasText: _altSuggestsText(hints.altText),
      cropHintsJson: _encodeHints(
        source: 'api',
        faceCount: hints.preferFace ? 1 : 0,
        faceCx: hints.preferFace ? 0.5 : null,
        faceCy: hints.preferFace ? 0.35 : null,
        textDensity: _altSuggestsText(hints.altText) ? 0.2 : 0,
        energyCx: 0.5,
        energyCy: hints.preferFace ? 0.35 : 0.5,
      ),
    );
  }

  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
    return null;
  }

  final fullW = decoded.width;
  final fullH = decoded.height;
  final analysis = _downscaleForAnalysis(decoded, maxSide: 160);

  final skin = _skinMap(analysis);
  final face = _largestSkinBlob(skin, analysis.width, analysis.height);
  final textDensity = _textLikeDensity(analysis);
  final energy = _energyCentroid(analysis, skinBoost: skin);

  final altFace = _altSuggestsFace(hints.altText) || hints.preferFace;
  final altText = _altSuggestsText(hints.altText);
  final hasFace = face != null || altFace;
  final hasText = textDensity >= 0.08 || altText;

  double focalX;
  double focalY;
  String source = 'analyze';

  if (face != null) {
    focalX = face.cx;
    focalY = (face.cy - 0.05).clamp(0.0, 1.0);
  } else if (altFace) {
    focalX = 0.5;
    focalY = 0.35;
    source = hints.altText != null ? 'merged' : 'api';
  } else if (hasText) {
    focalX = energy.cx;
    focalY = energy.cy;
  } else if (energy.strength >= 0.12) {
    focalX = energy.cx;
    focalY = energy.cy;
  } else {
    focalX = 0.5;
    focalY = 0.35;
  }

  if (hints.pixelWidth != null && hints.pixelHeight != null) {
    // Prefer API pixel sizes when provided.
  }

  return BlobCropAnalysis(
    pixelWidth: hints.pixelWidth ?? fullW,
    pixelHeight: hints.pixelHeight ?? fullH,
    focalX: focalX.clamp(0.0, 1.0),
    focalY: focalY.clamp(0.0, 1.0),
    hasFace: hasFace,
    hasText: hasText,
    cropHintsJson: _encodeHints(
      source: source,
      faceCount: face != null ? 1 : (altFace ? 1 : 0),
      faceCx: face?.cx ?? (altFace ? 0.5 : null),
      faceCy: face?.cy ?? (altFace ? 0.35 : null),
      textDensity: textDensity,
      energyCx: energy.cx,
      energyCy: energy.cy,
    ),
  );
}

img.Image _downscaleForAnalysis(img.Image src, {required int maxSide}) {
  final longest = math.max(src.width, src.height);
  if (longest <= maxSide) {
    return src;
  }
  final scale = maxSide / longest;
  final w = math.max(1, (src.width * scale).round());
  final h = math.max(1, (src.height * scale).round());
  return img.copyResize(
    src,
    width: w,
    height: h,
    interpolation: img.Interpolation.average,
  );
}

bool _altSuggestsFace(String? alt) {
  if (alt == null || alt.trim().isEmpty) {
    return false;
  }
  final lower = alt.toLowerCase();
  const keys = [
    'person',
    'people',
    'man',
    'woman',
    'face',
    'portrait',
    'child',
    'boy',
    'girl',
    'crowd',
  ];
  for (final k in keys) {
    if (lower.contains(k)) {
      return true;
    }
  }
  return false;
}

bool _altSuggestsText(String? alt) {
  if (alt == null || alt.trim().isEmpty) {
    return false;
  }
  final lower = alt.toLowerCase();
  const keys = [
    'text',
    'sign',
    'caption',
    'headline',
    'logo',
    'banner',
    'chart',
  ];
  for (final k in keys) {
    if (lower.contains(k)) {
      return true;
    }
  }
  return false;
}

String _encodeHints({
  required String source,
  required int faceCount,
  double? faceCx,
  double? faceCy,
  required double textDensity,
  required double energyCx,
  required double energyCy,
}) {
  final map = <String, Object?>{
    'faceCount': faceCount,
    'textDensity': double.parse(textDensity.toStringAsFixed(4)),
    'energyCx': double.parse(energyCx.toStringAsFixed(4)),
    'energyCy': double.parse(energyCy.toStringAsFixed(4)),
    'source': source,
    'version': kBlobCropHintsVersion,
  };
  if (faceCx != null) {
    map['faceCx'] = double.parse(faceCx.toStringAsFixed(4));
  }
  if (faceCy != null) {
    map['faceCy'] = double.parse(faceCy.toStringAsFixed(4));
  }
  return jsonEncode(map);
}

List<bool> _skinMap(img.Image image) {
  final out = List<bool>.filled(image.width * image.height, false);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();
      out[y * image.width + x] = _isSkinTone(r, g, b);
    }
  }
  return out;
}

bool _isSkinTone(int r, int g, int b) {
  // Classic RGB skin heuristic (loose, Pi-friendly).
  return r > 95 &&
      g > 40 &&
      b > 20 &&
      r > g &&
      r > b &&
      (r - g).abs() > 15 &&
      r - b > 15;
}

final class _FaceBlob {
  const _FaceBlob({required this.cx, required this.cy, required this.area});
  final double cx;
  final double cy;
  final int area;
}

_FaceBlob? _largestSkinBlob(List<bool> skin, int w, int h) {
  final visited = List<bool>.filled(skin.length, false);
  _FaceBlob? best;
  final minArea = math.max(12, (w * h * 0.01).round());

  for (var i = 0; i < skin.length; i++) {
    if (!skin[i] || visited[i]) {
      continue;
    }
    var area = 0;
    var sumX = 0;
    var sumY = 0;
    final stack = <int>[i];
    visited[i] = true;
    while (stack.isNotEmpty) {
      final idx = stack.removeLast();
      final x = idx % w;
      final y = idx ~/ w;
      area++;
      sumX += x;
      sumY += y;
      final neighbors = <int>[
        if (x > 0) idx - 1,
        if (x + 1 < w) idx + 1,
        if (y > 0) idx - w,
        if (y + 1 < h) idx + w,
      ];
      for (final n in neighbors) {
        if (!visited[n] && skin[n]) {
          visited[n] = true;
          stack.add(n);
        }
      }
    }
    if (area < minArea) {
      continue;
    }
    final cx = (sumX / area) / (w - 1).clamp(1, w);
    final cy = (sumY / area) / (h - 1).clamp(1, h);
    // Prefer upper-half blobs (heads).
    final score = area * (1.2 - cy);
    final bestScore = best == null ? -1.0 : best.area * (1.2 - best.cy);
    if (score > bestScore) {
      best = _FaceBlob(
        cx: cx.clamp(0.0, 1.0),
        cy: cy.clamp(0.0, 1.0),
        area: area,
      );
    }
  }
  return best;
}

double _textLikeDensity(img.Image image) {
  // High local luminance contrast in a grid suggests captions / graphics.
  var strong = 0;
  var cells = 0;
  const step = 4;
  for (var y = 1; y < image.height - 1; y += step) {
    for (var x = 1; x < image.width - 1; x += step) {
      cells++;
      final c = _luma(image.getPixel(x, y));
      final l = _luma(image.getPixel(x - 1, y));
      final r = _luma(image.getPixel(x + 1, y));
      final u = _luma(image.getPixel(x, y - 1));
      final d = _luma(image.getPixel(x, y + 1));
      final grad =
          (c - l).abs() + (c - r).abs() + (c - u).abs() + (c - d).abs();
      if (grad > 140) {
        strong++;
      }
    }
  }
  if (cells == 0) {
    return 0;
  }
  return strong / cells;
}

final class _EnergyCentroid {
  const _EnergyCentroid({
    required this.cx,
    required this.cy,
    required this.strength,
  });
  final double cx;
  final double cy;
  final double strength;
}

_EnergyCentroid _energyCentroid(
  img.Image image, {
  required List<bool> skinBoost,
}) {
  var sumW = 0.0;
  var sumX = 0.0;
  var sumY = 0.0;
  final w = image.width;
  final h = image.height;
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final luma = _luma(image.getPixel(x, y));
      final gx =
          _luma(image.getPixel(x + 1, y)) - _luma(image.getPixel(x - 1, y));
      final gy =
          _luma(image.getPixel(x, y + 1)) - _luma(image.getPixel(x, y - 1));
      // Edge energy plus brightness so large bright regions pull the focal.
      var e = math.sqrt(gx * gx + gy * gy) + luma * 0.35;
      if (skinBoost[y * w + x]) {
        e *= 2.2;
      }
      // Mild upper bias for news portraits.
      e *= 1.0 + 0.35 * (1.0 - y / (h - 1));
      sumW += e;
      sumX += e * x;
      sumY += e * y;
    }
  }
  if (sumW < 1e-6) {
    return const _EnergyCentroid(cx: 0.5, cy: 0.35, strength: 0);
  }
  final samples = (w - 2) * (h - 2);
  final meanEnergy = samples > 0 ? sumW / samples : 0.0;
  return _EnergyCentroid(
    cx: ((sumX / sumW) / (w - 1).clamp(1, w)).clamp(0.0, 1.0),
    cy: ((sumY / sumW) / (h - 1).clamp(1, h)).clamp(0.0, 1.0),
    strength: (meanEnergy / 80.0).clamp(0.0, 1.0),
  );
}

double _luma(img.Pixel p) => 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
