import 'package:flutter_test/flutter_test.dart';
import 'package:mentaliq/models/user_dna_model.dart';
import 'package:mentaliq/services/addiction_service.dart';

void main() {
  group('Addiction long scenario simulations', () {
    test('Scenario A: gambling escalation then stabilization', () {
      final step1 = AddictionDna(
        id: 'gambling',
        type: 'behavioral',
        willpowerIndex: 0.22,
        dependencySeverity: 9,
        changeStage: 'contemplation',
        averageDailyBet: 900,
        triggers: const ['stres', 'yalnizlik', 'gece'],
      );
      final snap1 = AddictionService.snapshotFromAddiction(step1);
      expect(snap1.riskScore, greaterThanOrEqualTo(75));
      expect(snap1.mode, AddictionRiskMode.crisis);

      final step2 = AddictionDna(
        id: 'gambling',
        type: 'behavioral',
        willpowerIndex: 0.48,
        dependencySeverity: 7,
        changeStage: 'preparation',
        averageDailyBet: 200,
        streakDays: 2,
        triggers: const ['stres', 'gece'],
      );
      final snap2 = AddictionService.snapshotFromAddiction(step2);
      expect(snap2.riskScore, lessThan(snap1.riskScore));

      final step3 = AddictionDna(
        id: 'gambling',
        type: 'behavioral',
        willpowerIndex: 0.74,
        dependencySeverity: 5,
        changeStage: 'action',
        averageDailyBet: 0,
        streakDays: 10,
        triggers: const ['stres'],
      );
      final snap3 = AddictionService.snapshotFromAddiction(step3);
      expect(snap3.riskScore, lessThan(snap2.riskScore));
      expect(
        snap3.mode == AddictionRiskMode.normal || snap3.mode == AddictionRiskMode.elevated,
        isTrue,
      );
    });

    test('Scenario B: smoking moderate user enters action stage', () {
      final step1 = AddictionDna(
        id: 'smoking',
        type: 'substance',
        willpowerIndex: 0.43,
        dependencySeverity: 7,
        changeStage: 'contemplation',
        dailyEpisodes: 14,
        triggers: const ['kahve', 'is stresi'],
      );
      final snap1 = AddictionService.snapshotFromAddiction(step1);
      expect(snap1.mode == AddictionRiskMode.elevated || snap1.mode == AddictionRiskMode.crisis, isTrue);

      final step2 = AddictionDna(
        id: 'smoking',
        type: 'substance',
        willpowerIndex: 0.67,
        dependencySeverity: 5,
        changeStage: 'action',
        dailyEpisodes: 4,
        streakDays: 6,
        triggers: const ['kahve'],
      );
      final snap2 = AddictionService.snapshotFromAddiction(step2);
      expect(snap2.riskScore, lessThan(snap1.riskScore));
    });

    test('Scenario C: social media relapse recovery detected', () {
      final step = AddictionDna(
        id: 'social_media',
        type: 'behavioral',
        willpowerIndex: 0.62,
        dependencySeverity: 6,
        changeStage: 'action',
        lastRelapse: DateTime.now().subtract(const Duration(hours: 6)),
        triggers: const ['can sikintisi'],
      );
      final snap = AddictionService.snapshotFromAddiction(step);
      expect(snap.mode, AddictionRiskMode.relapseRecovery);
    });

    test('Critical safety keywords are detected', () {
      expect(AddictionService.isHighSafetyRiskMessage('Bugun yasamak istemiyorum'), isTrue);
      expect(AddictionService.isHighSafetyRiskMessage('Kendime zarar vermek istiyorum'), isTrue);
      expect(AddictionService.isHighSafetyRiskMessage('Sadece canim sikkin'), isFalse);
    });
  });
}
