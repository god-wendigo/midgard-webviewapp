import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("About")),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Midgard Translation",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("A lightweight WebView browsing app with instant bookmarks, "
                "smooth UI and theme control created for Midgard Fans."),
            SizedBox(height: 20),
            Text("Features:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("• Save & open bookmarks instantly\n"
                "• Light/Dark mode\n"
                "• Clean fast browsing experience\n"
                "• Built with Flutter & Material Design"),
          ],
        ),
      ),
    );
  }
}
