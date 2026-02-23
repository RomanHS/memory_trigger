import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/word.dart';
import '../providers/word_provider.dart';
import '../widgets/word_card.dart';
import '../widgets/add_word_dialog.dart';
import 'settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<WordProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, provider),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 28),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Header(status: provider.status),
            const SizedBox(height: 20),
            _SubHeader(wordCount: provider.words.length, onRefresh: provider.refresh),
            const SizedBox(height: 8),
            Expanded(
              child: provider.isLoading && provider.words.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                  : _WordList(provider: provider),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WordProvider provider, {Word? wordToEdit}) {
    showDialog(
      context: context,
      builder: (_) => AddWordDialog(
        wordToEdit: wordToEdit?.toMap(),
        onSave: (foreign, translation) {
          if (wordToEdit == null) {
            provider.addWord(foreign, translation);
          } else {
            provider.updateWord(wordToEdit.copyWith(foreignWord: foreign, translation: translation));
          }
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String status;
  const _Header({required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          if (status.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
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
                    child: Text(status, style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubHeader extends StatelessWidget {
  final int wordCount;
  final VoidCallback onRefresh;

  const _SubHeader({required this.wordCount, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Icon(Icons.menu_book_rounded, color: Color(0xFF6C63FF), size: 20),
          const SizedBox(width: 8),
          Text(
            'Словарь ($wordCount)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFEFEFEF)),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF666677), size: 20),
            onPressed: onRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF666677), size: 20),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
    );
  }
}

class _WordList extends StatelessWidget {
  final WordProvider provider;
  const _WordList({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.words.isEmpty) {
      return const _EmptyState();
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: provider.words.length,
      itemBuilder: (context, index) {
        final word = provider.words[index];
        return WordCard(
          word: word,
          index: index,
          isActive: word.id == provider.activeWordId,
          onActivate: () => provider.activateWord(word.id),
          onEdit: () => _showEditDialog(context, word),
          onDelete: () => provider.deleteWord(word.id),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, Word word) {
    showDialog(
      context: context,
      builder: (_) => AddWordDialog(
        wordToEdit: word.toMap(),
        onSave: (foreign, translation) {
          provider.updateWord(word.copyWith(foreignWord: foreign, translation: translation));
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
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
    );
  }
}
