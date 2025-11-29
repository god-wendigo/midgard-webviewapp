import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../service/bookmark_service.dart';
import 'about_screen.dart';
import '../widgets/bottom_nav_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool darkMode = false;
  String version = "—";

  @override
  void initState() {
    super.initState();
    loadAppInfo();
  }

  Future<void> loadAppInfo() async {
    PackageInfo info = await PackageInfo.fromPlatform();
    setState(() => version = info.version);
  }

  //🌗 Animated Theme Switch — uses Overlay fade
  void toggleTheme() async {
    OverlayEntry overlay = OverlayEntry(
      builder: (_) => AnimatedOpacity(
        opacity: 0.9,
        duration: const Duration(milliseconds: 500),
        child: Container(color: Colors.black),
      ),
    );

    Overlay.of(context).insert(overlay);

    await Future.delayed(const Duration(milliseconds: 350));
    setState(() => darkMode = !darkMode);

    await Future.delayed(const Duration(milliseconds: 300));
    overlay.remove();
  }

  void contactTelegram() => launchUrl(Uri.parse("https://t.me/MidgardSupport"),
      mode: LaunchMode.externalApplication);

  void contactEmail() => launchUrl(
      Uri.parse("mailto:support@midgard.com?subject=Support Request"));

  void clearBookmarks() async {
    await BookmarkService.clearAll();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("All bookmarks removed")),
    );
  }

  Future<void> clearCache() async {
    // later: use WebViewController.clearCache();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Cache wiped")),
    );
  }

  void shareApp() =>
      Share.share("Download Midgard App — https://midgardtranslation.org");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(5),
        children: [
          //================ APPEARANCE ================
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text("Appearance",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),

          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text("Dark / Light Mode"),
            trailing: Switch(value: darkMode, onChanged: (_) => toggleTheme()),
          ),

          const Divider(),

          //================ BOOKMARK + STORAGE =================
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text("Storage & Library",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),

          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text("Clear all bookmarks"),
            onTap: clearBookmarks,
          ),

          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text("Clear Web Cache"),
            onTap: () async {
              final web = MidgardBottomNav.webViewKey.currentState;

              if (web == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("WebView not active yet!")));
                return;
              }

              await web.clearCache();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Web cache cleared successfully!")));
            },
          ),

          const Divider(),

          //================ INFO =================
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text("Information & Support",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("About This App"),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),

          ListTile(
            leading: const Icon(Icons.telegram),
            title: const Text("Telegram Support"),
            subtitle: const Text("@MidgardSupport"),
            onTap: contactTelegram,
          ),

          const Divider(),

          //================ SHARE ================
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text("Share This App"),
            onTap: shareApp,
          ),

          Padding(
            padding: const EdgeInsets.all(15),
            child: Center(
              child: Text("Version $version",
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ),
          )
        ],
      ),
    );
  }
}
