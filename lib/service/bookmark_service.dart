import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class BookmarkService {
  static const String key = "bookmarks";

  /// Callback function for UI auto-refresh
  static Function()? onBookmarksUpdated;

  /// Add bookmark instantly with safe JSON handling
  static Future<void> addBookmark(String url, String title) async {
    final prefs = await SharedPreferences.getInstance();

    List<String> raw = prefs.getStringList(key) ?? [];
    List<Map<String, String>> list = [];

    // Decode safely
    for (var item in raw) {
      try {
        list.add(Map<String, String>.from(jsonDecode(item)));
      } catch (_) {}
    }

    // Prevent duplicates
    if (list.any((e) => e["url"] == url)) return;

    list.add({"title": title, "url": url});

    List<String> encoded =
        list.map((e) => jsonEncode(e)).toList(growable: false);
    await prefs.setStringList(key, encoded);

    onBookmarksUpdated?.call();
  }

  /// Load bookmarks safely
  static Future<List<Map<String, String>>> loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(key) ?? [];

    List<Map<String, String>> list = [];

    for (var item in raw) {
      try {
        list.add(Map<String, String>.from(jsonDecode(item)));
      } catch (_) {}
    }

    return list;
  }

  /// Delete one bookmark by URL
  static Future<void> deleteBookmark(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(key) ?? [];

    List<String> cleaned = [];

    for (var item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded["url"] != url) cleaned.add(item);
      } catch (_) {}
    }

    await prefs.setStringList(key, cleaned);
    onBookmarksUpdated?.call();
  }

  /// ⭐ Clear all bookmarks completely
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    onBookmarksUpdated?.call();
  }
}
