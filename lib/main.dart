import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ==========================================
// 1. 全局状态
// ==========================================
String appVersion = "v1.0.0";

class ThemePreset {
  final String name;
  final Color background;
  final Color cardColor;
  final Color accent;
  final Color textColor;

  ThemePreset({required this.name, required this.background, required this.cardColor, required this.accent, required this.textColor});
}

final List<ThemePreset> themePresets = [
  ThemePreset(name: '深灰极简', background: const Color(0xFF121212), cardColor: const Color(0xFF222222), accent: const Color(0xFF9CA3AF), textColor: const Color(0xFFF3F4F6)),
  ThemePreset(name: '白天模式', background: const Color(0xFFF7F8FA), cardColor: const Color(0xFFFFFFFF), accent: const Color(0xFF3B82F6), textColor: const Color(0xFF1F2937)),
  ThemePreset(name: '黑底红韵', background: const Color(0xFF1A1A1A), cardColor: const Color(0xFF2C2C2C), accent: const Color(0xFFE54D42), textColor: Colors.white),
  ThemePreset(name: '午夜星空', background: const Color(0xFF0F172A), cardColor: const Color(0xFF1E293B), accent: const Color(0xFF3B82F6), textColor: const Color(0xFFE2E8F0)),
  ThemePreset(name: '护眼暗绿', background: const Color(0xFF121A15), cardColor: const Color(0xFF1B2B22), accent: const Color(0xFF10B981), textColor: const Color(0xFFD1D5DB)),
];

ValueNotifier<ThemePreset> currentTheme = ValueNotifier<ThemePreset>(themePresets[0]);
ValueNotifier<bool> showPercentMode = ValueNotifier<bool>(false);
ValueNotifier<String> appFontFamily = ValueNotifier<String>('sans-serif');
ValueNotifier<String?> customBackgroundImage = ValueNotifier<String?>(null);

// ==========================================
// 2. 数据管理
// ==========================================
class StorageManager {
  static const String _keyBooks = 'saved_books';
  static const String _keyNotes = 'saved_notes';
  static const String _keyBgImage = 'saved_bg_image';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    customBackgroundImage.value = prefs.getString(_keyBgImage);
  }
  static Future<void> saveBooks(List<BookModel> books) async { final prefs = await SharedPreferences.getInstance(); await prefs.setString(_keyBooks, jsonEncode(books.map((b) => b.toJson()).toList())); }
  static Future<List<BookModel>> loadBooks() async { final prefs = await SharedPreferences.getInstance(); final str = prefs.getString(_keyBooks); if (str == null) return []; return (jsonDecode(str) as List).map((json) => BookModel.fromJson(json)).toList(); }
  static Future<void> saveNotes(List<NoteItem> notes) async { final prefs = await SharedPreferences.getInstance(); await prefs.setString(_keyNotes, jsonEncode(notes.map((n) => n.toJson()).toList())); }
  static Future<List<NoteItem>> loadNotes() async { final prefs = await SharedPreferences.getInstance(); final str = prefs.getString(_keyNotes); if (str == null) return []; return (jsonDecode(str) as List).map((json) => NoteItem.fromJson(json)).toList(); }
  static Future<void> saveBgImage(String? path) async { final prefs = await SharedPreferences.getInstance(); if (path == null) { await prefs.remove(_keyBgImage); customBackgroundImage.value = null; } else { await prefs.setString(_keyBgImage, path); customBackgroundImage.value = path; } }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageManager.init();
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  appVersion = "v${packageInfo.version}";
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemePreset>(
      valueListenable: currentTheme, builder: (context, theme, child) {
        return ValueListenableBuilder<String>(
          valueListenable: appFontFamily, builder: (context, font, _) {
            final isLightMode = theme.name == '白天模式';
            return MaterialApp(
              title: 'TXT 阅读器', 
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                brightness: isLightMode ? Brightness.light : Brightness.dark,
                scaffoldBackgroundColor: theme.background, 
                fontFamily: font, 
                textTheme: TextTheme(
                  bodyLarge: TextStyle(fontWeight: FontWeight.w600, color: theme.textColor),
                  bodyMedium: TextStyle(fontWeight: FontWeight.w600, color: theme.textColor),
                  titleLarge: TextStyle(fontWeight: FontWeight.w600, color: theme.textColor),
                  titleMedium: TextStyle(fontWeight: FontWeight.w600, color: theme.textColor),
                ),
                appBarTheme: AppBarTheme(
                  backgroundColor: theme.background, 
                  elevation: 0,
                  iconTheme: IconThemeData(color: theme.textColor),
                  titleTextStyle: TextStyle(color: theme.textColor, fontSize: 20, fontWeight: FontWeight.w600, fontFamily: font),
                ),
                colorScheme: ColorScheme.fromSeed(seedColor: theme.accent, brightness: isLightMode ? Brightness.light : Brightness.dark),
              ),
              home: const MainScaffold(),
            );
          }
        );
      },
    );
  }
}

// ==========================================
// 3. 底层框架
// ==========================================
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});
  @override State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  @override
  Widget build(BuildContext context) {
    final theme = currentTheme.value;
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex, 
        children: const [
          BookshelfPage(), 
          NotepadPage(), 
          ExtensionPage()
        ]
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: theme.cardColor, 
        selectedItemColor: theme.accent, 
        unselectedItemColor: theme.textColor.withOpacity(0.5),
        currentIndex: _currentIndex, 
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.book), label: '书架'),
          BottomNavigationBarItem(icon: Icon(Icons.edit_note), label: '记事本'),
          BottomNavigationBarItem(icon: Icon(Icons.extension), label: '扩展'),
        ],
      ),
    );
  }
}

// ==========================================
// 4. 扩展页面
// ==========================================
class ExtensionPage extends StatefulWidget {
  const ExtensionPage({super.key});
  @override State<ExtensionPage> createState() => _ExtensionPageState();
}

class _ExtensionPageState extends State<ExtensionPage> {
  bool _isLoading = false;

  Future<void> _importFont() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: false, type: FileType.custom, allowedExtensions: ['ttf', 'otf']);
      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);
        String fontPath = result.files.single.path!;
        String fontName = p.basenameWithoutExtension(fontPath);
        File fontFile = File(fontPath);
        Uint8List fontData = await fontFile.readAsBytes();
        FontLoader fontLoader = FontLoader(fontName);
        fontLoader.addFont(Future.value(ByteData.view(fontData.buffer)));
        await fontLoader.load();
        appFontFamily.value = fontName;
        if (mounted) { 
          setState(() => _isLoading = false); 
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('字体 $fontName 导入成功！'))); 
        }
      }
    } catch (e) { 
      if (mounted) { 
        setState(() => _isLoading = false); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('字体导入失败: $e'))); 
      } 
    }
  }

  Future<void> _pickBackgroundImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) { 
        await StorageManager.saveBgImage(result.files.single.path!); 
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('阅读背景已更换！'))); 
      }
    } catch (e) { 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('设置失败: $e'))); 
    }
  }

  void _showConversionMenu() {
    final theme = currentTheme.value;
    showModalBottomSheet(
      context: context, 
      backgroundColor: theme.cardColor, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))), 
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0), 
                child: Text('选择转换格式', style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.bold))
              ),
              ListTile(leading: Icon(Icons.text_snippet, color: theme.accent), title: Text('任意文本转纯净 TXT', style: TextStyle(color: theme.textColor)), onTap: () { Navigator.pop(context); _convertFile('txt'); }),
              ListTile(leading: Icon(Icons.html, color: theme.accent), title: Text('文本转 HTML 网页', style: TextStyle(color: theme.textColor)), onTap: () { Navigator.pop(context); _convertFile('html'); }),
              ListTile(leading: Icon(Icons.code, color: theme.accent), title: Text('文本转 Markdown (MD)', style: TextStyle(color: theme.textColor)), onTap: () { Navigator.pop(context); _convertFile('md'); }),
              Divider(color: theme.textColor.withOpacity(0.1)),
              ListTile(leading: Icon(Icons.image, color: theme.accent), title: Text('图片转 Base64 代码', style: TextStyle(color: theme.textColor)), onTap: () { Navigator.pop(context); _convertFile('base64'); }),
            ]
          )
        );
      }
    );
  }

  Future<void> _convertFile(String targetFormat) async {
    try {
      FilePickerResult? sourceResult = await FilePicker.platform.pickFiles(allowMultiple: false, type: FileType.any);
      if (sourceResult == null || sourceResult.files.single.path == null) return;
      setState(() => _isLoading = true);
      File sourceFile = File(sourceResult.files.single.path!);
      String outContent = ''; String extension = targetFormat; Uint8List fileBytes;

      if (targetFormat == 'base64') {
        Uint8List bytes = await sourceFile.readAsBytes();
        outContent = base64Encode(bytes);
        fileBytes = Uint8List.fromList(utf8.encode(outContent));
        extension = 'txt'; 
      } else {
        String content = await sourceFile.readAsString();
        if (targetFormat == 'html') { outContent = '<!DOCTYPE html>\n<html>\n<head>\n<meta charset="utf-8">\n<title>Converted</title>\n</head>\n<body>\n<pre>\n$content\n</pre>\n</body>\n</html>'; }
        else if (targetFormat == 'md') { outContent = '# ${p.basenameWithoutExtension(sourceFile.path)}\n\n$content'; }
        else { outContent = content; }
        fileBytes = Uint8List.fromList(utf8.encode(outContent));
      }

      await FilePicker.platform.saveFile(dialogTitle: '保存文件', fileName: '${p.basenameWithoutExtension(sourceFile.path)}_转换.$extension', type: FileType.any, bytes: fileBytes);
      if (mounted) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('转换成功！'))); }
    } catch (e) { 
      if (mounted) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('失败: $e'))); } 
    }
  }

  Future<void> _createZip() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.any);
      if (result == null || result.files.isEmpty) return;
      setState(() => _isLoading = true);
      final archive = Archive();
      for (var file in result.files) {
        if (file.path == null) continue;
        File f = File(file.path!);
        Uint8List bytes = await f.readAsBytes();
        archive.addFile(ArchiveFile(p.basename(f.path), bytes.length, bytes));
      }
      final zipped = ZipEncoder().encode(archive);
      if (zipped == null) throw Exception('压缩失败');
      await FilePicker.platform.saveFile(dialogTitle: '保存 ZIP', fileName: '打包_${DateTime.now().millisecondsSinceEpoch}.zip', type: FileType.any, bytes: Uint8List.fromList(zipped));
      if (mounted) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('成功打包！'))); }
    } catch (e) { 
      if (mounted) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('失败: $e'))); } 
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = currentTheme.value;
    return Scaffold(
      appBar: AppBar(title: const Text('扩展')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('休闲娱乐', style: TextStyle(color: theme.accent, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                color: theme.cardColor, elevation: 0,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.gamepad, color: theme.textColor), 
                      title: Text('2048', style: TextStyle(color: theme.textColor)), 
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Game2048Page()))
                    ),
                    Divider(height: 1, color: theme.textColor.withOpacity(0.1)),
                    ListTile(
                      leading: Icon(Icons.grid_on, color: theme.textColor), 
                      title: Text('扫雷', style: TextStyle(color: theme.textColor)), 
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MinesweeperPage()))
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('外观与阅读', style: TextStyle(color: theme.accent, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                color: theme.cardColor, elevation: 0,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.wallpaper, color: theme.textColor), 
                      title: Text('设置阅读背景图', style: TextStyle(color: theme.textColor)), 
                      onTap: _pickBackgroundImage
                    ),
                    if (customBackgroundImage.value != null)
                      ListTile(
                        leading: const Icon(Icons.delete, color: Colors.redAccent), 
                        title: const Text('清除背景图', style: TextStyle(color: Colors.redAccent)), 
                        onTap: () async { await StorageManager.saveBgImage(null); setState(() {}); }
                      ),
                    Divider(height: 1, color: theme.textColor.withOpacity(0.1)),
                    ListTile(
                      leading: Icon(Icons.font_download, color: theme.textColor), 
                      title: Text('导入本地字体', style: TextStyle(color: theme.textColor)), 
                      onTap: _importFont
                    ),
                    Divider(height: 1, color: theme.textColor.withOpacity(0.1)),
                    ListTile(
                      leading: Icon(Icons.restore, color: theme.textColor), 
                      title: Text('恢复默认字体', style: TextStyle(color: theme.textColor)), 
                      onTap: () { appFontFamily.value = 'sans-serif'; }
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('工具箱', style: TextStyle(color: theme.accent, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                color: theme.cardColor, elevation: 0,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.transform, color: theme.textColor), 
                      title: Text('格式转换', style: TextStyle(color: theme.textColor)), 
                      onTap: _showConversionMenu
                    ),
                    Divider(height: 1, color: theme.textColor.withOpacity(0.1)),
                    ListTile(
                      leading: Icon(Icons.folder_zip, color: theme.textColor), 
                      title: Text('文件打包 (ZIP)', style: TextStyle(color: theme.textColor)), 
                      onTap: _createZip
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isLoading) Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}

// ==========================================
// 5. 2048
// ==========================================
class Game2048Page extends StatefulWidget {
  const Game2048Page({super.key});
  @override State<Game2048Page> createState() => _Game2048PageState();
}

class _Game2048PageState extends State<Game2048Page> {
  List<List<int>> _board = List.generate(4, (_) => List.filled(4, 0));
  int _score = 0; bool _isGameOver = false; final Random _random = Random();

  @override void initState() { super.initState(); _startGame(); }
  void _startGame() { setState(() { _board = List.generate(4, (_) => List.filled(4, 0)); _score = 0; _isGameOver = false; _addRandomTile(); _addRandomTile(); }); }
  void _addRandomTile() { List<List<int>> empty = []; for (int i = 0; i < 4; i++) for (int j = 0; j < 4; j++) if (_board[i][j] == 0) empty.add([i, j]); if (empty.isNotEmpty) { final cell = empty[_random.nextInt(empty.length)]; _board[cell[0]][cell[1]] = _random.nextDouble() > 0.9 ? 4 : 2; } }
  void _handleSwipe(String dir) {
    if (_isGameOver) return; bool moved = false; List<List<int>> newBoard = List.generate(4, (_) => List.filled(4, 0));
    if (dir == 'left' || dir == 'right') { for (int i = 0; i < 4; i++) { List<int> row = List.from(_board[i]); if (dir == 'right') row = row.reversed.toList(); List<int> newRow = _compress(row); if (dir == 'right') newRow = newRow.reversed.toList(); if (!_listEquals(_board[i], newRow)) moved = true; newBoard[i] = newRow; } } 
    else { for (int j = 0; j < 4; j++) { List<int> col = [_board[0][j], _board[1][j], _board[2][j], _board[3][j]]; if (dir == 'down') col = col.reversed.toList(); List<int> newCol = _compress(col); if (dir == 'down') newCol = newCol.reversed.toList(); for (int i = 0; i < 4; i++) { if (_board[i][j] != newCol[i]) moved = true; newBoard[i][j] = newCol[i]; } } }
    if (moved) setState(() { _board = newBoard; _addRandomTile(); _checkGameOver(); });
  }
  List<int> _compress(List<int> row) { List<int> newRow = row.where((x) => x != 0).toList(); for (int i = 0; i < newRow.length - 1; i++) { if (newRow[i] == newRow[i + 1]) { newRow[i] *= 2; _score += newRow[i]; newRow.removeAt(i + 1); } } while (newRow.length < 4) newRow.add(0); return newRow; }
  bool _listEquals(List<int> a, List<int> b) { for (int i = 0; i < a.length; i++) if (a[i] != b[i]) return false; return true; }
  void _checkGameOver() { for (int i = 0; i < 4; i++) for (int j = 0; j < 4; j++) { if (_board[i][j] == 0) return; if (i < 3 && _board[i][j] == _board[i + 1][j]) return; if (j < 3 && _board[i][j] == _board[i][j + 1]) return; } setState(() => _isGameOver = true); }
  
  Color _getTileColor(int value, ThemePreset theme) { final isLight = theme.name == '白天模式'; switch (value) { case 2: return isLight ? const Color(0xFFEEE4DA) : theme.cardColor; case 4: return isLight ? const Color(0xFFEDE0C8) : Colors.blueGrey.withOpacity(0.5); case 8: return const Color(0xFFF2B179); case 16: return const Color(0xFFF59563); case 32: return const Color(0xFFF67C5F); case 64: return const Color(0xFFF65E3B); case 128: return const Color(0xFFEDCF72); case 256: return const Color(0xFFEDCC61); case 512: return const Color(0xFFEDC850); case 1024: return const Color(0xFFEDC53F); case 2048: return const Color(0xFFEDC22E); default: return theme.cardColor; } }
  Color _getTextColor(int value, ThemePreset theme) { if (theme.name == '白天模式' && value <= 4) return theme.textColor; if (value <= 2) return theme.textColor; return Colors.white; }

  @override Widget build(BuildContext context) {
    final theme = currentTheme.value;
    return Scaffold(
      backgroundColor: theme.background, 
      appBar: AppBar(
        title: const Text('2048'), 
        actions: [
          Center(child: Text('得分: $_score', style: TextStyle(color: theme.accent, fontSize: 18, fontWeight: FontWeight.bold))), 
          IconButton(icon: const Icon(Icons.refresh), onPressed: _startGame)
        ]
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0), 
                child: GestureDetector(
                  onPanEnd: (details) { 
                    final velocity = details.velocity.pixelsPerSecond; 
                    if (velocity.dx.abs() > velocity.dy.abs()) { 
                      if (velocity.dx > 0) _handleSwipe('right'); else _handleSwipe('left'); 
                    } else { 
                      if (velocity.dy > 0) _handleSwipe('down'); else _handleSwipe('up'); 
                    } 
                  }, 
                  child: AspectRatio(
                    aspectRatio: 1, 
                    child: Container(
                      padding: const EdgeInsets.all(8), 
                      decoration: BoxDecoration(color: theme.cardColor.withOpacity(0.5), borderRadius: BorderRadius.circular(16)), 
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(), 
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8), 
                        itemCount: 16, 
                        itemBuilder: (context, index) { 
                          int row = index ~/ 4; int col = index % 4; int value = _board[row][col]; 
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200), 
                            curve: Curves.easeInOutCubic, 
                            decoration: BoxDecoration(
                              color: value == 0 ? theme.textColor.withOpacity(0.05) : _getTileColor(value, theme), 
                              borderRadius: BorderRadius.circular(8), 
                              boxShadow: value != 0 ? [BoxShadow(color: _getTileColor(value, theme).withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 2))] : []
                            ), 
                            child: Center(
                              child: AnimatedScale(
                                duration: const Duration(milliseconds: 200), 
                                scale: value == 0 ? 0.0 : 1.0, 
                                child: Text(value == 0 ? '' : '$value', style: TextStyle(color: _getTextColor(value, theme), fontSize: 24, fontWeight: FontWeight.bold))
                              )
                            )
                          ); 
                        }
                      )
                    )
                  )
                )
              )
            )
          ), 
          Padding(
            padding: const EdgeInsets.only(bottom: 30, top: 10), 
            child: Column(
              children: [
                _buildControlBtn(Icons.keyboard_arrow_up, 'up', theme), 
                Row(
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: [
                    _buildControlBtn(Icons.keyboard_arrow_left, 'left', theme), 
                    const SizedBox(width: 50), 
                    _buildControlBtn(Icons.keyboard_arrow_right, 'right', theme)
                  ]
                ), 
                _buildControlBtn(Icons.keyboard_arrow_down, 'down', theme)
              ]
            )
          )
        ]
      ),
    );
  }
  Widget _buildControlBtn(IconData icon, String direction, ThemePreset theme) { 
    return Container(
      margin: const EdgeInsets.all(4), 
      child: IconButton(
        onPressed: () => _handleSwipe(direction), 
        icon: Icon(icon, size: 36, color: theme.textColor), 
        style: IconButton.styleFrom(backgroundColor: theme.cardColor, padding: const EdgeInsets.all(12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))
      )
    ); 
  }
}

// ==========================================
// 6. 扫雷游戏
// ==========================================
class MinesweeperPage extends StatefulWidget {
  const MinesweeperPage({super.key});
  @override State<MinesweeperPage> createState() => _MinesweeperPageState();
}

class _MinesweeperPageState extends State<MinesweeperPage> {
  int _rows = 9; int _cols = 9; int _mines = 10;
  List<List<int>> _board = []; List<List<bool>> _revealed = []; List<List<bool>> _flagged = [];
  bool _gameOver = false; bool _win = false; final Random _random = Random();

  @override void initState() { super.initState(); _startGame(9, 9, 10); }

  void _startGame(int r, int c, int m) {
    setState(() {
      _rows = r; _cols = c; _mines = m;
      _board = List.generate(r, (_) => List.filled(c, 0));
      _revealed = List.generate(r, (_) => List.filled(c, false));
      _flagged = List.generate(r, (_) => List.filled(c, false));
      _gameOver = false; _win = false;
      int placed = 0;
      while (placed < m) { int i = _random.nextInt(r); int j = _random.nextInt(c); if (_board[i][j] != -1) { _board[i][j] = -1; placed++; } }
      for (int i = 0; i < r; i++) {
        for (int j = 0; j < c; j++) {
          if (_board[i][j] == -1) continue;
          int count = 0;
          for (int dr = -1; dr <= 1; dr++) for (int dc = -1; dc <= 1; dc++) { int ni = i + dr; int nj = j + dc; if (ni >= 0 && ni < r && nj >= 0 && nj < c && _board[ni][nj] == -1) count++; }
          _board[i][j] = count;
        }
      }
    });
  }

  void _reveal(int r, int c) {
    if (_gameOver || _win || _revealed[r][c] || _flagged[r][c]) return;
    setState(() {
      if (_board[r][c] == -1) { _gameOver = true; for (int i = 0; i < _rows; i++) for (int j = 0; j < _cols; j++) if (_board[i][j] == -1) _revealed[i][j] = true; return; }
      _floodFill(r, c); _checkWin();
    });
  }
  void _floodFill(int r, int c) { if (r < 0 || r >= _rows || c < 0 || c >= _cols || _revealed[r][c] || _flagged[r][c]) return; _revealed[r][c] = true; if (_board[r][c] == 0) { for (int dr = -1; dr <= 1; dr++) for (int dc = -1; dc <= 1; dc++) _floodFill(r + dr, c + dc); } }
  void _toggleFlag(int r, int c) { if (_gameOver || _win || _revealed[r][c]) return; setState(() => _flagged[r][c] = !_flagged[r][c]); }
  void _checkWin() { for (int i = 0; i < _rows; i++) for (int j = 0; j < _cols; j++) { if (_board[i][j] != -1 && !_revealed[i][j]) return; } setState(() => _win = true); }

  Color _getNumColor(int num, ThemePreset theme) { switch (num) { case 1: return Colors.blue; case 2: return Colors.green; case 3: return Colors.red; case 4: return Colors.purple; case 5: return Colors.brown; case 6: return Colors.teal; case 7: return Colors.black; case 8: return Colors.grey; default: return theme.textColor; } }

  void _showDifficultyMenu() {
    final theme = currentTheme.value;
    showModalBottomSheet(
      context: context, 
      backgroundColor: theme.cardColor, 
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            ListTile(title: Text('初级 (9x9, 10雷)', style: TextStyle(color: theme.textColor)), onTap: () { Navigator.pop(context); _startGame(9, 9, 10); }),
            ListTile(title: Text('中级 (16x16, 40雷)', style: TextStyle(color: theme.textColor)), onTap: () { Navigator.pop(context); _startGame(16, 16, 40); }),
            ListTile(title: Text('高级 (16x30, 99雷)', style: TextStyle(color: theme.textColor)), onTap: () { Navigator.pop(context); _startGame(16, 30, 99); }),
          ]
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = currentTheme.value;
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        title: const Text('扫雷'),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: _showDifficultyMenu),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _startGame(_rows, _cols, _mines)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_gameOver ? '💥 踩雷了！' : (_win ? '🎉 胜利！' : '🚩 标记地雷，长按插旗'), style: TextStyle(color: theme.accent, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: Column(
                    children: List.generate(_rows, (r) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_cols, (c) {
                          return GestureDetector(
                            onTap: () => _reveal(r, c),
                            onLongPress: () => _toggleFlag(r, c),
                            child: Container(
                              width: 32, height: 32,
                              margin: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                color: _revealed[r][c] ? theme.cardColor : theme.textColor.withOpacity(0.2),
                                border: Border.all(color: theme.background.withOpacity(0.5)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: _revealed[r][c]
                                    ? (_board[r][c] == -1 ? const Icon(Icons.dangerous, color: Colors.red, size: 20) : (_board[r][c] > 0 ? Text('${_board[r][c]}', style: TextStyle(color: _getNumColor(_board[r][c], theme), fontWeight: FontWeight.bold, fontSize: 16)) : const SizedBox()))
                                    : (_flagged[r][c] ? const Icon(Icons.flag, color: Colors.redAccent, size: 18) : const SizedBox()),
                              ),
                            ),
                          );
                        }),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 7. 记事本
// ==========================================
class NoteItem {
  String name; bool isFolder; List<NoteItem> children; String content;
  NoteItem({required this.name, this.isFolder = false, List<NoteItem>? children, this.content = ''}) : children = children ?? [];
  Map<String, dynamic> toJson() => {'name': name, 'isFolder': isFolder, 'content': content, 'children': children.map((c) => c.toJson()).toList()};
  factory NoteItem.fromJson(Map<String, dynamic> json) => NoteItem(name: json['name'], isFolder: json['isFolder'] ?? false, content: json['content'] ?? '', children: (json['children'] as List?)?.map((c) => NoteItem.fromJson(c)).toList() ?? []);
}

class NotepadPage extends StatefulWidget {
  const NotepadPage({super.key});
  @override State<NotepadPage> createState() => _NotepadPageState();
}

class _NotepadPageState extends State<NotepadPage> {
  List<NoteItem> _rootItems = []; List<NoteItem> _pathStack = [];
  bool _isSelectionMode = false; final Set<NoteItem> _selectedNotes = {};

  @override void initState() { super.initState(); _loadData(); }
  Future<void> _loadData() async { final notes = await StorageManager.loadNotes(); setState(() => _rootItems = notes); }
  void _save() async { await StorageManager.saveNotes(_rootItems); }
  List<NoteItem> get _currentList => _pathStack.isEmpty ? _rootItems : _pathStack.last.children;

  void _createItem(bool isFolder) {
    final controller = TextEditingController();
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        backgroundColor: currentTheme.value.cardColor, 
        title: Text(isFolder ? '新建文件夹' : '新建笔记', style: TextStyle(color: currentTheme.value.textColor)),
        content: TextField(controller: controller, autofocus: true, style: TextStyle(color: currentTheme.value.textColor), decoration: InputDecoration(hintText: isFolder ? '文件夹名称' : '笔记标题', hintStyle: TextStyle(color: currentTheme.value.textColor.withOpacity(0.5)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('取消', style: TextStyle(color: currentTheme.value.textColor.withOpacity(0.5)))),
          TextButton(onPressed: () { final name = controller.text.trim(); if (name.isNotEmpty) { setState(() { _currentList.add(NoteItem(name: name, isFolder: isFolder)); }); _save(); } Navigator.pop(context); }, child: Text('创建', style: TextStyle(color: currentTheme.value.accent))),
        ],
      )
    );
  }

  void _openNote(NoteItem note) {
    final controller = TextEditingController(text: note.content);
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        backgroundColor: currentTheme.value.cardColor, 
        title: Text(note.name, style: TextStyle(color: currentTheme.value.textColor)),
        content: SizedBox(width: double.maxFinite, height: 300, child: TextField(controller: controller, maxLines: null, expands: true, style: TextStyle(color: currentTheme.value.textColor), decoration: InputDecoration(border: InputBorder.none, hintText: '开始记录...', hintStyle: TextStyle(color: currentTheme.value.textColor.withOpacity(0.5))))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('取消', style: TextStyle(color: currentTheme.value.textColor.withOpacity(0.5)))),
          TextButton(onPressed: () { setState(() { note.content = controller.text; }); _save(); Navigator.pop(context); }, child: Text('保存', style: TextStyle(color: currentTheme.value.accent))),
        ],
      )
    );
  }

  void _getAllFolders(List<NoteItem> items, List<NoteItem> result) { for (var item in items) { if (item.isFolder) { result.add(item); _getAllFolders(item.children, result); } } }
  bool _removeItemFromTree(List<NoteItem> tree, NoteItem target) { if (tree.remove(target)) return true; for (var node in tree) { if (node.isFolder && _removeItemFromTree(node.children, target)) return true; } return false; }

  void _moveSelectedNotes() {
    List<NoteItem> allFolders = []; _getAllFolders(_rootItems, allFolders);
    showDialog(
      context: context, 
      builder: (context) => SimpleDialog(
        backgroundColor: currentTheme.value.cardColor, 
        title: Text('移动到...', style: TextStyle(color: currentTheme.value.textColor)),
        children: [
          SimpleDialogOption(onPressed: () { for (var item in _selectedNotes) { _removeItemFromTree(_rootItems, item); _rootItems.add(item); } _save(); setState(() { _isSelectionMode = false; _selectedNotes.clear(); }); Navigator.pop(context); }, child: Text('根目录', style: TextStyle(color: currentTheme.value.textColor))),
          ...allFolders.map((folder) { 
            if (_pathStack.contains(folder) || _selectedNotes.contains(folder)) return const SizedBox.shrink(); 
            return SimpleDialogOption(onPressed: () { for (var item in _selectedNotes) { if (item == folder) continue; _removeItemFromTree(_rootItems, item); folder.children.add(item); } _save(); setState(() { _isSelectionMode = false; _selectedNotes.clear(); }); Navigator.pop(context); }, child: Text(folder.name, style: TextStyle(color: currentTheme.value.textColor))); 
          })
        ],
      )
    );
  }

  void _deleteSelectedNotes() { setState(() { for (var item in _selectedNotes) { _removeItemFromTree(_rootItems, item); } _isSelectionMode = false; _selectedNotes.clear(); }); _save(); }

  @override Widget build(BuildContext context) {
    final theme = currentTheme.value;
    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode ? Text('已选 ${_selectedNotes.length} 项') : Text(_pathStack.isEmpty ? '记事本' : _pathStack.last.name),
        leading: _isSelectionMode 
            ? IconButton(icon: const Icon(Icons.close), onPressed: () { setState(() { _isSelectionMode = false; _selectedNotes.clear(); }); }) 
            : (_pathStack.isNotEmpty ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { setState(() { _pathStack.removeLast(); }); }) : null),
        actions: _isSelectionMode 
            ? [
                TextButton(
                  onPressed: () { setState(() { if (_selectedNotes.length == _currentList.length) _selectedNotes.clear(); else _selectedNotes.addAll(_currentList); }); }, 
                  child: Text('全选', style: TextStyle(color: theme.accent))
                )
              ] 
            : [
                IconButton(icon: const Icon(Icons.create_new_folder), onPressed: () => _createItem(true)), 
                IconButton(icon: const Icon(Icons.note_add), onPressed: () => _createItem(false))
              ],
      ),
      body: _currentList.isEmpty 
          ? Center(child: Text('空空的，点击右上角新建', style: TextStyle(color: theme.textColor.withOpacity(0.5)))) 
          : ListView.builder(
              itemCount: _currentList.length, 
              itemBuilder: (context, index) {
                final item = _currentList[index]; final isSelected = _selectedNotes.contains(item);
                return Container(
                  color: isSelected ? theme.accent.withOpacity(0.2) : Colors.transparent, 
                  child: ListTile(
                    leading: Icon(item.isFolder ? Icons.folder : Icons.insert_drive_file, color: isSelected ? theme.accent : (item.isFolder ? theme.accent : theme.textColor.withOpacity(0.5))),
                    title: Text(item.name, style: TextStyle(color: theme.textColor)),
                    onLongPress: () { if (!_isSelectionMode) setState(() { _isSelectionMode = true; _selectedNotes.add(item); }); },
                    onTap: () { 
                      if (_isSelectionMode) { 
                        setState(() { if (isSelected) _selectedNotes.remove(item); else _selectedNotes.add(item); if (_selectedNotes.isEmpty) _isSelectionMode = false; }); 
                      } else { 
                        if (item.isFolder) { setState(() { _pathStack.add(item); }); } else { _openNote(item); } 
                      } 
                    },
                  )
                );
              },
            ),
      bottomNavigationBar: _isSelectionMode 
          ? BottomAppBar(
              color: theme.cardColor, 
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround, 
                children: [
                  IconButton(icon: Icon(Icons.drive_file_move, color: theme.textColor), onPressed: _moveSelectedNotes), 
                  IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: _deleteSelectedNotes)
                ]
              )
            ) 
          : null,
    );
  }
}

// ==========================================
// 8. 数据模型与解析器
// ==========================================
class ChapterModel {
  final String title; final String content;
  ChapterModel({required this.title, required this.content});
}

class BookModel {
  String title; String filePath; List<ChapterModel> chapters;
  bool isFavorite; double progress; int currentChapterIndex; String group;
  BookModel({required this.title, required this.filePath, this.chapters = const [], this.isFavorite = false, this.progress = 0.0, this.currentChapterIndex = 0, this.group = '未分组'});
  Map<String, dynamic> toJson() => {'title': title, 'filePath': filePath, 'isFavorite': isFavorite, 'progress': progress, 'currentChapterIndex': currentChapterIndex, 'group': group};
  factory BookModel.fromJson(Map<String, dynamic> json) => BookModel(title: json['title'], filePath: json['filePath'] ?? '', isFavorite: json['isFavorite'] ?? false, progress: (json['progress'] as num?)?.toDouble() ?? 0.0, currentChapterIndex: json['currentChapterIndex'] ?? 0, group: json['group'] ?? '未分组');
}

String _decodeTxtBytes(Uint8List bytes) { try { return utf8.decode(bytes); } catch (_) { try { return gbk.decode(bytes); } catch (_) { return utf8.decode(bytes, allowMalformed: true); } } }

String _formatTextContent(String rawText) {
  final lines = rawText.split('\n'); final buffer = StringBuffer();
  for (var line in lines) {
    String trimmed = line.trim();
    if (trimmed.isEmpty) continue; 
    if (trimmed.length < 30 && trimmed.startsWith('第') && (trimmed.contains('章') || trimmed.contains('节'))) { buffer.writeln(trimmed); } 
    else { buffer.writeln('\u3000\u3000$trimmed'); }
    buffer.writeln(); 
  }
  return buffer.toString();
}

List<ChapterModel> parseTxtToChapters(String text) {
  final RegExp chapterRegex = RegExp(r'第[0-9一二三四五六七八九十百千万零两]+[章回节]\s*.*');
  List<ChapterModel> chapters = []; List<String> lines = text.split('\n');
  String currentTitle = '开始阅读'; StringBuffer currentContent = StringBuffer();
  for (String line in lines) {
    if (line.trim().length < 30 && chapterRegex.hasMatch(line.trim())) {
      if (currentContent.isNotEmpty) { chapters.add(ChapterModel(title: currentTitle, content: _formatTextContent(currentContent.toString()))); currentContent.clear(); }
      currentTitle = line.trim();
    } else { currentContent.writeln(line); }
  }
  if (currentContent.isNotEmpty) chapters.add(ChapterModel(title: currentTitle, content: _formatTextContent(currentContent.toString())));
  if (chapters.isEmpty) chapters.add(ChapterModel(title: '全文', content: _formatTextContent(text)));
  return chapters;
}

// ==========================================
// 9. 书架页面
// ==========================================
class BookshelfPage extends StatefulWidget {
  const BookshelfPage({super.key});
  @override State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  List<BookModel> _books = [];
  List<String> _groups = ['全部', '喜爱', '未分组'];
  String _currentCategory = '全部';
  bool _isSelectionMode = false; final Set<int> _selectedIndexes = {};
  bool _isLoading = false; String _searchQuery = '';

  @override void initState() { super.initState(); _loadData(); }
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final books = await StorageManager.loadBooks();
    setState(() {
      _books = books;
      for (var b in books) { if (!_groups.contains(b.group) && b.group.isNotEmpty) _groups.add(b.group); }
      _isLoading = false;
    });
  }
  void _saveData() async { await StorageManager.saveBooks(_books); }

  List<BookModel> get _filteredBooks {
    var books = _books;
    if (_searchQuery.isNotEmpty) books = books.where((b) => b.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    if (_currentCategory == '全部') return books;
    if (_currentCategory == '喜爱') return books.where((b) => b.isFavorite).toList();
    return books.where((b) => b.group == _currentCategory).toList();
  }

  Future<void> _importBook() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.any);
      if (result != null && result.files.isNotEmpty) {
        setState(() => _isLoading = true);
        for (var file in result.files) {
          if (file.path == null) continue;
          setState(() { _books.add(BookModel(title: p.basenameWithoutExtension(file.name), filePath: file.path!)); });
        }
        _saveData();
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导入成功！')));
      }
    } catch (e) {
      if (mounted) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导入失败'))); }
    }
  }

  void _showBookMenu(BookModel book, int originalIndex) {
    final theme = currentTheme.value;
    showModalBottomSheet(
      context: context, 
      backgroundColor: theme.cardColor, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))), 
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              ListTile(
                leading: Icon(book.isFavorite ? Icons.favorite : Icons.favorite_border, color: book.isFavorite ? theme.accent : theme.textColor), 
                title: Text(book.isFavorite ? '取消喜爱' : '加入喜爱', style: TextStyle(color: theme.textColor)), 
                onTap: () { setState(() { book.isFavorite = !book.isFavorite; }); _saveData(); Navigator.pop(context); }
              ),
              ListTile(
                leading: Icon(Icons.edit_outlined, color: theme.textColor), 
                title: Text('重命名', style: TextStyle(color: theme.textColor)), 
                onTap: () { Navigator.pop(context); _showRenameDialog(book); }
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent), 
                title: const Text('从书架移除', style: TextStyle(color: Colors.redAccent)), 
                onTap: () { setState(() { _books.removeAt(originalIndex); }); _saveData(); Navigator.pop(context); }
              ),
            ]
          )
        );
      }
    );
  }

  void _showRenameDialog(BookModel book) {
    final controller = TextEditingController(text: book.title);
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        backgroundColor: currentTheme.value.cardColor, 
        title: Text('重命名', style: TextStyle(color: currentTheme.value.textColor)),
        content: TextField(controller: controller, autofocus: true, style: TextStyle(color: currentTheme.value.textColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(onPressed: () { setState(() { if (controller.text.trim().isNotEmpty) book.title = controller.text.trim(); }); _saveData(); Navigator.pop(context); }, child: const Text('确定')),
        ],
      )
    );
  }

  void _showSearchDialog() {
    final controller = TextEditingController(text: _searchQuery);
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        backgroundColor: currentTheme.value.cardColor, 
        title: Text('搜索书名', style: TextStyle(color: currentTheme.value.textColor)),
        content: TextField(controller: controller, autofocus: true, style: TextStyle(color: currentTheme.value.textColor), decoration: const InputDecoration(hintText: '输入书名...', prefixIcon: Icon(Icons.search)), onChanged: (val) { setState(() { _searchQuery = val; }); }),
        actions: [
          TextButton(onPressed: () { setState(() { _searchQuery = ''; }); Navigator.pop(context); }, child: const Text('清除')),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('关闭', style: TextStyle(color: currentTheme.value.accent))),
        ],
      )
    );
  }

  void _showCreateGroupDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        backgroundColor: currentTheme.value.cardColor, 
        title: Text('新建分组', style: TextStyle(color: currentTheme.value.textColor)),
        content: TextField(controller: controller, autofocus: true, style: TextStyle(color: currentTheme.value.textColor), decoration: const InputDecoration(hintText: '输入名称')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(onPressed: () { final name = controller.text.trim(); if (name.isNotEmpty && !_groups.contains(name) && name != '全部' && name != '喜爱') { setState(() { _groups.add(name); }); } Navigator.pop(context); }, child: Text('创建', style: TextStyle(color: currentTheme.value.accent))),
        ],
      )
    );
  }

  void _moveSelectedToGroup() {
    showDialog(
      context: context, 
      builder: (context) => SimpleDialog(
        backgroundColor: currentTheme.value.cardColor, 
        title: Text('移动到...', style: TextStyle(color: currentTheme.value.textColor)),
        children: _groups.where((g) => g != '全部' && g != '喜爱').map((group) => SimpleDialogOption(
          onPressed: () { setState(() { for (var idx in _selectedIndexes) { _books[idx].group = group; } _isSelectionMode = false; _selectedIndexes.clear(); }); _saveData(); Navigator.pop(context); },
          child: Text(group, style: TextStyle(color: currentTheme.value.textColor)),
        )).toList(),
      )
    );
  }

  void _deleteSelectedBooks() {
    setState(() { var indexes = _selectedIndexes.toList()..sort((a, b) => b.compareTo(a)); for (var idx in indexes) { _books.removeAt(idx); } _isSelectionMode = false; _selectedIndexes.clear(); });
    _saveData();
  }

  @override Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemePreset>(
      valueListenable: currentTheme, builder: (context, theme, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: showPercentMode, builder: (context, isPercentMode, _) {
            final displayBooks = _filteredBooks;
            return Scaffold(
              appBar: AppBar(
                title: _isSelectionMode 
                    ? Text('已选 ${_selectedIndexes.length} 项', style: const TextStyle(fontSize: 18)) 
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('书架'),
                          const SizedBox(width: 8),
                          Text(appVersion, style: TextStyle(fontSize: 12, color: theme.textColor.withOpacity(0.5))),
                        ],
                      ),
                leading: _isSelectionMode 
                    ? IconButton(
                        icon: const Icon(Icons.close), 
                        onPressed: () { setState(() { _isSelectionMode = false; _selectedIndexes.clear(); }); }
                      ) 
                    : null,
                bottom: _isSelectionMode 
                    ? null 
                    : PreferredSize(
                        preferredSize: const Size.fromHeight(46.0), 
                        child: Container(
                          height: 46, 
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal, 
                            padding: const EdgeInsets.symmetric(horizontal: 16.0), 
                            child: Row(
                              children: [
                                ..._groups.map((group) => Padding(padding: const EdgeInsets.only(right: 8.0), child: _buildFolderChip(group, theme))),
                                GestureDetector(
                                  onTap: _showCreateGroupDialog, 
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), 
                                    decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)), 
                                    child: Icon(Icons.add, size: 16, color: theme.textColor)
                                  )
                                ),
                              ]
                            )
                          )
                        )
                      ),
                actions: _isSelectionMode 
                    ? [
                        TextButton(
                          onPressed: () { 
                            setState(() { 
                              if (_selectedIndexes.length == _filteredBooks.length) _selectedIndexes.clear(); 
                              else for (int i = 0; i < _books.length; i++) if (_filteredBooks.contains(_books[i])) _selectedIndexes.add(i); 
                            }); 
                          }, 
                          child: Text('全选', style: TextStyle(color: theme.accent))
                        )
                      ] 
                    : [
                        IconButton(icon: Icon(Icons.search, color: theme.textColor), onPressed: _showSearchDialog),
                        IconButton(icon: Icon(isPercentMode ? Icons.percent : Icons.format_list_numbered, color: theme.textColor), onPressed: () => showPercentMode.value = !showPercentMode.value),
                        IconButton(
                          icon: Icon(Icons.palette_outlined, color: theme.textColor), 
                          onPressed: () {
                            showDialog(
                              context: context, 
                              builder: (context) => AlertDialog(
                                backgroundColor: theme.cardColor, 
                                title: Text('选择主题', style: TextStyle(color: theme.textColor)), 
                                content: SizedBox(
                                  width: double.maxFinite, 
                                  child: ListView.builder(
                                    shrinkWrap: true, 
                                    itemCount: themePresets.length, 
                                    itemBuilder: (context, index) { 
                                      final preset = themePresets[index]; 
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0), 
                                        child: ListTile(
                                          tileColor: preset.background, 
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), 
                                          title: Text(preset.name, style: TextStyle(color: preset.textColor, fontWeight: FontWeight.bold)), 
                                          trailing: currentTheme.value.name == preset.name ? Icon(Icons.check, color: preset.accent) : null, 
                                          onTap: () { currentTheme.value = preset; Navigator.pop(context); }
                                        )
                                      ); 
                                    }
                                  )
                                )
                              )
                            );
                          }
                        ),
                        IconButton(icon: Icon(Icons.add, color: theme.textColor), onPressed: _importBook),
                      ],
              ),
              body: Stack(
                children: [
                  displayBooks.isEmpty 
                      ? Center(child: Text('没有找到书籍', style: TextStyle(color: theme.textColor.withOpacity(0.5)))) 
                      : GridView.builder(
                          padding: const EdgeInsets.all(16), 
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.52, crossAxisSpacing: 16, mainAxisSpacing: 20), 
                          itemCount: displayBooks.length,
                          itemBuilder: (context, index) {
                            final book = displayBooks[index]; 
                            final originalIndex = _books.indexOf(book); 
                            final isSelected = _selectedIndexes.contains(originalIndex);
                            return GestureDetector(
                              onTap: () {
                                if (_isSelectionMode) { 
                                  setState(() { if (isSelected) _selectedIndexes.remove(originalIndex); else _selectedIndexes.add(originalIndex); if (_selectedIndexes.isEmpty) _isSelectionMode = false; }); 
                                } else { 
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => ReaderPage(book: book))).then((_) { _saveData(); setState((){}); }); 
                                }
                              },
                              onLongPress: () { if (!_isSelectionMode) setState(() { _isSelectionMode = true; _selectedIndexes.add(originalIndex); }); },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start, 
                                children: [
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: double.infinity, 
                                          height: double.infinity, 
                                          decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(8), border: isSelected ? Border.all(color: theme.accent, width: 2.0) : null), 
                                          child: Center(child: Icon(Icons.book, size: 40, color: theme.textColor.withOpacity(0.3)))
                                        ),
                                        if (isSelected) 
                                          Positioned(
                                            top: 8, left: 8, 
                                            child: Container(decoration: BoxDecoration(color: theme.accent, shape: BoxShape.circle), child: const Icon(Icons.check, size: 20, color: Colors.white))
                                          ),
                                        Positioned(
                                          right: 0, bottom: 0, 
                                          child: IconButton(icon: const Icon(Icons.more_horiz, color: Colors.grey, size: 20), onPressed: () => _showBookMenu(book, originalIndex))
                                        ),
                                      ]
                                    )
                                  ),
                                  const SizedBox(height: 8),
                                  Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: theme.textColor)),
                                  const SizedBox(height: 4),
                                  Text(
                                    isPercentMode ? '已读 ${(book.progress * 100).toStringAsFixed(1)}%' : '第 ${book.currentChapterIndex + 1} 章', 
                                    style: TextStyle(fontSize: 12, color: theme.textColor.withOpacity(0.5))
                                  ),
                                ]
                              ),
                            );
                          },
                        ),
                  if (_isLoading) 
                    Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator())),
                ]
              ),
              bottomNavigationBar: _isSelectionMode 
                  ? BottomAppBar(
                      color: theme.cardColor, 
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround, 
                        children: [
                          IconButton(icon: Icon(Icons.drive_file_move, color: theme.textColor), onPressed: _moveSelectedToGroup), 
                          IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: _deleteSelectedBooks)
                        ]
                      )
                    ) 
                  : null,
            );
          }
        );
      }
    );
  }

  Widget _buildFolderChip(String text, ThemePreset theme) {
    final isSelected = _currentCategory == text;
    return GestureDetector(
      onTap: () => setState(() => _currentCategory = text), 
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), 
        decoration: BoxDecoration(color: isSelected ? theme.accent : theme.cardColor, borderRadius: BorderRadius.circular(16)), 
        child: Center(child: Text(text, style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : theme.textColor)))
      )
    );
  }
}

// ==========================================
// 10. 阅读页面
// ==========================================
class ReaderPage extends StatefulWidget {
  final BookModel book;
  const ReaderPage({super.key, required this.book});
  @override State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  bool _showMenu = false; 
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  double _brightness = 1.0; double _fontSize = 18.0; double _lineHeight = 1.8; double _letterSpacing = 1.0; double _horizontalMargin = 24.0;
  List<int> _bookmarks = []; bool _isAscending = true; bool _isLoading = true;

  List<ChapterModel> get _chapters => widget.book.chapters;

  @override void initState() {
    super.initState();
    _loadBookContent();
    _itemPositionsListener.itemPositions.addListener(() {
      final positions = _itemPositionsListener.itemPositions.value;
      if (positions.isNotEmpty) {
        final firstVisible = positions.reduce((a, b) => a.index < b.index ? a : b);
        if (firstVisible.index != widget.book.currentChapterIndex) {
          setState(() { widget.book.currentChapterIndex = firstVisible.index; });
        }
      }
    });
  }

  Future<void> _loadBookContent() async {
    if (_chapters.isNotEmpty) { 
      setState(() => _isLoading = false); 
      _scrollToChapter(widget.book.currentChapterIndex, jump: true);
      return; 
    }
    try {
      File file = File(widget.book.filePath);
      if (await file.exists()) {
        Uint8List bytes = await file.readAsBytes();
        String content = _decodeTxtBytes(bytes);
        List<ChapterModel> parsed = parseTxtToChapters(content);
        setState(() { widget.book.chapters = parsed; _isLoading = false; });
        _scrollToChapter(widget.book.currentChapterIndex, jump: true);
      } else {
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('原文件已被删除')));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('读取失败: $e')));
    }
  }

  void _scrollToChapter(int index, {bool jump = false}) {
    if (index >= 0 && index < _chapters.length) {
      if (_itemScrollController.isAttached) {
        _itemScrollController.scrollTo(index: index, duration: jump ? Duration.zero : const Duration(milliseconds: 300), curve: Curves.easeInOut);
        setState(() => widget.book.currentChapterIndex = index);
      }
    }
  }

  void _toggleBookmark() { 
    setState(() { 
      if (_bookmarks.contains(widget.book.currentChapterIndex)) { _bookmarks.remove(widget.book.currentChapterIndex); }
      else { _bookmarks.add(widget.book.currentChapterIndex); } 
    }); 
  }

  void _showSettingsPanel() {
    final theme = currentTheme.value;
    showModalBottomSheet(
      context: context, 
      backgroundColor: theme.cardColor, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))), 
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPanelState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0), 
                child: Column(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    Text('排版设置', style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.bold)), 
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('字号', style: TextStyle(color: theme.textColor.withOpacity(0.7))), 
                        Expanded(child: Slider(value: _fontSize, min: 12.0, max: 32.0, activeColor: theme.accent, inactiveColor: theme.textColor.withOpacity(0.2), onChanged: (val) { setPanelState(() => _fontSize = val); setState((){}); })), 
                        Text('${_fontSize.toInt()}', style: TextStyle(color: theme.textColor))
                      ]
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text('行距', style: TextStyle(color: theme.textColor.withOpacity(0.7), fontSize: 13)), 
                              Expanded(child: Slider(value: _lineHeight, min: 1.0, max: 3.0, activeColor: theme.accent, inactiveColor: theme.textColor.withOpacity(0.2), onChanged: (val) { setPanelState(() => _lineHeight = val); setState((){}); }))
                            ]
                          )
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Text('字距', style: TextStyle(color: theme.textColor.withOpacity(0.7), fontSize: 13)), 
                              Expanded(child: Slider(value: _letterSpacing, min: 0.0, max: 5.0, activeColor: theme.accent, inactiveColor: theme.textColor.withOpacity(0.2), onChanged: (val) { setPanelState(() => _letterSpacing = val); setState((){}); }))
                            ]
                          )
                        ),
                      ]
                    ),
                    Row(
                      children: [
                        Text('边距', style: TextStyle(color: theme.textColor.withOpacity(0.7))), 
                        Expanded(child: Slider(value: _horizontalMargin, min: 8.0, max: 48.0, activeColor: theme.accent, inactiveColor: theme.textColor.withOpacity(0.2), onChanged: (val) { setPanelState(() => _horizontalMargin = val); setState((){}); })), 
                        Text('${_horizontalMargin.toInt()}', style: TextStyle(color: theme.textColor))
                      ]
                    ),
                    Row(
                      children: [
                        Icon(Icons.brightness_2, color: theme.textColor.withOpacity(0.5), size: 20), 
                        Expanded(child: Slider(value: _brightness, min: 0.2, max: 1.0, activeColor: theme.accent, inactiveColor: theme.textColor.withOpacity(0.2), onChanged: (val) { setPanelState(() => _brightness = val); setState((){}); })), 
                        Icon(Icons.brightness_5, color: theme.textColor.withOpacity(0.5), size: 20)
                      ]
                    ),
                  ]
                )
              )
            );
          }
        );
      }
    );
  }

  void _showCatalog() {
    final theme = currentTheme.value;
    showModalBottomSheet(
      context: context, 
      backgroundColor: theme.cardColor, 
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))), 
      builder: (context) {
        return DefaultTabController(
          length: 2, 
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7, 
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: TabBar(indicatorColor: theme.accent, labelColor: theme.accent, unselectedLabelColor: theme.textColor.withOpacity(0.5), tabs: const [Tab(text: '目录'), Tab(text: '书签')])),
                    IconButton(icon: Icon(_isAscending ? Icons.sort : Icons.sort_outlined, color: theme.textColor), onPressed: () { setState(() => _isAscending = !_isAscending); Navigator.pop(context); _showCatalog(); }),
                  ]
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      StatefulBuilder(
                        builder: (context, setModalState) {
                          List<int> indices = List.generate(_chapters.length, (i) => i); 
                          if (!_isAscending) indices = indices.reversed.toList();
                          return ListView.builder(
                            itemCount: indices.length, 
                            itemBuilder: (context, idx) {
                              final realIndex = indices[idx]; final isCurrent = realIndex == widget.book.currentChapterIndex;
                              return ListTile(
                                title: Text(_chapters[realIndex].title, style: TextStyle(color: isCurrent ? theme.accent : theme.textColor, fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal)), 
                                onTap: () { Navigator.pop(context); _scrollToChapter(realIndex); }
                              );
                            }
                          );
                        }
                      ),
                      _bookmarks.isEmpty 
                          ? Center(child: Text('暂无书签', style: TextStyle(color: theme.textColor.withOpacity(0.5)))) 
                          : ListView.builder(
                              itemCount: _bookmarks.length, 
                              itemBuilder: (context, index) {
                                final chapterIdx = _bookmarks[index];
                                return ListTile(
                                  leading: Icon(Icons.bookmark, color: theme.accent), 
                                  title: Text(_chapters[chapterIdx].title, style: TextStyle(color: theme.textColor)), 
                                  trailing: IconButton(icon: Icon(Icons.delete, color: theme.textColor.withOpacity(0.5), size: 20), onPressed: () { setState(() => _bookmarks.remove(chapterIdx)); Navigator.pop(context); }), 
                                  onTap: () { Navigator.pop(context); _scrollToChapter(chapterIdx); }
                                );
                              }
                            ),
                    ]
                  )
                ),
              ]
            )
          )
        );
      }
    );
  }

  @override void dispose() { super.dispose(); }

  @override Widget build(BuildContext context) {
    final theme = currentTheme.value; 
    final readerTextColor = theme.textColor.withOpacity(0.85); 
    final hasBookmark = _bookmarks.contains(widget.book.currentChapterIndex);

    return Scaffold(
      backgroundColor: theme.background,
      body: Stack(
        children: [
          ValueListenableBuilder<String?>(
            valueListenable: customBackgroundImage, 
            builder: (context, bgImage, child) {
              if (bgImage != null && File(bgImage).existsSync()) {
                return Container(decoration: BoxDecoration(image: DecorationImage(image: FileImage(File(bgImage)), fit: BoxFit.cover)), child: Container(color: theme.background.withOpacity(0.7)));
              }
              return Container(color: theme.background);
            },
          ),
          
          if (_isLoading) 
            const Center(child: CircularProgressIndicator())
          else 
            GestureDetector(
              behavior: HitTestBehavior.translucent, 
              onTap: () => setState(() => _showMenu = !_showMenu),
              child: ScrollablePositionedList.builder(
                itemScrollController: _itemScrollController,
                itemPositionsListener: _itemPositionsListener,
                padding: EdgeInsets.fromLTRB(_horizontalMargin, 60, _horizontalMargin, 120), 
                itemCount: _chapters.length,
                itemBuilder: (context, index) {
                  final chapter = _chapters[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Text(chapter.title, style: TextStyle(fontSize: _fontSize + 4, color: readerTextColor, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      Text(chapter.content, style: TextStyle(fontSize: _fontSize, color: readerTextColor, height: _lineHeight, letterSpacing: _letterSpacing)),
                      const SizedBox(height: 40),
                      Divider(color: theme.textColor.withOpacity(0.1), thickness: 1),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
            ),
          
          IgnorePointer(child: Container(color: Colors.black.withOpacity((1.0 - _brightness) * 0.8))),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 200), 
            top: _showMenu ? 0 : -100, 
            left: 0, right: 0,
            child: AppBar(
              backgroundColor: theme.cardColor, 
              title: Text(widget.book.title, style: TextStyle(fontSize: 16, color: theme.textColor)),
              leading: IconButton(icon: Icon(Icons.arrow_back, color: theme.textColor), onPressed: () => Navigator.pop(context)),
              actions: [
                IconButton(
                  icon: Icon(hasBookmark ? Icons.bookmark : Icons.bookmark_border, color: hasBookmark ? theme.accent : theme.textColor), 
                  onPressed: _toggleBookmark
                )
              ],
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 200), 
            bottom: _showMenu ? 0 : -100, 
            left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12), 
              decoration: BoxDecoration(color: theme.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround, 
                children: [
                  TextButton.icon(onPressed: () => _scrollToChapter(widget.book.currentChapterIndex - 1), icon: Icon(Icons.chevron_left, color: theme.textColor), label: Text('上一章', style: TextStyle(color: theme.textColor))),
                  TextButton.icon(onPressed: _showCatalog, icon: Icon(Icons.menu, color: theme.textColor), label: Text('目录', style: TextStyle(color: theme.textColor))),
                  TextButton.icon(onPressed: _showSettingsPanel, icon: Icon(Icons.text_format, color: theme.textColor), label: Text('排版', style: TextStyle(color: theme.textColor))),
                  TextButton.icon(onPressed: () => _scrollToChapter(widget.book.currentChapterIndex + 1), icon: Icon(Icons.chevron_right, color: theme.textColor), label: Text('下一章', style: TextStyle(color: theme.textColor))),
                ]
              ),
            ),
          ),
        ],
      ),
    );
  }
}