import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/word.dart';
import '../../domain/repositories/word_repository.dart';

class WordRepositoryImpl implements WordRepository {
  static const _channel = MethodChannel('com.example.memory_trigger/notifications');
  static const _dbChannel = MethodChannel('com.example.memory_trigger/database');
  static const _eventChannel = EventChannel('com.example.memory_trigger/events');

  @override
  Future<List<Word>> getAllWords() async {
    final List<dynamic> raw = await _dbChannel.invokeMethod('getAllWords');
    return raw.map((e) => Word.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  @override
  Future<void> addWord(Word word) async {
    await _dbChannel.invokeMethod('addWord', {
      'foreign_word': word.foreignWord,
      'translation': word.translation,
      'created_at': word.createdAt,
      'timestamp_ms': word.timestampMs,
    });
  }

  @override
  Future<void> updateWord(Word word) async {
    await _dbChannel.invokeMethod('updateWord', {'id': word.id, 'foreign_word': word.foreignWord, 'translation': word.translation});
  }

  @override
  Future<void> deleteWord(int id) async {
    await _dbChannel.invokeMethod('deleteWord', {'id': id});
  }

  @override
  Future<void> updateWordPriority(int id, int priority) async {
    await _dbChannel.invokeMethod('updateWordPriority', {'id': id, 'priority': priority});
  }

  @override
  Future<void> scheduleNotification(Word word) async {
    await _channel.invokeMethod('scheduleNotification', {'word_id': word.id, 'title': word.foreignWord, 'body': word.translation});
  }

  @override
  Future<void> scheduleImmediate(int id) async {
    await _dbChannel.invokeMethod('scheduleImmediate', {'id': id});
  }

  @override
  Future<Map<String, dynamic>> getSettings() async {
    final Map<dynamic, dynamic> raw = await _dbChannel.invokeMethod('getSettings');
    return Map<String, dynamic>.from(raw);
  }

  @override
  Future<void> setDelaySeconds(int seconds) async {
    await _dbChannel.invokeMethod('setDelaySeconds', {'seconds': seconds});
  }

  @override
  Future<void> setGSheetLink(String link) async {
    await _dbChannel.invokeMethod('setGSheetLink', {'link': link});
  }

  @override
  Future<int> syncGSheets(String link) async {
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

    // 3. Парсим CSV
    final decodedBody = utf8.decode(response.bodyBytes);
    final List<List<dynamic>> csvData = const CsvDecoder().convert(decodedBody);
    if (csvData.isEmpty) throw Exception('Таблица пуста');

    // 4. Формируем список для импорта
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
    return result as int;
  }

  @override
  Future<void> requestNotificationPermission() async {
    await _channel.invokeMethod('requestNotificationPermission');
  }

  @override
  Stream<String> get eventStream => _eventChannel.receiveBroadcastStream().map((e) => e.toString());
}
