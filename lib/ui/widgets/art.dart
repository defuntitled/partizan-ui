import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

/// Paths of the art in `assets/images/`.
abstract final class Art {
  static const logo = 'assets/images/partizan-logo.svg';
  static const arrow = 'assets/images/arrow.svg';
  static const world = 'assets/images/world.svg';
  static const recordFull = 'assets/images/full_plast.webp';
  static const recordBroken = 'assets/images/broken_plast.webp';
  static const connectBackground = 'assets/images/connect_bg.webp';
  static const debris = 'assets/images/trash_line_mainscreen.webp';
  static const splashDebris = 'assets/images/trash_line_loadscreen.webp';
  static const plate = 'assets/images/table.webp';
  static const noise = 'assets/images/noise.png';

  static const all = [
    logo,
    arrow,
    world,
    recordFull,
    recordBroken,
    connectBackground,
    debris,
    splashDebris,
    plate,
    noise,
  ];
}

/// The `partizan` wordmark in one color: sized by `height` or `width`, or filling its box.
class Logo extends StatelessWidget {
  const Logo({
    super.key,
    this.height,
    this.width,
    this.color = PartizanColors.black,
  });

  final double? height;
  final double? width;
  final Color color;

  /// Width / height of the wordmark's `viewBox` (2655 × 1015).
  static const aspect = 2655 / 1015;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    Art.logo,
    height: height,
    width: width,
    fit: BoxFit.contain,
    alignment: Alignment.centerLeft,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    semanticsLabel: 'partizan',
  );
}

/// The long hand-drawn arrow.
class LongArrow extends StatelessWidget {
  const LongArrow({super.key, this.color = PartizanColors.black});

  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    Art.arrow,
    fit: BoxFit.fitWidth,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

/// Art standing on the bottom edge, full width (or wider, cropped at the sides), sunk below
/// the edge by its sparse lower part so no background shows under it. Goes in a
/// `Positioned.fill`.
class BottomArt extends StatelessWidget {
  const BottomArt(
    this.asset, {
    super.key,
    required this.aspect,
    required this.sunk,
    this.widthFactor = 1,
  });

  final String asset;

  /// Width / height of the image.
  final double aspect;

  /// Share of the image's height that goes below the edge: its sparse bottom, measured on
  /// the asset (rows under ~90% coverage).
  final double sunk;

  /// Image width / screen width; above 1 the sides are cropped.
  final double widthFactor;

  /// Height of the image on a screen `width` wide.
  double height(double width) => width * widthFactor / aspect;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth * widthFactor;
        final h = height(box.maxWidth);
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: (box.maxWidth - width) / 2,
              width: width,
              bottom: -h * sunk,
              height: h,
              child: Image.asset(asset, fit: BoxFit.fill, cacheWidth: 1600),
            ),
          ],
        );
      },
    ),
  );
}

/// Rubble along the bottom edge, under the content; the same strip on every screen.
class Debris extends StatelessWidget {
  const Debris({super.key});

  /// `trash_line_mainscreen.webp` is 2172×724; rows below 600 are sparse pebbles.
  static const _art = BottomArt(
    Art.debris,
    aspect: 2172 / 724,
    sunk: 124 / 724,
    widthFactor: 1.25,
  );

  /// Where the stones start, measured from the bottom edge, on a screen `width` wide; the
  /// strip's top 130 rows are empty.
  static double top(double width) =>
      _art.height(width) * (1 - 124 / 724 - 130 / 724);

  @override
  Widget build(BuildContext context) => _art;
}

/// A screen of the dark kind: plain dark grey, rubble at the bottom, content above.
class DarkScaffold extends StatelessWidget {
  const DarkScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.behind,
    this.debris = true,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  /// Decoration between the background and the content, e.g. the world map.
  final Widget? behind;

  /// The rubble strip at the bottom; off where it would sit under text.
  final bool debris;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    floatingActionButton: floatingActionButton,
    body: Stack(
      children: [
        if (debris) const Positioned.fill(child: Debris()),
        if (behind != null) Positioned.fill(child: behind!),
        Positioned.fill(child: body),
      ],
    ),
  );
}
