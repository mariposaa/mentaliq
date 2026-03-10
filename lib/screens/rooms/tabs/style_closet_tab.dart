import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/app_theme.dart';
import '../../../models/style_item.dart';
import '../../../services/style_service.dart';
import '../../../l10n/app_translations.dart';

class StyleClosetTab extends StatefulWidget {
  const StyleClosetTab({super.key});

  @override
  State<StyleClosetTab> createState() => _StyleClosetTabState();
}

class _StyleClosetTabState extends State<StyleClosetTab> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _isDeleting = false;

  String _localizedCategory(String raw) {
    switch (raw.toLowerCase()) {
      case 'top':
      case 'üst':
      case 'ust':
        return AppTranslations.currentLanguage == 'tr' ? 'Üst Giyim' : 'Top';
      case 'bottom':
      case 'alt':
        return AppTranslations.currentLanguage == 'tr' ? 'Alt Giyim' : 'Bottom';
      case 'outerwear':
      case 'dış giyim':
      case 'dis giyim':
        return AppTranslations.currentLanguage == 'tr'
            ? 'Dış Giyim'
            : 'Outerwear';
      case 'shoes':
      case 'ayakkabı':
      case 'ayakkabi':
        return AppTranslations.currentLanguage == 'tr' ? 'Ayakkabı' : 'Shoes';
      case 'accessory':
      case 'aksesuar':
        return AppTranslations.currentLanguage == 'tr'
            ? 'Aksesuar'
            : 'Accessory';
      default:
        return AppTranslations.currentLanguage == 'tr' ? 'Diğer' : 'Other';
    }
  }

  String _localizedSeason(String raw) {
    switch (raw.toLowerCase()) {
      case 'summer':
      case 'yaz':
        return AppTranslations.currentLanguage == 'tr' ? 'Yaz' : 'Summer';
      case 'winter':
      case 'kış':
      case 'kis':
        return AppTranslations.currentLanguage == 'tr' ? 'Kış' : 'Winter';
      case 'spring':
      case 'bahar':
        return AppTranslations.currentLanguage == 'tr' ? 'Bahar' : 'Spring';
      case 'autumn':
      case 'sonbahar':
        return AppTranslations.currentLanguage == 'tr' ? 'Sonbahar' : 'Autumn';
      default:
        return AppTranslations.currentLanguage == 'tr'
            ? 'Dört Mevsim'
            : 'All Season';
    }
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isUploading = true);

    final newItem = await StyleService.addToCloset(image);

    setState(() => _isUploading = false);

    if (newItem != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.get('clothingAdded'))),
      );
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Kıyafet eklenemedi. Lütfen bağlantını kontrol edip tekrar dene.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          StreamBuilder<List<StyleItem>>(
            stream: StyleService.getClosetStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final items = snapshot.data ?? [];

              if (items.isEmpty) {
                return _buildEmptyState();
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 820 ? 3 : 2;
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return _buildClosetItem(items[index]);
                    },
                  );
                },
              );
            },
          ),
          if (_isUploading || _isDeleting)
            Container(
              color: Colors.black26,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppTheme.terracotta),
                    const SizedBox(height: 16),
                    Text(
                      _isDeleting
                          ? 'Siliniyor...'
                          : AppTranslations.get('analyzing'),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: GestureDetector(
        onTap: _pickAndUploadImage,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.terracotta, Color(0xFFE59A85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            boxShadow: [
              BoxShadow(
                color: AppTheme.terracotta.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_a_photo_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                AppTranslations.get('addNew'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 64, color: AppTheme.mutedSage.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(AppTranslations.get('closetEmpty'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(AppTranslations.get('closetEmptyMsg'),
              style: TextStyle(color: AppTheme.mutedSage, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildClosetItem(StyleItem item) {
    return GestureDetector(
      onTap: () => _showItemDetails(item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  item.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppTheme.warmCream,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _localizedCategory(item.category),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.tags.isNotEmpty ? item.tags.first : '',
                    style: TextStyle(fontSize: 11, color: AppTheme.mutedSage),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showItemDetails(StyleItem item) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.warmCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.softBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  item.imageUrl,
                  height: 260,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 220,
                    color: AppTheme.sandBeige,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined, size: 34),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _localizedCategory(item.category),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.forestCharcoal,
                      ),
                    ),
                  ),
                  Text(
                    _localizedSeason(item.season),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.mutedSage,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: item.tags
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.sandBeige,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.softBorder),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.forestCharcoal),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              if (item.aiDescription.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.aiDescription,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.forestCharcoal,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final shouldDelete = await _confirmDelete();
                    if (!shouldDelete) return;
                    if (!mounted) return;
                    Navigator.pop(context);
                    setState(() => _isDeleting = true);
                    final success = await StyleService.deleteClosetItem(item);
                    if (!mounted) return;
                    setState(() => _isDeleting = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Kıyafet dolaptan silindi.'
                              : 'Silme işlemi başarısız oldu. Tekrar dene.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Dolaptan Sil'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.warmCream,
        title: const Text('Kıyafeti sil'),
        content:
            const Text('Bu ürünü dolabından kaldırmak istediğine emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    return approved ?? false;
  }
}
