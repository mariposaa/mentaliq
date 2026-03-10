import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_theme.dart';
import '../../config/responsive.dart';
import '../../services/auth_service.dart';
import '../../l10n/app_translations.dart';
import '../../services/silent_flirt_chat_service.dart';
import '../../services/silent_flirt_service.dart';
import '../../widgets/responsive_card.dart';
import 'silent_flirt_chat_screen.dart';

class CampfireSilentFlirtTab extends StatefulWidget {
  const CampfireSilentFlirtTab({super.key});

  @override
  State<CampfireSilentFlirtTab> createState() => _CampfireSilentFlirtTabState();
}

class _CampfireSilentFlirtTabState extends State<CampfireSilentFlirtTab> {
  static const String _prefKeyAccepted = 'silent_flirt_intro_accepted_v1';
  static const List<String> _ageRanges = ['18-24', '25-31', '32-39', '40+'];
  static const List<String> _intents = [
    'silent_support',
    'getting_to_know',
    'light_flirt',
    'deep_talk',
  ];
  static const List<String> _moods = [
    'calm',
    'cheerful',
    'thoughtful',
    'shy',
    'excited',
  ];
  static const List<String> _chatPaces = ['slow', 'flow', 'fast'];
  static const List<String> _traits = [
    'empathetic',
    'humorous',
    'calm',
    'energetic',
    'good_listener',
    'romantic',
    'adventurous',
    'logical',
    'emotional',
    'night_person',
  ];

  bool _loading = true;
  bool _accepted = false;
  bool _checkedPrivacy = false;
  bool _checkedPolicy = false;
  bool _saving = false;
  bool _hydratedFromProfile = false;

  final _nickController = TextEditingController();
  final _boundaryController = TextEditingController();
  final _firstLineController = TextEditingController();

  String _selectedAgeRange = _ageRanges.first;
  String _selectedIntent = _intents.first;
  String _selectedMood = _moods.first;
  String _selectedChatPace = _chatPaces.first;
  final Set<String> _selectedTraits = {};

  @override
  void initState() {
    super.initState();
    _loadAcceptance();
  }

  @override
  void dispose() {
    _nickController.dispose();
    _boundaryController.dispose();
    _firstLineController.dispose();
    super.dispose();
  }

  Future<void> _loadAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool(_prefKeyAccepted) ?? false;
    if (!mounted) return;
    setState(() {
      _accepted = accepted;
      _loading = false;
      _checkedPrivacy = accepted;
      _checkedPolicy = accepted;
    });
  }

  Future<void> _acceptAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyAccepted, true);
    if (!mounted) return;
    setState(() => _accepted = true);
  }

  Future<void> _saveTemplate() async {
    final nick = _nickController.text.trim();
    if (nick.isEmpty) {
      _snack(AppTranslations.get('silentFlirtNickRequired'));
      return;
    }
    if (_selectedTraits.length < 3) {
      _snack(AppTranslations.get('silentFlirtTraitsRequired'));
      return;
    }
    setState(() => _saving = true);
    try {
      await SilentFlirtService.saveMyProfile(
        nick: nick,
        ageRange: _selectedAgeRange,
        intent: _selectedIntent,
        mood: _selectedMood,
        traits: _selectedTraits.toList(),
        chatPace: _selectedChatPace,
        boundary: _boundaryController.text,
        firstLine: _firstLineController.text,
      );
      _snack(AppTranslations.get('silentFlirtTemplateSaved'));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _fillFromProfile(SilentFlirtProfile profile) {
    _nickController.text = profile.nick;
    _boundaryController.text = profile.boundary ?? '';
    _firstLineController.text = profile.firstLine ?? '';
    _selectedAgeRange = _ageRanges.contains(profile.ageRange)
        ? profile.ageRange
        : _ageRanges.first;
    _selectedIntent = _intents.contains(profile.intent)
        ? profile.intent
        : _intents.first;
    _selectedMood =
        _moods.contains(profile.mood) ? profile.mood : _moods.first;
    _selectedChatPace = _chatPaces.contains(profile.chatPace)
        ? profile.chatPace
        : _chatPaces.first;
    _selectedTraits
      ..clear()
      ..addAll(profile.traits.where(_traits.contains));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.terracotta),
      );
    }

    if (!_accepted) {
      return _buildIntro();
    }

    return _buildTemplateAndProfiles();
  }

  Widget _buildIntro() {
    final isCompact = context.isCompactPhone;
    return ListView(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      children: [
        ResponsiveCard(
          padding: 16,
          radius: 16,
          border: Border.all(color: AppTheme.softBorder),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.get('silentFlirtIntroTitle'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.forestCharcoal,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppTranslations.get('silentFlirtHowItWorks'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.forestCharcoal,
                ),
              ),
              const SizedBox(height: 8),
              _bullet(AppTranslations.get('silentFlirtRule1')),
              _bullet(AppTranslations.get('silentFlirtRule2')),
              _bullet(AppTranslations.get('silentFlirtRule3')),
              _bullet(AppTranslations.get('silentFlirtRule4')),
              const SizedBox(height: 14),
              Text(
                AppTranslations.get('silentFlirtPrivacyTitle'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.forestCharcoal,
                ),
              ),
              const SizedBox(height: 8),
              _bullet(AppTranslations.get('silentFlirtPrivacy1')),
              _bullet(AppTranslations.get('silentFlirtPrivacy2')),
              _bullet(AppTranslations.get('silentFlirtPrivacy3')),
              _bullet(AppTranslations.get('silentFlirtPrivacy4')),
              const SizedBox(height: 14),
              Text(
                AppTranslations.get('silentFlirtSafetyTitle'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.forestCharcoal,
                ),
              ),
              const SizedBox(height: 8),
              _bullet(AppTranslations.get('silentFlirtSafety1')),
              _bullet(AppTranslations.get('silentFlirtSafety2')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          value: _checkedPrivacy,
          onChanged: (v) => setState(() => _checkedPrivacy = v ?? false),
          contentPadding: EdgeInsets.zero,
          title: Text(AppTranslations.get('silentFlirtConsentPrivacy')),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          value: _checkedPolicy,
          onChanged: (v) => setState(() => _checkedPolicy = v ?? false),
          contentPadding: EdgeInsets.zero,
          title: Text(AppTranslations.get('silentFlirtConsent18')),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: isCompact ? double.infinity : (context.screenWidth - 42) / 2,
              child: OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppTranslations.get('areaWillBeFilled')),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.mutedSage,
                  side: BorderSide(color: AppTheme.softBorder),
                ),
                child: Text(AppTranslations.get('cancel')),
              ),
            ),
            SizedBox(
              width: isCompact ? double.infinity : (context.screenWidth - 42) / 2,
              child: FilledButton(
                onPressed: (_checkedPrivacy && _checkedPolicy)
                    ? _acceptAndContinue
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.terracotta,
                ),
                child: Text(
                  AppTranslations.get('silentFlirtAcceptContinue'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTemplateAndProfiles() {
    final isCompact = context.isCompactPhone;
    return StreamBuilder<SilentFlirtProfile?>(
      stream: SilentFlirtService.watchMyProfile(),
      builder: (context, snap) {
        final mine = snap.data;
        if (mine != null && !_hydratedFromProfile) {
          _fillFromProfile(mine);
          _hydratedFromProfile = true;
        } else if (mine == null) {
          _hydratedFromProfile = false;
        }
        return ListView(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          children: [
            _buildTemplateCard(
              title: mine == null
                  ? AppTranslations.get('silentFlirtTemplateCreate')
                  : AppTranslations.get('silentFlirtTemplateUpdate'),
            ),
            const SizedBox(height: 14),
            _buildLocalChatsSection(),
            const SizedBox(height: 14),
            _buildDiscoverHeader(mine != null),
            const SizedBox(height: 10),
            if (mine == null)
              _emptyDiscovery()
            else
              _buildDiscoverList(mine),
          ],
        );
      },
    );
  }

  Widget _buildTemplateCard({required String title}) {
    return ResponsiveCard(
      padding: 14,
      radius: 16,
      border: Border.all(color: AppTheme.softBorder),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.forestCharcoal,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nickController,
            maxLength: 20,
            decoration: InputDecoration(
              labelText: AppTranslations.get('silentFlirtNick'),
              hintText: AppTranslations.get('silentFlirtNickHint'),
              filled: true,
              fillColor: AppTheme.sandBeige,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          _dropDownField(
            value: _selectedAgeRange,
            label: AppTranslations.get('silentFlirtAgeRange'),
            items: _ageRanges,
            onChanged: (v) => setState(() => _selectedAgeRange = v),
          ),
          const SizedBox(height: 8),
          _dropDownField(
            value: _selectedIntent,
            label: AppTranslations.get('silentFlirtIntent'),
            items: _intents,
            display: _labelForIntent,
            onChanged: (v) => setState(() => _selectedIntent = v),
          ),
          const SizedBox(height: 8),
          _dropDownField(
            value: _selectedMood,
            label: AppTranslations.get('silentFlirtMood'),
            items: _moods,
            display: _labelForMood,
            onChanged: (v) => setState(() => _selectedMood = v),
          ),
          const SizedBox(height: 8),
          _dropDownField(
            value: _selectedChatPace,
            label: AppTranslations.get('silentFlirtChatPace'),
            items: _chatPaces,
            display: _labelForPace,
            onChanged: (v) => setState(() => _selectedChatPace = v),
          ),
          const SizedBox(height: 10),
          Text(
            AppTranslations.get('silentFlirtPickTraits'),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.forestCharcoal,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _traits.map((trait) {
              final selected = _selectedTraits.contains(trait);
              return FilterChip(
                selected: selected,
                label: Text(_labelForTrait(trait)),
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selectedTraits.add(trait);
                    } else {
                      _selectedTraits.remove(trait);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _boundaryController,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: AppTranslations.get('silentFlirtBoundary'),
              hintText: AppTranslations.get('silentFlirtBoundaryHint'),
              filled: true,
              fillColor: AppTheme.sandBeige,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _firstLineController,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: AppTranslations.get('silentFlirtFirstLine'),
              hintText: AppTranslations.get('silentFlirtFirstLineHint'),
              filled: true,
              fillColor: AppTheme.sandBeige,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _saveTemplate,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.terracotta,
              ),
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(AppTranslations.get('save')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropDownField({
    required String value,
    required String label,
    required List<String> items,
    required ValueChanged<String> onChanged,
    String Function(String)? display,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppTheme.sandBeige,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(display?.call(e) ?? e),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _buildDiscoverHeader(bool hasTemplate) {
    return Text(
      hasTemplate
          ? AppTranslations.get('silentFlirtDiscoverTitle')
          : AppTranslations.get('silentFlirtDiscoverLocked'),
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppTheme.forestCharcoal,
      ),
    );
  }

  Widget _emptyDiscovery() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warmCream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Text(
        AppTranslations.get('silentFlirtDiscoverHint'),
        style: const TextStyle(color: AppTheme.mutedSage),
      ),
    );
  }

  Widget _buildDiscoverList(SilentFlirtProfile mine) {
    return StreamBuilder<List<SilentFlirtProfile>>(
      stream: SilentFlirtService.watchDiscoverProfiles(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.warmCream,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.softBorder),
            ),
            child: Text(
              AppTranslations.get('silentFlirtDiscoverError'),
              style: const TextStyle(color: AppTheme.terracotta),
            ),
          );
        }
        final profiles = snap.data ?? [];
        if (profiles.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.warmCream,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.softBorder),
            ),
            child: Text(
              AppTranslations.get('silentFlirtDiscoverHintDetailed'),
              style: const TextStyle(color: AppTheme.mutedSage),
            ),
          );
        }
        return Column(
          children: profiles.map((p) {
            final score = SilentFlirtService.matchScore(mine: mine, other: p);
            final canAutoMatch = score >= 3;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warmCream,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.softBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '@${p.nick}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.forestCharcoal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${AppTranslations.get('silentFlirtScore')}: $score',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.terracotta,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${p.ageRange} · ${_labelForIntent(p.intent)} · ${_labelForMood(p.mood)}',
                    style: const TextStyle(color: AppTheme.mutedSage),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: p.traits
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.sandBeige,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _labelForTrait(t),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.forestCharcoal,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    canAutoMatch
                        ? AppTranslations.get('silentFlirtAutoMatchReady')
                        : AppTranslations.get('silentFlirtAutoMatchWait'),
                    style: TextStyle(
                      color: canAutoMatch
                          ? AppTheme.terracotta
                          : AppTheme.mutedSage,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (canAutoMatch) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _startLocalChat(mine, p, score),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.terracotta,
                        ),
                        child: Text(
                          AppTranslations.get('silentFlirtStartLocalChat'),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text('• ', style: TextStyle(color: AppTheme.mutedSage)),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppTheme.forestCharcoal, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  String _labelForIntent(String key) {
    switch (key) {
      case 'silent_support':
        return AppTranslations.get('silentFlirtIntentSupport');
      case 'getting_to_know':
        return AppTranslations.get('silentFlirtIntentKnow');
      case 'light_flirt':
        return AppTranslations.get('silentFlirtIntentLight');
      case 'deep_talk':
        return AppTranslations.get('silentFlirtIntentDeep');
      default:
        return key;
    }
  }

  String _labelForMood(String key) {
    switch (key) {
      case 'calm':
        return AppTranslations.get('silentFlirtMoodCalm');
      case 'cheerful':
        return AppTranslations.get('silentFlirtMoodCheerful');
      case 'thoughtful':
        return AppTranslations.get('silentFlirtMoodThoughtful');
      case 'shy':
        return AppTranslations.get('silentFlirtMoodShy');
      case 'excited':
        return AppTranslations.get('silentFlirtMoodExcited');
      default:
        return key;
    }
  }

  String _labelForPace(String key) {
    switch (key) {
      case 'slow':
        return AppTranslations.get('silentFlirtPaceSlow');
      case 'flow':
        return AppTranslations.get('silentFlirtPaceFlow');
      case 'fast':
        return AppTranslations.get('silentFlirtPaceFast');
      default:
        return key;
    }
  }

  String _labelForTrait(String key) {
    switch (key) {
      case 'empathetic':
        return AppTranslations.get('silentFlirtTraitEmpathetic');
      case 'humorous':
        return AppTranslations.get('silentFlirtTraitHumorous');
      case 'calm':
        return AppTranslations.get('silentFlirtTraitCalm');
      case 'energetic':
        return AppTranslations.get('silentFlirtTraitEnergetic');
      case 'good_listener':
        return AppTranslations.get('silentFlirtTraitListener');
      case 'romantic':
        return AppTranslations.get('silentFlirtTraitRomantic');
      case 'adventurous':
        return AppTranslations.get('silentFlirtTraitAdventurous');
      case 'logical':
        return AppTranslations.get('silentFlirtTraitLogical');
      case 'emotional':
        return AppTranslations.get('silentFlirtTraitEmotional');
      case 'night_person':
        return AppTranslations.get('silentFlirtTraitNight');
      default:
        return key;
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _buildLocalChatsSection() {
    return StreamBuilder<List<SilentFlirtChatSummary>>(
      stream: SilentFlirtChatService.watchMyChats(),
      builder: (context, snap) {
        final chats = snap.data ?? [];
        return Container(
          padding: context.insetsAll(12),
          decoration: BoxDecoration(
            color: AppTheme.warmCream,
            borderRadius: BorderRadius.circular(context.radius(14)),
            border: Border.all(color: AppTheme.softBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.get('silentFlirtLocalChats'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.forestCharcoal,
                ),
              ),
              const SizedBox(height: 8),
              if (chats.isEmpty)
                Text(
                  AppTranslations.get('silentFlirtNoLocalChats'),
                  style: const TextStyle(color: AppTheme.mutedSage),
                )
              else
                Column(
                  children: chats.map((chat) {
                    final me = AuthService.userId;
                    final partnerId = chat.participants.firstWhere(
                      (p) => p != me,
                      orElse: () => '',
                    );
                    final partnerNick =
                        chat.participantNicks[partnerId] ?? 'User';
                    final blocked = me != null && chat.blockedBy.contains(me);
                    final subtitle = chat.updatedAt == null
                        ? AppTranslations.get('silentFlirtNoMessages')
                        : '${AppTranslations.get('today')} ${DateFormat('HH:mm').format(chat.updatedAt!)}';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => _openChatScreen(chat.id),
                      title: Text(
                        '@$partnerNick',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(subtitle),
                      trailing: Icon(
                        blocked ? Icons.block : Icons.chevron_right,
                        color: blocked
                            ? AppTheme.terracotta
                            : AppTheme.mutedSage,
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startLocalChat(
    SilentFlirtProfile myProfile,
    SilentFlirtProfile otherProfile,
    int score,
  ) async {
    try {
      final chatId = await SilentFlirtChatService.openOrCreateChat(
        myProfile: myProfile,
        otherProfile: otherProfile,
        matchScore: score,
      );
      if (!mounted) return;
      await _openChatScreen(chatId);
    } catch (e) {
      if (!mounted) return;
      _snack('Sohbet acilamadi: $e');
    }
  }

  Future<void> _openChatScreen(String chatId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SilentFlirtChatScreen(chatId: chatId),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }
}
