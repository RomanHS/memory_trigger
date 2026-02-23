import 'package:flutter/material.dart';

class AddWordDialog extends StatefulWidget {
  final Map<String, dynamic>? wordToEdit;
  final Function(String, String) onSave;

  const AddWordDialog({super.key, this.wordToEdit, required this.onSave});

  @override
  State<AddWordDialog> createState() => _AddWordDialogState();
}

class _AddWordDialogState extends State<AddWordDialog> {
  late final TextEditingController _foreignWordCtrl;
  late final TextEditingController _translationCtrl;

  @override
  void initState() {
    super.initState();
    _foreignWordCtrl = TextEditingController(text: widget.wordToEdit?['foreign_word'] ?? '');
    _translationCtrl = TextEditingController(text: widget.wordToEdit?['translation'] ?? '');
  }

  @override
  void dispose() {
    _foreignWordCtrl.dispose();
    _translationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.translate, color: Color(0xFF6C63FF), size: 24),
                const SizedBox(width: 10),
                Text(
                  widget.wordToEdit == null ? 'Новое слово' : 'Редактировать',
                  style: const TextStyle(color: Color(0xFFEFEFEF), fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildField(controller: _foreignWordCtrl, label: 'Иностранное слово', icon: Icons.language, hint: 'например: Serendipity'),
            const SizedBox(height: 16),
            _buildField(controller: _translationCtrl, label: 'Перевод', icon: Icons.abc, hint: 'например: Счастливая случайность'),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
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
                      widget.onSave(word, trans);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      widget.wordToEdit == null ? 'Добавить' : 'Сохранить',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
}
