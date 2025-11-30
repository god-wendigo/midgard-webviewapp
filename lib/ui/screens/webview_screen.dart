// lib/ui/screens/webview_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../service/bookmark_service.dart';

import 'loading_screen.dart'; // a simple loading overlay
import 'offline_screen.dart'; // offline overlay with onRetry callback

class WebViewScreen extends StatefulWidget {
  final VoidCallback? onBookmarkAdded;

  const WebViewScreen({super.key, this.onBookmarkAdded});

  @override
  WebViewScreenState createState() => WebViewScreenState();
}

class WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController controller;
  double progress = 1.0;
  bool hasConnectionError = false;

  String currentUrl = "";
  String currentTitle = "Loading...";

  static const String homeUrl = "https://midgardtranslation.org";

  bool _isLoading = true;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _setupWebView();
    _loadUrl(homeUrl);
  }

  void _setupWebView() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setUserAgent('Midgard/1.0')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              progress = 0.0;
              currentTitle = "Loading...";
              _isLoading = true;
              _isOffline = false;
            });
            currentUrl = url;
          },
          onProgress: (value) => setState(() {
            progress = value / 100;
            _isLoading = true;
          }),
          onPageFinished: (url) async {
            currentUrl = url;
            setState(() {
              progress = 1.0;
              _isLoading = false;
              _isOffline = false;
            });

            String? title;
            try {
              title = await controller.getTitle();
            } catch (_) {
              title = null;
            }

            if (title == null || title.isEmpty) {
              try {
                final raw = await controller
                    .runJavaScriptReturningResult("document.title");
                title = raw.toString();
              } catch (_) {
                title = "Untitled";
              }
            }

            // Keep your existing title logic unchanged
            for (var sep in [' | ', ' - ', ' • ', ' — ']) {
              if (title != null && title.contains(sep)) {
                title = title.split(sep)[0].trim();
                break;
              }
            }

            setState(() => currentTitle = title ?? "Untitled");
          },
          onWebResourceError: (_) async {
            final connected = await _hasInternet();
            if (!connected) {
              setState(() {
                _isOffline = true;
                _isLoading = false;
              });
            }
          },
        ),
      );
    _loadUrlSafely(homeUrl);
  }

  Future<void> _loadUrl(String url) async {
    if (!await _hasInternet()) {
      setState(() {
        _isOffline = true;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isOffline = false;
    });

    try {
      await controller.loadRequest(Uri.parse(url));
    } catch (_) {
      setState(() {
        _isOffline = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUrlSafely(String url) async {
    bool online = await _hasInternet();
    if (online) {
      try {
        await controller.loadRequest(Uri.parse(url));
      } catch (_) {
        if (mounted) setState(() => hasConnectionError = true);
      }
    } else {
      if (mounted) setState(() => hasConnectionError = true);
    }
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('midgardtranslation.org');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    }
  }

  Future<void> _retry() async {
    await _loadUrl(currentUrl.isNotEmpty ? currentUrl : homeUrl);
  }

  Future<void> openBookmark(String url) async {
    currentUrl = url;
    setState(() {
      progress = 0.0;
      hasConnectionError = false;
    });
    await _loadUrlSafely(url);
  }

  Future<void> saveBookmark() async {
    if (currentUrl.isEmpty) return;

    final titleToSave = currentTitle.isNotEmpty ? currentTitle : currentUrl;
    await BookmarkService.addBookmark(currentUrl, titleToSave);
    widget.onBookmarkAdded?.call();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Bookmark saved: $titleToSave")),
    );
  }

  Future<bool> canGoBack() => controller.canGoBack();
  Future<void> goBack() async {
    if (await controller.canGoBack()) await controller.goBack();
  }

  Future<void> clearCache() async => controller.clearCache();

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
          if (!_isOffline) WebViewWidget(controller: controller),
          if (_isOffline) OfflineScreen(onRetry: _retry),
          if (_isLoading) const LoadingScreen(),
          if (progress < 1.0)
            LinearProgressIndicator(value: progress, minHeight: 3),
        ],
      ),
    );
  }
}
