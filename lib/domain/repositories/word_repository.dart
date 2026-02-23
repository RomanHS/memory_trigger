import '../entities/word.dart';

abstract class WordRepository {
  Future<List<Word>> getAllWords();
  Future<void> addWord(Word word);
  Future<void> updateWord(Word word);
  Future<void> deleteWord(int id);
  Future<void> updateWordPriority(int id, int priority);
  Future<void> scheduleNotification(Word word);
  Future<void> scheduleImmediate(int id);
  Future<Map<String, dynamic>> getSettings();
  Future<void> setDelaySeconds(int seconds);
  Future<void> setGSheetLink(String link);
  Future<int> syncGSheets(String link);
  Future<void> requestNotificationPermission();
  Stream<String> get eventStream;
}
