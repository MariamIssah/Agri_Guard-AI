import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../services/user_session.dart';
import '../utils/app_theme.dart';
import 'login_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loadingStats = true;
  Map<String, int> _stats = {};
  String? _statsError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() { _loadingStats = true; _statsError = null; });
    try {
      final res = await context.read<BackendService>().adminStats();
      final raw = (res['stats'] as Map<String, dynamic>? ?? {});
      if (mounted) setState(() => _stats = raw.map((k, v) => MapEntry(k, (v as num).toInt())));
    } catch (e) {
      if (mounted) setState(() => _statsError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _triggerRetrain() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retrain Model?'),
        content: const Text(
          'This will merge all farmer submissions with historical data and '
          'retrain the yield prediction model. It may take a few minutes.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retrain'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<BackendService>().triggerRetrain();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Retraining started successfully.'),
            backgroundColor: AgriColors.forestGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Retrain failed: $e'), backgroundColor: AgriColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabColor = isDark ? AgriColors.mintGreen : AgriColors.forestGreen;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.model_training_rounded),
            tooltip: 'Retrain Model',
            onPressed: _triggerRetrain,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () async {
              await context.read<AuthService>().logout();
              if (!mounted) return;
              context.read<UserSession>().clear();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: tabColor,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: tabColor,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Users'),
            Tab(text: 'Submissions'),
            Tab(text: 'Buyer Activity'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _OverviewTab(
            loading: _loadingStats,
            stats: _stats,
            error: _statsError,
            onRetry: _loadStats,
            onRetrain: _triggerRetrain,
          ),
          _UsersTab(),
          _SubmissionsTab(),
          _BuyerActivityTab(),
        ],
      ),
    );
  }
}

// ── Overview tab ───────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.loading,
    required this.stats,
    required this.error,
    required this.onRetry,
    required this.onRetrain,
  });
  final bool loading;
  final Map<String, int> stats;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onRetrain;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: AgriColors.danger),
          const SizedBox(height: 12),
          Text(error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
        ]),
      );
    }

    final botPad = MediaQuery.viewPaddingOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, botPad + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Platform Statistics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),

          _StatsGrid(stats: stats),

          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetrain,
            icon: const Icon(Icons.model_training_rounded),
            label: const Text('Retrain Yield Prediction Model'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AgriColors.forestGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Uses all ${stats['total_submissions'] ?? 0} harvest submissions + historical data.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final Map<String, int> stats;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCard('Total Users',    stats['total_users'] ?? 0,    Icons.people_rounded,      AgriColors.forestGreen),
      _StatCard('Farmers',        stats['total_farmers'] ?? 0,  Icons.agriculture_rounded, AgriColors.leafGreen),
      _StatCard('Buyers',         stats['total_buyers'] ?? 0,   Icons.storefront_rounded,  AgriColors.sky),
      _StatCard('Deleted Users',  stats['deleted_users'] ?? 0,  Icons.person_off_rounded,  AgriColors.danger),
      _StatCard('Submissions',    stats['total_submissions'] ?? 0, Icons.assignment_rounded, AgriColors.gold),
      _StatCard('Hidden Records', stats['hidden_submissions'] ?? 0, Icons.visibility_off_rounded, Colors.grey),
      _StatCard('Diary Entries',  stats['total_diary_entries'] ?? 0, Icons.book_rounded,   AgriColors.leafGreen),
      _StatCard('Today\'s Logs',  stats['diary_entries_today'] ?? 0, Icons.today_rounded,  AgriColors.sky),
      _StatCard('Active Farmers', stats['active_farmers'] ?? 0, Icons.person_rounded,      AgriColors.forestGreen),
      _StatCard('Unique Crops',   stats['unique_crops'] ?? 0,   Icons.grass_rounded,       AgriColors.leafGreen),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: cards,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, this.icon, this.color);
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(label,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 6),
            Text(value.toString(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Users tab ──────────────────────────────────────────────────────────────────

class _UsersTab extends StatefulWidget {
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _users = [];
  bool _showDeleted = true;
  String _search = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await context.read<BackendService>().adminUsers(includeDeleted: _showDeleted);
      final list = (res['users'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) setState(() => _users = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _users.where((u) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return (u['name'] ?? '').toString().toLowerCase().contains(q) ||
             (u['email'] ?? '').toString().toLowerCase().contains(q) ||
             (u['region'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    final botPad = MediaQuery.viewPaddingOf(context).bottom;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search by name, email, region…',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Deleted'),
              selected: _showDeleted,
              onSelected: (v) { setState(() => _showDeleted = v); _load(); },
            ),
          ]),
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(child: Center(child: Text(_error!)))
        else
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(12, 0, 12, botPad + 12),
              itemCount: filtered.length,
              itemBuilder: (_, i) => _UserTile(user: filtered[i]),
            ),
          ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final isDeleted = user['hidden'] == true;
    final role = user['role']?.toString() ?? 'farmer';
    final roleColor = role == 'buyer' ? AgriColors.sky : AgriColors.forestGreen;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: roleColor.withValues(alpha: 0.15),
          child: Icon(
            role == 'buyer' ? Icons.storefront_rounded : Icons.person_rounded,
            color: roleColor, size: 20,
          ),
        ),
        title: Text(
          user['name']?.toString() ?? '',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: isDeleted ? TextDecoration.lineThrough : null,
            color: isDeleted ? Theme.of(context).colorScheme.onSurfaceVariant : null,
          ),
        ),
        subtitle: Text(
          '${user['email']} · ${user['region'] ?? 'No region'}',
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(role, style: TextStyle(fontSize: 11, color: roleColor,
                  fontWeight: FontWeight.w600)),
            ),
            if (isDeleted) ...[
              const SizedBox(height: 2),
              const Text('Deleted', style: TextStyle(fontSize: 10, color: AgriColors.danger)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Submissions tab ────────────────────────────────────────────────────────────

class _SubmissionsTab extends StatefulWidget {
  @override
  State<_SubmissionsTab> createState() => _SubmissionsTabState();
}

class _SubmissionsTabState extends State<_SubmissionsTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];
  bool _showHidden = true;
  String _search = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await context.read<BackendService>().adminSubmissions(includeHidden: _showHidden);
      final list = (res['submissions'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) setState(() => _rows = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _rows.where((r) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return (r['crop'] ?? '').toString().toLowerCase().contains(q) ||
             (r['region'] ?? '').toString().toLowerCase().contains(q) ||
             (r['farmer_id'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    final botPad = MediaQuery.viewPaddingOf(context).bottom;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search by crop, region, farmer ID…',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Deleted'),
              selected: _showHidden,
              onSelected: (v) { setState(() => _showHidden = v); _load(); },
            ),
          ]),
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(child: Center(child: Text(_error!)))
        else
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(12, 0, 12, botPad + 12),
              itemCount: filtered.length,
              itemBuilder: (_, i) => _SubmissionTile(record: filtered[i]),
            ),
          ),
      ],
    );
  }
}

// ── Buyer Activity tab ────────────────────────────────────────────────────────

class _BuyerActivityTab extends StatefulWidget {
  @override
  State<_BuyerActivityTab> createState() => _BuyerActivityTabState();
}

class _BuyerActivityTabState extends State<_BuyerActivityTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _stats = {};
  String _filter = 'all'; // all | search | select | browse
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await context.read<BackendService>().adminBuyerActivity();
      final list = (res['activity'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final stats = Map<String, dynamic>.from(
          res['stats'] as Map<String, dynamic>? ?? {});
      if (mounted) setState(() { _rows = list; _stats = stats; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'all'
        ? _rows
        : _rows.where((r) => r['action'] == _filter).toList();

    final botPad = MediaQuery.viewPaddingOf(context).bottom;
    return Column(
      children: [
        // ── Stats strip ──────────────────────────────────────────────────────
        if (_stats.isNotEmpty)
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              _MiniStat('Buyers',   _stats['unique_buyers']?.toString() ?? '0', AgriColors.sky),
              _MiniStat('Searches', _stats['total_searches']?.toString() ?? '0', AgriColors.gold),
              _MiniStat('Selects',  _stats['total_selects']?.toString() ?? '0', AgriColors.forestGreen),
              _MiniStat('Today',    _stats['actions_today']?.toString() ?? '0', AgriColors.leafGreen),
            ]),
          ),

        // ── Top interest ─────────────────────────────────────────────────────
        if (_stats['top_crop'] != null || _stats['top_region'] != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              if (_stats['top_crop'] != null)
                Chip(
                  avatar: const Icon(Icons.grass_rounded, size: 16),
                  label: Text('Top: ${_stats['top_crop']}'),
                  backgroundColor: AgriColors.forestGreen.withValues(alpha: 0.1),
                ),
              const SizedBox(width: 8),
              if (_stats['top_region'] != null)
                Chip(
                  avatar: const Icon(Icons.map_outlined, size: 16),
                  label: Text('Top: ${_stats['top_region']}'),
                  backgroundColor: AgriColors.sky.withValues(alpha: 0.1),
                ),
            ]),
          ),

        // ── Filter row ───────────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
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
            IconButton(icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: _load),
          ]),
        ),

        const SizedBox(height: 4),

        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(child: Center(child: Text(_error!)))
        else if (filtered.isEmpty)
          const Expanded(child: Center(child: Text('No activity logged yet.')))
        else
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(12, 0, 12, botPad + 12),
              itemCount: filtered.length,
              itemBuilder: (_, i) => _ActivityTile(record: filtered[i]),
            ),
          ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value, this.color);
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w700,
            fontSize: 18, color: color)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.record});
  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final action  = record['action']?.toString() ?? '';
    final screen  = record['screen']?.toString() ?? '';
    final crop    = record['crop']?.toString() ?? '';
    final region  = record['region']?.toString() ?? '';
    final query   = record['query']?.toString() ?? '';
    final buyerId = record['buyer_id']?.toString() ?? '';
    final loggedAt = record['logged_at']?.toString() ?? '';
    final timeLabel = loggedAt.length >= 19 ? loggedAt.substring(0, 19).replaceFirst('T', ' ') : loggedAt;

    final (icon, color) = switch (action) {
      'search' => (Icons.search_rounded,    AgriColors.gold),
      'select' => (Icons.touch_app_rounded, AgriColors.forestGreen),
      _        => (Icons.visibility_outlined, AgriColors.sky),
    };

    final subtitle = [
      if (crop.isNotEmpty) crop,
      if (region.isNotEmpty) region,
      if (query.isNotEmpty) '"$query"',
      screen,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, size: 16, color: color),
        ),
        title: Text(action.toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: color)),
        subtitle: Text(subtitle, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(timeLabel, style: const TextStyle(fontSize: 10)),
            Text(buyerId.length > 15 ? '${buyerId.substring(0, 15)}…' : buyerId,
                style: const TextStyle(fontSize: 10,
                    color: AgriColors.forestGreen)),
          ],
        ),
      ),
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  const _SubmissionTile({required this.record});
  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final isHidden = record['hidden'] == true;
    final crop = record['crop']?.toString() ?? '';
    final region = record['region']?.toString() ?? '';
    final yieldKg = (record['actual_yield_kg'] as num?)?.toStringAsFixed(0) ?? '0';
    final phone = record['phone']?.toString() ?? '';
    final submittedAt = record['submitted_at']?.toString() ?? '';
    final dateLabel = submittedAt.length >= 10 ? submittedAt.substring(0, 10) : submittedAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AgriColors.leafGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.agriculture_rounded, color: AgriColors.leafGreen, size: 20),
        ),
        title: Text(
          '$crop · $region',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: isHidden ? TextDecoration.lineThrough : null,
            color: isHidden ? Theme.of(context).colorScheme.onSurfaceVariant : null,
          ),
        ),
        subtitle: Text(
          '${yieldKg} kg · ${phone.isNotEmpty ? phone : "No phone"} · $dateLabel',
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isHidden
            ? const Icon(Icons.visibility_off_rounded, color: AgriColors.danger, size: 18)
            : const Icon(Icons.check_circle_outline_rounded,
                color: AgriColors.forestGreen, size: 18),
      ),
    );
  }
}
