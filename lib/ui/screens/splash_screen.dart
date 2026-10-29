import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/art.dart';

/// The first screen, while the app opens its storage: the wordmark, the tagline, the rubble
/// with the record.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: PartizanColors.red,
    body: Stack(
      children: [
        // 1536×1024; the last 34 rows are sparse.
        const Positioned.fill(
          child: BottomArt(
            Art.splashDebris,
            aspect: 1536 / 1024,
            sunk: 34 / 1024,
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FittedBox(child: Logo(height: 120)),
                const SizedBox(height: 28),
                const SizedBox(width: 72, height: 24, child: LongArrow()),
                const SizedBox(height: 24),
                Text(
                  'СВОБОДНЫЙ\nИНТЕРНЕТ\nВСЕГДА\nС ТОБОЙ',
                  style: oswald(
                    15,
                    weight: 500,
                    color: PartizanColors.black,
                    spacing: 5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
