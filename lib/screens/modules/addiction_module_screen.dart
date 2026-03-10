import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../l10n/app_translations.dart';
import '../../models/user_dna_model.dart';
import '../../services/addiction_service.dart';
import '../../services/auth_service.dart';
import '../../services/crisis_hotline_service.dart';
import '../../services/emergency_contact_service.dart';
import '../../services/proactive_checkin_service.dart';
import '../../services/safety_event_service.dart';
import '../../services/token_service.dart';
import '../../services/user_dna_service.dart';
import '../../widgets/token_dialog.dart';

class AddictionModuleScreen extends StatefulWidget {
  final String? initialAddictionId;

  const AddictionModuleScreen({super.key, this.initialAddictionId});

  @override
  State<AddictionModuleScreen> createState() => _AddictionModuleScreenState();
}

class _AddictionModuleScreenState extends State<AddictionModuleScreen> {
  bool _isAdding = false;

  @override
  Widget build(BuildContext context) {
    final addictions = UserDNAService.currentDNA?.activeAddictions ?? const <AddictionDna>[];

    return Scaffold(
      backgroundColor: AppTheme.sandBeige,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: addictions.isEmpty
                  ? _buildSelectionPanel(currentAddictions: addictions)
                  : _buildAddictionTabs(
                      addictions,
                      initialAddictionId: widget.initialAddictionId,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'MENTALIQ / BAGIMLILIK DESTEK',
              style: TextStyle(
                color: AppTheme.forestCharcoal,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: AppTheme.forestCharcoal),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionPanel({
    List<AddictionDna> currentAddictions = const [],
    void Function(int tabIndex)? onOpenExisting,
  }) {
    final options = [
      {'id': 'gambling', 'label': AppTranslations.get('gambling'), 'icon': '🎰', 'type': 'behavioral'},
      {'id': 'smoking', 'label': AppTranslations.get('smoking'), 'icon': '🚬', 'type': 'substance'},
      {'id': 'social_media', 'label': AppTranslations.get('socialMedia'), 'icon': '📱', 'type': 'behavioral'},
      {'id': 'sugar', 'label': AppTranslations.get('sugar'), 'icon': '🍬', 'type': 'substance'},
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Aktif + proaktif destek',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.forestCharcoal),
        ),
        const SizedBox(height: 8),
        const Text(
          'Risk takibi, mikro gorev, SOS, guven kisi ve zamanli check-in aktif.',
          style: TextStyle(color: AppTheme.mutedSage),
        ),
        const SizedBox(height: 20),
        ...options.map((opt) {
          final optionId = opt['id']!;
          final existingIndex =
              currentAddictions.indexWhere((a) => a.id == optionId);
          final isAlreadyTracking = existingIndex >= 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: Text(opt['icon']!, style: const TextStyle(fontSize: 30)),
              title: Text(opt['label']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Aktif takip + proaktif check-in'),
              trailing: _isAdding
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _isAdding
                  ? null
                  : () async {
                      if (isAlreadyTracking) {
                        onOpenExisting?.call(existingIndex);
                        return;
                      }
                      setState(() => _isAdding = true);
                      await AddictionService.startTracking(optionId, opt['type']!);
                      if (mounted) setState(() => _isAdding = false);
                    },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAddictionTabs(
    List<AddictionDna> addictions, {
    String? initialAddictionId,
  }) {
    final index = initialAddictionId == null
        ? 0
        : addictions.indexWhere((a) => a.id == initialAddictionId);
    final initialIndex = index < 0 ? 0 : index;

    return DefaultTabController(
      length: addictions.length + 1,
      initialIndex: initialIndex,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            labelColor: AppTheme.forestCharcoal,
            indicatorColor: AppTheme.terracotta,
            tabs: [
              ...addictions.map((a) => Tab(text: a.id.toUpperCase())),
              const Tab(icon: Icon(Icons.add_circle_outline)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ...addictions.asMap().entries.map(
                      (entry) => _ActiveAddictionView(
                        addictionId: entry.value.id,
                        tabIndex: entry.key,
                      ),
                    ),
                Builder(
                  builder: (ctx) => _buildSelectionPanel(
                    currentAddictions: addictions,
                    onOpenExisting: (tabIndex) {
                      final controller = DefaultTabController.of(ctx);
                      controller.animateTo(tabIndex);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveAddictionView extends StatefulWidget {
  final String addictionId;
  final int tabIndex;
  const _ActiveAddictionView({
    required this.addictionId,
    required this.tabIndex,
  });

  @override
  State<_ActiveAddictionView> createState() => _ActiveAddictionViewState();
}

class _ActiveAddictionViewState extends State<_ActiveAddictionView> {
  AddictionSnapshot? _snapshot;
  String _greeting = '';
  String _mission = '';
  String _nudge = '';
  bool _loading = true;
  bool _busy = false;
  bool _forcedCheckShown = false;
  bool _needsIntake = false;
  bool _isInitializedForTab = false;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.maybeOf(context);
    if (controller == null) return;
    if (_tabController == controller) {
      _maybeLoadIfActive();
      return;
    }
    _tabController?.removeListener(_onTabChanged);
    _tabController = controller;
    _tabController!.addListener(_onTabChanged);
    _maybeLoadIfActive();
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (!mounted) return;
    _maybeLoadIfActive();
  }

  void _maybeLoadIfActive() {
    final controller = _tabController;
    if (controller == null) return;
    if (controller.index != widget.tabIndex) return;
    if (_isInitializedForTab) return;
    _isInitializedForTab = true;
    _refresh();
  }

  Future<void> _refresh({bool consumeToken = true}) async {
    if (consumeToken) {
      final canProceed = await _ensureUsageTokens();
      if (!canProceed) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }
    }

    setState(() => _loading = true);
    final snapshot = AddictionService.getSnapshot(widget.addictionId);
    final needsIntake = AddictionService.needsIntake(widget.addictionId);
    final greetingFuture = AddictionService.getEntryGreeting(widget.addictionId);
    final missionFuture = needsIntake
        ? Future.value('Ilk adim: kisa durum degerlendirmesini tamamla.')
        : AddictionService.generateOrGetDailyMission(widget.addictionId);
    final nudgeFuture = needsIntake
        ? Future.value('Durumunu netlestirirsek dogru mudahale veririz.')
        : AddictionService.getProactiveNudge(widget.addictionId);
    final results = await Future.wait<String>([
      greetingFuture,
      missionFuture,
      nudgeFuture,
    ]);
    final greeting = results[0];
    final mission = results[1];
    final nudge = results[2];

    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _greeting = greeting;
      _mission = mission;
      _nudge = nudge;
      _needsIntake = needsIntake;
      _loading = false;
    });
    if (!needsIntake) {
      _maybeForceCheckIn(snapshot);
    }
  }

  void _maybeForceCheckIn(AddictionSnapshot snapshot) {
    if (_forcedCheckShown) return;
    if (snapshot.riskScore < 85) return;
    _forcedCheckShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await SafetyEventService.log(
        type: SafetyEventType.forcedCheckInTriggered,
        addictionId: widget.addictionId,
        severity: 'high',
        data: {'riskScore': snapshot.riskScore, 'source': 'in_app_gate'},
      );
      await _openQuickCheckIn();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final addiction = _snapshot!.addiction;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _riskCard(),
          const SizedBox(height: 14),
          _coachLineCard(),
          const SizedBox(height: 14),
          _missionCard(addiction),
          if (_needsIntake) ...[
            const SizedBox(height: 12),
            _intakeCard(),
          ],
          const SizedBox(height: 14),
          _proactiveCard(),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: _buildActionButton('Quick Check-in', Colors.blueGrey, _openQuickCheckIn)),
              const SizedBox(width: 10),
              Expanded(child: _buildActionButton('SOS', Colors.red, _openSos)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _riskCard() {
    final danger = _snapshot!.riskScore >= 75;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: danger ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: danger ? Colors.red : AppTheme.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: AppTheme.terracotta),
              const SizedBox(width: 8),
              Text(
                'Durum: ${_snapshot!.modeLabel}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'Risk ${_snapshot!.riskScore}/100',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_snapshot!.modeHint),
        ],
      ),
    );
  }

  Widget _coachLineCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _greeting,
        style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
      ),
    );
  }

  Widget _missionCard(AddictionDna addiction) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: addiction.isMissionCompleted ? Colors.grey.shade200 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: addiction.isMissionCompleted ? Colors.grey.shade400 : AppTheme.terracotta,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            addiction.isMissionCompleted ? 'Bugunun gorevi tamamlandi' : 'Gunluk mikro gorev',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.terracotta),
          ),
          const SizedBox(height: 8),
          Text(_mission, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (!addiction.isMissionCompleted && !_needsIntake)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.terracotta),
                onPressed: _busy ? null : _verifyMission,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Yaptim, dogrula', style: TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _intakeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ilk Degerlendirme (Zorunlu)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text('Sana uygun plan icin once bagimlilik seviyeni olcelim.'),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _openIntake,
              child: const Text('Degerlendirmeyi Baslat'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _proactiveCard() {
    final protocol = AddictionService.getSosProtocol(widget.addictionId);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Proaktif destek', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_nudge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniAction('Stres', () => _showProtocol('stres')),
              _miniAction('Yalnizlik', () => _showProtocol('yalnizlik')),
              _miniAction('Can sikintisi', () => _showProtocol('can sikintisi')),
            ],
          ),
          const SizedBox(height: 10),
          Text('Hizli protokol: ${protocol.first}', style: const TextStyle(color: AppTheme.mutedSage)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _configureCheckInSchedule,
            icon: const Icon(Icons.schedule),
            label: const Text('Check-in saatlerini ayarla'),
          ),
        ],
      ),
    );
  }

  Widget _miniAction(String title, VoidCallback onTap) {
    return OutlinedButton(onPressed: onTap, child: Text(title));
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _verifyMission() async {
    final reflection = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _MissionVerificationSheet(),
    );

    if (reflection == null || reflection.trim().isEmpty) return;
    final canProceed = await _ensureUsageTokens();
    if (!canProceed) return;
    setState(() => _busy = true);
    final result = await AddictionService.verifyMissionAndMaybeComplete(widget.addictionId, reflection);

    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    await _refresh(consumeToken: false);
  }

  Future<void> _openIntake() async {
    final answers = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _IntakeSheet(addictionId: widget.addictionId),
    );
    if (answers == null || answers.isEmpty) return;
    final canProceed = await _ensureUsageTokens();
    if (!canProceed) return;
    setState(() => _busy = true);
    final result = await AddictionService.submitIntakeAnswers(widget.addictionId, answers);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Intake tamamlandi: ${result.summary}')),
    );
    await _refresh(consumeToken: false);
  }

  Future<void> _openQuickCheckIn() async {
    final checkIn = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _QuickCheckInSheet(),
    );

    if (checkIn == null) return;
    await AddictionService.saveQuickCheckIn(
      widget.addictionId,
      cravingLevel: (checkIn['level'] as int?) ?? 5,
      trigger: (checkIn['trigger'] as String?) ?? '',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check-in kaydedildi')));
    await _refresh(consumeToken: false);
  }

  Future<bool> _ensureUsageTokens() async {
    final result = await TokenService.consumeAddictionUsage();
    if (!mounted) return false;
    if (result == TokenConsumeResult.successFree) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.get('addictionFirstUseFreeToast'))),
      );
      return true;
    }
    if (result == TokenConsumeResult.successPaid) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppTranslations.get('addictionTokensFinishedToast'))),
    );
    final rewarded = await TokenDialog.show(context);
    if (!rewarded) return false;
    final retry = await TokenService.consumeAddictionUsage();
    return retry == TokenConsumeResult.successFree ||
        retry == TokenConsumeResult.successPaid;
  }

  void _openSos() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _CrisisRoom(addictionId: widget.addictionId)),
    );
  }

  void _showProtocol(String trigger) {
    final steps = AddictionService.getSosProtocol(widget.addictionId, trigger: trigger);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('3 adimli acil protokol'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: steps.map((s) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('• $s'))).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
        ],
      ),
    );
  }

  Future<void> _configureCheckInSchedule() async {
    final current = await ProactiveCheckInService.getSchedule();
    if (!mounted) return;
    final next = await showModalBottomSheet<CheckInSchedule>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CheckInScheduleSheet(initial: current),
    );
    if (next == null) return;

    await ProactiveCheckInService.saveSchedule(next);
    await ProactiveCheckInService.runDueCheckIns();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Check-in saatleri guncellendi')),
    );
  }
}

class _MissionVerificationSheet extends StatefulWidget {
  const _MissionVerificationSheet();

  @override
  State<_MissionVerificationSheet> createState() => _MissionVerificationSheetState();
}

class _MissionVerificationSheetState extends State<_MissionVerificationSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Gorevi nasil yaptin?', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Kisa ve net yaz. Ornek: 7 dakika dayandim, uygulamayi acmadim.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
              child: const Text('Dogrulamaya gonder'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCheckInSheet extends StatefulWidget {
  const _QuickCheckInSheet();

  @override
  State<_QuickCheckInSheet> createState() => _QuickCheckInSheetState();
}

class _IntakeSheet extends StatefulWidget {
  final String addictionId;
  const _IntakeSheet({required this.addictionId});

  @override
  State<_IntakeSheet> createState() => _IntakeSheetState();
}

class _IntakeSheetState extends State<_IntakeSheet> {
  late final List<String> _questions;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _questions = AddictionService.getIntakeQuestions(widget.addictionId);
    for (final q in _questions) {
      _controllers[q] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ilk Degerlendirme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            ..._questions.map((q) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _controllers[q],
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: q,
                    border: const OutlineInputBorder(),
                  ),
                ),
              );
            }),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final answers = <String, String>{};
                  for (final q in _questions) {
                    final value = _controllers[q]!.text.trim();
                    if (value.isNotEmpty) {
                      answers[q] = value;
                    }
                  }
                  if (answers.length < 3) return;
                  Navigator.pop(context, answers);
                },
                child: const Text('Analize Gonder'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickCheckInSheetState extends State<_QuickCheckInSheet> {
  double _level = 5;
  String _trigger = '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Check-in', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('Durtu seviyesi: ${_level.round()}/10'),
          Slider(
            value: _level,
            min: 0,
            max: 10,
            divisions: 10,
            onChanged: (v) => setState(() => _level = v),
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Tetikleyici (tek kelime yeterli)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _trigger = v,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {'level': _level.round(), 'trigger': _trigger});
              },
              child: const Text('Kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInScheduleSheet extends StatefulWidget {
  final CheckInSchedule initial;
  const _CheckInScheduleSheet({required this.initial});

  @override
  State<_CheckInScheduleSheet> createState() => _CheckInScheduleSheetState();
}

class _CheckInScheduleSheetState extends State<_CheckInScheduleSheet> {
  late bool _enabled;
  late List<int> _hours;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initial.enabled;
    _hours = [...widget.initial.hours];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Proaktif check-in saatleri', style: TextStyle(fontWeight: FontWeight.bold)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Aktif'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(24, (hour) {
              final selected = _hours.contains(hour);
              return ChoiceChip(
                label: Text('${hour.toString().padLeft(2, '0')}:00'),
                selected: selected,
                onSelected: (on) {
                  setState(() {
                    if (on) {
                      _hours.add(hour);
                    } else {
                      _hours.remove(hour);
                    }
                    _hours = _hours.toSet().toList()..sort();
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final safeHours = _hours.isEmpty ? [10, 16, 21] : _hours;
                Navigator.pop(
                  context,
                  CheckInSchedule(enabled: _enabled, hours: safeHours),
                );
              },
              child: const Text('Kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrisisRoom extends StatefulWidget {
  final String addictionId;
  const _CrisisRoom({required this.addictionId});

  @override
  State<_CrisisRoom> createState() => _CrisisRoomState();
}

class _CrisisRoomState extends State<_CrisisRoom> {
  final List<String> _chat = [];
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final protocol = AddictionService.getSosProtocol(widget.addictionId);
    _chat.add('Sistem: ${protocol[0]}');
    _chat.add('Sistem: ${protocol[1]}');
    _chat.add('Sistem: ${protocol[2]}');
    _initiate();
  }

  Future<void> _initiate() async {
    final canProceed = await _ensureUsageTokens();
    if (!canProceed) return;
    final first = await AddictionService.handleCrisisMessage(widget.addictionId, 'SOS basladi');
    if (!mounted) return;
    setState(() => _chat.add('Uzman: $first'));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade900,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Acil Destek'),
        actions: [
          TextButton(
            onPressed: _openSafetyActions,
            child: const Text('Guven Kisi', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _chat.length,
              itemBuilder: (_, i) {
                final text = _chat[i];
                final isUser = text.startsWith('Sen:');
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.white : Colors.black87,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(color: isUser ? Colors.black : Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Ne hissediyorsun?',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _busy ? null : _send,
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final message = _ctrl.text.trim();
    if (message.isEmpty) return;
    if (AddictionService.isHighSafetyRiskMessage(message)) {
      await SafetyEventService.log(
        type: SafetyEventType.crisisKeywordDetected,
        addictionId: widget.addictionId,
        severity: 'critical',
        data: {'message': message},
      );
      setState(() {
        _chat.add('Sen: $message');
        _chat.add('Sistem: ${AddictionService.getHardSafetyResponse()}');
        _ctrl.clear();
      });
      await _openSafetyActions();
      return;
    }
    setState(() {
      _busy = true;
      _chat.add('Sen: $message');
      _ctrl.clear();
    });
    final canProceed = await _ensureUsageTokens();
    if (!canProceed) {
      if (mounted) {
        setState(() => _busy = false);
      }
      return;
    }
    await SafetyEventService.log(
      type: SafetyEventType.crisisChatMessage,
      addictionId: widget.addictionId,
      severity: 'high',
      data: {'message': message},
    );
    final reply = await AddictionService.handleCrisisMessage(widget.addictionId, message);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _chat.add('Uzman: $reply');
    });
  }

  Future<bool> _ensureUsageTokens() async {
    final result = await TokenService.consumeAddictionUsage();
    if (!mounted) return false;
    if (result == TokenConsumeResult.successFree) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.get('addictionFirstUseFreeToast'))),
      );
      return true;
    }
    if (result == TokenConsumeResult.successPaid) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppTranslations.get('addictionTokensFinishedToast'))),
    );
    final rewarded = await TokenDialog.show(context);
    if (!rewarded) return false;
    final retry = await TokenService.consumeAddictionUsage();
    return retry == TokenConsumeResult.successFree ||
        retry == TokenConsumeResult.successPaid;
  }

  Future<void> _openSafetyActions() async {
    await SafetyEventService.log(
      type: SafetyEventType.safetyActionsOpened,
      addictionId: widget.addictionId,
      severity: 'high',
    );
    if (!mounted) return;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SafetyActionsSheet(addictionId: widget.addictionId),
    );
    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
  }
}

class _SafetyActionsSheet extends StatefulWidget {
  final String addictionId;
  const _SafetyActionsSheet({required this.addictionId});

  @override
  State<_SafetyActionsSheet> createState() => _SafetyActionsSheetState();
}

class _SafetyActionsSheetState extends State<_SafetyActionsSheet> {
  EmergencyContact? _contact;
  List<CrisisHotlineEntry> _hotlines = const [];
  String _countryCode = 'US';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final contact = await EmergencyContactService.getContact();
    final hotlines = await CrisisHotlineService.getHotlinesForCurrentUser();
    final countryCode = await CrisisHotlineService.getCurrentCountryCode();
    if (!mounted) return;
    setState(() {
      _contact = contact;
      _hotlines = hotlines;
      _countryCode = countryCode;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Acil guvenlik aksiyonlari', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_contact == null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_add_alt_1),
              title: const Text('Guven kisi ekle'),
              subtitle: const Text('Kriz aninda tek tikla ara/SMS'),
              onTap: _editContact,
            )
          else
            Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_user),
                  title: Text(_contact!.name),
                  subtitle: Text('${_contact!.relation} · ${_contact!.phone}'),
                  trailing: IconButton(icon: const Icon(Icons.edit), onPressed: _editContact),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final ok = await EmergencyContactService.callContact(_contact!);
                          await SafetyEventService.log(
                            type: SafetyEventType.emergencyContactCallAttempt,
                            addictionId: widget.addictionId,
                            severity: 'critical',
                            data: {'ok': ok},
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context, ok ? 'Guven kisi aramasi baslatildi' : 'Arama baslatilamadi');
                        },
                        icon: const Icon(Icons.call),
                        label: const Text('Ara'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final msg =
                              'Acil destek ihtiyacim var. Benimle iletisime gecebilir misin? (${widget.addictionId})';
                          final ok = await EmergencyContactService.smsContact(_contact!, msg);
                          await SafetyEventService.log(
                            type: SafetyEventType.emergencyContactSmsAttempt,
                            addictionId: widget.addictionId,
                            severity: 'critical',
                            data: {'ok': ok},
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context, ok ? 'SMS uygulamasi acildi' : 'SMS baslatilamadi');
                        },
                        icon: const Icon(Icons.sms),
                        label: const Text('SMS'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 6),
          const Text('Ulke bazli kriz hatlari', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.softBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<String>(
              isExpanded: true,
              underline: const SizedBox.shrink(),
              value: CrisisHotlineService.supportedCountryCodes.contains(_countryCode) ? _countryCode : 'US',
              items: CrisisHotlineService.supportedCountryCodes
                  .map((code) => DropdownMenuItem<String>(
                        value: code,
                        child: Text('$code - ${CrisisHotlineService.countryNames[code] ?? code}'),
                      ))
                  .toList(),
              onChanged: (value) async {
                if (value == null) return;
                await CrisisHotlineService.setCurrentUserCountryCode(value);
                if (!mounted) return;
                setState(() => _countryCode = value);
                await _load();
              },
            ),
          ),
          const SizedBox(height: 8),
          ..._hotlines.map((h) {
            return Card(
              child: ListTile(
                title: Text(h.title),
                subtitle: Text('${h.region} · ${h.phone}'),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    if (h.phone != 'N/A')
                      IconButton(
                        icon: const Icon(Icons.call),
                        onPressed: () async {
                          final ok = await CrisisHotlineService.callHotline(h.phone);
                          await SafetyEventService.log(
                            type: SafetyEventType.hotlineCallAttempt,
                            addictionId: widget.addictionId,
                            severity: 'critical',
                            data: {'ok': ok, 'region': h.region, 'phone': h.phone},
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context, ok ? 'Kriz hattina yonlendirildi' : 'Arama baslatilamadi');
                        },
                      ),
                    if (h.website != null)
                      IconButton(
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () async {
                          final ok = await CrisisHotlineService.openWebsite(h.website!);
                          if (!context.mounted) return;
                          Navigator.pop(context, ok ? 'Kriz kaynagi acildi' : 'Baglanti acilamadi');
                        },
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _editContact() async {
    final initial = _contact;
    final updated = await showModalBottomSheet<EmergencyContact>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EmergencyContactSheet(initial: initial),
    );
    if (updated == null) return;
    await EmergencyContactService.saveContact(updated);
    await AuthService.updateProfile({'lastSafetyUpdate': DateTime.now().toIso8601String()});
    await _load();
  }
}

class _EmergencyContactSheet extends StatefulWidget {
  final EmergencyContact? initial;
  const _EmergencyContactSheet({this.initial});

  @override
  State<_EmergencyContactSheet> createState() => _EmergencyContactSheetState();
}

class _EmergencyContactSheetState extends State<_EmergencyContactSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _relationCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial?.name ?? '');
    _phoneCtrl = TextEditingController(text: widget.initial?.phone ?? '');
    _relationCtrl = TextEditingController(text: widget.initial?.relation ?? 'Aile');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _relationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Guven kisi', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Ad', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefon', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _relationCtrl, decoration: const InputDecoration(labelText: 'Yakinlik', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final contact = EmergencyContact(
                  name: _nameCtrl.text.trim(),
                  phone: _phoneCtrl.text.trim(),
                  relation: _relationCtrl.text.trim(),
                );
                if (!contact.isValid) return;
                Navigator.pop(context, contact);
              },
              child: const Text('Kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}
