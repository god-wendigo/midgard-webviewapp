// lib/ui/screens/webview_screen.dart

// no using this code file
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../service/bookmark_service.dart';
import 'loading_screen.dart';
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

  bool _isLoading = true;
  bool _isOffline = false;
  String? _lastUrl;

  static const String homeUrl = "https://midgardtranslation.org";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initWebView();
    _load(homeUrl);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // optional: reload last url on resume to avoid Android white-screen edge-cases
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
      ..setUserAgent('Midgard/1.0')
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _handleNavigationRequest,
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _isOffline = false;
            });
          },
          onPageFinished: (url) async {
            _lastUrl = url;

            Future.delayed(const Duration(milliseconds: 700), () async {
              if (mounted) setState(() => _isLoading = false);
            });

            // Inject viewport & optional protections to ensure overlays (search/modal) appear correctly
            await controller.runJavaScript('''
              try {
                var meta = document.querySelector('meta[name="viewport"]');
                if (!meta) {
                  meta = document.createElement('meta');
                  meta.name = 'viewport';
                  meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                  document.head.appendChild(meta);
                }
                document.addEventListener('contextmenu', function(e){ e.preventDefault(); });
                document.body.style.webkitTouchCallout = 'none';
                document.body.style.userSelect = 'none';
              } catch (e) { /* ignore */ }
            ''');

            // only set loading false when done
            if (mounted) {
              setState(() {
                _isLoading = false;
                _isOffline = false;
              });
            }
          },
          onWebResourceError: (_) async {
            final hasNet = await _hasInternet();
            if (!hasNet && mounted) {
              setState(() {
                _isOffline = true;
                _isLoading = false;
              });
            }
          },
        ),
      );
  }

  // ---------------- Internet check ----------------
  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }

  // ---------------- Load helpers ----------------
  Future<void> _load(String url) async {
    if (!await _hasInternet()) {
      if (mounted) {
        setState(() {
          _isOffline = true;
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isOffline = false;
        _isLoading = true;
      });
    }

    _lastUrl = url;
    try {
      await controller.loadRequest(Uri.parse(url));
    } catch (_) {
      if (mounted) setState(() => _isOffline = true);
    }
  }

  Future<void> _loadSafely(String url) async => _load(url);

  // ---------------- Public helpers you asked for ----------------

  /// Open a bookmark URL inside the webview
  Future<void> openBookmark(String url) async {
    _lastUrl = url;
    if (!await _hasInternet()) {
      if (mounted) {
        setState(() {
          _isOffline = true;
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isOffline = false;
        _isLoading = true;
      });
    }

    try {
      await controller.loadRequest(Uri.parse(url));
    } catch (_) {
      if (mounted) {
        setState(() {
          _isOffline = true;
          _isLoading = false;
        });
      }
    }
  }

  /// Save current url as bookmark
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

  /// Clear webview cache
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

  /// Check whether the webview can go back
  Future<bool> canGoBack() => controller.canGoBack();

  /// Navigate back in webview history if possible
  Future<void> goBack() async {
    if (await controller.canGoBack()) {
      await controller.goBack();
    }
  }

  // ---------------- Navigation handler ----------------
  Future<NavigationDecision> _handleNavigationRequest(
      NavigationRequest request) async {
    final uri = Uri.parse(request.url);

    // external domain -> open externally
    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        !uri.host.contains(Uri.parse(homeUrl).host)) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // ignore launch error
      }
      return NavigationDecision.prevent;
    }

    // check internet before navigate
    if (!await _hasInternet()) {
      if (mounted) {
        setState(() {
          _isOffline = true;
          _isLoading = false;
        });
      }
      return NavigationDecision.prevent;
    }

    _lastUrl = request.url;
    if (mounted) setState(() => _isLoading = true);
    return NavigationDecision.navigate;
  }

  // ---------------- Reload current page ----------------
  Future<void> _retry() async {
    final url = _lastUrl ?? homeUrl;
    await _loadSafely(url);
  }

  // ---------------- Back button / exit dialog ----------------
  Future<bool> _onWillPop() async {
    try {
      if (await controller.canGoBack()) {
        await controller.goBack();
        return false;
      }
    } catch (_) {
      // ignore
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
        floatingActionButton: FloatingActionButton.extended(
          onPressed: saveBookmark,
          icon: const Icon(Icons.bookmark_add_outlined),
          label: const Text("Save"),
        ),
        body: Stack(
          children: [
            if (_isOffline)
              OfflineScreen(onRetry: _retry)
            else
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
            if (_isLoading && !_isOffline) const LoadingScreen(),
          ],
        ),
      ),
    );
  }
}
