// lib/ui/screens/webview_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../service/bookmark_service.dart';
import 'offline_screen.dart';

class WebViewScreen extends StatefulWidget {
  final VoidCallback? onBookmarkAdded;
  const WebViewScreen({super.key, this.onBookmarkAdded});

  @override
  WebViewScreenState createState() => WebViewScreenState();
}

class WebViewScreenState extends State<WebViewScreen>
    with WidgetsBindingObserver {
  late final WebViewController controller;

  bool _isOffline = false;
  String? _lastUrl;
  double _progress = 0.0;

  static const String homeUrl = "https://midgardtranslation.org/wp-admin";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initWebView();
    _load(homeUrl);
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      AndroidWebViewController.enableDebugging(false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isOffline && _lastUrl != null) {
      controller.loadRequest(Uri.parse(_lastUrl!));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ---------------- WebView init ----------------
  void _initWebView() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setUserAgent("Midgard/1.0 (Android Webview)")
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _progress = progress / 100.0;
              });
            }
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _progress = 0.0;
                _isOffline = false;
              });
            }
          },
          onPageFinished: (url) async {
            _lastUrl = url;
            if (mounted) {
              setState(() {
                _progress = 1.0;
              });
            }

            await controller.runJavaScript('''
              try {
                var meta = document.querySelector('meta[name="viewport"]');
                document.querySelectorAll('input').forEach(function(input) {
                input.setAttribute('autocomplete', 'off');
                });
                document.querySelectorAll('input[type="password"]').forEach(function(pwd) {
                pwd.setAttrubute('autocomplete', 'new-password');
                });
                }
                if (!meta) {
                  meta = document.createElement('meta');
                  meta.name = 'viewport';
                  meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                  document.head.appendChild(meta);
                }
                document.addEventListener('contextmenu', function(e){ e.preventDefault(); });
                document.body.style.webkitTouchCallout = 'none';
                document.body.style.userSelect = 'none';
              } catch (e) {}
            ''');
          },
          onWebResourceError: (_) async {
            final hasNet = await _hasInternet();
            if (!hasNet && mounted) {
              setState(() {
                _isOffline = true;
                _progress = 0.0;
              });
            }
          },
          onNavigationRequest: _handleNavigationRequest,
        ),
      )
      ..runJavaScript('''if (window.AndroidAutoFill) {
      AndroidAutoFill.disable();
      }
      ''');
  }

  // ---------------- Internet check ----------------
  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ---------------- Load helpers ----------------
  Future<void> _load(String url) async {
    final hasNet = await _hasInternet();
    if (!hasNet) {
      if (mounted) {
        setState(() {
          _isOffline = true;
          _progress = 0.0;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isOffline = false;
        _progress = 0.0;
      });
    }

    _lastUrl = url;
    try {
      await controller.loadRequest(Uri.parse(url));
    } catch (_) {
      if (mounted) {
        setState(() {
          _isOffline = true;
          _progress = 0.0;
        });
      }
    }
  }

  Future<void> _loadSafely(String url) async => _load(url);

  // ---------------- Public helpers ----------------
  Future<void> openBookmark(String url) async => _load(url);

  Future<void> saveBookmark() async {
    final url = _lastUrl;
    if (url == null || url.isEmpty) return;

    String title;
    try {
      title = await controller.getTitle() ?? url;
    } catch (_) {
      title = url;
    }

    await BookmarkService.addBookmark(url, title);
    widget.onBookmarkAdded?.call();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Bookmark saved: $title")),
    );
  }

  Future<void> clearCache() async {
    try {
      await controller.clearCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cache cleared.")),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to clear cache.")),
        );
      }
    }
  }

  Future<bool> canGoBack() => controller.canGoBack();

  Future<void> goBack() async {
    if (await controller.canGoBack()) {
      await controller.goBack();
    }
  }

  // ---------------- Navigation handler ----------------
  Future<NavigationDecision> _handleNavigationRequest(
    NavigationRequest request,
  ) async {
    final uri = Uri.parse(request.url);

    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        !uri.host.contains(Uri.parse(homeUrl).host)) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
      return NavigationDecision.prevent;
    }

    if (!await _hasInternet()) {
      if (mounted) {
        setState(() {
          _isOffline = true;
          _progress = 0.0;
        });
      }
      return NavigationDecision.prevent;
    }

    _lastUrl = request.url;
    return NavigationDecision.navigate;
  }

  // ---------------- Retry ----------------
  Future<void> _retry() async {
    final url = _lastUrl ?? homeUrl;
    await _loadSafely(url);
  }

  // ---------------- Back button / exit dialog ----------------
  Future<bool> _onWillPop() async {
    if (await controller.canGoBack()) {
      await controller.goBack();
      return false;
    }

    final doExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Do you want to exit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    return doExit ?? false;
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: "refresh",
              mini: true,
              onPressed: () async {
                try {
                  await controller.reload();
                } catch (_) {
                  await _retry();
                }
              },
              child: const Icon(Icons.refresh),
            ),
            const SizedBox(height: 10),
            FloatingActionButton.extended(
              heroTag: "bookmark",
              onPressed: saveBookmark,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text("Save"),
            ),
          ],
        ),
        body: Stack(
          children: [
            if (!_isOffline)
              RefreshIndicator(
                onRefresh: () async {
                  try {
                    await controller.reload();
                  } catch (_) {
                    await _retry();
                  }
                },
                child: WebViewWidget(controller: controller),
              ),

            if (_isOffline) OfflineScreen(onRetry: _retry),

            // 🔹 Top linear progress bar
            if (_progress < 1.0 && !_isOffline)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 3,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
