import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../service/bookmark_service.dart';

class WebViewScreen extends StatefulWidget {
  final Function()? onBookmarkAdded; // notify bottom nav or library refresh

  const WebViewScreen({super.key, this.onBookmarkAdded});

  @override
  WebViewScreenState createState() => WebViewScreenState();
}

class WebViewScreenState extends State<WebViewScreen> {
  late WebViewController controller;
  double progress = 0.0;

  String currentUrl = "";
  String currentTitle = "Loading...";

  @override
  void initState() {
    super.initState();

    // ⚡ Set WebViewController
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setUserAgent('MyCustomUserAgent/1.0') // <-- Your custom User-Agent
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            currentUrl = url;
            setState(() {
              currentTitle = "Loading...";
            });
          },
          onPageFinished: (url) async {
            currentUrl = url;

            // Try 1: get <title>
            String? title = await controller.getTitle();

            // Try 2: JS title fallback
            title ??= await controller
                .runJavaScriptReturningResult("document.title")
                .then((v) => v.toString().replaceAll('"', ''))
                .catchError((_) {
              return "Untitled";
            });

            currentTitle = title;
            setState(() {});
          },
          onProgress: (value) {
            setState(() => progress = value / 100);
          },
        ),
      )
      ..loadRequest(Uri.parse("https://midgardtranslation.org"));
  }

  /// 📌 Called from LibraryScreen → open saved page
  void openBookmark(String url) {
    controller.loadRequest(Uri.parse(url));
  }

  /// ⭐ Save bookmark and update UI
  Future<void> saveBookmark() async {
    if (currentUrl.isEmpty) return;

    String cleanedTitle = currentTitle;

    // Remove site name if separated by common separators
    List<String> separators = [' - ', ' | ', ' • '];
    for (var sep in separators) {
      if (cleanedTitle.contains(sep)) {
        cleanedTitle = cleanedTitle.split(sep)[0];
        break; // only split by the first matched separator
      }
    }

    await BookmarkService.addBookmark(currentUrl, cleanedTitle);

    widget.onBookmarkAdded?.call();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Saved: $cleanedTitle")));
  }

  // Check if WebView can go back
  Future<bool> canGoBack() async {
    return await controller.canGoBack();
  }

  // Go back inside WebView
  Future<void> goBack() async {
    if (await controller.canGoBack()) {
      controller.goBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: saveBookmark,
        icon: const Icon(Icons.bookmark_add_outlined),
        label: const Text("Save"),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),

          /// Loading bar
          if (progress < 1)
            LinearProgressIndicator(value: progress, minHeight: 3),
        ],
      ),
    );
  }
}
