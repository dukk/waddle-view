import 'dart:typed_data';

import 'package:flutter/material.dart';

/// In-memory image for display slides; decode failures render [errorWidget]
/// instead of throwing through the global fatal handler.
class DisplayMemoryImage extends StatelessWidget {
  const DisplayMemoryImage({
    super.key,
    required this.bytes,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorWidget = const SizedBox.shrink(),
  });

  final Uint8List bytes;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget errorWidget;

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      bytes,
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => errorWidget,
    );
  }
}
