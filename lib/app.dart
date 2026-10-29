import 'package:flutter/material.dart';

import 'ui/screens/connection_screen.dart';
import 'ui/theme.dart';

class PartizanApp extends StatelessWidget {
  const PartizanApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'partizan',
    theme: partizanTheme(),
    debugShowCheckedModeBanner: false,
    home: const ConnectionScreen(),
  );
}
