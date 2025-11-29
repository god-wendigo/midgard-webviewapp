import 'package:flutter/material.dart';
import '../../service/bookmark_service.dart';
import '../widgets/bottom_nav_bar.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Map<String, String>> bookmarks = [];

  @override
  void initState() {
    super.initState();
    loadBookmarks();

    // Auto refresh when bookmark list changes
    BookmarkService.onBookmarksUpdated = () {
      if (mounted) loadBookmarks();
    };
  }

  Future<void> loadBookmarks() async {
    bookmarks = await BookmarkService.loadBookmarks();
    if (mounted) setState(() {});
  }

  /// 🔗 Open bookmark inside WebView tab
  Future<void> _openBookmark(String url) async {
    // Switch tab → Home (index 0)
    MidgardBottomNav.changeTab!(0);

    // Wait a moment for widget to rebuild
    await Future.delayed(const Duration(milliseconds: 120));

    final webViewState = MidgardBottomNav.webViewKey.currentState;

    if (webViewState != null) {
      webViewState.openBookmark(url);
    } else {
      debugPrint("ERROR: WebViewScreenState is null (cannot open bookmark)");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bookmarks")),
      body: bookmarks.isEmpty
          ? const Center(
              child: Text(
                "No bookmarks saved",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.separated(
              itemCount: bookmarks.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = bookmarks[index];
                final title = item["title"]!;
                final url = item["url"]!;

                return ListTile(
                  leading: const Icon(Icons.bookmark, color: Colors.blueAccent),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _openBookmark(url),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    onPressed: () async {
                      await BookmarkService.deleteBookmark(url);
                    },
                  ),
                );
              },
            ),
    );
  }
}
