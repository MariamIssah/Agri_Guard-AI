import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../utils/app_theme.dart';

class MyActivityScreen extends StatefulWidget {
  const MyActivityScreen({super.key});

  @override
  State<MyActivityScreen> createState() => _MyActivityScreenState();
}

class _MyActivityScreenState extends State<MyActivityScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];
  String? _error;
  String _filter = 'all';

  String get _buyerId =>
      context.read<AuthService>().currentUser?.id ?? 'guest';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await context.read<BackendService>().getMyActivity(_buyerId);
      final list = (res['activity'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) setState(() => _rows = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteEntry(Map<String, dynamic> record) async {
    final id = record['id'] as int?;
    if (id == null) return;
    try {
      await context.read<BackendService>().deleteActivityEntry(
        buyerId: _buyerId,
        entryId: id,
      );
      setState(() => _rows.removeWhere((r) => r['id'] == id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e'),
              backgroundColor: AgriColors.danger),
        );
      }
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Activity?'),
        content: const Text(
          'This will permanently delete your entire browsing and search history '
          'from AgriGuard. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All',
                style: TextStyle(color: AgriColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<BackendService>().clearMyActivity(_buyerId);
      setState(() => _rows.clear());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'),
              backgroundColor: AgriColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'all'
        ? _rows
        : _rows.where((r) => r['action'] == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Activity History'),
        actions: [
          if (_rows.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: const Text('Clear All',
                  style: TextStyle(color: AgriColors.danger)),
            ),
          IconButton(
              icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(children: [
              for (final f in ['all', 'browse', 'search', 'select'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f[0].toUpperCase() + f.substring(1)),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                    selectedColor: AgriColors.leafGreen.withValues(alpha: 0.2),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 8),

          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48, color: AgriColors.danger),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry')),
              ],
            )))
          else if (filtered.isEmpty)
            Expanded(child: Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history_rounded, size: 56,
                    color: AgriColors.leafGreen),
                const SizedBox(height: 16),
                Text(_filter == 'all'
                    ? 'No activity recorded yet.'
                    : 'No ${_filter}s recorded yet.',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Your browsing, searches and selections\nwill appear here.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center),
              ],
            )))
          else
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(12, 0, 12,
                    MediaQuery.viewPaddingOf(context).bottom + 12),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _ActivityTile(
                  record: filtered[i],
                  onDelete: () => _deleteEntry(filtered[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.record, required this.onDelete});
  final Map<String, dynamic> record;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final action   = record['action']?.toString() ?? '';
    final screen   = record['screen']?.toString() ?? '';
    final crop     = record['crop']?.toString() ?? '';
    final region   = record['region']?.toString() ?? '';
    final query    = record['query']?.toString() ?? '';
    final loggedAt = record['logged_at']?.toString() ?? '';
    final timeLabel = loggedAt.length >= 19
        ? loggedAt.substring(0, 19).replaceFirst('T', ' ')
        : loggedAt;

    final (icon, color, label) = switch (action) {
      'search' => (Icons.search_rounded,     AgriColors.gold,         'Search'),
      'select' => (Icons.touch_app_rounded,  AgriColors.forestGreen,  'Viewed'),
      _        => (Icons.visibility_outlined, AgriColors.sky,          'Browse'),
    };

    final detail = [
      if (crop.isNotEmpty)  crop,
      if (region.isNotEmpty) region,
      if (query.isNotEmpty) '"$query"',
      if (screen.isNotEmpty) screen.replaceAll('_', ' '),
    ].join(' · ');

    return Dismissible(
      key: ValueKey(record['id']),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AgriColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AgriColors.danger),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, size: 16, color: color),
          ),
          title: Text(label,
              style: TextStyle(fontWeight: FontWeight.w600,
                  fontSize: 13, color: color)),
          subtitle: Text(detail,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(timeLabel, style: const TextStyle(fontSize: 10)),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AgriColors.danger, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onDelete,
            ),
          ]),
        ),
      ),
    );
  }
}
