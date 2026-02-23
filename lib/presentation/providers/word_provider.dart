import 'package:flutter/foundation.dart';
import '../../domain/entities/word.dart';
import '../../domain/repositories/word_repository.dart';

class WordProvider with ChangeNotifier {
  final WordRepository _repository;

  WordProvider(this._repository) {
    _init();
  }

  List<Word> _words = [];
  int _delaySeconds = 5;
  int _activeWordId = -1;
  String _gsheetLink = '';
  String _status = '';
  bool _isLoading = false;
  bool _isSyncing = false;

  List<Word> get words => _words;
  int get delaySeconds => _delaySeconds;
  int get activeWordId => _activeWordId;
  String get gsheetLink => _gsheetLink;
  String get status => _status;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;

  void _init() {
    _repository.eventStream.listen((event) {
      if (event == "db_changed") {
        refresh();
      }
    });
    refresh();
    _repository.requestNotificationPermission();
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    try {
      final wordsData = await _repository.getAllWords();
      final settings = await _repository.getSettings();

      _words = wordsData;
      _delaySeconds = (settings['delay_seconds'] as int?) ?? 5;
      _activeWordId = (settings['last_word_id'] as int?) ?? -1;
      _gsheetLink = (settings['gsheet_link'] as String?) ?? '';
      _status = '';
    } catch (e) {
      _status = 'Error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncData(String link) async {
    if (link.isEmpty) return;
    _isSyncing = true;
    _status = 'Синхронизация...';
    notifyListeners();
    try {
      final count = await _repository.syncGSheets(link);
      await _repository.setGSheetLink(link);
      _gsheetLink = link;
      _status = 'Импортировано слов: $count ✓';
      await refresh();
    } catch (e) {
      _status = 'Ошибка синхронизации: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
      Future.delayed(const Duration(seconds: 3), () {
        _status = '';
        notifyListeners();
      });
    }
  }

  Future<void> saveSettings({int? delay, String? link}) async {
    try {
      if (delay != null) {
        await _repository.setDelaySeconds(delay);
        _delaySeconds = delay;
      }
      if (link != null) {
        await _repository.setGSheetLink(link);
        _gsheetLink = link;
      }
      _status = 'Настройки сохранены ✓';
      notifyListeners();
      Future.delayed(const Duration(seconds: 2), () {
        _status = '';
        notifyListeners();
      });
    } catch (e) {
      _status = 'Ошибка сохранения: $e';
      notifyListeners();
    }
  }

  Future<void> addWord(String foreign, String translation) async {
    final now = DateTime.now();
    final tsMs = now.millisecondsSinceEpoch;
    final createdAt = '${now.year}-${_p(now.month)}-${_p(now.day)} ${_p(now.hour)}:${_p(now.minute)}:${_p(now.second)}';

    final newWord = Word(id: 0, foreignWord: foreign, translation: translation, createdAt: createdAt, timestampMs: tsMs, priority: 1);

    try {
      await _repository.addWord(newWord);
      final updatedWords = await _repository.getAllWords();
      _words = updatedWords;

      if (_words.length == 1) {
        final addedWord = _words.first;
        await _repository.scheduleNotification(addedWord);
        _status = 'Слово добавлено, уведомление через ${_delayLabel()}';
      } else {
        _status = 'Слово добавлено в очередь';
      }
      notifyListeners();
    } catch (e) {
      _status = 'Ошибка: $e';
      notifyListeners();
    }
  }

  Future<void> updateWord(Word word) async {
    try {
      await _repository.updateWord(word);
      await refresh();
    } catch (e) {
      _status = 'Ошибка обновления: $e';
      notifyListeners();
    }
  }

  Future<void> deleteWord(int id) async {
    try {
      await _repository.deleteWord(id);
      _words.removeWhere((w) => w.id == id);
      notifyListeners();
    } catch (e) {
      _status = 'Ошибка удаления: $e';
      notifyListeners();
    }
  }

  Future<void> activateWord(int id) async {
    try {
      await _repository.scheduleImmediate(id);
      _status = 'Слово активировано';
      notifyListeners();
    } catch (e) {
      _status = 'Ошибка активации: $e';
      notifyListeners();
    }
  }

  String _delayLabel() {
    if (_delaySeconds < 60) return '$_delaySeconds сек';
    final m = _delaySeconds ~/ 60;
    final s = _delaySeconds % 60;
    return s == 0 ? '$m мин' : '$m мин $s сек';
  }

  String _p(int v) => v.toString().padLeft(2, '0');
}
