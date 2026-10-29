import 'package:flutter/material.dart';

import '../theme.dart';

/// Placeholder body for a screen whose content comes in a later step.
class StubBody extends StatelessWidget {
  const StubBody(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: PartizanColors.muted),
      ),
    ),
  );
}
