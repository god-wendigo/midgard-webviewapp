import 'package:flutter/material.dart';
import '../screens/webview_screen.dart';
import '../screens/library_screen.dart';
import '../screens/settings_screen.dart';

class MidgardBottomNav extends StatefulWidget {
  const MidgardBottomNav({super.key});

  /// Allow other pages to switch tab (Library → Home)
  static Function(int)? changeTab;

  /// Access webview state globally
  static final GlobalKey<WebViewScreenState> webViewKey = GlobalKey();

  @override
  State<MidgardBottomNav> createState() => _MidgardBottomNavState();
}

class _MidgardBottomNavState extends State<MidgardBottomNav> {
  int index = 0;

  late final List<Widget> pages = [
    WebViewScreen(key: MidgardBottomNav.webViewKey),
    const LibraryScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();

    /// Expose tab switch control globally
    MidgardBottomNav.changeTab = (int i) {
      if (mounted) setState(() => index = i);
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // SHOW APPBAR ONLY ON HOME TAB
      appBar: index == 0
          ? AppBar(title: const Text("Midgard"), actions: [
              IconButton(
                icon: const Icon(Icons.west),
                onPressed: () async {
                  final web = MidgardBottomNav.webViewKey.currentState;

                  if (web != null && await web.canGoBack()) {
                    web.goBack(); // Go back inside WebView
                  }
                },
              ),
            ])
          : null, // No appBar in Library & Settings

      body: IndexedStack(
        index: index,
        children: pages,
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        height: 65,
        onDestinationSelected: (value) {
          setState(() => index = value);
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: "Home"),
          NavigationDestination(
              icon: Icon(Icons.library_books_outlined),
              selectedIcon: Icon(Icons.library_books),
              label: "Library"),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: "Settings"),
        ],
      ),
    );
  }
}
