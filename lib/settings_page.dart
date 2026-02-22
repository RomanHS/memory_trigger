import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _dbChannel = MethodChannel('com.example.memory_trigger/database');

  int _delaySeconds = 5;
  String _gsheetLink = '';
  final _linkCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _syncing = false;
  String? _savedMsg;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final Map<dynamic, dynamic> raw = await _dbChannel.invokeMethod('getSettings');
      if (!mounted) return;
      setState(() {
        _delaySeconds = (raw['delay_seconds'] as int?) ?? 5;
        _gsheetLink = (raw['gsheet_link'] as String?) ?? '';
        _linkCtrl.text = _gsheetLink;
        _loading = false;
      });
    } on PlatformException catch (e) {
      debugPrint('Settings load error: ${e.message}');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _savedMsg = null;
    });
    try {
      await _dbChannel.invokeMethod('setDelaySeconds', {'seconds': _delaySeconds});
      await _dbChannel.invokeMethod('setGSheetLink', {'link': _linkCtrl.text.trim()});

      if (!mounted) return;
      setState(() {
        _gsheetLink = _linkCtrl.text.trim();
        _saving = false;
        _savedMsg = 'Настройки сохранены ✓';
      });
      // Скрываем сообщение через 2 секунды
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _savedMsg = null);
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _savedMsg = 'Ошибка: ${e.message}';
      });
    }
  }

  Future<void> _sync() async {
    final link = _linkCtrl.text.trim();
    if (link.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите ссылку на таблицу')));
      return;
    }

    setState(() => _syncing = true);

    try {
      // 1. Превращаем ссылку в CSV export URL
      String csvUrl = link;
      if (link.contains('/edit')) {
        csvUrl = link.replaceRange(link.indexOf('/edit'), link.length, '/export?format=csv');
      } else if (!link.endsWith('/export?format=csv')) {
        if (link.endsWith('/')) {
          csvUrl = '${link}export?format=csv';
        } else {
          csvUrl = '$link/export?format=csv';
        }
      }

      // 2. Качаем данные
      final response = await http.get(Uri.parse(csvUrl));
      if (response.statusCode != 200) {
        throw Exception('Не удалось загрузить таблицу (код ${response.statusCode})');
      }

      // 3. Парсим CSV с принудительной поддержкой UTF-8
      final decodedBody = utf8.decode(response.bodyBytes);
      final List<List<dynamic>> csvData = const CsvDecoder().convert(decodedBody);
      if (csvData.isEmpty) throw Exception('Таблица пуста');

      // 4. Формируем список для импорта (ожидаем Col 0: Word, Col 1: Translation)
      final List<Map<String, String>> wordsToImport = [];
      for (var row in csvData) {
        if (row.length < 2) continue;
        final foreign = row[0].toString().trim();
        final translation = row[1].toString().trim();
        if (foreign.isEmpty) continue;

        wordsToImport.add({'foreign_word': foreign, 'translation': translation});
      }

      if (wordsToImport.isEmpty) throw Exception('Не найдено слов для импорта');

      // 5. Отправляем в натив
      final dynamic result = await _dbChannel.invokeMethod('bulkAddWords', {'words': wordsToImport});
      final int importedCount = result as int;

      if (!mounted) return;
      setState(() {
        _syncing = false;
        _savedMsg = 'Импортировано слов: $importedCount ✓';
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _savedMsg = null);
      });
    } catch (e) {
      debugPrint('Sync error: $e');
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _savedMsg = 'Ошибка синхронизации';
      });
    }
  }

  String _label(int seconds) {
    if (seconds < 60) return '$seconds сек';
    if (seconds < 3600) {
      final m = seconds ~/ 60;
      final s = seconds % 60;
      return s == 0 ? '$m мин' : '$m мин $s сек';
    }
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (m == 0 && s == 0) return '$h ч';
    if (s == 0) return '$h ч $m мин';
    return '$h ч $m мин $s сек';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0E17),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFEFEFEF), size: 20),
          onPressed: () => Navigator.of(context).pop(_delaySeconds),
        ),
        title: const Text(
          'Настройки',
          style: TextStyle(color: Color(0xFFEFEFEF), fontSize: 20, fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Карточка задержки ────────────────────────────────────
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF13132A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.25)),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.timer_outlined, color: Color(0xFF6C63FF), size: 22),
                                SizedBox(width: 10),
                                Text(
                                  'Задержка уведомления',
                                  style: TextStyle(color: Color(0xFFEFEFEF), fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Через сколько секунд появится уведомление после добавления слова или нажатия "Next"',
                              style: TextStyle(color: Color(0xFF666677), fontSize: 12, height: 1.4),
                            ),
                            const SizedBox(height: 24),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  _label(_delaySeconds),
                                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFF6C63FF),
                                inactiveTrackColor: const Color(0xFF2A2A3E),
                                thumbColor: const Color(0xFF6C63FF),
                                overlayColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: _delaySeconds.toDouble(),
                                min: 0,
                                max: 7200,
                                divisions: 1440,
                                onChanged: (v) => setState(() => _delaySeconds = v.round()),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('0 сек', style: TextStyle(color: Color(0xFF555566), fontSize: 11)),
                                  Text('2 ч', style: TextStyle(color: Color(0xFF555566), fontSize: 11)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text('Быстрый выбор', style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [0, 5, 10, 60, 300, 1800, 3600, 7200].map((sec) {
                                final selected = _delaySeconds == sec;
                                return GestureDetector(
                                  onTap: () => setState(() => _delaySeconds = sec),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: selected ? const Color(0xFF6C63FF).withValues(alpha: 0.3) : const Color(0xFF1A1A2E),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: selected ? const Color(0xFF6C63FF) : const Color(0xFF333355),
                                        width: selected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Text(
                                      _label(sec),
                                      style: TextStyle(
                                        color: selected ? const Color(0xFF9B8FFF) : const Color(0xFF666677),
                                        fontSize: 13,
                                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // ── Карточка Синхронизации ──────────────────────────────
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF13132A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.25)),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.sync_rounded, color: Color(0xFF6C63FF), size: 22),
                                SizedBox(width: 10),
                                Text(
                                  'Синхронизация Google Таблиц',
                                  style: TextStyle(color: Color(0xFFEFEFEF), fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Импорт слов. Формат таблицы: 1-й столбец — слово, 2-й — перевод.',
                              style: TextStyle(color: Color(0xFF666677), fontSize: 12, height: 1.4),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _linkCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Вставьте ссылку на таблицу',
                                hintStyle: const TextStyle(color: Color(0xFF444455)),
                                filled: true,
                                fillColor: const Color(0xFF0F0E17),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _syncing ? Icons.hourglass_empty : Icons.cloud_download_outlined,
                                    color: const Color(0xFF6C63FF),
                                    size: 20,
                                  ),
                                  onPressed: _syncing ? null : _sync,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _syncing ? null : _sync,
                                icon: _syncing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF)),
                                      )
                                    : const Icon(Icons.sync_rounded, size: 18),
                                label: Text(_syncing ? 'Синхронизация...' : 'Синхронизировать сейчас'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF6C63FF),
                                  side: const BorderSide(color: Color(0xFF6C63FF)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // ── Сообщение об успехе ──────────────────────────────────
                      if (_savedMsg != null) ...[
                        Center(
                          child: AnimatedOpacity(
                            opacity: _savedMsg != null ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
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
                                  Text(_savedMsg!, style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      // ── Кнопка Сохранить ─────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFF6C63FF),
                            disabledBackgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _saving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
