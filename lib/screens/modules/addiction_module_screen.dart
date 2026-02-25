import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/user_dna_model.dart';
import '../../services/user_dna_service.dart';
import '../../services/addiction_service.dart';

class AddictionModuleScreen extends StatefulWidget {
  const AddictionModuleScreen({super.key});

  @override
  State<AddictionModuleScreen> createState() => _AddictionModuleScreenState();
}

class _AddictionModuleScreenState extends State<AddictionModuleScreen> with TickerProviderStateMixin {
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    final userDna = UserDNAService.currentDNA;
    final addictions = userDna?.activeAddictions ?? [];

    return Scaffold(
      backgroundColor: Colors.black, // Dark mode for serious tone (Auditor vibe) ? Or keep app theme?
      // Keeping AppTheme but focusing on "Active" layout
      body: Container(
        color: AppTheme.sandBeige,
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: addictions.isEmpty 
                  ? _buildSelectionPanel()
                  : _buildAddictionTabs(addictions),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          const Expanded(child: Text("MENTALIQ", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, color: AppTheme.forestCharcoal))),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: AppTheme.forestCharcoal))
        ],
      ),
    );
  }

  // --- SELECTION (New Architecture) ---
  Widget _buildSelectionPanel() {
    final options = [
      {'id': 'gambling', 'label': 'Kumar', 'icon': '🎰', 'type': 'behavioral'},
      {'id': 'smoking', 'label': 'Sigara', 'icon': '🚬', 'type': 'substance'},
      {'id': 'social_media', 'label': 'Sosyal Medya', 'icon': '📱', 'type': 'behavioral'},
      {'id': 'sugar', 'label': 'Şeker', 'icon': '🍬', 'type': 'substance'},
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("Neyle savaşıyoruz?", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.forestCharcoal)),
        const SizedBox(height: 20),
        ...options.map((opt) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: Text(opt['icon']!, style: const TextStyle(fontSize: 32)),
            title: Text(opt['label']!, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              setState(() => _isLoading = true);
              await AddictionService.startTracking(opt['id']!, opt['type']!);
              setState(() => _isLoading = false);
            },
          ),
        ))
      ],
    );
  }

  // --- ACTIVE ARCHITECTURE TABS ---
  Widget _buildAddictionTabs(List<AddictionDna> addictions) {
    return DefaultTabController(
      length: addictions.length + 1, // +1 for "Add New"
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            labelColor: AppTheme.forestCharcoal,
            indicatorColor: AppTheme.terracotta,
            tabs: [
              ...addictions.map((a) => Tab(text: a.id.toUpperCase())).toList(),
              const Tab(icon: Icon(Icons.add_circle_outline)), // The Add Tab
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ...addictions.map((a) => _ActiveAddictionView(dna: a)).toList(),
                _buildSelectionPanel(), // The Add View
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveAddictionView extends StatefulWidget {
  final AddictionDna dna;
  const _ActiveAddictionView({required this.dna});

  @override
  State<_ActiveAddictionView> createState() => _ActiveAddictionViewState();
}

class _ActiveAddictionViewState extends State<_ActiveAddictionView> {
  String? _entryGreeting;
  String? _dynamicMission;
  bool _missionLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveContent();
  }

  Future<void> _loadActiveContent() async {
    // 1. Get Entry Greeting
    final greeting = await AddictionService.getEntryGreeting(widget.dna.id);
    // 2. Get/Generate Mission
    String mission = widget.dna.currentMission;
    if (mission.isEmpty) {
      mission = await AddictionService.getDynamicMission(widget.dna.id);
    }

    if (mounted) {
      setState(() {
        _entryGreeting = greeting;
        _dynamicMission = mission;
        _missionLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 1. ENTRY GREETING (Persona Voice)
            if (_entryGreeting != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.record_voice_over, color: Colors.white70),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _entryGreeting!,
                        style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 20),

            // 2. DASHBOARD (Financial for Gambling, Streak for others)
            widget.dna.id == 'gambling' 
                ? _buildGamblingDashboard()
                : _buildStandardDashboard(),

            const SizedBox(height: 20),

            // 3. DYNAMIC MISSION
            _buildMissionCard(),

            const SizedBox(height: 40),
            
            // 4. BIG RED BUTTON (Crisis Room)
            Center(child: _buildCrisisButton()),
          ],
        ),
      ],
    );
  }

  Widget _buildGamblingDashboard() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard("Kayıp", "₺${widget.dna.totalLostCapital}", Colors.red.shade100, Colors.red),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard("Temiz", "${widget.dna.streakDays} Gün", Colors.green.shade100, Colors.green),
        )
      ],
    );
  }

  Widget _buildStandardDashboard() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard("İrade", "%${(widget.dna.willpowerIndex * 100).toInt()}", Colors.blue.shade100, Colors.blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard("Temiz", "${widget.dna.streakDays} Gün", Colors.green.shade100, Colors.green),
        )
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: text)),
          Text(label, style: TextStyle(color: text.withOpacity(0.8))),
        ],
      ),
    );
  }

  Widget _buildMissionCard() {
    final completed = widget.dna.isMissionCompleted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: completed ? Colors.grey.shade200 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: completed ? null : Border.all(color: AppTheme.terracotta, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               Icon(Icons.flag, color: completed ? Colors.grey : AppTheme.terracotta),
               const SizedBox(width: 8),
               Text(
                 completed ? "GÖREV TAMAMLANDI" : "GÜNLÜK GÖREVİN",
                 style: TextStyle(fontWeight: FontWeight.bold, color: completed ? Colors.grey : AppTheme.terracotta)
               ),
            ],
          ),
          const SizedBox(height: 16),
          _missionLoading 
            ? const LinearProgressIndicator()
            : Text(
                _dynamicMission ?? "Yükleniyor...",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.4),
              ),
          const SizedBox(height: 20),
          if (!completed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.terracotta,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _openVerificationChat,
                child: const Text("Yüzleş ve Tamamla", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildCrisisButton() {
    return GestureDetector(
      onTap: _openCrisisRoom,
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          boxShadow: [
             BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)
          ]
        ),
        alignment: Alignment.center,
        child: const Text("SOS", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _openVerificationChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _VerificationChat(
        addictionId: widget.dna.id,
        onVerified: () {
          Navigator.pop(ctx);
          AddictionService.completeMission(widget.dna.id);
          setState(() {
            // Force Update logic locally 
            // In real app, StreamBuilder would handle this update from Service
          });
        }
      )
    );
  }

  void _openCrisisRoom() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => _CrisisRoom(addictionId: widget.dna.id))
    );
  }
}

// --- SUB-SCREENS ---

class _VerificationChat extends StatefulWidget {
  final String addictionId;
  final VoidCallback onVerified;
  const _VerificationChat({required this.addictionId, required this.onVerified});

  @override
  State<_VerificationChat> createState() => _VerificationChatState();
}

class _VerificationChatState extends State<_VerificationChat> {
  final _controller = TextEditingController();
  final List<String> _logs = ["Gemini: Görevi gerçekten tamamladın mı? Sadece dürüst ol. Nasıl hissettin?"];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("DOĞRULAMA", style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (ctx, i) => Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(_logs[i], style: TextStyle(color: i % 2 == 0 ? Colors.black : Colors.blue)),
                ),
              ),
            ),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "Cevabın...",
                suffixIcon: IconButton(icon: const Icon(Icons.send), onPressed: _send)
              ),
              onSubmitted: (_) => _send(),
            )
          ],
        ),
      ),
    );
  }

  void _send() async {
    final text = _controller.text;
    if (text.isEmpty) return;
    
    setState(() {
      _logs.add("Sen: $text");
      _controller.clear();
      _logs.add("Gemini: Analiz ediliyor...");
    });

    final response = await AddictionService.verifyMissionCompletion(widget.addictionId, text);
    
    setState(() {
       _logs.removeLast(); // Remove analysis
       _logs.add("Gemini: $response");
    });
    
    // Auto complete after short delay
    Future.delayed(const Duration(seconds: 2), widget.onVerified);
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

  @override
  void initState() {
    super.initState();
    _chat.add("SİSTEM: KRİZ MODU BAŞLATILDI.");
    _initiate();
  }

  void _initiate() async {
    // Initial punch
    final punch = await AddictionService.handleCrisisMessage(widget.addictionId, "START SOS");
    if(mounted) setState(() => _chat.add("Uzman: $punch"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade900,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("KRİZ ODASI", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 5)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _chat.length,
                itemBuilder: (ctx, i) {
                   final msg = _chat[i];
                   final isUser = msg.startsWith("Sen:");
                   return Align(
                     alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                     child: Container(
                       margin: const EdgeInsets.only(bottom: 12),
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(
                         color: isUser ? Colors.white : Colors.black,
                         borderRadius: BorderRadius.circular(12)
                       ),
                       child: Text(msg, style: TextStyle(color: isUser ? Colors.black : Colors.white, fontSize: 16)),
                     ),
                   );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Konuş...",
                  hintStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                  fillColor: Colors.black26,
                  filled: true
                ),
                onSubmitted: (_) => _send(),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _send() async {
    final t = _ctrl.text;
    if(t.isEmpty) return;
    setState(() {
      _chat.add("Sen: $t");
      _ctrl.clear();
    });
    
    final resp = await AddictionService.handleCrisisMessage(widget.addictionId, t);
    
    if(mounted) setState(() {
      _chat.add("Uzman: $resp");
    });
  }
}
