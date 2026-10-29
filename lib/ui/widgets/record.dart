import 'package:flutter/material.dart';

import '../../core/vpn_status.dart';
import '../../state/vpn.dart';
import 'art.dart';

/// The record is the switch: broken while the tunnel is down, whole while it is up. Coming
/// up it mends smoothly (a crossfade at equal size) under a blinking white glow; going
/// down it shatters at once.
class RecordToggle extends StatefulWidget {
  const RecordToggle({super.key, required this.state, required this.onTap});

  final VpnState state;
  final VoidCallback onTap;

  /// How long the broken record takes to become whole.
  static const mend = Duration(milliseconds: 1100);

  @override
  State<RecordToggle> createState() => _RecordToggleState();
}

class _RecordToggleState extends State<RecordToggle>
    with TickerProviderStateMixin {
  /// 0 broken … 1 whole.
  late final AnimationController _whole = AnimationController(
    vsync: this,
    duration: RecordToggle.mend,
    value: isActive(widget.state) ? 1 : 0,
  );

  /// The glow while connecting.
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// Brings the broken record to the whole one's size, so mending is a pure crossfade.
  static const _brokenScale = 1.06;

  /// Puts the broken record's centre hole where the whole one's is. Measured on the 1254 px
  /// images: the holes sit at (+19.4, −36.9) and (−1.4, −6.3) from the centre; scaled by
  /// [_brokenScale] the first is at (+20.6, −39.1), so it moves by (−22.0, +32.8).
  static const _brokenShift = Offset(-22.0 / 1254, 32.8 / 1254);

  bool get _connecting =>
      widget.state == VpnState.connecting ||
      widget.state == VpnState.reconnecting;

  @override
  void initState() {
    super.initState();
    if (_connecting) _glow.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(RecordToggle old) {
    super.didUpdateWidget(old);
    if (isActive(widget.state)) {
      _whole.forward();
    } else {
      // Down: no animation, it breaks.
      _whole.value = 0;
    }
    if (_connecting) {
      if (!_glow.isAnimating) _glow.repeat(reverse: true);
    } else {
      _glow
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _whole.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: isActive(widget.state) ? 'Отключить VPN' : 'Подключить VPN',
    child: GestureDetector(
      key: const Key('vpn-toggle'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: AnimatedBuilder(
          animation: Listenable.merge([_whole, _glow]),
          builder: (context, _) {
            final whole = Curves.easeInOut.transform(_whole.value);
            return Stack(
              fit: StackFit.expand,
              children: [
                if (_glow.value > 0)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.55 * _glow.value),
                          Colors.white.withValues(alpha: 0),
                        ],
                        stops: const [0.45, 1],
                      ),
                    ),
                  ),
                Opacity(
                  opacity: 1 - whole,
                  // The shards' median outer radius is 562 px against the whole
                  // record's 585, and the gaps make it look smaller still.
                  child: FractionalTranslation(
                    translation: _brokenShift,
                    child: Transform.scale(
                      scale: _brokenScale,
                      child: Image.asset(
                        Art.recordBroken,
                        key: const Key('record-broken'),
                        cacheWidth: 1000,
                      ),
                    ),
                  ),
                ),
                Opacity(
                  opacity: whole,
                  child: Image.asset(
                    Art.recordFull,
                    key: const Key('record-full'),
                    cacheWidth: 1000,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
