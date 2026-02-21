import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'settings_page.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Trigger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF), brightness: Brightness.dark),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _channel = MethodChannel('com.example.memory_trigger/notifications');
  static const _dbChannel = MethodChannel('com.example.memory_trigger/database');
  static const _eventChannel = EventChannel('com.example.memory_trigger/events');

  String _status = '';
  List<Map<String, dynamic>> _words = [];
  int _delaySeconds = 5; // загружается из БД

  // Контроллеры для полей ввода в диалоге
  final _foreignWordCtrl = TextEditingController();
  final _translationCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _requestPermission();
    _loadWords();
    _loadSettings();
    _listenToEvents();
  }

  Future<void> _requestPermission() async {
    try {
      await _channel.invokeMethod('requestNotificationPermission');
    } catch (e) {
      debugPrint('Permission request error: $e');
    }
  }

  void _listenToEvents() {
    _eventChannel.receiveBroadcastStream().listen((event) {
      if (event == "db_changed") {
        debugPrint("Event received: db_changed. Refreshing words...");
        _loadWords();
      }
    });
  }

  @override
  void dispose() {
    _foreignWordCtrl.dispose();
    _translationCtrl.dispose();
    super.dispose();
  }

  // ── Загрузка слов из БД ───────────────────────────────────────────────────

  Future<void> _loadWords() async {
    try {
      final List<dynamic> raw = await _dbChannel.invokeMethod('getAllWords');
      if (!mounted) return;
      setState(() {
        _words = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } on PlatformException catch (e) {
      debugPrint('DB error (getAllWords): ${e.message}');
    }
  }

  // ── Загрузка настроек из БД ──────────────────────────────────────────────

  Future<void> _loadSettings() async {
    try {
      final Map<dynamic, dynamic> raw = await _dbChannel.invokeMethod('getSettings');
      if (!mounted) return;
      setState(() => _delaySeconds = (raw['delay_seconds'] as int?) ?? 5);
    } on PlatformException catch (e) {
      debugPrint('Settings error: ${e.message}');
    }
  }

  // ── Удаление слова ───────────────────────────────────────────────────────

  Future<void> _deleteWord(int id) async {
    try {
      await _dbChannel.invokeMethod('deleteWord', {'id': id});
      if (!mounted) return;
      setState(() {
        _words.removeWhere((w) => w['id'] == id);
      });
    } on PlatformException catch (e) {
      debugPrint('Delete error: ${e.message}');
    }
  }

  // ── Редактирование слова ──────────────────────────────────────────────────

  Future<void> _updateWord(int id, String foreign, String translation) async {
    try {
      await _dbChannel.invokeMethod('updateWord', {'id': id, 'foreign_word': foreign, 'translation': translation});
      _loadWords();
    } on PlatformException catch (e) {
      debugPrint('Update error: ${e.message}');
    }
  }

  // ── Добавление слова ──────────────────────────────────────────────────────

  Future<void> _addWord(String foreignWord, String translation) async {
    final now = DateTime.now();
    final tsMs = now.millisecondsSinceEpoch;
    final createdAt = '${now.year}-${_p(now.month)}-${_p(now.day)} ${_p(now.hour)}:${_p(now.minute)}:${_p(now.second)}';

    try {
      // 1. Сохраняем в БД
      final int newId = await _dbChannel.invokeMethod('addWord', {
        'foreign_word': foreignWord,
        'translation': translation,
        'created_at': createdAt,
        'timestamp_ms': tsMs,
      });

      // 2. Добавляем в локальный список
      if (!mounted) return;
      final bool isFirstWord = _words.isEmpty;

      setState(() {
        _words = [
          {
            'id': newId,
            'foreign_word': foreignWord,
            'translation': translation,
            'created_at': createdAt,
            'timestamp_ms': tsMs,
            'priority': 1, // HIGH
          },
          ..._words,
        ];
        if (isFirstWord) {
          _status = 'Слово добавлено, уведомление через ${_delayLabel()}';
        } else {
          _status = 'Слово добавлено в очередь';
        }
      });

      // 3. Планируем уведомление только если это первое слово
      if (isFirstWord) {
        await _channel.invokeMethod('scheduleNotification', {'word_id': newId, 'title': foreignWord, 'body': translation});
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Ошибка: ${e.message}');
    }
  }

  // ── Диалог добавления слова ───────────────────────────────────────────────

  Future<void> _showAddWordDialog({Map<String, dynamic>? wordToEdit}) async {
    if (wordToEdit != null) {
      _foreignWordCtrl.text = wordToEdit['foreign_word'] ?? '';
      _translationCtrl.text = wordToEdit['translation'] ?? '';
    } else {
      _foreignWordCtrl.clear();
      _translationCtrl.clear();
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Заголовок
                Row(
                  children: [
                    const Icon(Icons.translate, color: Color(0xFF6C63FF), size: 24),
                    const SizedBox(width: 10),
                    Text(
                      wordToEdit == null ? 'Новое слово' : 'Редактировать',
                      style: const TextStyle(color: Color(0xFFEFEFEF), fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Поле: иностранное слово
                _buildField(controller: _foreignWordCtrl, label: 'Иностранное слово', icon: Icons.language, hint: 'например: Serendipity'),

                const SizedBox(height: 16),

                // Поле: перевод
                _buildField(controller: _translationCtrl, label: 'Перевод', icon: Icons.abc, hint: 'например: Счастливая случайность'),

                const SizedBox(height: 28),

                // Кнопки
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF888888),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFF333355)),
                          ),
                        ),
                        child: const Text('Отмена', style: TextStyle(fontSize: 15)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final word = _foreignWordCtrl.text.trim();
                          final trans = _translationCtrl.text.trim();
                          if (word.isEmpty || trans.isEmpty) return;
                          Navigator.of(ctx).pop();
                          if (wordToEdit == null) {
                            _addWord(word, trans);
                          } else {
                            _updateWord(wordToEdit['id'] as int, word, trans);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(wordToEdit == null ? 'Добавить' : 'Сохранить', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildField({required TextEditingController controller, required String label, required IconData icon, required String hint}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Color(0xFFEFEFEF), fontSize: 15),
      cursorColor: const Color(0xFF6C63FF),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF444466), fontSize: 13),
        labelStyle: const TextStyle(color: Color(0xFF888888)),
        prefixIcon: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
        filled: true,
        fillColor: const Color(0xFF0F0E17),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF333355)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _delayLabel() {
    if (_delaySeconds < 60) return '$_delaySeconds сек';
    final m = _delaySeconds ~/ 60;
    final s = _delaySeconds % 60;
    return s == 0 ? '$m мин' : '$m мин $s сек';
  }

  String _p(int v) => v.toString().padLeft(2, '0');

  String _formatDate(dynamic tsMs) {
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(tsMs as int);
      return '${_p(dt.day)}.${_p(dt.month)}.${dt.year}  ${_p(dt.hour)}:${_p(dt.minute)}';
    } catch (_) {
      return tsMs.toString();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),

      // ── FAB ─────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddWordDialog,
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 28),
      ),

      body: SafeArea(
        child: Column(
          children: [
            // ── Хедер ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Column(
                children: [
                  const Text(
                    'Memory Trigger',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFEFEFEF), letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Нажмите + чтобы добавить слово и запланировать уведомление',
                    style: TextStyle(fontSize: 12, color: Color(0xFF666677)),
                    textAlign: TextAlign.center,
                  ),

                  // Статус
                  if (_status.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 400),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline, color: Color(0xFF6C63FF), size: 16),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(_status, style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Заголовок секции ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_rounded, color: Color(0xFF6C63FF), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Словарь (${_words.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFEFEFEF)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _loadWords,
                    child: const Icon(Icons.refresh, color: Color(0xFF666677), size: 20),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () async {
                      final result = await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => const SettingsPage()));
                      if (result != null) {
                        setState(() => _delaySeconds = result);
                      }
                    },
                    child: const Icon(Icons.settings_outlined, color: Color(0xFF666677), size: 20),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Список слов ──────────────────────────────────────────────
            Expanded(
              child: _words.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.translate_outlined, color: const Color(0xFF2A2A3E), size: 64),
                          const SizedBox(height: 16),
                          const Text(
                            'Словарь пуст',
                            style: TextStyle(color: Color(0xFF555566), fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 6),
                          const Text('Нажмите + чтобы добавить первое слово', style: TextStyle(color: Color(0xFF444455), fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: _words.length,
                      itemBuilder: (context, index) {
                        final item = _words[index];
                        final isNew = index == 0;
                        final foreign = item['foreign_word'] as String? ?? '';
                        final translation = item['translation'] as String? ?? '';
                        final tsMs = item['timestamp_ms'];

                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 300 + index * 30),
                          builder: (ctx, v, child) => Opacity(
                            opacity: v,
                            child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: child),
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF13132A),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isNew ? const Color(0xFF6C63FF).withOpacity(0.55) : const Color(0xFF6C63FF).withOpacity(0.12),
                                width: isNew ? 1.5 : 1,
                              ),
                              boxShadow: isNew
                                  ? [BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))]
                                  : null,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    foreign.isNotEmpty ? foreign[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      foreign,
                                      style: const TextStyle(color: Color(0xFFEFEFEF), fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  if (isNew)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6C63FF).withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'new',
                                        style: TextStyle(color: Color(0xFF9B8FFF), fontSize: 10, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 3),
                                  Text(translation, style: const TextStyle(color: Color(0xFF9B8FFF), fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      _buildPriorityBadge(item['priority'] as int?),
                                      const SizedBox(width: 8),
                                      Text(_formatDate(tsMs), style: const TextStyle(color: Color(0xFF444455), fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Color(0xFF666677)),
                                onSelected: (val) {
                                  if (val == 'edit') {
                                    _showAddWordDialog(wordToEdit: item);
                                  } else if (val == 'delete') {
                                    _deleteWord(item['id'] as int);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Удалить', style: TextStyle(color: Colors.redAccent)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(int? priority) {
    String text;
    Color color;
    switch (priority) {
      case 1:
        text = 'Высокий';
        color = Colors.redAccent;
        break;
      case 2:
        text = 'Средний';
        color = Colors.orangeAccent;
        break;
      case 3:
        text = 'Низкий';
        color = Colors.greenAccent;
        break;
      default:
        text = 'Высокий';
        color = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
