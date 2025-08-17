import 'package:flutter/material.dart';
import '../theme.dart';

class SpecialEventsScreen extends StatelessWidget {
  const SpecialEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    Widget pricePill(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        border: Border.all(color: AppTheme.stroke),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: text.labelLarge),
    );

    Widget include(String t) => Row(
      children: [
        const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white70),
        const SizedBox(width: 8),
        Expanded(child: Text(t, style: text.bodyMedium)),
      ],
    );

    Widget eventCard({
      required String title,
      required String soloPrice,
      required String bulkPrice,
    }) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.titleLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                pricePill(soloPrice),
                pricePill(bulkPrice),
                pricePill('Solo or Group'),
              ],
            ),
            const SizedBox(height: 14),
            Text("What's included", style: text.titleMedium),
            const SizedBox(height: 8),
            include('Music selection & editing'),
            include('Complete choreography'),
            include('Dedicated private sessions'),
            include('Faculty/Admin available on event day'),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/booking'),
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Call Now'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/booking'),
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: const Text('Book now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Special Events'),
        // ✅ Settings yahin rakha — dashboard se hata diya
        actions: [
          IconButton(
            tooltip: 'Event settings',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.pushNamed(context, '/events-settings'),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Book choreography for schools, sangeet, and corporate events. '
              'Transparent pricing • Music edit • Private sessions • Faculty/Admin support on event day.',
              style: text.bodyMedium,
            ),
          ),
          const SizedBox(height: 12),
          eventCard(
            title: 'School Function Choreography',
            soloPrice: '₹4,500 / dance',
            bulkPrice: '₹3,500 / dance (5+ dances)',
          ),
          const SizedBox(height: 12),
          eventCard(
            title: 'Sangeet / Wedding Choreography',
            soloPrice: '₹7,500 / dance',
            bulkPrice: '₹5,500 / dance (5+ dances)',
          ),
          const SizedBox(height: 12),
          eventCard(
            title: 'Corporate Event Performance',
            soloPrice: '₹7,500 / dance',
            bulkPrice: '₹5,500 / dance (5+ dances)',
          ),
        ],
      ),
    );
  }
}