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
      } catch (_) {
        // Skip corrupted entry
      }
    }

    // Prevent duplicates
    if (list.any((e) => e["url"] == url)) {
      return;
    }

    list.add({"title": title, "url": url});

    // Save new list
    List<String> encoded =
        list.map((e) => jsonEncode(e)).toList(growable: false);

    await prefs.setStringList(key, encoded);

    // Notify UI
    onBookmarksUpdated?.call();
  }

  /// Load bookmarks safely (skips corrupted or old entries)
  static Future<List<Map<String, String>>> loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(key) ?? [];

    List<Map<String, String>> list = [];

    for (var item in raw) {
      try {
        list.add(Map<String, String>.from(jsonDecode(item)));
      } catch (_) {
        // skip corrupted entry
      }
    }

    return list;
  }

  /// Delete bookmark by URL
  static Future<void> deleteBookmark(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(key) ?? [];

    List<String> cleaned = [];

    for (var item in raw) {
      try {
        final decoded = jsonDecode(item);

        if (decoded["url"] != url) {
          cleaned.add(item);
        }
      } catch (_) {
        // skip corrupted item
      }
    }

    await prefs.setStringList(key, cleaned);

    onBookmarksUpdated?.call();
  }
}
