import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/app_theme.dart';
import '../../../models/style_outfit_record.dart';
import '../../../services/style_outfit_history_service.dart';

class StyleTrendTab extends StatefulWidget {
  const StyleTrendTab({super.key});

  @override
  State<StyleTrendTab> createState() => _StyleTrendTabState();
}

class _StyleTrendTabState extends State<StyleTrendTab> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StyleOutfitRecord>>(
      stream: StyleOutfitHistoryService.watchRecords(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = snapshot.data ?? [];
        if (records.isEmpty) {
          return const Center(
            child: Text(
              'Henüz kayıtlı kombin yok.',
              style: TextStyle(color: AppTheme.mutedSage),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            return _buildRecordCard(record);
          },
        );
      },
    );
  }

  Widget _buildRecordCard(StyleOutfitRecord record) {
    final firstOutfit = record.outfits.isNotEmpty ? record.outfits.first : null;
    final previewImages = firstOutfit?.previewImages() ?? const <String>[];
    final createdAtText = DateFormat('dd.MM.yyyy HH:mm').format(record.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.softBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.query,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.forestCharcoal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                createdAtText,
                style: const TextStyle(fontSize: 11, color: AppTheme.mutedSage),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildChip(record.sourceMode == 'gardrop_disi_oneri' ? 'Gardrop Disi Oneri' : 'Sadece Arsivim'),
              if ((record.moodTag ?? '').isNotEmpty) _buildChip(record.moodTag!),
              if (record.weather.isNotEmpty) _buildChip(record.weather),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            record.recommendation,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppTheme.mutedSage, height: 1.3),
          ),
          if (previewImages.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: previewImages.take(3).map((url) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      url,
                      width: 64,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 64,
                        height: 72,
                        color: AppTheme.sandBeige,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined, size: 16),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => StyleOutfitHistoryService.deleteRecord(record.id),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Sil'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.warmCream,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, color: AppTheme.forestCharcoal),
      ),
    );
  }
}
