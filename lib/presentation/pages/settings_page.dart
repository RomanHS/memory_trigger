import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/word_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _linkCtrl = TextEditingController();
  int? _localDelay;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<WordProvider>(context, listen: false);
    _linkCtrl.text = provider.gsheetLink;
    _localDelay = provider.delaySeconds;
  }

  @override
  void dispose() {
    _linkCtrl.dispose();
    super.dispose();
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
    final provider = Provider.of<WordProvider>(context);
    _localDelay ??= provider.delaySeconds;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0E17),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFEFEFEF), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Настройки',
          style: TextStyle(color: Color(0xFFEFEFEF), fontSize: 20, fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDelayCard(provider),
                const SizedBox(height: 20),
                _buildSyncCard(provider),
                const SizedBox(height: 24),
                if (provider.status.isNotEmpty) _buildStatus(provider.status),
                const SizedBox(height: 14),
                _buildSaveButton(provider),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDelayCard(WordProvider provider) {
    return Container(
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
                gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _label(_localDelay!),
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Slider(
            value: _localDelay!.toDouble(),
            min: 0,
            max: 7200,
            divisions: 1440,
            activeColor: const Color(0xFF6C63FF),
            onChanged: (v) => setState(() => _localDelay = v.round()),
          ),
          _buildQuickSelect(),
        ],
      ),
    );
  }

  Widget _buildQuickSelect() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [0, 5, 10, 60, 300, 1800, 3600, 7200].map((sec) {
        final selected = _localDelay == sec;
        return GestureDetector(
          onTap: () => setState(() => _localDelay = sec),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF6C63FF).withValues(alpha: 0.2) : const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? const Color(0xFF6C63FF) : const Color(0xFF333355)),
            ),
            child: Text(_label(sec), style: TextStyle(color: selected ? Colors.white : Colors.grey, fontSize: 12)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSyncCard(WordProvider provider) {
    return Container(
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
          const SizedBox(height: 20),
          TextField(
            controller: _linkCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Вставьте ссылку на таблицу',
              filled: true,
              fillColor: const Color(0xFF0F0E17),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              suffixIcon: IconButton(
                icon: Icon(provider.isSyncing ? Icons.hourglass_empty : Icons.cloud_download_outlined, color: const Color(0xFF6C63FF)),
                onPressed: provider.isSyncing ? null : () => provider.syncData(_linkCtrl.text.trim()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatus(String msg) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(10)),
        child: Text(msg, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ),
    );
  }

  Widget _buildSaveButton(WordProvider provider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => provider.saveSettings(delay: _localDelay, link: _linkCtrl.text.trim()),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text(
          'Сохранить',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
