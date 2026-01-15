import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/app_constants.dart';
import '../../services/auth_service.dart';
import '../../services/token_service.dart';
import '../../services/mood_service.dart';
import '../chat/chat_screen.dart';
import '../rooms/relationship_room_screen.dart';
import '../rooms/motivation_room_screen.dart';
import '../rooms/astrology_dream_room_screen.dart';
import '../rooms/style_room_screen.dart';
import '../rooms/mind_atelier_room_screen.dart';
import '../rooms/tests_room_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isMoodBarExpanded = false;
  String? _selectedMoodId;  // Now stores mood ID, not emoji
  late TextEditingController _nameController;
  bool _isEditingName = false;
  
  // Announcement Panel Logic
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;
  
  final List<Map<String, dynamic>> _announcements = [
    {
      'title': 'Zihin DNA\'nı Keşfet',
      'subtitle': 'Yaptığın her derin konuşma, karakter haritandaki travmaları, güçlü yönleri ve hedefleri gerçek zamanlı güncelleyerek sana özel bir rehberlik sunar.',
      'icon': '🧠',
      'color': const Color(0xFF6B8E23), // Sage Green
    },
    {
      'title': 'Kozmik Veri & Rüya Analizi',
      'subtitle': 'Cyber-Mistik motoruyla rüyalarının derin psikolojik anlamlarını çözebilir, doğum haritanın bugünkü kozmik etkilerle olan stratejik bağını keşfedebilirsin.',
      'icon': '🌌',
      'color': const Color(0xFF483D8B), // Dark Slate Blue
    },
    {
      'title': 'Arketipik Stil Mimarı',
      'subtitle': 'Gardırobun boş olsa bile Master DNA verilerini (yaş, meslek, ruh hali) analiz ederek sana en karizmatik ve psikolojik açıdan güçlü stil önerilerini sunuyoruz.',
      'icon': '🧥',
      'color': const Color(0xFFCD5C5C), // Indian Red
    },
    {
      'title': 'Stratejik İlişki Stratejisti',
      'subtitle': 'Aldatılma, ghosting veya ilk buluşma gibi senaryolarda burç tabanlı ve psikolojik derinliği olan saha taktikleriyle sosyal bağlarını profesyonelce yönet.',
      'icon': '💞',
      'color': const Color(0xFFDB7093), // Pale Violet Red
    },
    {
      'title': 'Gelecek Mimarı & Odaklanma',
      'subtitle': 'Kariyer hedeflerine giden yolda dopamin seviyeni optimize et, nöro-mimari teknikleriyle odaklanmanı artır ve hayallerini somut birer projeye dönüştür.',
      'icon': '🗺️',
      'color': const Color(0xFF2F4F4F), // Dark Slate Gray
    },
  ];
  
  // Local state for data
  String _userName = 'Misafir';
  int _tokenBalance = 100;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _userName);
    _pageController = PageController(initialPage: 0);
    _loadUserData();
    _startAnnouncementTimer();
  }

  void _startAnnouncementTimer() {
    _timer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (_pageController.hasClients) {
        _currentPage++;
        if (_currentPage >= _announcements.length) {
          _currentPage = 0;
        }
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadUserData() async {
    // Load profile
    final profile = await AuthService.getProfile();
    if (profile != null && profile['name'] != null) {
      setState(() {
        _userName = profile['name'];
        _nameController.text = _userName;
      });
    }
    
    // Load tokens
    final balance = await TokenService.getBalance();
    setState(() => _tokenBalance = balance);
    
    // Load saved mood
    final savedMood = await MoodService.getCurrentMood();
    if (savedMood != null) {
      setState(() => _selectedMoodId = savedMood);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty) {
      await AuthService.updateProfile({'name': newName});
      setState(() {
        _userName = newName;
        _isEditingName = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Refresh tokens whenever build is called if they are still 100 (initial)
    if (_tokenBalance == 100) {
      _loadUserData();
    }
    
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppTheme.sandBeige,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMoodSelector(),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Seninle buradayım'),
                      const SizedBox(height: 12),
                    // Dynamic Card Construction
                    ..._buildCategoryGrid(),
                    const SizedBox(height: 40),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.forestCharcoal,
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          // User Avatar & Name
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.sageGreen.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'M',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.sageGreen,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Merhaba,',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.mutedSage,
                            ),
                      ),
                      _isEditingName
                          ? Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 32,
                                    child: TextField(
                                      controller: _nameController,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            color: AppTheme.forestCharcoal,
                                            fontWeight: FontWeight.w600,
                                          ),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: AppTheme.warmCream,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: AppTheme.sageGreen),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: AppTheme.sageGreen, width: 2),
                                        ),
                                      ),
                                      onSubmitted: (_) => _saveName(),
                                      autofocus: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _saveName,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.sageGreen,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () {
                                    _nameController.text = _userName;
                                    setState(() => _isEditingName = false);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.mutedSage.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.close_rounded, color: AppTheme.forestCharcoal, size: 18),
                                  ),
                                ),
                              ],
                            )
                          : GestureDetector(
                              onTap: () => setState(() => _isEditingName = true),
                              child: Row(
                                children: [
                                  Text(
                                    _userName,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: AppTheme.forestCharcoal,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.edit_rounded,
                                    size: 14,
                                    color: AppTheme.mutedSage,
                                  ),
                                ],
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Token Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.warmCream,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: AppTheme.softBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppTheme.terracotta.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('✨', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$_tokenBalance',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.forestCharcoal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodSelector() {
    // Get current mood info for display
    final currentMoodInfo = _selectedMoodId != null 
        ? MoodService.getMoodInfo(_selectedMoodId!)
        : null;
    
    if (!_isMoodBarExpanded) {
      return GestureDetector(
        onTap: () => setState(() => _isMoodBarExpanded = true),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.warmCream,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Text(
                currentMoodInfo?['emoji'] ?? '🌿',
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentMoodInfo == null 
                          ? 'Bugün nasıl hissediyorsun?'
                          : 'Bugünkü ruh halin',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.mutedSage,
                          ),
                    ),
                    if (currentMoodInfo != null)
                      Text(
                        currentMoodInfo['label']!,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppTheme.forestCharcoal,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppTheme.mutedSage,
              ),
            ],
          ),
        ),
      );
    }
    
    // Expanded mood selector with 8 moods in grid
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.warmCream,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bugün nasıl hissediyorsun?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              GestureDetector(
                onTap: () => setState(() => _isMoodBarExpanded = false),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.mutedSage.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, color: AppTheme.mutedSage, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // First row - 4 moods
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: MoodService.availableMoods.sublist(0, 4).map((mood) {
              return _buildMoodItem(mood);
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Second row - 4 moods
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: MoodService.availableMoods.sublist(4, 8).map((mood) {
              return _buildMoodItem(mood);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodItem(Map<String, String> mood) {
    final isSelected = _selectedMoodId == mood['id'];
    final moodColor = Color(int.parse(mood['color']!));
    
    return GestureDetector(
      onTap: () async {
        setState(() {
          _selectedMoodId = mood['id'];
          _isMoodBarExpanded = false;
        });
        // Save to Firebase
        await MoodService.saveMood(mood['id']!);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? moodColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected 
              ? Border.all(color: moodColor, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mood['emoji']!, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              mood['label']!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? moodColor : AppTheme.mutedSage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build grid dynamically across categories
  List<Widget> _buildCategoryGrid() {
    List<Widget> gridItems = [];
    final categories = AppConstants.aiCategories;
    
    // First row
    gridItems.add(_buildCardRow(0, 1));
    gridItems.add(const SizedBox(height: 16));
    
    // Daily Insight (Always after first row for importance)
    gridItems.add(_buildDailyInsight());
    gridItems.add(const SizedBox(height: 16));
    
    // Subsequent rows
    for (int i = 2; i < categories.length; i += 2) {
      gridItems.add(_buildCardRow(i, i + 1));
      gridItems.add(const SizedBox(height: 12));
    }
    
    return gridItems;
  }

  /// Build a row of 2 cards
  Widget _buildCardRow(int index1, int index2) {
    final categories = AppConstants.aiCategories;
    return Row(
      children: [
        if (index1 < categories.length)
          Expanded(child: _buildModuleCard(categories[index1])),
        const SizedBox(width: 12),
        if (index2 < categories.length)
          Expanded(child: _buildModuleCard(categories[index2]))
        else
          const Expanded(child: SizedBox()),
      ],
    );
  }

  Widget _buildModuleCard(String category) {
    final name = AppConstants.categoryNames[category] ?? category;
    final icon = AppConstants.categoryIcons[category] ?? '🌿';

    // Astroloji ve Rüya için özel kart
    if (category == 'anksiyete') {
      return GestureDetector(
        onTap: () => _openChat(context, category),
        child: Container(
          height: 120,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.warmCream,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/astrology_dream.png',
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 70,
                    height: 70,
                    color: AppTheme.sageGreen.withOpacity(0.1),
                    child: Center(child: Text(icon, style: const TextStyle(fontSize: 30))),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Keşfet',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.terracotta,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.terracotta),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Stil Danışmanlığı için özel kart
    if (category == 'stil_danismanligi') {
      return GestureDetector(
        onTap: () => _openChat(context, category),
        child: Container(
          height: 120,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.warmCream,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/style_modern.png',
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 70,
                    height: 70,
                    color: AppTheme.terracotta.withOpacity(0.1),
                    child: Center(child: Text(icon, style: const TextStyle(fontSize: 30))),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Başla',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.terracotta,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.terracotta),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // İlişki Desteği için özel kart
    if (category == 'iliskiler') {
      return GestureDetector(
        onTap: () => _openChat(context, category),
        child: Container(
          height: 120,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.warmCream,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/couple_hugging.png',
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 70,
                    height: 70,
                    color: AppTheme.sageGreen.withOpacity(0.1),
                    child: Center(child: Text(icon, style: const TextStyle(fontSize: 30))),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Başla',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.terracotta,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.terracotta),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Persona Psikoloji (kendin_kesfet) için özel kart
    if (category == 'kendin_kesfet') {
      return GestureDetector(
        onTap: () => _openChat(context, category),
        child: Container(
          height: 120, 
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.warmCream,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/persona.png',
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 70,
                    height: 70,
                    color: AppTheme.sageGreen.withOpacity(0.1),
                    child: Center(child: Text(icon, style: const TextStyle(fontSize: 30))),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.forestCharcoal,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Başla',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.terracotta,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.terracotta),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Duygusal Destek (duygusal_destek) için özel kart
    if (category == 'duygusal_destek') {
      return GestureDetector(
        onTap: () => _openChat(context, category),
        child: Container(
          height: 120,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.warmCream,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppTheme.sageGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 34))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Başla',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.terracotta,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.terracotta),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Zihin Testleri (zihin_testleri) için özel kart
    if (category == 'zihin_testleri') {
      return GestureDetector(
        onTap: () => _openChat(context, category),
        child: Container(
          height: 120,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.warmCream,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/tests.png',
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 70,
                    height: 70,
                    color: AppTheme.sageGreen.withOpacity(0.1),
                    child: Center(child: Text(icon, style: const TextStyle(fontSize: 30))),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.forestCharcoal,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Testleri Çöz',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.terracotta,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.terracotta),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Motivasyon ve diğerleri için standart kaliteli kart
    return GestureDetector(
      onTap: () => _openChat(context, category),
      child: Container(
        height: 120, // Hepsi 120 oldu
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.warmCream,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: category == 'motivasyon' 
                    ? AppTheme.terracotta.withOpacity(0.1)
                    : AppTheme.sageGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 34)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'Başla',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.terracotta,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.terracotta),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyInsight() {
    return SizedBox(
      height: 220, // Increased height to prevent overflow with detailed text
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemCount: _announcements.length,
        itemBuilder: (context, index) {
          final announcement = _announcements[index];
          return _buildAnnouncementCard(announcement);
        },
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            data['color'] as Color,
            (data['color'] as Color).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(data['icon'], style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Text(
                'Duyuru & Rehberlik',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            data['title'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data['subtitle'],
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }

  String _getMotivationalTag() {
    final weekday = DateTime.now().weekday;
    const tags = {
      1: 'Yeni hafta, yeni başlangıç',
      2: 'Devam et',
      3: 'Yarı yoldayız',
      4: 'Neredeyse orada',
      5: 'Hafta sonu yaklaşıyor',
      6: 'Kendine zaman ayır',
      7: 'Dinlen ve yenilen',
    };
    return tags[weekday] ?? 'Büyüme zamanı';
  }

  void _openChat(BuildContext context, String category) {
    // Route to specific room screens or generic chat
    if (category == 'iliskiler') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const RelationshipRoomScreen()),
      );
    } else if (category == 'anksiyete') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const AstrologyDreamRoomScreen()),
      );
    } else if (category == 'motivasyon') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const MotivationRoomScreen()),
      );
    } else if (category == 'stil_danismanligi') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const StyleRoomScreen()),
      );
    } else if (category == 'kendin_kesfet') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const MindAtelierRoomScreen()),
      );
    } else if (category == 'zihin_testleri') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const TestsRoomScreen()),
      );
    } else if (category == 'duygusal_destek') {
      // These use a general chat screen but with their specific personas
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => ChatScreen(category: category)),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => ChatScreen(category: category)),
      );
    }
  }

}
