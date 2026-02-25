import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../models/forum_daily_question.dart';
import '../../services/forum_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedLang = 'tr';
  final _textController = TextEditingController();
  List<ForumDailyQuestion> _questions = [];
  bool _loading = false;
  String? _editingId;

  static const Map<String, String> _langLabels = {
    'tr': 'Türkçe',
    'en': 'English',
    'de': 'Deutsch',
    'es': 'Español',
    'ar': 'العربية',
  };

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() => _loading = true);
    final list = await ForumService.getDailyQuestionsForDate(_selectedDate);
    if (mounted) setState(() => _questions = list..sort((a, b) => a.language.compareTo(b.language)));
    setState(() => _loading = false);
  }

  void _editQuestion(ForumDailyQuestion q) {
    setState(() {
      _editingId = q.id;
      _selectedLang = q.language;
      _textController.text = q.text;
    });
  }

  Future<void> _save() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Soru metni girin')));
      return;
    }
    setState(() => _loading = true);
    try {
      await ForumService.setDailyQuestion(
        language: _selectedLang,
        date: _selectedDate,
        text: text,
        id: _editingId,
      );
      if (mounted) {
        _textController.clear();
        setState(() => _editingId = null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi')));
        _loadQuestions();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteQuestion(ForumDailyQuestion q) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Günün sorusunu sil'),
        content: const Text('Bu soruyu silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: AppTheme.terracotta)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      await ForumService.deleteDailyQuestion(q.id);
      if (mounted) {
        if (_editingId == q.id) {
          _textController.clear();
          setState(() => _editingId = null);
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silindi')));
        _loadQuestions();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.sandBeige,
      appBar: AppBar(
        backgroundColor: AppTheme.sandBeige,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.forestCharcoal),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Admin paneli', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.forestCharcoal)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Günün sorusu', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.forestCharcoal)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null && mounted) {
                        setState(() => _selectedDate = d);
                        _loadQuestions();
                      }
                    },
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: Text(DateFormat('d MMM yyyy', 'tr').format(_selectedDate)),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.forestCharcoal),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedLang,
                    decoration: const InputDecoration(
                      labelText: 'Dil',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _langLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                    onChanged: (v) => setState(() => _selectedLang = v ?? 'tr'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Soru metni',
                hintText: 'Günün sorusunu yazın...',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: AppTheme.warmCream,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_editingId != null)
                  TextButton(
                    onPressed: () {
                      _textController.clear();
                      setState(() => _editingId = null);
                    },
                    child: const Text('Yeni soru'),
                  ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _save,
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.terracotta),
                  child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_editingId != null ? 'Güncelle' : 'Kaydet'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Kayıtlı sorular (${DateFormat('d MMM', 'tr').format(_selectedDate)})', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.forestCharcoal)),
            const SizedBox(height: 8),
            if (_loading && _questions.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppTheme.terracotta)))
            else if (_questions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Bu tarih için soru yok', style: TextStyle(color: AppTheme.mutedSage)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _questions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final q = _questions[i];
                  return Card(
                    color: AppTheme.warmCream,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      title: Text(q.text, style: const TextStyle(fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(_langLabels[q.language] ?? q.language, style: TextStyle(fontSize: 12, color: AppTheme.mutedSage)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.forestCharcoal),
                            onPressed: () => _editQuestion(q),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.terracotta),
                            onPressed: () => _deleteQuestion(q),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
