import 'package:webview_flutter/webview_flutter.dart';

class MidgardWebController {
  final WebViewController controller = WebViewController();

  Future<void> init() async {
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse("https:..midgardtranslation.org"));
  }

  Future<bool> canGoBack() => controller.canGoBack();
  Future<bool> canGoForward() => controller.canGoForward();
  Future<void> goBack() async => controller.goBack();
  Future<void> goForward() async => controller.goForward();
  Future<void> reload() async => controller.reload();
  Future<void> goHome() async =>
      controller.loadRequest(Uri.parse("https://midgardtranslation.org"));
}
