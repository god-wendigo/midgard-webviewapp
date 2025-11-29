import 'package:flutter/material.dart';
import 'ui/widgets/bottom_nav_bar.dart';

class MidgardApp extends StatelessWidget {
  const MidgardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.amber, // Midgard gold theme
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepOrange, // Viking ember tone
        brightness: Brightness.dark,
      ),
      home: const MidgardBottomNav(), // Entry point
    );
  }
}
