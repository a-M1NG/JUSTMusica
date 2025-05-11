import 'package:flutter/material.dart';
import 'package:just_musica/utils/tools.dart';
import '../models/song_model.dart';
import '../services/playback_service.dart';
import '../services/favorites_service.dart';
import '../widgets/song_list_item.dart';
import '../services/database_service.dart';
import '../services/playlist_service.dart';

enum AppBarMode {
  normal,
  multiSelect,
  search,
}

abstract class SongListPageBase extends StatefulWidget {
  final PlaybackService playbackService;
  final FavoritesService favoritesService;

  const SongListPageBase({
    super.key,
    required this.playbackService,
    required this.favoritesService,
  });
}

abstract class SongListPageBaseState<T extends SongListPageBase>
    extends State<T> {
  late Future<List<SongModel>> songsFuture;
  List<SongModel> loadedSongs = [];
  List<SongModel> _displayedSongs =
      []; // For displaying either all or searched songs
  Set<int> selectedSongIds = {};

  AppBarMode _appBarMode = AppBarMode.normal;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Helper to determine if we are in multi-select logical mode
  bool get _isActuallyMultiSelectMode => _appBarMode == AppBarMode.multiSelect;

  @override
  void initState() {
    super.initState();
    loadSongs();
  }

  // Abstract method: load songs implementation
  Future<List<SongModel>> loadSongsImplementation();

  // Load songs and cache
  Future<void> loadSongs() async {
    songsFuture = loadSongsImplementation();
    songsFuture.then((songs) {
      setState(() {
        loadedSongs = songs;
        _displayedSongs = List.from(loadedSongs); // Initialize displayed songs
        _resetSearch(); // If songs are reloaded, reset search
      });
    }).catchError((error) {
      // Handle or log error if necessary
      if (mounted) {
        setState(() {
          loadedSongs = [];
          _displayedSongs = [];
        });
      }
    });
  }

  void _resetSearch() {
    _searchController.clear();
    if (_appBarMode == AppBarMode.search) {
      // If currently in search mode, re-apply empty search to show all loaded songs
      _performSearch("");
    } else {
      // Otherwise, ensure displayed songs reflect all loaded songs
      _displayedSongs = List.from(loadedSongs);
    }
  }

  void _performSearch(String query) {
    final lowerCaseQuery = query.toLowerCase().trim();
    setState(() {
      if (lowerCaseQuery.isEmpty) {
        _displayedSongs = List.from(loadedSongs);
      } else {
        // Use a set to avoid duplicates
        final Set<int> seenIds = {};
        _displayedSongs = loadedSongs.where((song) {
          final titleMatch =
              song.title?.toLowerCase().contains(lowerCaseQuery) ?? false;
          final artistMatch =
              song.artist?.toLowerCase().contains(lowerCaseQuery) ?? false;
          final isMatch = titleMatch || artistMatch;
          if (isMatch && song.id != null && !seenIds.contains(song.id)) {
            seenIds.add(song.id!);
            return true;
          }
          return false;
        }).toList();
      }
      // When a search is performed, multi-selection should be reset
      selectedSongIds.clear();
      _isSelectAll = false;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Play song
  void playSong(SongModel song) {
    // Use _displayedSongs for context if it makes sense, or always loadedSongs for full playlist
    // For now, using loadedSongs implies the original full list context for playback.
    // If you want playback to be only from search results, use _displayedSongs.
    widget.playbackService.setPlaybackList(loadedSongs, song);
    widget.playbackService.playSong(song);
  }

  // Add to next
  void addToNext(SongModel song) {
    widget.playbackService.playNext(song.id!);
  }

  // Toggle favorite
  void toggleFavorite(SongModel song) {
    setState(() {
      song.isFavorite = !song.isFavorite;
    });
    widget.favoritesService.toggleFavorite(song.id!);
  }

  // Abstract method: delete song
  Future<void> deleteSong(SongModel song);

  // Show delete confirmation dialog
  Future<bool?> showDeleteDialog(
      BuildContext context, String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  // No longer directly setting _isMultiSelectMode. It's derived from _appBarMode.
  // The old setter logic is moved to where _appBarMode changes.
  // bool _isMultiSelectMode = false;
  // bool get isMultiSelectMode => _isMultiSelectMode;

  bool _isSelectAll = false;

  void _switchToMultiSelectMode() {
    setState(() {
      _appBarMode = AppBarMode.multiSelect;
      selectedSongIds.clear();
      _isSelectAll = false;
    });
  }

  void _exitMultiSelectMode() {
    setState(() {
      _appBarMode = AppBarMode.normal;
      selectedSongIds.clear();
      _isSelectAll = false;
    });
  }

  void _exitSearchMode() {
    setState(() {
      _appBarMode = AppBarMode.normal;
      _searchController.clear();
      _displayedSongs = List.from(loadedSongs); // Reset to all songs
      selectedSongIds.clear(); // Clear selections when exiting search
      _isSelectAll = false;
    });
  }

  void toggleSelection(int songId) {
    if (!_isActuallyMultiSelectMode)
      return; // Can only select in multi-select mode
    setState(() {
      if (selectedSongIds.contains(songId)) {
        selectedSongIds.remove(songId);
        _isSelectAll =
            false; // If one item is deselected, it's no longer "select all"
      } else {
        selectedSongIds.add(songId);
        if (selectedSongIds.length == _displayedSongs.length &&
            _displayedSongs.isNotEmpty) {
          _isSelectAll = true;
        }
      }
    });
  }

  Future<bool?> onDeleteSelected(); // This should be implemented by subclasses

  void _onDeleteSelected() async {
    if (selectedSongIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择歌曲')),
      );
      return;
    }
    var res = await onDeleteSelected(); // Subclass implements actual deletion
    if (res == true) {
      // The loadSongs() or equivalent refresh should be called by the subclass
      // which will then update loadedSongs and _displayedSongs.
      // For now, assume the subclass handles UI refresh post-deletion.
      _exitMultiSelectMode(); // Exit multi-select mode after successful deletion
    }
  }

  Widget? getHeader() => null;

  void onAddToFavoritesSelected() {
    if (selectedSongIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择歌曲')),
      );
      return;
    }
    showAddToPlaylistDialogMultiSelection(context, mounted, selectedSongIds,
        _exitMultiSelectMode); // Show dialog to add to favorites
  }

  PreferredSizeWidget _buildAppBar() {
    final ThemeData theme = Theme.of(context); // Get the current theme

    switch (_appBarMode) {
      case AppBarMode.search:
        // Determine default text color for AppBar to use for TextField input and hint base
        final Color appBarForegroundColor = theme.appBarTheme
                .foregroundColor ?? // New in Flutter 3.0 for icons and text
            theme.appBarTheme.titleTextStyle?.color ??
            (theme.brightness == Brightness.dark ? Colors.white : Colors.black);

        return AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back,
                color: appBarForegroundColor), // Match icon color
            tooltip: '返回',
            onPressed: _exitSearchMode,
          ),
          title: TextField(
            controller: _searchController,
            autofocus: true,
            textAlign: TextAlign
                .center, // Centers both hint and input text horizontally
            textAlignVertical:
                TextAlignVertical.center, // Helps center text vertically
            style: TextStyle(
                color:
                    appBarForegroundColor), // Style for the actual input text
            decoration: InputDecoration(
              hintText: '按标题和歌手搜索歌曲...',
              hintStyle: TextStyle(
                // Make hint color a semi-transparent version of the AppBar's foreground color
                color: appBarForegroundColor.withOpacity(0.6),
              ),
              border: InputBorder
                  .none, // Removes the underline for a cleaner look in AppBar
              isDense: true, // Reduces TextField's intrinsic padding
              suffixIcon: IconButton(
                icon: Icon(Icons.search,
                    color: appBarForegroundColor
                        .withOpacity(0.7)), // Match icon color with opacity
                tooltip: '搜索',
                onPressed: () {
                  _performSearch(_searchController.text);
                  // Optionally hide keyboard after search initiated
                  FocusScope.of(context).unfocus();
                },
              ),
            ),
            onSubmitted: (query) {
              // Allows searching by pressing enter on keyboard
              _performSearch(query);
              FocusScope.of(context).unfocus(); // Hide keyboard
            },
            // onChanged: (query) { // Uncomment for live search:
            //   _performSearch(query);
            // },
          ),
          centerTitle:
              true, // This is crucial for centering the TextField widget itself within the AppBar
          backgroundColor: theme.appBarTheme.backgroundColor?.withAlpha(220) ??
              Colors.transparent,
          elevation: 0,
        );
      case AppBarMode.multiSelect:
        final Color appBarForegroundColor = theme.appBarTheme.foregroundColor ??
            theme.appBarTheme.titleTextStyle?.color ??
            (theme.brightness == Brightness.dark ? Colors.white : Colors.black);
        return AppBar(
          leading: IconButton(
            icon: Icon(Icons.close, color: appBarForegroundColor),
            tooltip: '取消多选',
            onPressed: _exitMultiSelectMode,
          ),
          title: Text('已选择 ${selectedSongIds.length} 项',
              style: TextStyle(color: appBarForegroundColor)),
          backgroundColor: theme.appBarTheme.backgroundColor?.withAlpha(220) ??
              Colors.transparent,
          elevation: 0,
          actions: [
            // ... (multi-select actions - ensure their styling is consistent if needed)
            ElevatedButton.icon(
              icon: Icon(_isSelectAll ? Icons.deselect : Icons.select_all,
                  size: 20),
              label: Text(
                  _isSelectAll ? '取消全选' : '全选 (${_displayedSongs.length})'),
              onPressed: _displayedSongs.isEmpty
                  ? null
                  : () {
                      setState(() {
                        _isSelectAll = !_isSelectAll;
                        if (_isSelectAll) {
                          for (var song in _displayedSongs) {
                            selectedSongIds.add(song.id!);
                          }
                        } else {
                          selectedSongIds.clear();
                        }
                      });
                    },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 4), // Reduced spacing slightly
            ElevatedButton.icon(
              icon: const Icon(Icons.delete, size: 20),
              label: const Text('删除'),
              onPressed: selectedSongIds.isEmpty ? null : _onDeleteSelected,
              style: ElevatedButton.styleFrom(
                foregroundColor: selectedSongIds.isEmpty
                    ? Colors.grey.shade700
                    : theme.colorScheme.onError,
                backgroundColor: selectedSongIds.isEmpty
                    ? Colors.grey.shade300
                    : theme.colorScheme.error,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 4),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_special, size: 20),
              label: const Text('加入收藏'),
              onPressed:
                  selectedSongIds.isEmpty ? null : onAddToFavoritesSelected,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
          ],
        );
      case AppBarMode.normal:
      default:
        final Color appBarForegroundColor = theme.appBarTheme.foregroundColor ??
            theme.appBarTheme.titleTextStyle?.color ??
            (theme.brightness == Brightness.dark ? Colors.white : Colors.black);
        return AppBar(
          title: Text(getPageTitle(),
              style: TextStyle(color: appBarForegroundColor)),
          backgroundColor: theme.appBarTheme.backgroundColor?.withAlpha(220) ??
              Colors.transparent,
          elevation: 0,
          actions: <Widget>[
                ElevatedButton.icon(
                  icon: const Icon(Icons.checklist_rtl, size: 20),
                  label: const Text('多选'),
                  onPressed: _switchToMultiSelectMode,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search, size: 20),
                  label: const Text('搜索'),
                  onPressed: () {
                    setState(() {
                      _appBarMode = AppBarMode.search;
                      selectedSongIds.clear();
                      _isSelectAll = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
              ] +
              getAppBarActions() +
              [const SizedBox(width: 8)],
        );
    }
  }

  // Build the UI structure
  @override
  Widget build(BuildContext context) {
    var hasHeader = getHeader() != null;
    return Scaffold(
      extendBodyBehindAppBar: !hasHeader &&
          _appBarMode ==
              AppBarMode
                  .normal, // Adjust extendBody for different app bar states
      appBar: _buildAppBar(),
      body: Container(
        color: Theme.of(context)
            .colorScheme
            .background
            .withOpacity(0.2), // Use colorScheme
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<SongModel>>(
                future: songsFuture, // This future loads `loadedSongs`
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      loadedSongs.isEmpty) {
                    // Show loading only if songs aren't loaded yet
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('正在加载...'),
                        ],
                      ),
                    );
                  }
                  if (snapshot.hasError && loadedSongs.isEmpty) {
                    // Show error only if songs aren't loaded
                    return Center(child: Text('加载失败: ${snapshot.error}'));
                  }
                  // Use _displayedSongs for the list
                  if (_displayedSongs.isEmpty &&
                      _appBarMode == AppBarMode.search &&
                      _searchController.text.isNotEmpty) {
                    return Center(
                        child: Text('未找到与 "${_searchController.text}" 相关的歌曲'));
                  }
                  if (_displayedSongs.isEmpty) {
                    return Center(child: Text(getEmptyMessage()));
                  }

                  final songsToDisplay =
                      _displayedSongs; // Use the filtered/full list

                  if (hasHeader) {
                    return ListView.builder(
                      cacheExtent: 2000,
                      controller: _scrollController,
                      itemCount: songsToDisplay.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return getHeader()!;
                        } else {
                          final songIndex = index - 1;
                          final song = songsToDisplay[songIndex];
                          return SongListItem(
                            song: song,
                            index: songIndex + 1, // Display index
                            onPlay: () => playSong(song),
                            onToggleFavorite: () => toggleFavorite(song),
                            onDelete: () => deleteSong(song),
                            onAddToNext: () => addToNext(song),
                            onSelect: () => toggleSelection(song.id!),
                            isSelected: selectedSongIds.contains(song.id!),
                            isMultiSelectMode: _isActuallyMultiSelectMode,
                          );
                        }
                      },
                    );
                  } else {
                    return ListView.builder(
                      cacheExtent: 2000,
                      controller: _scrollController,
                      itemCount: songsToDisplay.length,
                      itemBuilder: (context, index) {
                        final song = songsToDisplay[index];
                        return SongListItem(
                          song: song,
                          index: index + 1, // Display index
                          onPlay: () => playSong(song),
                          onToggleFavorite: () => toggleFavorite(song),
                          onDelete: () => deleteSong(song),
                          onAddToNext: () => addToNext(song),
                          onSelect: () => toggleSelection(song.id!),
                          isSelected: selectedSongIds.contains(song.id!),
                          isMultiSelectMode: _isActuallyMultiSelectMode,
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Abstract method: get page title
  String getPageTitle();

  // Abstract method: get AppBar actions for normal mode
  List<Widget> getAppBarActions() {
    return [];
  }

  // Abstract method: get empty message
  String getEmptyMessage();
}
