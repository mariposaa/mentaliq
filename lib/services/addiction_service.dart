import 'dart:convert';
import '../models/user_dna_model.dart';
import '../services/user_dna_service.dart';
import '../services/gemini_service.dart';

enum AddictionRiskMode { normal, elevated, crisis, relapseRecovery }

class AddictionSnapshot {
  final AddictionDna addiction;
  final int riskScore;
  final AddictionRiskMode mode;
  final String modeLabel;
  final String modeHint;

  const AddictionSnapshot({
    required this.addiction,
    required this.riskScore,
    required this.mode,
    required this.modeLabel,
    required this.modeHint,
  });
}

class MissionVerificationResult {
  final bool approved;
  final String message;

  const MissionVerificationResult({
    required this.approved,
    required this.message,
  });
}

class AddictionIntakeResult {
  final int severity; // 0-10
  final String stage;
  final int dailyEpisodes;
  final String summary;
  final String focus;

  const AddictionIntakeResult({
    required this.severity,
    required this.stage,
    required this.dailyEpisodes,
    required this.summary,
    required this.focus,
  });
}

/// Phase-1 addiction support engine
class AddictionService {
  static const Map<String, String> trackedTypeById = {
    'gambling': 'behavioral',
    'smoking': 'substance',
    'sugar': 'substance',
    'social_media': 'behavioral',
    'gaming': 'behavioral',
    'vaping': 'substance',
  };

  static const List<String> _criticalSafetyKeywords = [
    'intihar',
    'kendime zarar',
    'kendimi oldur',
    'yasamak istemiyorum',
    'i want to die',
    'kill myself',
    'self harm',
    'suicide',
    'overdose',
    'olmek istiyorum',
  ];

  static String _getAuditorPrompt() {
    return '''
You are 'The Auditor'. The user is fighting gambling addiction.
Identity: World-class Behavioral Economist & Math Expert. Cold, analytical, truth-focused.
Psychological Framework: 'Prospect Theory' & 'Cognitive Debiasing'.
Core Tasks:
1. DEBUNK: Use 'Gambler’s Fallacy' (The coin has no memory) to destroy "luck is due" thoughts.
2. FINANCIAL REALITY: Constantly reference 'Total Lost Capital'. Show the 'Opportunity Cost' (e.g., "With that 5000TL, you burnt a vacation").
3. TONE: No empathy for value destruction. Sobering, mathematical, high-impact.
Language: Detect user's system language and respond in that language.
''';
  }

  static String _getBioHackerPrompt() {
    return '''
You are 'The Bio-Hacker'. User is fighting substance addiction (Smoking/Sugar).
Identity: Neurochemistry & Physiology Expert. 
Psychological Framework: 'Interoceptive Exposure' & 'ACT (Acceptance and Commitment Therapy)'.
Core Tasks:
1. URGE SURFING: Remind them cravings follow a wave pattern (peak at 3 mins, then subside).
2. PHYSIOLOGY: Give somatic commands (e.g., "activate mammalian dive reflex with cold water").
3. REFRAMING: Shift focus from "deprivation" to "healing dopamine receptors".
Tone: Clinical, calm, authoritative but grounding.
Language: Detect user's system language and respond in that language.
''';
  }

  static String _getArchitectPrompt() {
    return '''
You are 'The Architect'. User is fighting digital addiction (Social Media/Gaming).
Identity: Digital Minimalist & Attention Economy Strategist.
Psychological Framework: 'Environmental Design' & 'Dopamine Fasting'.
Core Tasks:
1. FRICTION: Instructions to increase physical/digital effort to access the addiction (e.g., "Grayscale mode", "Delete app icon").
2. ATTENTION: Explain how algorithms hack their 'Reward Prediction Error'.
3. REPLACEMENT: Suggest high-quality analog alternatives immediately.
Tone: Strategic, modern, 'Life-Hack' style.
Language: Detect user's system language and respond in that language.
''';
  }

  static String _getSystemPromptFor(String id) {
    if (id == 'gambling') return _getAuditorPrompt();
    if (['smoking', 'sugar', 'vaping'].contains(id)) return _getBioHackerPrompt();
    if (['social_media', 'gaming'].contains(id)) return _getArchitectPrompt();
    return _getBioHackerPrompt(); // Default fallback
  }

  static String _sanitizeText(String text) {
    return text.replaceAll('"', '').trim();
  }

  static List<String> getIntakeQuestions(String addictionId) {
    if (addictionId == 'gambling') {
      return const [
        'Son 7 gunde kac kez kumar oynadin?',
        'Bir oturumda ortalama ne kadar para riske atiyorsun?',
        'En guclu tetikleyicin ne? (stres, can sikintisi, yalnizlik...)',
        'Kaybettikten sonra geri almaya calisiyor musun?',
        'Birakmaya hazirlik seviyen kac? (0-10)',
      ];
    }
    if (addictionId == 'smoking') {
      return const [
        'Gunde ortalama kac sigara tuketiyorsun?',
        'Ilk sigarayi uyandiktan ne kadar sonra iciyorsun?',
        'En guclu tetikleyicin ne? (kahve, stres, sosyal ortam...)',
        'Daha once birakma denemesi yaptin mi?',
        'Birakmaya hazirlik seviyen kac? (0-10)',
      ];
    }
    if (addictionId == 'social_media') {
      return const [
        'Gunde ortalama kac saat sosyal medya kullaniyorsun?',
        'En cok hangi saatlerde kontrol ediyorsun?',
        'Tetikleyicin ne? (yalnizlik, kacis, aliskanlik...)',
        'Kontrol kaybi hissediyor musun? (bildirim gelmese de bakma)',
        'Azaltmaya hazirlik seviyen kac? (0-10)',
      ];
    }
    return const [
      'Son 7 gunde bu davranis kac kez oldu?',
      'En guclu tetikleyicin ne?',
      'Kontrol kaybi hissettigin oluyor mu?',
      'Degisime hazirlik seviyen kac? (0-10)',
    ];
  }

  static bool needsIntake(String addictionId) {
    final a = _findAddiction(addictionId);
    return a == null || !a.assessmentCompleted;
  }

  static bool isHighSafetyRiskMessage(String message) {
    final lowered = message.toLowerCase();
    return _criticalSafetyKeywords.any(lowered.contains);
  }

  static String getHardSafetyResponse() {
    return 'Bu kritik bir guvenlik durumu olabilir. '
        'Yalniz kalma. Hemen guven kisini veya yerel acil hatti ara. '
        'Su an tek hedef guvende kalmak.';
  }

  static AddictionDna? _findAddiction(String addictionId) {
    final userDna = UserDNAService.currentDNA;
    final addictions = userDna?.activeAddictions ?? const <AddictionDna>[];
    for (final addiction in addictions) {
      if (addiction.id == addictionId) return addiction;
    }
    return null;
  }

  static Future<void> _updateAddiction(
    String addictionId,
    AddictionDna Function(AddictionDna) updater,
  ) async {
    final userDna = UserDNAService.currentDNA;
    if (userDna == null || userDna.activeAddictions == null) return;

    final updatedAddictions = userDna.activeAddictions!.map((a) {
      if (a.id == addictionId) return updater(a);
      return a;
    }).toList();

    await UserDNAService.updateDNA(UserDNAModel(activeAddictions: updatedAddictions));
  }

  static int _riskScoreFor(AddictionDna addiction) {
    final lowWillpowerRisk = (1 - addiction.willpowerIndex).clamp(0.0, 1.0) * 60;
    final triggerRisk = (addiction.triggers.length * 4).clamp(0, 20);
    final streakProtection = (addiction.streakDays * 1.5).clamp(0, 20);
    final severityRisk = (addiction.dependencySeverity * 3).clamp(0, 30);
    final gamblingRisk = addiction.id == 'gambling'
        ? (addiction.averageDailyBet * 0.02).clamp(0, 20)
        : 0.0;

    final raw = lowWillpowerRisk + triggerRisk + severityRisk + gamblingRisk - streakProtection;
    return raw.round().clamp(0, 100);
  }

  static AddictionRiskMode _modeFor(AddictionDna addiction, int score) {
    final recentRelapse = addiction.lastRelapse != null &&
        DateTime.now().difference(addiction.lastRelapse!).inHours <= 48;
    if (recentRelapse) return AddictionRiskMode.relapseRecovery;
    if (score >= 75) return AddictionRiskMode.crisis;
    if (score >= 50) return AddictionRiskMode.elevated;
    return AddictionRiskMode.normal;
  }

  static AddictionSnapshot snapshotFromAddiction(AddictionDna addiction) {
    final score = _riskScoreFor(addiction);
    final mode = _modeFor(addiction, score);

    switch (mode) {
      case AddictionRiskMode.crisis:
        return AddictionSnapshot(
          addiction: addiction,
          riskScore: score,
          mode: mode,
          modeLabel: 'KRIZ',
          modeHint: 'Bugun karar degil koruma modu. Ilk hedef 10 dakika dayanmak.',
        );
      case AddictionRiskMode.elevated:
        return AddictionSnapshot(
          addiction: addiction,
          riskScore: score,
          mode: mode,
          modeLabel: 'YUKSEK RISK',
          modeHint: 'Bugun mikro adimlar ve tetikleyici azaltma odakta olmali.',
        );
      case AddictionRiskMode.relapseRecovery:
        return AddictionSnapshot(
          addiction: addiction,
          riskScore: score,
          mode: mode,
          modeLabel: 'NUKS SONRASI',
          modeHint: 'Sucluluk yerine 24 saatlik toparlanma plani uygula.',
        );
      case AddictionRiskMode.normal:
        return AddictionSnapshot(
          addiction: addiction,
          riskScore: score,
          mode: mode,
          modeLabel: 'DENGELI',
          modeHint: 'Ritmi koru. Kisa ve uygulanabilir gorev en iyi kaldirac.',
        );
    }
  }

  static AddictionSnapshot getSnapshot(String addictionId) {
    final addiction = _findAddiction(addictionId) ??
        AddictionDna(id: addictionId, type: 'behavioral');
    return snapshotFromAddiction(addiction);
  }

  static Future<AddictionIntakeResult> submitIntakeAnswers(
    String addictionId,
    Map<String, String> answers,
  ) async {
    try {
      final dna = await UserDNAService.getDNAForAI();
      final sysPrompt = _getSystemPromptFor(addictionId);
      final lines = answers.entries
          .map((e) => '- ${e.key}: ${e.value}')
          .join('\n');
      final response = await GeminiService.generateResponse(
        '$dna\nAnalyze intake answers for addiction: $addictionId\n$lines\n'
            'Return STRICT JSON:\n'
            '{"severity":0-10,"stage":"precontemplation|contemplation|preparation|action|maintenance",'
            '"daily_episodes":0-99,"summary":"max 2 cümle","focus":"tek odak"}',
        'addiction_intake',
        customSystemPrompt: sysPrompt,
      );

      final clean = response.replaceAll('```json', '').replaceAll('```', '').trim();
      final map = json.decode(clean) as Map<String, dynamic>;
      final severity = ((map['severity'] as num?)?.toInt() ?? 5).clamp(0, 10);
      final stage = (map['stage'] ?? 'contemplation').toString();
      final dailyEpisodes = ((map['daily_episodes'] as num?)?.toInt() ?? 1).clamp(0, 99);
      final summary = (map['summary'] ?? '').toString();
      final focus = (map['focus'] ?? 'tetikleyici kontrol').toString();

      await _updateAddiction(addictionId, (a) {
        return AddictionDna(
          id: a.id,
          type: a.type,
          willpowerIndex: a.willpowerIndex,
          streakDays: a.streakDays,
          totalLostCapital: a.totalLostCapital,
          averageDailyBet: a.averageDailyBet,
          highRiskDays: a.highRiskDays,
          triggers: a.triggers,
          lastRelapse: a.lastRelapse,
          currentMission: a.currentMission,
          isMissionCompleted: a.isMissionCompleted,
          assessmentCompleted: true,
          dependencySeverity: severity,
          changeStage: stage,
          dailyEpisodes: dailyEpisodes,
          intakeSummary: summary,
          lastAssessmentAt: DateTime.now(),
        );
      });

      return AddictionIntakeResult(
        severity: severity,
        stage: stage,
        dailyEpisodes: dailyEpisodes,
        summary: summary,
        focus: focus,
      );
    } catch (_) {
      await _updateAddiction(addictionId, (a) {
        return AddictionDna(
          id: a.id,
          type: a.type,
          willpowerIndex: a.willpowerIndex,
          streakDays: a.streakDays,
          totalLostCapital: a.totalLostCapital,
          averageDailyBet: a.averageDailyBet,
          highRiskDays: a.highRiskDays,
          triggers: a.triggers,
          lastRelapse: a.lastRelapse,
          currentMission: a.currentMission,
          isMissionCompleted: a.isMissionCompleted,
          assessmentCompleted: true,
          dependencySeverity: 5,
          changeStage: 'contemplation',
          dailyEpisodes: 1,
          intakeSummary: 'Temel intake tamamlandi.',
          lastAssessmentAt: DateTime.now(),
        );
      });
      return const AddictionIntakeResult(
        severity: 5,
        stage: 'contemplation',
        dailyEpisodes: 1,
        summary: 'Temel intake tamamlandi.',
        focus: 'tetikleyici kontrol',
      );
    }
  }

  /// Entry line shown at top of module.
  static Future<String> getEntryGreeting(String addictionId) async {
    try {
      final dna = await UserDNAService.getDNAForAI();
      final sysPrompt = _getSystemPromptFor(addictionId);
      final snap = getSnapshot(addictionId);
      final response = await GeminiService.generateResponse(
        '$dna\nRisk mode: ${snap.modeLabel}, Risk score: ${snap.riskScore}.\n'
            'User just opened support module. Give one short reality check and one action sentence.',
        'addiction_entry',
        customSystemPrompt: sysPrompt,
      );
      return _sanitizeText(response);
    } catch (e) {
      return "Savaş devam ediyor. Hazır mısın?";
    }
  }

  static Future<String> _generateMissionFromAI(
    String addictionId,
    AddictionSnapshot snap,
  ) async {
    try {
      final dna = await UserDNAService.getDNAForAI();
      final sysPrompt = _getSystemPromptFor(addictionId);
      final response = await GeminiService.generateResponse(
        '$dna\nRisk mode: ${snap.modeLabel}, risk score: ${snap.riskScore}\n'
            'Severity: ${snap.addiction.dependencySeverity}/10, Stage: ${snap.addiction.changeStage}\n'
            'Generate one mission under 12 words, completable in <10 min. '
            'Action only, no explanation.',
        'addiction_mission',
        customSystemPrompt: sysPrompt,
      );
      return _sanitizeText(response);
    } catch (e) {
      return "Bugun sadece dur ve nefesi duzenle.";
    }
  }

  /// Creates and persists mission when needed.
  static Future<String> generateOrGetDailyMission(String addictionId) async {
    final current = _findAddiction(addictionId);
    if (current != null &&
        current.currentMission.isNotEmpty &&
        !current.isMissionCompleted) {
      return current.currentMission;
    }

    final snap = getSnapshot(addictionId);
    final mission = await _generateMissionFromAI(addictionId, snap);
    await _updateAddiction(addictionId, (a) {
      return AddictionDna(
        id: a.id,
        type: a.type,
        willpowerIndex: a.willpowerIndex,
        streakDays: a.streakDays,
        totalLostCapital: a.totalLostCapital,
        averageDailyBet: a.averageDailyBet,
        highRiskDays: a.highRiskDays,
        triggers: a.triggers,
        lastRelapse: a.lastRelapse,
        currentMission: mission,
        isMissionCompleted: false,
        assessmentCompleted: a.assessmentCompleted,
        dependencySeverity: a.dependencySeverity,
        changeStage: a.changeStage,
        dailyEpisodes: a.dailyEpisodes,
        intakeSummary: a.intakeSummary,
        lastAssessmentAt: a.lastAssessmentAt,
      );
    });
    return mission;
  }

  /// Backward-compatible alias.
  static Future<String> getDynamicMission(String addictionId) async {
    try {
      return await generateOrGetDailyMission(addictionId);
    } catch (e) {
      return "Bugun sadece iradeni koru.";
    }
  }

  static Future<MissionVerificationResult> verifyMissionAndMaybeComplete(
    String addictionId,
    String userReflection,
  ) async {
    final mission = _findAddiction(addictionId)?.currentMission ?? '';
    try {
      final dna = await UserDNAService.getDNAForAI();
      final sysPrompt = _getSystemPromptFor(addictionId);

      final response = await GeminiService.generateResponse(
        '$dna\nDaily mission: "$mission"\n'
            'User reflection: "$userReflection"\n'
            'Decide mission completion. Return STRICT JSON only:\n'
            '{"approved":true/false,"coach_reply":"...max 2 sentences..."}',
        'addiction_verify',
        customSystemPrompt: sysPrompt,
      );

      final clean = response.replaceAll('```json', '').replaceAll('```', '').trim();
      final map = json.decode(clean) as Map<String, dynamic>;
      final approved = map['approved'] == true;
      final message = (map['coach_reply'] ?? 'Kisa bir check-in daha yapalim.').toString();

      if (approved) {
        await completeMission(addictionId);
      }

      return MissionVerificationResult(approved: approved, message: message);
    } catch (e) {
      return const MissionVerificationResult(
        approved: false,
        message: "Bu yanitla dogrulama yapamadim. Biraz daha net yaz.",
      );
    }
  }

  /// Backward-compatible verification endpoint.
  static Future<String> verifyMissionCompletion(
    String addictionId,
    String userFeeling,
  ) async {
    final result = await verifyMissionAndMaybeComplete(addictionId, userFeeling);
    return result.message;
  }

  static List<String> getSosProtocol(String addictionId, {String? trigger}) {
    final cause = (trigger == null || trigger.trim().isEmpty)
        ? 'durtu'
        : trigger.trim();

    if (addictionId == 'gambling') {
      return [
        '90 sn: Telefonu birak, ayaga kalk, 6 yavas nefes.',
        '3 dk: Kumar uygulamasi/site erisimini fiziksel olarak kes.',
        '10 dk: "$cause" tetigini not et ve bir guven kisisiyle paylas.',
      ];
    }

    if (addictionId == 'smoking') {
      return [
        '60 sn: Derin nefes + su ile yuz sogut.',
        '3 dk: Sigara yerine agiz meşgul edecek alternatif kullan.',
        '10 dk: "$cause" anini yaz, yuru ve geri dön.',
      ];
    }

    if (addictionId == 'social_media') {
      return [
        '60 sn: Ekrani kapat, telefonu farkli odaya koy.',
        '3 dk: Gri ton + bildirim kapatma uygula.',
        '10 dk: "$cause" yerine analog bir mini aktivite yap.',
      ];
    }

    return [
      '60 sn: Nefesini yavaslat ve bedeni sakinlestir.',
      '3 dk: Tetikleyiciden fiziksel uzaklas.',
      '10 dk: "$cause" yerine tek bir saglikli alternatif sec.',
    ];
  }

  static Future<void> saveQuickCheckIn(
    String addictionId, {
    required int cravingLevel,
    required String trigger,
  }) async {
    await _updateAddiction(addictionId, (a) {
      final nextTriggers = <String>{...a.triggers};
      final cleanTrigger = trigger.trim();
      if (cleanTrigger.isNotEmpty) {
        nextTriggers.add(cleanTrigger);
      }

      final delta = cravingLevel >= 8
          ? -0.08
          : cravingLevel >= 5
              ? -0.04
              : 0.02;

      return AddictionDna(
        id: a.id,
        type: a.type,
        willpowerIndex: (a.willpowerIndex + delta).clamp(0.0, 1.0),
        streakDays: a.streakDays,
        totalLostCapital: a.totalLostCapital,
        averageDailyBet: a.averageDailyBet,
        highRiskDays: a.highRiskDays,
        triggers: nextTriggers.toList(),
        lastRelapse: cravingLevel >= 9 ? DateTime.now() : a.lastRelapse,
        currentMission: a.currentMission,
        isMissionCompleted: a.isMissionCompleted,
        assessmentCompleted: a.assessmentCompleted,
        dependencySeverity: a.dependencySeverity,
        changeStage: a.changeStage,
        dailyEpisodes: a.dailyEpisodes,
        intakeSummary: a.intakeSummary,
        lastAssessmentAt: a.lastAssessmentAt,
      );
    });
  }

  static Future<String> getProactiveNudge(String addictionId) async {
    final snap = getSnapshot(addictionId);
    try {
      final dna = await UserDNAService.getDNAForAI();
      final sysPrompt = _getSystemPromptFor(addictionId);
      final response = await GeminiService.generateResponse(
        '$dna\nRisk mode: ${snap.modeLabel}.\n'
            'Give one proactive nudge in max 1 sentence.',
        'addiction_proactive',
        customSystemPrompt: sysPrompt,
      );
      return _sanitizeText(response);
    } catch (_) {
      return snap.mode == AddictionRiskMode.crisis
          ? 'Karar verme. Sadece 3 dakika geciktir.'
          : 'Bugun tek hedef: tetikleyiciyi bir adim zorlastir.';
    }
  }

  /// 4. CRISIS CHAT (legacy stream placeholder)
  static Future<Stream<String>> startCrisisChat(String addictionId, String userMessage) async {
    return const Stream.empty();
  }

  /// Backward-compatible SOS helper.
  static Future<List<String>?> triggerEmergency(String addictionId) async {
    try {
      final first = await handleCrisisMessage(
        addictionId,
        'Acil durumdayım. Beni şimdi gerçekliğe döndür.',
      );
      return [first, ...getSosProtocol(addictionId)];
    } catch (_) {
      return null;
    }
  }

  static Future<String> handleCrisisMessage(String addictionId, String message) async {
     try {
      final dna = await UserDNAService.getDNAForAI();
      final sysPrompt = _getSystemPromptFor(addictionId);
      
      final fullPrompt = '$sysPrompt\nCRISIS MODE ACTIVE. USER SAYS: "$message". RESPOND IMMEDIATELY.';

      final response = await GeminiService.generateResponse(
        '$dna\nCRISIS: $message',
        'addiction_sos',
        customSystemPrompt: fullPrompt,
      );
      return response;
    } catch (e) {
      return "Nefes al. Buradayım.";
    }
  }

  static Future<void> completeMission(String addictionId) async {
    await _updateAddiction(addictionId, (a) {
      return AddictionDna(
        id: a.id,
        type: a.type,
        willpowerIndex: (a.willpowerIndex + 0.05).clamp(0.0, 1.0),
        streakDays: a.streakDays + 1,
        totalLostCapital: a.totalLostCapital,
        averageDailyBet: a.averageDailyBet,
        highRiskDays: a.highRiskDays,
        triggers: a.triggers,
        lastRelapse: a.lastRelapse,
        currentMission: a.currentMission,
        isMissionCompleted: true,
        assessmentCompleted: a.assessmentCompleted,
        dependencySeverity: a.dependencySeverity,
        changeStage: a.changeStage,
        dailyEpisodes: a.dailyEpisodes,
        intakeSummary: a.intakeSummary,
        lastAssessmentAt: a.lastAssessmentAt,
      );
    });
  }

  static Future<void> startTracking(String id, String type) async {
    final userDna = UserDNAService.currentDNA;
    final currentList = userDna?.activeAddictions ?? [];
    
    if (currentList.any((a) => a.id == id)) return;

    final newList = [...currentList, AddictionDna(id: id, type: type)];
    await UserDNAService.updateDNA(UserDNAModel(activeAddictions: newList));
  }

  static Future<void> ensureTrackingForId(String id) async {
    final type = trackedTypeById[id];
    if (type == null) return;
    await startTracking(id, type);
  }
}
