#需求分析
我和另一位团队成员准备开发一款windows上的，基于flutter的本地音乐播放器，以下是功能需求：除了基本的播放功能外，能导入文件夹（扫描给定路径下的歌曲，常见格式）、导入单曲、多首歌曲、具备”我喜欢“功能，自定义音乐收藏夹功能（包括收藏夹封面自定义和标题自定义，封面默认为最新收藏歌曲的封面，收藏夹内可以按加入时间、字母序排序），显示所有歌曲功能（按字母序排序,a-z），主题功能，可以统一切换应用整体的颜色风格，应用设计风格现代化，简约，按钮多用svg的icon直接表示。
页面方面，除了歌曲播放页面，在UI左侧是导航栏，UI底部是播放状态控制栏。
控制栏包括进度条，播放暂停按钮、上一曲、下一曲，随机/单曲循环/顺序播放/循环所有的切换功能，一个爱心按钮，切换歌曲的喜欢状态，一个收藏按钮，点击后弹出一个小窗，显示当前的收藏夹并可以收藏当前歌曲到指定的收藏夹，且这个小窗顶部的区域中是一个按钮，点击后弹出“新建收藏”小窗，根据输入的名称创建新的收藏夹并将歌曲收藏进新建的收藏夹，一个展开按钮，切换当前页面为歌曲播放页面，这个展开按钮是一个矩形区域，显示歌曲封面和曲名、歌手名，若长度不够，用滚动方式显示；
导航栏包括”所有歌曲“，”我喜欢“，”收藏夹“（在导航栏中可折叠，即折叠状态下只显示“收藏夹”三个字，点击按钮展开后显示所有收藏夹，封面和名称，在展开/收回按钮旁边是一个加号，打开“新建收藏”小窗创建新的收藏夹），”播放列表“（显示当前的播放列表，支持调整歌曲的顺序）。
歌曲播放页面左上角是收回主界面按钮，页面左侧是大图的歌曲封面，用圆角矩形，封面下方是播放控制区，功能和上面提到的播放状态控制栏基本相同，只是没有展开按钮功能，页面右侧上方是曲名、歌手名、专辑名，中间是歌曲歌词显示区域，解析lrc歌词文件一句句滚动显示，自动检测歌曲目录下有无同名lrc歌词，有则显示，无则显示“暂无歌词”，点击歌词的某一句可以跳转到对应位置，页面底色由提取封面颜色而来，若无封面则默认为应用主题色。
在收藏夹、我喜欢、所有歌曲及播放列表页面，均以列表形式显示歌曲，列表的每一项样式为，最左侧显示序号，然后是歌曲封面，然后是曲名和歌手，这两个竖直显示，一上一下，然后列表项从右边开始的大概1/3处显示歌曲专辑名称，右侧先是一个爱心按钮，toggle歌曲的喜欢状态，最右是歌曲时长，列表项需要支持右键弹出一个菜单，圆角，颜色与整体风格一致，内容包括“下一首播放”，“加入收藏夹”（与上面播放状态控制栏的收藏按钮功能一致），“播放”（直接播放这首歌曲，如不是在播放列表页面进行的操作，则播放列表替换为当前页面的歌曲），“删除”（如在所有歌曲页面，弹窗显示是否删除本地歌曲文件，如在收藏夹、我喜欢、播放列表页面，则弹窗显示是否从当前列表中删除此歌曲）。
为了提高性能，在进入各个歌曲页面时，异步加载歌曲列表（若歌曲较多，在加载期间先显示一个旋转的加载图标并提示正在加载...），列表项的歌曲封面只加载显示区域部分的歌曲封面略缩图，其他歌曲的封面略缩图只在滚动到显示该项时才加载，若无略缩图，则生成略缩图并存储在程序目录下的thumbs文件夹，文件名为歌曲路径的MD5哈希值，格式为webp。歌曲信息、应用配置信息、收藏夹、我喜欢等信息统一使用sqlite数据库存储在应用目录下。

你先设计flutter应用的各个模块，无需给出具体的代码，给出数据库表结构、模块划分、页面划分、数据结构、model、view以及项目结构，以分工，我们两名成员分别负责前后端（即界面逻辑和后台处理逻辑），因此各模块界面需要清晰，前后端界面清晰，耦合度低，给出后端需要实现的给前端调用的所有接口。

---

以下是为你们设计的基于 Flutter 的 Windows 本地音乐播放器应用的模块设计，包括数据库表结构、模块划分、页面划分、数据结构、Model、View 以及项目结构。为了方便你和另一位团队成员分工开发，我将明确前后端的职责，确保接口清晰、耦合度低，并提供后端需要实现的接口列表。

---

### 1. 数据库表结构
我们将使用 SQLite 数据库存储应用数据，数据库文件存储在应用目录下。以下是表结构设计：

#### 1.1 歌曲表 (Songs)
- `id` INTEGER PRIMARY KEY AUTOINCREMENT  
- `path` TEXT NOT NULL UNIQUE (歌曲文件路径)  
- `title` TEXT (曲名)  
- `artist` TEXT (歌手)  
- `album` TEXT (专辑)  
- `duration` INTEGER (时长，单位：秒)  
- `cover_path` TEXT (封面图片路径，若无则为空)  
- `is_favorite` BOOLEAN DEFAULT 0 (是否为“我喜欢”)  

#### 1.2 收藏夹表 (Playlists)
- `id` INTEGER PRIMARY KEY AUTOINCREMENT  
- `name` TEXT NOT NULL (收藏夹名称)  
- `cover_path` TEXT (封面路径，默认使用最新收藏歌曲的封面)  
- `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP (创建时间)  

#### 1.3 收藏夹歌曲关联表 (PlaylistSongs)
- `playlist_id` INTEGER  
- `song_id` INTEGER  
- `added_at` DATETIME DEFAULT CURRENT_TIMESTAMP (添加时间，用于按加入时间排序)  
- PRIMARY KEY (playlist_id, song_id)  
- FOREIGN KEY (playlist_id) REFERENCES Playlists(id)  
- FOREIGN KEY (song_id) REFERENCES Songs(id)  

#### 1.4 配置表 (Settings)
- `key` TEXT PRIMARY KEY (配置键，如 "theme_color")  
- `value` TEXT (配置值，如主题颜色值)  

---

### 2. 模块划分
应用分为以下主要模块：

- **音乐扫描与导入模块**：扫描指定路径下的音乐文件（支持常见格式），提取元数据并存入数据库，支持导入文件夹、单曲或多首歌曲。  
- **播放控制模块**：管理播放、暂停、上一曲、下一曲，以及播放模式（随机、单曲循环、顺序播放、循环所有）。  
- **收藏夹管理模块**：管理收藏夹的创建、编辑、删除，以及歌曲的添加、移除，支持按加入时间或字母序排序。  
- **我喜欢模块**：管理用户喜欢的歌曲列表。  
- **主题管理模块**：管理应用的主题颜色，支持统一切换风格。  
- **页面导航模块**：管理页面切换和导航栏交互。  
- **歌词解析与显示模块**：解析 LRC 歌词文件并在播放时滚动显示，支持跳转到指定时间。  
- **歌曲列表加载模块**：异步加载歌曲列表，支持延迟加载封面缩略图，提升性能。  

---

### 3. 页面划分
应用包含以下主要页面：

- **主页面**：包含左侧导航栏和底部播放状态控制栏，内容区域根据导航切换。  
- **所有歌曲页面**：显示所有歌曲列表，按字母序 (A-Z) 排序。  
- **我喜欢页面**：显示用户喜欢的歌曲列表。  
- **收藏夹页面**：显示所有收藏夹，点击进入具体收藏夹的歌曲列表。  
- **播放列表页面**：显示当前播放列表，支持拖动调整顺序。  
- **歌曲播放页面**：显示歌曲封面、歌词、播放控制等，底色根据封面提取或使用主题色。  

---

### 4. 数据结构与 Model
以下是核心数据模型的设计：

#### 4.1 SongModel
```dart
class SongModel {
  int id;
  String path;
  String title;
  String artist;
  String album;
  int duration;
  String coverPath; // 封面路径，若无则为空
  bool isFavorite;
}
```

#### 4.2 PlaylistModel
```dart
class PlaylistModel {
  int id;
  String name;
  String coverPath; // 默认使用最新收藏歌曲的封面
  DateTime createdAt;
  List<SongModel> songs;
}
```

#### 4.3 SettingsModel
```dart
class SettingsModel {
  String themeColor; // 主题颜色值
}
```

---

### 5. View 设计
应用的 UI 设计遵循现代化、简约风格，按钮多使用 SVG 图标表示。以下是主要视图设计：

#### 5.1 导航栏
- 位置：UI 左侧  
- 内容：
  - “所有歌曲”
  - “我喜欢”
  - “收藏夹”（可折叠，展开时显示所有收藏夹的封面和名称，旁边有加号按钮创建新收藏夹）
  - “播放列表”

#### 5.2 播放状态控制栏
- 位置：UI 底部  
- 内容：
  - 进度条
  - 播放/暂停、上一曲、下一曲按钮
  - 播放模式切换按钮（随机/单曲循环/顺序播放/循环所有）
  - 爱心按钮（切换“我喜欢”状态）
  - 收藏按钮（弹出收藏夹选择小窗，顶部有“新建收藏”按钮）
  - 展开按钮（矩形区域，显示封面、曲名、歌手名，超长时滚动显示，点击切换到歌曲播放页面）

#### 5.3 歌曲列表项
- 样式：
  - 最左侧：序号
  - 左侧：封面缩略图
  - 中间：曲名（上）、歌手（下）
  - 右侧 1/3：专辑名
  - 右侧：爱心按钮、时长
- 交互：右键弹出圆角菜单（“下一首播放”、“加入收藏夹”、“播放”、“删除”）

#### 5.4 歌曲播放页面
- 左上角：收回主界面按钮  
- 左侧：大图圆角矩形封面，下方是播放控制区（无展开按钮）  
- 右侧：上方显示曲名、歌手、专辑名，中间是歌词滚动显示区（支持点击跳转，无歌词时显示“暂无歌词”）  
- 底色：提取封面颜色，无封面时使用主题色  

---

### 6. 项目结构
以下是推荐的项目目录结构：

```
lib/
├── models/
│   ├── song_model.dart
│   ├── playlist_model.dart
│   └── settings_model.dart
├── views/
│   ├── main_page.dart
│   ├── all_songs_page.dart
│   ├── favorites_page.dart
│   ├── playlists_page.dart
│   ├── playlist_detail_page.dart
│   ├── playback_list_page.dart
│   └── song_play_page.dart
├── widgets/
│   ├── navigation_bar.dart
│   ├── playback_control_bar.dart
│   ├── song_list_item.dart
│   └── lyrics_display.dart
├── services/
│   ├── music_scanner_service.dart  // 音乐扫描与导入
│   ├── playback_service.dart      // 播放控制
│   ├── playlist_service.dart      // 收藏夹管理
│   ├── favorites_service.dart     // 我喜欢管理
│   ├── theme_service.dart         // 主题管理
│   ├── lyrics_service.dart        // 歌词解析与显示
│   └── database_service.dart      // 数据库操作
├── utils/
│   ├── thumbnail_generator.dart   // 生成封面缩略图
│   └── lrc_parser.dart            // LRC 歌词解析
└── main.dart
```

封面缩略图存储在`final appDocDir = await getApplicationDocumentsDirectory();`这个貌似会返回win下面的文档文件夹？

程序目录下的 `appDocDir/JUSTMusic/thumbs/` 文件夹，文件名为歌曲路径的 MD5 哈希值，格式为 WebP，数据库文件放在`appDocDir/JUSTMusic/db/`

---

### 7. 后端接口设计
后端（后台处理逻辑）负责核心功能实现，并为前端（界面逻辑）提供以下接口：

#### 7.1 音乐扫描与导入
- `Future<List<SongModel>> scanMusic(String path)`：扫描指定路径下的音乐文件，返回歌曲列表。  
- `Future<void> importSongs(List<String> paths)`：导入指定路径的歌曲文件到数据库。  

#### 7.2 播放控制
- `Future<void> playSong(SongModel song)`：播放指定歌曲。  
- `Future<void> pause()`：暂停播放。  
- `Future<void> resume()`：继续播放。  
- `Future<void> next()`：播放下一曲。  
- `Future<void> previous()`：播放上一曲。  
- `Future<void> setPlaybackMode(PlaybackMode mode)`：设置播放模式（枚举：Random, SingleLoop, Sequential, LoopAll）。  
- `Stream<PlaybackState> get playbackStateStream`：获取播放状态流（包含当前歌曲、进度、状态等）。  
- `Future<void> seekTo(int seconds)`：跳转到指定时间。  

#### 7.3 收藏夹管理
- `Future<List<PlaylistModel>> getPlaylists()`：获取所有收藏夹。  
- `Future<PlaylistModel> createPlaylist(String name, {String coverPath})`：创建新收藏夹，可选封面路径，默认使用最新加入歌曲的封面。  
- `Future<void> addSongToPlaylist(int playlistId, int songId)`：将歌曲添加到收藏夹。  
- `Future<void> removeSongFromPlaylist(int playlistId, int songId)`：从收藏夹移除歌曲。  
- `Future<void> deletePlaylist(int playlistId)`：删除收藏夹。  
- `Future<List<SongModel>> getPlaylistSongs(int playlistId, {String sortBy})`：获取收藏夹歌曲列表，支持排序（"added_at" 或 "title"）。  

#### 7.4 我喜欢
- `Future<List<SongModel>> getFavoriteSongs()`：获取我喜欢的歌曲列表。  
- `Future<void> toggleFavorite(int songId)`：切换歌曲的喜欢状态。  

#### 7.5 主题管理
- `Future<void> setThemeColor(String color)`：设置主题颜色。  
- `Future<String> getThemeColor()`：获取当前主题颜色。  

#### 7.6 歌词解析
- `Future<List<LrcLine>> parseLrc(String lrcContent)`：解析 LRC 歌词内容，返回歌词行列表。  
- `Future<String> getLrcForSong(SongModel song)`：检测并返回歌曲的 LRC 歌词内容，无则返回空字符串。  

#### 7.7 数据库操作
- `Future<void> initDatabase()`：初始化数据库。  
- `Future<List<SongModel>> getAllSongs()`：获取所有歌曲，按字母序排序。  
- `Future<SongModel> getSongById(int id)`：根据 ID 获取歌曲。  
- `Future<void> updateSong(SongModel song)`：更新歌曲信息。  
- `Future<void> deleteSong(int songId, {bool deleteFile})`：删除歌曲，可选择是否删除本地文件。  

#### 7.8 播放列表管理
- `Future<List<SongModel>> getPlaybackList()`：获取当前播放列表。  
- `Future<void> setPlaybackList(List<SongModel> songs)`：设置播放列表。  
- `Future<void> reorderPlaybackList(int oldIndex, int newIndex)`：调整播放列表顺序。  
- `Future<void> playNext(int songId)`：将歌曲加入下一首播放。  

#### 7.9 缩略图生成
- `Future<String> getThumbnail(String songPath)`：获取（若没有则生成）歌曲封面缩略图（使用webp格式），返回存储路径。  
- `Future<String> getThumbnail(int songid)`：获取（若没有则生成）歌曲封面缩略图（使用webp格式），返回存储路径。
---

### 8. 分工建议
- **前端（界面逻辑）**：  
  - 实现所有页面和组件的 UI（导航栏、播放控制栏、歌曲列表项等）。  
  - 处理用户交互（如右键菜单、收藏夹选择小窗、歌词点击跳转）。  
  - 调用后端接口获取数据并更新界面。  
  - 实现异步加载歌曲列表和封面缩略图的逻辑，显示加载动画。  
- **后端（后台处理逻辑）**：  
  - 实现音乐扫描、播放控制、数据库操作、歌词解析、缩略图生成等功能。  
  - 提供上述接口，确保数据处理高效且稳定。  
  - 管理 SQLite 数据库和文件操作（如删除本地歌曲文件）。  

`pubspec.yaml`:

```yaml
name: just_musica
description: A modern local music player for Windows built with Flutter.
version: 1.0.0
publish_to: 'none'

environment:
  sdk: '>=3.4.0 <4.0.0'  # 兼容 Flutter 3.29.0
  flutter: 3.29.0

dependencies:
  flutter:
    sdk: flutter
  # UI 相关
  cupertino_icons: ^1.0.8  # 用于默认图标
  flutter_svg: ^2.0.10     # 支持 SVG 图标
  provider: ^6.1.2         # 状态管理
  scrollable_positioned_list: ^0.3.2  # 歌词滚动显示
  cached_network_image: ^3.3.1  # 封面缓存加载

  # 文件与存储
  path_provider: ^2.1.5    # 获取应用目录
  sqflite: ^2.3.3          # SQLite 数据库
  file_picker: ^8.1.2      # 文件夹和文件选择
  permission_handler: ^11.3.1  # 文件权限管理

  # 音乐与元数据
  just_audio: ^0.9.40      # 音频播放
  audio_service: ^0.18.15  # 后台播放支持
  audiotags: ^2.0.0        # 读取音乐元数据（如封面、歌手等）

  # 工具
  crypto: ^3.0.5           # MD5 哈希用于缩略图命名
  image: ^4.2.0            # 图像处理（生成缩略图）
  webp: ^0.3.0             # WebP 格式支持
  get_it: ^7.7.0           # 依赖注入
  logger: ^2.4.0           # 日志记录

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0    # 代码静态分析
  build_runner: ^2.4.12    # 代码生成支持（若需要）

flutter:
  uses-material-design: true

  assets:
    - assets/icons/  # SVG 图标存放路径
    - assets/images/ # 其他图片资源
```

