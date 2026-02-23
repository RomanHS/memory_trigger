import 'package:flutter/material.dart';
import '../../domain/entities/word.dart';

class WordCard extends StatelessWidget {
  final Word word;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final int index;

  const WordCard({
    super.key,
    required this.word,
    required this.isActive,
    required this.onActivate,
    required this.onEdit,
    required this.onDelete,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
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
          border: Border.all(color: isActive ? const Color(0xFF6C63FF) : const Color(0xFF6C63FF).withValues(alpha: 0.12), width: isActive ? 1.5 : 1),
          boxShadow: isActive
              ? [BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 4))]
              : null,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: _buildLeading(),
          title: _buildTitle(),
          subtitle: _buildSubtitle(),
          trailing: _buildTrailing(context),
        ),
      ),
    );
  }

  Widget _buildLeading() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          word.foreignWord.isNotEmpty ? word.foreignWord[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Row(
      children: [
        Expanded(
          child: Text(
            word.foreignWord,
            style: const TextStyle(color: Color(0xFFEFEFEF), fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        if (isActive)
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)]),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'ACTIVE',
              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget _buildSubtitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 3),
        Text(word.translation, style: const TextStyle(color: Color(0xFF9B8FFF), fontSize: 14)),
        const SizedBox(height: 4),
        Row(
          children: [
            _buildPriorityBadge(word.priority),
            const SizedBox(width: 8),
            Text(_formatDate(word.timestampMs), style: const TextStyle(color: Color(0xFF444455), fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildTrailing(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Color(0xFF666677)),
      itemBuilder: (ctx) => [
        if (!isActive) const PopupMenuItem(value: 'activate', child: Text('Показать следующим')),
        const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Удалить', style: TextStyle(color: Colors.redAccent)),
        ),
      ],
      onSelected: (val) {
        if (val == 'activate') {
          onActivate();
        } else if (val == 'edit') {
          onEdit();
        } else if (val == 'delete') {
          onDelete();
        }
      },
    );
  }

  Widget _buildPriorityBadge(int priority) {
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

  String _formatDate(int tsMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(tsMs);
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.${dt.year}  ${dt.hour}:$min';
  }
}
