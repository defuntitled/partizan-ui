import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'art.dart';

/// Wears `child` with scratches: `noise.png` cut out of whatever it paints. Plain until the
/// noise is decoded, and plain if it cannot be.
class Distressed extends StatelessWidget {
  const Distressed({super.key, required this.child});

  final Widget child;

  static Future<ui.Image>? _noise;

  static Future<ui.Image> _load() => _noise ??= () async {
    final data = await rootBundle.load(Art.noise);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }();

  @override
  Widget build(BuildContext context) => FutureBuilder<ui.Image>(
    future: _load(),
    builder: (context, noise) {
      final image = noise.data;
      if (image == null) return child;
      return ShaderMask(
        blendMode: BlendMode.dstOut,
        shaderCallback: (bounds) {
          // One scratch texture across the child, whatever its size.
          final scale = bounds.width / image.width;
          return ImageShader(
            image,
            TileMode.repeated,
            TileMode.repeated,
            Float64List.fromList([
              scale, 0, 0, 0, //
              0, scale, 0, 0,
              0, 0, 1, 0,
              0, 0, 0, 1,
            ]),
          );
        },
        child: child,
      );
    },
  );
}

/// The state headline, worn with scratches.
class DistressedTitle extends StatelessWidget {
  const DistressedTitle(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Distressed(
    child: FittedBox(
      child: Text(text, key: const Key('vpn-state'), style: style),
    ),
  );
}
