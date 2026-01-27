import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/campfire_service.dart';
import '../../services/token_service.dart';
import '../../widgets/campfire_token_dialog.dart';
import 'lobby_screen.dart';

/// Danışma Ekranı - Check-in
/// Kullanıcıdan konu, enerji durumu ve teyit alır
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  int _currentStep = 0;
  String? _selectedTopic;
  String? _selectedEnergy;
  String _nickname = '';
  final TextEditingController _nicknameController = TextEditingController();
  bool _isLoading = false;

  final List<Map<String, String>> _energyLevels = [
    {'id': 'talk', 'name': 'Konuşmaya ihtiyacım var', 'icon': '💬'},
    {'id': 'listen', 'name': 'Sadece dinlemek istiyorum', 'icon': '👂'},
    {'id': 'low', 'name': 'Çok kötüyüm', 'icon': '😔'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E), // Loş, sakin arka plan
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white54),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Kamp Ateşine Hoş Geldin',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Progress indicator
              _buildProgressIndicator(),
              const SizedBox(height: 40),
              
              // Step content
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildCurrentStep(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(4, (index) {
        final isActive = index <= _currentStep;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
            decoration: BoxDecoration(
              color: isActive 
                  ? AppTheme.terracotta 
                  : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildTopicStep();
      case 1:
        return _buildEnergyStep();
      case 2:
        return _buildNicknameStep();
      case 3:
        return _buildConfirmStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildTopicStep() {
    return Column(
      key: const ValueKey('topic'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bugün sırtındaki yük hangisi?',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Seni anlayabilecek insanlarla eşleştireceğiz',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 32),
        
        Expanded(
          child: ListView.builder(
            itemCount: CampfireService.availableTopics.length,
            itemBuilder: (context, index) {
              final topic = CampfireService.availableTopics[index];
              final isSelected = _selectedTopic == topic['id'];
              
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedTopic = topic['id']);
                  Future.delayed(const Duration(milliseconds: 200), () {
                    setState(() => _currentStep = 1);
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppTheme.terracotta.withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                          ? AppTheme.terracotta 
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        topic['icon'] ?? '🔥',
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        topic['name'] ?? '',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.terracotta,
                          size: 24,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEnergyStep() {
    return Column(
      key: const ValueKey('energy'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Şu an enerjin nasıl?',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Bu, seni uygun enerji seviyesindeki grupla eşleştirmemize yardımcı olur',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 32),
        
        ...List.generate(_energyLevels.length, (index) {
          final energy = _energyLevels[index];
          final isSelected = _selectedEnergy == energy['id'];
          
          return GestureDetector(
            onTap: () {
              setState(() => _selectedEnergy = energy['id']);
              Future.delayed(const Duration(milliseconds: 200), () {
                setState(() => _currentStep = 2);
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppTheme.terracotta.withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected 
                      ? AppTheme.terracotta 
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    energy['icon'] ?? '💬',
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      energy['name'] ?? '',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.terracotta,
                      size: 24,
                    ),
                ],
              ),
            ),
          );
        }),
        
        const Spacer(),
        
        // Geri butonu
        TextButton.icon(
          onPressed: () => setState(() => _currentStep = 0),
          icon: Icon(Icons.arrow_back, color: Colors.white.withOpacity(0.5)),
          label: Text(
            'Geri',
            style: TextStyle(color: Colors.white.withOpacity(0.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildNicknameStep() {
    return Column(
      key: const ValueKey('nickname'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Takma adını belirle',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Gizliliğin için gerçek adını kullanmak zorunda değilsin. Bu isim sadece grup içinde görünecek.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        
        // Takma ad input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E), // Koyu arka plan
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextField(
            controller: _nicknameController,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            cursorColor: AppTheme.terracotta,
            maxLength: 20,
            decoration: InputDecoration(
              hintText: 'Örn: Yıldız, Deniz, Bulut...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              border: InputBorder.none,
              counterStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              contentPadding: const EdgeInsets.symmetric(vertical: 20),
            ),
            onChanged: (value) => setState(() => _nickname = value.trim()),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Bilgilendirme
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.blue.shade300, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Kimliğin anonim kalır. Diğer katılımcılar sadece takma adını görür.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const Spacer(),
        
        // Butonlar
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() => _currentStep = 1),
              child: Text(
                'Geri',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _nickname.length >= 2 
                    ? () => setState(() => _currentStep = 3)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.terracotta,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Devam',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    final selectedTopicData = CampfireService.availableTopics
        .firstWhere((t) => t['id'] == _selectedTopic, orElse: () => {});
    final selectedEnergyData = _energyLevels
        .firstWhere((e) => e['id'] == _selectedEnergy, orElse: () => {});

    return Column(
      key: const ValueKey('confirm'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hazır mısın?',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 32),
        
        // Özet kartı
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              _buildSummaryRow(
                'Takma Ad',
                '👤 $_nickname',
              ),
              const Divider(color: Colors.white12, height: 24),
              _buildSummaryRow(
                'Konu',
                '${selectedTopicData['icon']} ${selectedTopicData['name']}',
              ),
              const Divider(color: Colors.white12, height: 24),
              _buildSummaryRow(
                'Enerji',
                '${selectedEnergyData['icon']} ${selectedEnergyData['name']}',
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Bilgilendirme
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.terracotta.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Seni benzer durumda olan kişilerle eşleştireceğiz. Grup 3 kişi olunca ateş yanacak.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Ücret bilgisi
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Text('💎', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Katılım Ücreti',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'İlk oturum: 50 elmas • Sonraki oturumlar: 20 elmas',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const Spacer(),
        
        // Butonlar
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() => _currentStep = 2),
              child: Text(
                'Geri',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.terracotta,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Ateşe Katıl',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _handleJoin() async {
    if (_selectedTopic == null) return;
    
    // Token kontrolü - dialog göster (yetersizse reklam izleme seçeneği)
    final canProceed = await CampfireTokenDialog.showJoinDialog(context);
    if (!canProceed) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Token düş
      final tokenUsed = await TokenService.useTokensForCampfireJoin();
      if (!tokenUsed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Elmas yetersiz')),
        );
        setState(() => _isLoading = false);
        return;
      }
      
      // Cihaz dili ve timezone al
      final deviceLocale = View.of(context).platformDispatcher.locale;
      final language = deviceLocale.languageCode; // tr, en, de vs.
      final timezoneOffset = DateTime.now().timeZoneOffset.inHours;
      final timezone = timezoneOffset >= 0 ? '+$timezoneOffset' : '$timezoneOffset';
      
      // Matchmaking - cohort bul veya oluştur
      final cohort = await CampfireService.findOrCreateCohort(
        topic: _selectedTopic!,
        timezone: timezone,
        language: language,
      );
      
      if (!mounted) return;
      
      // Lobby'e yönlendir
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LobbyScreen(
            cohort: cohort,
            nickname: _nickname,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bir hata oluştu: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
