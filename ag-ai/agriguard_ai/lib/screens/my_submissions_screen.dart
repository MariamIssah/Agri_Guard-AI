import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/backend_service.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';

class MySubmissionsScreen extends StatefulWidget {
  const MySubmissionsScreen({super.key});

  @override
  State<MySubmissionsScreen> createState() => _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends State<MySubmissionsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _submissions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final user = context.read<AuthService>().currentUser;
      final farmerId = user?.id ?? 'guest';
      final res = await context.read<BackendService>().getMySubmissions(farmerId);
      final list = (res['submissions'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) setState(() => _submissions = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _hide(Map<String, dynamic> record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove submission?'),
        content: const Text(
          'This will remove it from your list. '
          'The record is kept in our database to help improve crop predictions.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: AgriColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final user = context.read<AuthService>().currentUser;
      await context.read<BackendService>().hideSubmission(
        farmerId: user?.id ?? 'guest',
        submittedAt: record['submitted_at'] as String,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove: $e'), backgroundColor: AgriColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Harvest Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _submissions.isEmpty
                  ? _EmptyView()
                  : _ListView(submissions: _submissions, onHide: _hide),
    );
  }
}

// ── List ───────────────────────────────────────────────────────────────────────

class _ListView extends StatelessWidget {
  const _ListView({required this.submissions, required this.onHide});
  final List<Map<String, dynamic>> submissions;
  final Future<void> Function(Map<String, dynamic>) onHide;

  @override
  Widget build(BuildContext context) {
    final botPad = MediaQuery.viewPaddingOf(context).bottom;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, botPad + 16),
      itemCount: submissions.length,
      itemBuilder: (_, i) => _SubmissionCard(
        record: submissions[i],
        onHide: () => onHide(submissions[i]),
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({required this.record, required this.onHide});
  final Map<String, dynamic> record;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final crop     = record['crop']?.toString() ?? '';
    final region   = record['region']?.toString() ?? '';
    final district = record['district']?.toString() ?? '';
    final town     = record['town']?.toString() ?? '';
    final yieldKgHa = (record['actual_yield_kg_per_ha'] as num?) ?? 0;
    final totalKg  = (record['actual_yield_kg'] as num?) ?? 0;
    final qtyForSale = (record['quantity_available_kg'] as num?) ?? totalKg;
    final priceGhs = record['price_per_kg_ghs'] as num?;
    final phone    = record['phone']?.toString() ?? '';
    final quality  = record['quality_score'] as num?;
    final notes    = record['notes']?.toString() ?? '';
    final submittedAt = record['submitted_at']?.toString() ?? '';
    final year     = record['year']?.toString() ?? '';

    final locationParts = [
      if (town.isNotEmpty) town,
      if (district.isNotEmpty) district,
      region,
    ];
    final location = locationParts.join(', ');

    final dateLabel = submittedAt.length >= 10
        ? submittedAt.substring(0, 10)
        : submittedAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AgriColors.forestGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.agriculture_rounded,
              color: AgriColors.forestGreen, size: 22),
        ),
        title: Text(crop, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$location · $dateLabel',
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: AgriColors.danger, size: 20),
          tooltip: 'Remove from my list',
          onPressed: onHide,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: 1),
                const SizedBox(height: 12),

                _Row(icon: Icons.scale_rounded,
                    label: 'Total Harvested',
                    value: '${totalKg.toStringAsFixed(0)} kg',
                    color: AgriColors.forestGreen),
                _Row(icon: Icons.trending_up_rounded,
                    label: 'Yield',
                    value: '${yieldKgHa.toStringAsFixed(0)} kg/ha',
                    color: AgriColors.leafGreen),
                _Row(icon: Icons.inventory_2_outlined,
                    label: 'Available for Sale',
                    value: '${qtyForSale.toStringAsFixed(0)} kg',
                    color: AgriColors.leafGreen),
                if (priceGhs != null)
                  _Row(icon: Icons.attach_money_rounded,
                      label: 'Asking Price',
                      value: 'GHS ${priceGhs.toStringAsFixed(2)} / kg',
                      color: AgriColors.gold),
                if (phone.isNotEmpty)
                  _Row(icon: Icons.phone_outlined,
                      label: 'Contact',
                      value: phone,
                      color: AgriColors.sky),
                if (quality != null)
                  _Row(icon: Icons.star_outline_rounded,
                      label: 'Quality Score',
                      value: '${quality.toStringAsFixed(1)} / 10',
                      color: AgriColors.gold),
                if (year.isNotEmpty)
                  _Row(icon: Icons.calendar_today_outlined,
                      label: 'Harvest Year',
                      value: year,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                if (notes.isNotEmpty)
                  _Row(icon: Icons.notes_rounded,
                      label: 'Notes',
                      value: notes,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),

                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onHide,
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AgriColors.danger, size: 18),
                  label: const Text('Remove from my list',
                      style: TextStyle(color: AgriColors.danger)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AgriColors.danger),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600, color: color)),
          ),
        ],
      ),
    );
  }
}

// ── Empty / Error states ───────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.agriculture_rounded,
                size: 56, color: AgriColors.leafGreen),
            const SizedBox(height: 16),
            Text('No harvest reports yet',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Submit your first harvest report from the\nProduce Prediction screen.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56, color: AgriColors.danger),
            const SizedBox(height: 16),
            Text('Could not load submissions',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
