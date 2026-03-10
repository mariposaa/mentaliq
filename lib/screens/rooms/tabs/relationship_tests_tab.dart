import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../config/responsive.dart';
import '../../../l10n/app_translations.dart';
import '../../../models/partner_model.dart';
import '../../../services/partner_service.dart';
import '../../../services/answer_mode_service.dart';

/// Partner Bilgileri Tab - Partner info + Answer mode selection
class RelationshipTestsTab extends StatefulWidget {
  const RelationshipTestsTab({super.key});

  @override
  State<RelationshipTestsTab> createState() => _RelationshipTestsTabState();
}

class _RelationshipTestsTabState extends State<RelationshipTestsTab>
    with AutomaticKeepAliveClientMixin {
  
  PartnerModel? _partner;
  bool _isLoading = true;
  bool _isEditingPartner = false;
  AnswerMode _selectedMode = AnswerMode.realistic; // Default: Gerçekçi Ol

  // Form controllers
  final _nameController = TextEditingController();
  String? _selectedRelationType;
  String? _selectedGender;
  final _ageController = TextEditingController();
  String? _selectedZodiac;
  String? _selectedLoveLanguage;
  String? _selectedCommunicationStyle;
  final _notesController = TextEditingController();

  // Options
  final _relationTypes = ['Sevgili', 'Nişanlı', 'Eş', 'Eski Sevgili', 'Flört', 'Karmaşık'];
  final _genders = ['Kadın', 'Erkek', 'Diğer'];
  final _zodiacs = ['Koç', 'Boğa', 'İkizler', 'Yengeç', 'Aslan', 'Başak', 
                   'Terazi', 'Akrep', 'Yay', 'Oğlak', 'Kova', 'Balık'];
  final _loveLanguages = ['Onaylayıcı Sözler', 'Kaliteli Zaman', 'Hediye Alma', 
                          'Hizmet Etme', 'Fiziksel Dokunuş'];
  final _communicationStyles = ['Asertif', 'Pasif', 'Agresif', 'Pasif-Agresif'];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // Load saved mode from service
    final savedMode = await AnswerModeService.getSavedMode();
    _selectedMode = savedMode;
    
    // Load partner
    final partner = await PartnerService.getPrimaryPartner();
    if (partner != null) {
      _populateForm(partner);
    }
    
    setState(() {
      _partner = partner;
      _isLoading = false;
    });
  }

  Future<void> _saveMode(AnswerMode mode) async {
    setState(() => _selectedMode = mode);
    await AnswerModeService.saveMode(mode);
  }

  void _populateForm(PartnerModel partner) {
    _nameController.text = partner.name;
    _selectedRelationType = partner.relationshipType;
    _selectedGender = partner.gender;
    _ageController.text = partner.age?.toString() ?? '';
    _selectedZodiac = partner.zodiacSign;
    _selectedLoveLanguage = partner.loveLanguage;
    _selectedCommunicationStyle = partner.communicationStyle;
    _notesController.text = partner.notes ?? '';
  }

  void _clearForm() {
    _nameController.clear();
    _selectedRelationType = null;
    _selectedGender = null;
    _ageController.clear();
    _selectedZodiac = null;
    _selectedLoveLanguage = null;
    _selectedCommunicationStyle = null;
    _notesController.clear();
  }

  Future<void> _savePartner() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.get('errorPartnerName')), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final age = int.tryParse(_ageController.text);

    if (_partner == null) {
      final newPartner = await PartnerService.createPartner(
        name: _nameController.text.trim(),
        relationshipType: _selectedRelationType,
        gender: _selectedGender,
        age: age,
        zodiacSign: _selectedZodiac,
        loveLanguage: _selectedLoveLanguage,
        communicationStyle: _selectedCommunicationStyle,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      if (newPartner != null) {
        debugPrint('Partner saved successfully: ${newPartner.name}');
        setState(() => _partner = newPartner);
      } else {
        debugPrint('Failed to create partner');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppTranslations.get('errorPartnerSave')), backgroundColor: Colors.red),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
    } else {
      final updated = _partner!.copyWith(
        name: _nameController.text.trim(),
        relationshipType: _selectedRelationType,
        gender: _selectedGender,
        age: age,
        zodiacSign: _selectedZodiac,
        loveLanguage: _selectedLoveLanguage,
        communicationStyle: _selectedCommunicationStyle,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      await PartnerService.updatePartner(updated);
      setState(() => _partner = updated);
    }

    setState(() {
      _isLoading = false;
      _isEditingPartner = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppTranslations.get('partnerSaved')),
          backgroundColor: AppTheme.sageGreen,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.sageGreen));
    }

    // Show edit form if editing
    if (_isEditingPartner) {
      return _buildPartnerForm();
    }

    // Main view with mode selector and partner card
    return SingleChildScrollView(
      padding: context.insetsAll(context.isCompactPhone ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Answer Mode Selector
          _buildModeSelector(),
          
          const SizedBox(height: 24),
          
          // Partner Card or Add Button
          if (_partner != null)
            _buildPartnerCard()
          else
            _buildAddPartnerButton(),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    final isCompact = context.isCompactPhone;
    return Container(
      padding: EdgeInsets.all(isCompact ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.sageGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.psychology_outlined, color: AppTheme.sageGreen, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.get('myAnswers'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.forestCharcoal,
                          ),
                    ),
                    Text(
                      AppTranslations.get('answerModeQuestion'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.mutedSage,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Mode Options
          _buildModeOption(
            mode: AnswerMode.comfort,
            emoji: '🤗',
            title: AppTranslations.get('comfortMode'),
            subtitle: AppTranslations.get('comfortModeDesc'),
            color: const Color(0xFF4CAF50),
          ),
          
          const SizedBox(height: 10),
          
          _buildModeOption(
            mode: AnswerMode.realistic,
            emoji: '🎯',
            title: AppTranslations.get('realisticMode'),
            subtitle: AppTranslations.get('realisticModeDesc'),
            color: const Color(0xFF2196F3),
          ),
          
          const SizedBox(height: 10),
          
          _buildModeOption(
            mode: AnswerMode.harsh,
            emoji: '🔥',
            title: AppTranslations.get('harshMode'),
            subtitle: AppTranslations.get('harshModeDesc'),
            color: const Color(0xFFE91E63),
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required AnswerMode mode,
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isCompact = context.isCompactPhone;
    final isSelected = _selectedMode == mode;
    
    return GestureDetector(
      onTap: () => _saveMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : AppTheme.sandBeige,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: TextStyle(fontSize: isCompact ? 24 : 28)),
            SizedBox(width: isCompact ? 10 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isSelected ? color : AppTheme.forestCharcoal,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.mutedSage,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : Colors.transparent,
                border: Border.all(
                  color: isSelected ? color : AppTheme.mutedSage,
                  width: 2,
                ),
              ),
              child: isSelected 
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerCard() {
    return GestureDetector(
      onTap: () => setState(() => _isEditingPartner = true),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE91E63), Color(0xFFFF5722)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      _partner!.name.isNotEmpty ? _partner!.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _partner!.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (_partner!.relationshipType != null)
                        Text(
                          _partner!.relationshipType!,
                          style: TextStyle(
                            color: AppTheme.mutedSage,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.sageGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    color: AppTheme.sageGreen,
                    size: 18,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Info chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_partner!.gender != null)
                  _buildInfoChip('👤 ${_partner!.gender}'),
                if (_partner!.age != null)
                  _buildInfoChip('🎂 ${_partner!.age} yaş'),
                if (_partner!.zodiacSign != null)
                  _buildInfoChip('✨ ${_partner!.zodiacSign}'),
                if (_partner!.loveLanguage != null)
                  _buildInfoChip('💕 ${_partner!.loveLanguage}'),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Text(
              AppTranslations.get('tapToEdit'),
              style: TextStyle(
                color: AppTheme.sageGreen,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.sandBeige,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.forestCharcoal,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildAddPartnerButton() {
    return GestureDetector(
      onTap: () {
        _clearForm();
        setState(() => _isEditingPartner = true);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(
            color: AppTheme.sageGreen.withOpacity(0.3),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.sageGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_add_alt_1_rounded,
                color: AppTheme.sageGreen,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppTranslations.get('addPartner'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.forestCharcoal,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              AppTranslations.get('addPartnerDesc'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.mutedSage,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerForm() {
    return Scaffold(
      backgroundColor: AppTheme.sandBeige,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: AppTheme.forestCharcoal),
          onPressed: () {
            if (_partner != null) _populateForm(_partner!);
            setState(() => _isEditingPartner = false);
          },
        ),
        title: Text(
          _partner == null ? AppTranslations.get('newPartner') : AppTranslations.get('editPartner'),
          style: TextStyle(color: AppTheme.forestCharcoal),
        ),
        actions: [
          TextButton(
            onPressed: _savePartner,
            child: Text(AppTranslations.get('save'), style: TextStyle(color: AppTheme.sageGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              _buildTextField(
                controller: _nameController,
                label: AppTranslations.get('nameLabel'),
                hint: AppTranslations.get('nameHint'),
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      value: _selectedRelationType,
                      items: _relationTypes,
                      label: AppTranslations.get('relationshipType'),
                      hint: AppTranslations.get('selectHint'),
                      onChanged: (v) => setState(() => _selectedRelationType = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      value: _selectedGender,
                      items: _genders,
                      label: AppTranslations.get('gender'),
                      hint: AppTranslations.get('selectHint'),
                      onChanged: (v) => setState(() => _selectedGender = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _ageController,
                      label: AppTranslations.get('age'),
                      hint: '25',
                      icon: Icons.cake_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      value: _selectedZodiac,
                      items: _zodiacs,
                      label: AppTranslations.get('zodiacSign'),
                      hint: AppTranslations.get('selectHint'),
                      onChanged: (v) => setState(() => _selectedZodiac = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                value: _selectedLoveLanguage,
                items: _loveLanguages,
                label: AppTranslations.get('loveLanguage'),
                hint: AppTranslations.get('loveLangHint'),
                onChanged: (v) => setState(() => _selectedLoveLanguage = v),
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                value: _selectedCommunicationStyle,
                items: _communicationStyles,
                label: AppTranslations.get('commStyleLabel'),
                hint: AppTranslations.get('commStyleHint'),
                onChanged: (v) => setState(() => _selectedCommunicationStyle = v),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _notesController,
                label: AppTranslations.get('extraNotes'),
                hint: AppTranslations.get('extraNotesHint'),
                icon: Icons.notes_rounded,
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppTheme.forestCharcoal, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(color: AppTheme.forestCharcoal),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.mutedSage),
            prefixIcon: Icon(icon, color: AppTheme.sageGreen, size: 20),
            filled: true,
            fillColor: AppTheme.sandBeige,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String label,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppTheme.forestCharcoal, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: AppTheme.sandBeige, borderRadius: BorderRadius.circular(10)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text(hint, style: TextStyle(color: AppTheme.mutedSage)),
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.sageGreen),
              style: TextStyle(color: AppTheme.forestCharcoal, fontSize: 14),
              items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
