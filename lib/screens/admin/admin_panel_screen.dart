import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/app_theme.dart';
import '../../models/forum_daily_question.dart';
import '../../services/admin_role_service.dart';
import '../../services/forum_service.dart';
import '../../services/style_inspiration_pool_service.dart';
import '../../services/safety_event_service.dart';
import '../../services/memory_trigger_config_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedLang = 'tr';
  final _textController = TextEditingController();
  final _adminEmailController = TextEditingController();
  List<ForumDailyQuestion> _questions = [];
  bool _loading = false;
  bool _updatingAdmin = false;
  bool _checkingAccess = true;
  bool _isAuthorized = false;
  bool _canManageDailyQuestions = false;
  bool _canManageAdminEmails = false;
  bool? _searchedIsAdmin;
  String _searchedEmail = '';
  final _inspirationImageUrlController = TextEditingController();
  final _inspirationNoteController = TextEditingController();
  final _safetyUidFilterController = TextEditingController();
  final _triggerCrisisController = TextEditingController();
  final _triggerRelationshipController = TextEditingController();
  final _triggerAddictionController = TextEditingController();
  final _triggerSelfworthController = TextEditingController();
  final _triggerExplicitController = TextEditingController();
  bool _savingInspiration = false;
  bool _loadingTriggerConfig = false;
  bool _savingTriggerConfig = false;
  List<StyleInspirationItem> _latestInspirations = [];
  String? _editingId;
  String _safetySeverityFilter = 'all';
  DateTime _safetyFrom = DateTime.now().subtract(const Duration(days: 7));
  DateTime _safetyTo = DateTime.now();

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
    _checkAccessAndLoad();
  }

  @override
  void dispose() {
    _textController.dispose();
    _adminEmailController.dispose();
    _inspirationImageUrlController.dispose();
    _inspirationNoteController.dispose();
    _safetyUidFilterController.dispose();
    _triggerCrisisController.dispose();
    _triggerRelationshipController.dispose();
    _triggerAddictionController.dispose();
    _triggerSelfworthController.dispose();
    _triggerExplicitController.dispose();
    super.dispose();
  }

  Future<void> _checkAccessAndLoad() async {
    final isAdmin = await AdminRoleService.isCurrentUserAdmin();
    if (!mounted) return;
    if (!isAdmin) {
      setState(() {
        _isAuthorized = false;
        _checkingAccess = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin yetkisi gerekli.')),
        );
        Navigator.of(context).pop();
      });
      return;
    }

    final canManageDailyQuestions = await AdminRoleService.hasPermission(
        AdminPermission.manageDailyQuestions);
    final canManageAdminEmails =
        await AdminRoleService.isCurrentUserOwnerAdmin();

    setState(() {
      _isAuthorized = true;
      _checkingAccess = false;
      _canManageDailyQuestions = canManageDailyQuestions;
      _canManageAdminEmails = canManageAdminEmails;
    });
    await _loadQuestions();
    await _loadInspirations();
    await _loadMemoryTriggerConfig();
  }

  Future<void> _loadQuestions() async {
    if (!_isAuthorized) return;
    setState(() => _loading = true);
    final list = await ForumService.getDailyQuestionsForDate(_selectedDate);
    if (mounted) {
      setState(() =>
          _questions = list..sort((a, b) => a.language.compareTo(b.language)));
      setState(() => _loading = false);
    }
  }

  Future<void> _searchEmail() async {
    final email = _adminEmailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir e-posta girin.')),
      );
      return;
    }
    final isAdmin = await AdminRoleService.isEmailAdmin(email);
    if (!mounted) return;
    setState(() {
      _searchedEmail = email;
      _searchedIsAdmin = isAdmin;
    });
  }

  Future<void> _setEmailAdmin(bool shouldBeAdmin) async {
    final email = _adminEmailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir e-posta girin.')),
      );
      return;
    }
    if (_updatingAdmin) return;
    setState(() => _updatingAdmin = true);
    try {
      if (shouldBeAdmin) {
        await AdminRoleService.addAdminEmail(email);
      } else {
        await AdminRoleService.removeAdminEmail(email);
      }
      final isAdmin = await AdminRoleService.isEmailAdmin(email);
      if (!mounted) return;
      setState(() {
        _searchedEmail = email;
        _searchedIsAdmin = isAdmin;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shouldBeAdmin
                ? 'E-posta admin olarak eklendi.'
                : 'Admin yetkisi kaldırıldı.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İşlem başarısız: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingAdmin = false);
    }
  }

  Future<void> _loadInspirations() async {
    try {
      final items = await StyleInspirationPoolService.getLatest(limit: 6);
      if (!mounted) return;
      setState(() => _latestInspirations = items);
    } catch (_) {}
  }

  String _joinKeywords(List<String> values) => values.join(', ');

  List<String> _parseKeywords(String raw) {
    return raw
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _loadMemoryTriggerConfig() async {
    setState(() => _loadingTriggerConfig = true);
    try {
      final cfg = await MemoryTriggerConfigService.getConfig(forceRefresh: true);
      if (!mounted) return;
      _triggerCrisisController.text = _joinKeywords(cfg.crisis);
      _triggerRelationshipController.text = _joinKeywords(cfg.relationship);
      _triggerAddictionController.text = _joinKeywords(cfg.addiction);
      _triggerSelfworthController.text = _joinKeywords(cfg.selfworth);
      _triggerExplicitController.text = _joinKeywords(cfg.explicit);
    } finally {
      if (mounted) setState(() => _loadingTriggerConfig = false);
    }
  }

  Future<void> _saveMemoryTriggerConfig() async {
    if (_savingTriggerConfig) return;
    setState(() => _savingTriggerConfig = true);
    try {
      final cfg = MemoryTriggerConfig(
        crisis: _parseKeywords(_triggerCrisisController.text),
        relationship: _parseKeywords(_triggerRelationshipController.text),
        addiction: _parseKeywords(_triggerAddictionController.text),
        selfworth: _parseKeywords(_triggerSelfworthController.text),
        explicit: _parseKeywords(_triggerExplicitController.text),
      );
      final ok = await MemoryTriggerConfigService.saveConfig(cfg);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Memory trigger config kaydedildi.'
              : 'Kaydetme basarisiz (admin yetkisi gerekli).'),
        ),
      );
      if (ok) {
        await _loadMemoryTriggerConfig();
      }
    } finally {
      if (mounted) setState(() => _savingTriggerConfig = false);
    }
  }

  Future<void> _classifyAndAddInspiration() async {
    final imageUrl = _inspirationImageUrlController.text.trim();
    final note = _inspirationNoteController.text.trim();
    if (imageUrl.isEmpty || !imageUrl.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir görsel URL girin.')),
      );
      return;
    }
    if (_savingInspiration) return;
    setState(() => _savingInspiration = true);
    try {
      final saved = await StyleInspirationPoolService.classifyAndAdd(
        imageUrl: imageUrl,
        note: note,
      );
      if (!mounted) return;
      _inspirationImageUrlController.clear();
      _inspirationNoteController.clear();
      await _loadInspirations();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eklendi: ${saved.title} (${saved.category})'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eklenemedi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingInspiration = false);
    }
  }

  void _editQuestion(ForumDailyQuestion q) {
    setState(() {
      _editingId = q.id;
      _selectedLang = q.language;
      _textController.text = q.text;
    });
  }

  Future<void> _save() async {
    if (!_canManageDailyQuestions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Günün sorusu yönetim yetkin yok.')),
      );
      return;
    }
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Soru metni girin')));
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Kaydedildi')));
        _loadQuestions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteQuestion(ForumDailyQuestion q) async {
    if (!_canManageDailyQuestions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Günün sorusu silme yetkin yok.')),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Günün sorusunu sil'),
        content: const Text('Bu soruyu silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Sil', style: TextStyle(color: AppTheme.terracotta)),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Silindi')));
        _loadQuestions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return const Scaffold(
        backgroundColor: AppTheme.sandBeige,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.terracotta),
        ),
      );
    }

    if (!_isAuthorized) {
      return const Scaffold(
        backgroundColor: AppTheme.sandBeige,
        body: Center(
          child: Text('Bu alana erişim yetkin yok.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.sandBeige,
      appBar: AppBar(
        backgroundColor: AppTheme.sandBeige,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppTheme.forestCharcoal),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Admin paneli',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: AppTheme.forestCharcoal)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Günün sorusu',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: AppTheme.forestCharcoal)),
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
                    label: Text(
                        DateFormat('d MMM yyyy', 'tr').format(_selectedDate)),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.forestCharcoal),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedLang,
                    decoration: const InputDecoration(
                      labelText: 'Dil',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _langLabels.entries
                        .map((e) => DropdownMenuItem(
                            value: e.key, child: Text(e.value)))
                        .toList(),
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
                  onPressed:
                      (_loading || !_canManageDailyQuestions) ? null : _save,
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.terracotta),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_editingId != null ? 'Güncelle' : 'Kaydet'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
                'Kayıtlı sorular (${DateFormat('d MMM', 'tr').format(_selectedDate)})',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: AppTheme.forestCharcoal)),
            const SizedBox(height: 8),
            if (_loading && _questions.isEmpty)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                          color: AppTheme.terracotta)))
            else if (_questions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Bu tarih için soru yok',
                    style: TextStyle(color: AppTheme.mutedSage)),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      title: Text(q.text,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(_langLabels[q.language] ?? q.language,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.mutedSage)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                size: 20, color: AppTheme.forestCharcoal),
                            onPressed: _canManageDailyQuestions
                                ? () => _editQuestion(q)
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 20, color: AppTheme.terracotta),
                            onPressed: _canManageDailyQuestions
                                ? () => _deleteQuestion(q)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 28),
            const Divider(height: 1),
            const SizedBox(height: 20),
            Text(
              'Admin e-posta yönetimi',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: AppTheme.forestCharcoal),
            ),
            const SizedBox(height: 8),
            Text(
              _canManageAdminEmails
                  ? 'Tüm kullanıcı listesi yerine sadece e-posta ile admin yetkisi ver/kaldır.'
                  : 'Admin e-posta yönetimi sadece kurucu admine açık.',
              style: const TextStyle(color: AppTheme.mutedSage),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _adminEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                hintText: 'ornek@mail.com',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: AppTheme.warmCream,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: (_updatingAdmin || !_canManageAdminEmails)
                        ? null
                        : _searchEmail,
                    child: const Text('Ara'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: (_updatingAdmin || !_canManageAdminEmails)
                        ? null
                        : () => _setEmailAdmin(true),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.terracotta),
                    child: const Text('Admin Yap'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: (_updatingAdmin || !_canManageAdminEmails)
                        ? null
                        : () => _setEmailAdmin(false),
                    child: const Text('User Yap'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_searchedEmail.isNotEmpty && _searchedIsAdmin != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warmCream,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.softBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _searchedEmail,
                        style: const TextStyle(
                          color: AppTheme.forestCharcoal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(_searchedIsAdmin! ? 'Admin' : 'User'),
                      backgroundColor: _searchedIsAdmin!
                          ? AppTheme.sageGreen
                          : AppTheme.sandBeige,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 28),
            const Divider(height: 1),
            const SizedBox(height: 20),
            _buildMemoryTriggerConfigPanel(),
            const SizedBox(height: 28),
            const Divider(height: 1),
            const SizedBox(height: 20),
            _buildSafetyEventsPanel(),
            const SizedBox(height: 28),
            const Divider(height: 1),
            const SizedBox(height: 20),
            Text(
              'Hibrit ilham havuzu',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: AppTheme.forestCharcoal),
            ),
            const SizedBox(height: 8),
            const Text(
              'Kıyafet görsel linki ekle, AI sınıflandırsın ve hibrit mod önerilerinde kullanılsın.',
              style: TextStyle(color: AppTheme.mutedSage),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _inspirationImageUrlController,
              decoration: const InputDecoration(
                labelText: 'Görsel URL',
                hintText: 'https://...',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: AppTheme.warmCream,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _inspirationNoteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Kısa not (opsiyonel)',
                hintText: 'ör: ofis için rahat blazer',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: AppTheme.warmCream,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _savingInspiration ? null : _classifyAndAddInspiration,
                icon: const Icon(Icons.auto_awesome),
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.terracotta),
                label: Text(_savingInspiration
                    ? 'Ekleniyor...'
                    : 'AI Sınıflandır ve Ekle'),
              ),
            ),
            const SizedBox(height: 12),
            if (_latestInspirations.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _latestInspirations
                    .map(
                      (item) => Chip(
                        label: Text('${item.title} • ${item.category}'),
                        backgroundColor: AppTheme.sandBeige,
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyEventsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Safety olaylari',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: AppTheme.forestCharcoal),
        ),
        const SizedBox(height: 8),
        const Text(
          'Kriz anahtar kelime, hotline arama ve zorunlu check-in olaylari.',
          style: TextStyle(color: AppTheme.mutedSage),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickSafetyFromDate,
                icon: const Icon(Icons.date_range, size: 16),
                label: Text('Baslangic: ${DateFormat('d MMM', 'tr').format(_safetyFrom)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickSafetyToDate,
                icon: const Icon(Icons.event, size: 16),
                label: Text('Bitis: ${DateFormat('d MMM', 'tr').format(_safetyTo)}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _safetySeverityFilter,
                decoration: const InputDecoration(
                  labelText: 'Severity',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: SafetyEventService.severityLevels
                    .map((s) => DropdownMenuItem<String>(
                          value: s,
                          child: Text(s.toUpperCase()),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _safetySeverityFilter = v);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _safetyUidFilterController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'UID filtre (opsiyonel)',
                  hintText: 'kullanici uid',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: SafetyEventService.streamRecent(limit: 120),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: AppTheme.terracotta),
              );
            }
            final docs = snap.data?.docs ??
                const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Safety olayi yok'),
              );
            }
            final now = DateTime.now();
            final rangeFrom = DateTime(_safetyFrom.year, _safetyFrom.month, _safetyFrom.day);
            final rangeTo = DateTime(_safetyTo.year, _safetyTo.month, _safetyTo.day, 23, 59, 59);
            final inRange = docs.where((doc) {
              final ts = doc.data()['createdAt'];
              if (ts is! Timestamp) return false;
              final t = ts.toDate();
              return !t.isBefore(rangeFrom) && !t.isAfter(rangeTo);
            }).toList();

            final critical24h = inRange.where((doc) {
              final d = doc.data();
              final sev = (d['severity'] ?? 'medium').toString();
              final ts = d['createdAt'];
              if (sev != 'critical' || ts is! Timestamp) return false;
              final diff = now.difference(ts.toDate());
              return diff.inHours >= 0 && diff.inHours < 24;
            }).length;

            final uidFilter = _safetyUidFilterController.text.trim();
            final filtered = inRange.where((doc) {
              final d = doc.data();
              final sev = (d['severity'] ?? 'medium').toString();
              final uid = (d['uid'] ?? '').toString();
              final severityOk =
                  _safetySeverityFilter == 'all' || sev == _safetySeverityFilter;
              final uidOk = uidFilter.isEmpty || uid.contains(uidFilter);
              return severityOk && uidOk;
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCriticalCounter(critical24h),
                const SizedBox(height: 10),
                _buildTopRiskUsers(filtered),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: filtered.isEmpty ? null : () => _exportSafetyCsv(filtered),
                    icon: const Icon(Icons.download),
                    label: const Text('CSV disa aktar'),
                  ),
                ),
                const SizedBox(height: 8),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Filtreye uygun safety olayi yok'),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final d = filtered[i].data();
                      final ts = d['createdAt'];
                      final when = ts is Timestamp
                          ? DateFormat('d MMM HH:mm', 'tr').format(ts.toDate())
                          : '-';
                      final type = (d['type'] ?? '').toString();
                      final severity = (d['severity'] ?? 'medium').toString();
                      final addictionId = (d['addictionId'] ?? '').toString();
                      final uid = (d['uid'] ?? '').toString();
                      return Card(
                        color: AppTheme.warmCream,
                        child: ListTile(
                          title: Text('$type • $severity'),
                          subtitle: Text('$when  |  $addictionId  |  ${uid.isEmpty ? '-' : uid}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openSafetyEventDetail(d),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMemoryTriggerConfigPanel() {
    InputDecoration deco(String label, String hint) => InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: AppTheme.warmCream,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Memory trigger ayarlari',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: AppTheme.forestCharcoal),
        ),
        const SizedBox(height: 8),
        const Text(
          'Virgulle ayirarak yazin. Tetiklenince bellek acilir; aksi halde sessiz kalir.',
          style: TextStyle(color: AppTheme.mutedSage),
        ),
        const SizedBox(height: 12),
        if (_loadingTriggerConfig)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(color: AppTheme.terracotta),
          )
        else ...[
          TextField(
            controller: _triggerCrisisController,
            maxLines: 2,
            decoration: deco('Crisis', 'panik, kriz, dayanamiyorum'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _triggerRelationshipController,
            maxLines: 2,
            decoration: deco('Relationship', 'ayrildik, ghost, aldatti'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _triggerAddictionController,
            maxLines: 2,
            decoration: deco('Addiction', 'bozdum, tetiklendim, sigara'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _triggerSelfworthController,
            maxLines: 2,
            decoration: deco('Selfworth', 'degersizim, yetersizim'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _triggerExplicitController,
            maxLines: 2,
            decoration: deco('Explicit memory call', 'hatirliyor musun, gecen konusma'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loadingTriggerConfig ? null : _loadMemoryTriggerConfig,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Yenile'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _savingTriggerConfig ? null : _saveMemoryTriggerConfig,
                  icon: _savingTriggerConfig
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.terracotta),
                  label: Text(_savingTriggerConfig ? 'Kaydediliyor...' : 'Kaydet'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCriticalCounter(int critical24h) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: critical24h > 0 ? Colors.red.shade50 : AppTheme.warmCream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: critical24h > 0 ? Colors.red.shade300 : AppTheme.softBorder,
        ),
      ),
      child: Text(
        'Son 24 saat kritik olay: $critical24h',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: critical24h > 0 ? Colors.red.shade700 : AppTheme.forestCharcoal,
        ),
      ),
    );
  }

  Widget _buildTopRiskUsers(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final scoreByUid = <String, int>{};
    for (final doc in docs) {
      final d = doc.data();
      final uid = (d['uid'] ?? '').toString();
      if (uid.isEmpty) continue;
      final severity = (d['severity'] ?? 'medium').toString();
      final weight = switch (severity) {
        'critical' => 5,
        'high' => 3,
        'medium' => 2,
        _ => 1,
      };
      scoreByUid[uid] = (scoreByUid[uid] ?? 0) + weight;
    }
    final top = scoreByUid.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = top.take(5).toList();

    if (top5.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warmCream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top risky users (agırlıklı skor)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...top5.map((e) => Text('${e.key}  •  skor ${e.value}')),
        ],
      ),
    );
  }

  Future<void> _pickSafetyFromDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _safetyFrom,
      firstDate: DateTime(2020),
      lastDate: _safetyTo,
    );
    if (d == null || !mounted) return;
    setState(() => _safetyFrom = d);
  }

  Future<void> _pickSafetyToDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _safetyTo,
      firstDate: _safetyFrom,
      lastDate: DateTime.now(),
    );
    if (d == null || !mounted) return;
    setState(() => _safetyTo = d);
  }

  String _csvEscape(String value) {
    final safe = value.replaceAll('"', '""');
    return '"$safe"';
  }

  Future<void> _exportSafetyCsv(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln('createdAt,type,severity,uid,addictionId,data');
    for (final doc in docs) {
      final d = doc.data();
      final ts = d['createdAt'];
      final when = ts is Timestamp ? ts.toDate().toIso8601String() : '';
      final type = (d['type'] ?? '').toString();
      final severity = (d['severity'] ?? '').toString();
      final uid = (d['uid'] ?? '').toString();
      final addictionId = (d['addictionId'] ?? '').toString();
      final data = (d['data'] ?? const {}).toString();
      buffer.writeln([
        _csvEscape(when),
        _csvEscape(type),
        _csvEscape(severity),
        _csvEscape(uid),
        _csvEscape(addictionId),
        _csvEscape(data),
      ].join(','));
    }

    final csv = buffer.toString();
    await Share.share(csv, subject: 'mentaliq_safety_events_export');
  }

  void _openSafetyEventDetail(Map<String, dynamic> d) {
    final ts = d['createdAt'];
    final when = ts is Timestamp
        ? DateFormat('d MMM yyyy HH:mm', 'tr').format(ts.toDate())
        : '-';
    final data = (d['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Safety event detay'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tip: ${(d['type'] ?? '-').toString()}'),
              Text('Severity: ${(d['severity'] ?? '-').toString()}'),
              Text('UID: ${(d['uid'] ?? '-').toString()}'),
              Text('Addiction: ${(d['addictionId'] ?? '-').toString()}'),
              Text('Zaman: $when'),
              const SizedBox(height: 10),
              const Text('Data:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(data.isEmpty ? '-' : data.toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}
