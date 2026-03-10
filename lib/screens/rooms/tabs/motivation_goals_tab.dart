import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../config/responsive.dart';
import '../../../l10n/app_translations.dart';
import '../../../models/goal_model.dart';
import '../../../services/goal_service.dart';
import '../../../services/shadow_memory_service.dart';

/// Tab 1: Kimlik & Hedef - Input Layer
/// Sistemin yakıt deposu. Kullanıcı burayı doldurmadan diğer sekmeler aktif olmaz.
class MotivationGoalsTab extends StatefulWidget {
  const MotivationGoalsTab({super.key});

  @override
  State<MotivationGoalsTab> createState() => _MotivationGoalsTabState();
}

class _MotivationGoalsTabState extends State<MotivationGoalsTab>
    with AutomaticKeepAliveClientMixin {
  
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _statusController = TextEditingController();
  final _skillsController = TextEditingController();
  final _notesController = TextEditingController();
  
  double _dailyHours = 2;
  bool _isLoading = false;
  bool _isLoadingGoal = true;
  GoalModel? _existingGoal;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadExistingGoal();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _statusController.dispose();
    _skillsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingGoal() async {
    // Load pre-fill data from UserDNA
    final preFill = await GoalService.getPreFillData();
    if (preFill['currentStatus'] != null) {
      _statusController.text = preFill['currentStatus'];
    }

    // Load existing goal if any
    final goal = await GoalService.getActiveGoal();
    if (goal != null) {
      setState(() {
        _existingGoal = goal;
        _titleController.text = goal.title;
        _statusController.text = goal.currentStatus;
        _skillsController.text = goal.skills ?? '';
        _dailyHours = goal.dailyHours.toDouble();
        _notesController.text = goal.specialNotes ?? '';
      });
    }

    setState(() => _isLoadingGoal = false);
  }

  Future<void> _createOrUpdateGoal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final goal = await GoalService.createGoal(
      title: _titleController.text.trim(),
      currentStatus: _statusController.text.trim(),
      dailyHours: _dailyHours.round(),
      skills: _skillsController.text.trim().isNotEmpty 
          ? _skillsController.text.trim() 
          : null,
      specialNotes: _notesController.text.trim().isNotEmpty 
          ? _notesController.text.trim() 
          : null,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (goal != null) {
        setState(() => _existingGoal = goal);
        _showSnackbar(AppTranslations.get('goalSaved'), isSuccess: true);
        
        // Shadow Memory analizi - Hedef ve yetenekleri DNA'ya işle
        final contextData = "YENİ HEDEF TANIMI:\n"
            "Hedef: ${_titleController.text.trim()}\n"
            "Mevcut Durum: ${_statusController.text.trim()}\n"
            "Yetenekler: ${_skillsController.text.trim()}\n"
            "Notlar: ${_notesController.text.trim()}";
        ShadowMemoryService.analyzeAndUpdate(contextData, category: 'motivasyon');

        // TODO: Generate roadmap with Gemini (Tab 2)
      } else {
        _showSnackbar(AppTranslations.get('errorSave'), isSuccess: false);
      }
    }
  }

  void _showSnackbar(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_isLoadingGoal) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF9C27B0)),
      );
    }

    return SingleChildScrollView(
      padding: context.insetsAll(context.isCompactPhone ? 12 : 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info
            _buildInfoCard(),
            const SizedBox(height: 20),
            
            // Form fields
            _buildSectionTitle(AppTranslations.get('mainGoal')),
            const SizedBox(height: 8),
            _buildTitleField(),
            const SizedBox(height: 20),
            
            _buildSectionTitle(AppTranslations.get('currentStatus')),
            const SizedBox(height: 8),
            _buildStatusField(),
            const SizedBox(height: 20),

            _buildSectionTitle(AppTranslations.get('skills')),
            const SizedBox(height: 8),
            _buildSkillsField(),
            const SizedBox(height: 20),
            
            _buildSectionTitle(AppTranslations.get('dailyTime')),
            const SizedBox(height: 8),
            _buildTimeSlider(),
            const SizedBox(height: 20),
            
            _buildSectionTitle(AppTranslations.get('specialNotes')),
            const SizedBox(height: 8),
            _buildNotesField(),
            const SizedBox(height: 24),
            
            // Submit button
            _buildSubmitButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final isCompact = context.isCompactPhone;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF9C27B0).withOpacity(0.1),
            const Color(0xFF7B1FA2).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF9C27B0).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: isCompact ? 42 : 48,
            height: isCompact ? 42 : 48,
            decoration: BoxDecoration(
              color: const Color(0xFF9C27B0).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('🚀', style: TextStyle(fontSize: 24)),
            ),
          ),
          SizedBox(width: isCompact ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _existingGoal != null ? AppTranslations.get('updateGoal') : AppTranslations.get('defineGoal'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompact ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9C27B0),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppTranslations.get('goalInfoDesc'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompact ? 11 : 12,
                    color: AppTheme.mutedSage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.forestCharcoal,
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: InputDecoration(
        hintText: AppTranslations.get('mainGoalHint'),
        hintStyle: TextStyle(color: AppTheme.mutedSage, fontSize: 14),
        filled: true,
        fillColor: AppTheme.warmCream,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.softBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.softBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return AppTranslations.get('errorMainGoal');
        }
        return null;
      },
    );
  }

  Widget _buildStatusField() {
    return TextFormField(
      controller: _statusController,
      decoration: InputDecoration(
        hintText: AppTranslations.get('currentStatusHint'),
        hintStyle: TextStyle(color: AppTheme.mutedSage, fontSize: 14),
        filled: true,
        fillColor: AppTheme.warmCream,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.softBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.softBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return AppTranslations.get('errorCurrentStatus');
        }
        return null;
      },
    );
  }

  Widget _buildSkillsField() {
    return TextFormField(
      controller: _skillsController,
      maxLines: 2,
      decoration: InputDecoration(
        hintText: AppTranslations.get('skillsHint'),
        hintStyle: TextStyle(color: AppTheme.mutedSage, fontSize: 14),
        filled: true,
        fillColor: AppTheme.warmCream,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.softBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.softBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildTimeSlider() {
    final isCompact = context.isCompactPhone;
    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppTheme.warmCream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppTranslations.get('dailyHoursQuestion'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isCompact ? 12 : 13,
                  color: AppTheme.forestCharcoal,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_dailyHours.round()} ${AppTranslations.get('hours')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF9C27B0),
              inactiveTrackColor: const Color(0xFF9C27B0).withOpacity(0.2),
              thumbColor: const Color(0xFF9C27B0),
              overlayColor: const Color(0xFF9C27B0).withOpacity(0.2),
              trackHeight: 6,
            ),
            child: Slider(
              value: _dailyHours,
              min: 1,
              max: 8,
              divisions: 7,
              onChanged: (value) => setState(() => _dailyHours = value),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppTranslations.get('oneHour'), style: TextStyle(fontSize: 11, color: AppTheme.mutedSage)),
              Text(AppTranslations.get('eightHours'), style: TextStyle(fontSize: 11, color: AppTheme.mutedSage)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: AppTranslations.get('specialNotesHint'),
        hintStyle: TextStyle(color: AppTheme.mutedSage, fontSize: 14),
        filled: true,
        fillColor: AppTheme.warmCream,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.softBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.softBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _createOrUpdateGoal,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isLoading
                ? [Colors.grey.shade400, Colors.grey.shade500]
                : [const Color(0xFF9C27B0), const Color(0xFF7B1FA2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isLoading
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF9C27B0).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading) ...[
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Text(
              _isLoading 
                  ? AppTranslations.get('saving') 
                  : (_existingGoal != null ? AppTranslations.get('updateGoalButton') : AppTranslations.get('createRoadmap')),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
