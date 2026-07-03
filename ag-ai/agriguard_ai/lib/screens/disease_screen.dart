import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../services/backend_service.dart';
import '../utils/app_theme.dart';

class DiseaseScreen extends StatefulWidget {
  const DiseaseScreen({super.key});

  @override
  State<DiseaseScreen> createState() => _DiseaseScreenState();
}

class _DiseaseScreenState extends State<DiseaseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _picker = ImagePicker();

  // ── Photo tab ──────────────────────────────────────────────────────────────
  String? _selectedCrop;
  File? _imageFile;
  bool _imageLoading = false;
  Map<String, dynamic>? _imageResult;
  String? _imageError;

  // ── Text tab ───────────────────────────────────────────────────────────────
  final _cropCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _symptomsCtrl = TextEditingController();
  bool _textLoading = false;
  Map<String, dynamic>? _textResult;
  String? _textError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cropCtrl.dispose();
    _regionCtrl.dispose();
    _symptomsCtrl.dispose();
    super.dispose();
  }

  // ── Image picking ──────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (xfile == null || !mounted) return;
      setState(() {
        _imageFile = File(xfile.path);
        _imageResult = null;
        _imageError = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not access camera/gallery: $e'),
          backgroundColor: AgriColors.danger,
        ),
      );
    }
  }

  Future<void> _diagnoseImage() async {
    if (_imageFile == null) return;
    setState(() {
      _imageLoading = true;
      _imageError = null;
      _imageResult = null;
    });
    try {
      final result = await context.read<BackendService>().diagnoseDiseaseImageFile(
        _imageFile!,
        statedCrop: _selectedCrop,
      );
      if (!mounted) return;
      setState(() {
        _imageResult = result;
        _imageLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _imageError = e.toString();
        _imageLoading = false;
      });
    }
  }

  // ── Text diagnosis ─────────────────────────────────────────────────────────

  Future<void> _diagnoseText() async {
    final crop = _cropCtrl.text.trim();
    final region = _regionCtrl.text.trim();
    if (crop.isEmpty || region.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('enter_crop_region')),
          backgroundColor: AgriColors.danger,
        ),
      );
      return;
    }
    setState(() {
      _textLoading = true;
      _textError = null;
      _textResult = null;
    });
    try {
      final result = await context.read<BackendService>().diagnoseDisease({
        'crop': crop,
        'region': region,
        if (_symptomsCtrl.text.trim().isNotEmpty)
          'symptoms': _symptomsCtrl.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _textResult = result;
        _textLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _textError = e.toString();
        _textLoading = false;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('disease_title')),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AgriColors.danger,
          labelColor: isDark ? Colors.white : AgriColors.danger,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(icon: Icon(Icons.camera_alt_rounded), text: 'Photo Scan'),
            Tab(icon: Icon(Icons.text_fields_rounded), text: 'Describe Symptoms'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPhotoTab(),
          _buildTextTab(),
        ],
      ),
    );
  }

  // ── Photo tab ──────────────────────────────────────────────────────────────

  Widget _buildPhotoTab() {
    final botPad = MediaQuery.viewPaddingOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, botPad + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PhotoInstructionCard(),
          const SizedBox(height: 16),
          // ── Crop selector ─────────────────────────────────────────────────
          _CropSelector(
            selected: _selectedCrop,
            onChanged: (crop) => setState(() {
              _selectedCrop = crop;
              _imageResult = null;
              _imageError = null;
            }),
          ),
          const SizedBox(height: 16),
          // ── Camera / Gallery buttons ───────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _SourceButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Take Photo',
                  color: AgriColors.forestGreen,
                  onTap: () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SourceButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Upload Photo',
                  color: AgriColors.sky,
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
          // ── Image preview ──────────────────────────────────────────────────
          if (_imageFile != null) ...[
            const SizedBox(height: 20),
            _ImagePreview(
              file: _imageFile!,
              onRemove: () => setState(() {
                _imageFile = null;
                _imageResult = null;
                _imageError = null;
                _selectedCrop = null;
              }),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (_imageLoading || _selectedCrop == null)
                    ? null
                    : _diagnoseImage,
                icon: _imageLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.biotech_rounded),
                label: Text(_imageLoading
                    ? 'Analysing…'
                    : _selectedCrop == null
                        ? 'Select a crop first'
                        : 'Diagnose $_selectedCrop'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AgriColors.danger,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
          // ── Image result ───────────────────────────────────────────────────
          if (_imageError != null) ...[
            const SizedBox(height: 20),
            _ErrorCard(message: _imageError!),
          ],
          if (_imageResult != null) ...[
            const SizedBox(height: 20),
            _ImageDiagnosisResult(result: _imageResult!),
          ],
        ],
      ),
    );
  }

  // ── Text/Symptoms tab ──────────────────────────────────────────────────────

  Widget _buildTextTab() {
    final botPad = MediaQuery.viewPaddingOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, botPad + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AgriColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AgriColors.danger.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.biotech_rounded,
                    color: AgriColors.danger, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.t('disease_help'),
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _cropCtrl,
            decoration: InputDecoration(
              labelText: context.t('disease_crop'),
              prefixIcon: const Icon(Icons.grass_rounded),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _regionCtrl,
            decoration: InputDecoration(
              labelText: context.t('disease_region'),
              prefixIcon: const Icon(Icons.map_outlined),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _symptomsCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: context.t('disease_symptoms'),
              hintText:
                  'e.g. yellowing leaves, brown spots, wilting stems…',
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 64),
                child: Icon(Icons.notes_rounded),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _textLoading ? null : _diagnoseText,
              icon: _textLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(_textLoading
                  ? 'Analysing…'
                  : context.t('disease_button')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AgriColors.danger,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          if (_textError != null) ...[
            const SizedBox(height: 20),
            _ErrorCard(message: _textError!),
          ],
          if (_textResult != null) ...[
            const SizedBox(height: 20),
            _TextDiagnosisResult(result: _textResult!),
          ],
        ],
      ),
    );
  }
}

// ── Crop selector ──────────────────────────────────────────────────────────────

class _CropSelector extends StatelessWidget {
  static const _crops = [
    ('Corn/Maize', Icons.grain_rounded),
    ('Tomato', Icons.circle_rounded),
    ('Potato', Icons.spa_rounded),
    ('Bell Pepper', Icons.local_florist_rounded),
    ('Apple', Icons.eco_rounded),
    ('Grape', Icons.scatter_plot_rounded),
    ('Strawberry', Icons.favorite_rounded),
    ('Peach', Icons.lens_rounded),
    ('Cherry', Icons.fiber_manual_record_rounded),
    ('Soybean', Icons.grass_rounded),
    ('Squash', Icons.park_rounded),
    ('Raspberry', Icons.blur_circular_rounded),
    ('Blueberry', Icons.circle_outlined),
    ('Orange', Icons.brightness_7_rounded),
  ];

  const _CropSelector({required this.selected, required this.onChanged});
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3, height: 16,
              decoration: BoxDecoration(
                color: AgriColors.forestGreen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'What crop are you growing?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '(required)',
              style: TextStyle(
                fontSize: 12,
                color: AgriColors.danger,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _crops.map((entry) {
            final (name, icon) = entry;
            final isSelected = selected == name;
            final bg = isSelected
                ? (isDark
                    ? AgriColors.forestGreen.withValues(alpha: 0.80)
                    : AgriColors.forestGreen)
                : (isDark
                    ? AgriColors.forestGreen.withValues(alpha: 0.12)
                    : AgriColors.forestGreen.withValues(alpha: 0.08));
            final fg = isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : AgriColors.forestGreen);

            return GestureDetector(
              onTap: () => onChanged(isSelected ? null : name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AgriColors.forestGreen
                        : AgriColors.forestGreen.withValues(alpha: 0.30),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: fg),
                    const SizedBox(width: 5),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: fg,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.check_rounded, size: 13, color: fg),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (selected != null) ...[
          const SizedBox(height: 8),
          Text(
            'Selected: $selected — tap again to deselect',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : AgriColors.forestGreen.withValues(alpha: 0.70),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Instruction card ───────────────────────────────────────────────────────────

class _PhotoInstructionCard extends StatelessWidget {
  static const _supportedCrops = [
    'Corn/Maize', 'Tomato', 'Potato', 'Pepper', 'Apple',
    'Grape', 'Strawberry', 'Peach', 'Cherry', 'Soybean',
    'Squash', 'Raspberry', 'Blueberry', 'Orange',
  ];

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AgriColors.forestGreen.withValues(alpha: 0.15),
                AgriColors.leafGreen.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AgriColors.forestGreen.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AgriColors.forestGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: AgriColors.forestGreen, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Photo Disease Scan',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Take or upload a clear, close-up photo of the affected leaf. '
                      'Ensure good lighting for best results.',
                      style: TextStyle(
                        fontSize: 12,
                        color: onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // ── Supported crops notice ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AgriColors.gold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AgriColors.gold.withValues(alpha: 0.30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AgriColors.gold, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Supported crops only',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _supportedCrops
                    .map(
                      (c) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AgriColors.forestGreen
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          c,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AgriColors.forestGreen,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Camera / Gallery source button ─────────────────────────────────────────────

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? color.withValues(alpha: 0.80)
        : color.withValues(alpha: 0.10);
    final fg = isDark ? Colors.white : color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Icon(icon, color: fg, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                  color: fg, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Image preview ──────────────────────────────────────────────────────────────

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.file, required this.onRemove});
  final File file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            file,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Image diagnosis result ─────────────────────────────────────────────────────

class _ImageDiagnosisResult extends StatelessWidget {
  const _ImageDiagnosisResult({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final label = result['disease_label']?.toString() ?? '';
    final diseaseName =
        result['disease_name']?.toString() ?? _cleanLabel(label);
    final confidence = (result['confidence_score'] as num?)?.toDouble() ?? 0;
    final confidenceLevel = result['confidence_level']?.toString() ?? 'high';
    final description = result['description']?.toString() ?? '';
    final prevention = result['prevention']?.toString() ?? '';
    final rawTreatment = result['treatment'];
    final treatmentSteps = _toStringList(rawTreatment);
    final scopeWarning = result['scope_warning']?.toString();
    final alternatives =
        (result['alternatives'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    // ── Plant identification fields ──────────────────────────────────────────
    final plantIdentified = result['plant_identified'] as bool? ?? true;
    final identifiedCrop = result['identified_crop']?.toString() ?? '';
    final cropConfidence =
        (result['identified_crop_confidence'] as num?)?.toDouble() ?? 0;
    final cropCandidates =
        (result['crop_candidates'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final cropMismatch = result['crop_mismatch'] as bool? ?? false;
    final mismatchMessage = result['mismatch_message']?.toString();
    final statedCrop = result['stated_crop']?.toString();

    final isHealthy = label.toLowerCase().contains('healthy') ||
        diseaseName.toLowerCase().contains('no disease');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    final headerColor =
        isHealthy ? AgriColors.forestGreen : AgriColors.danger;
    final confBadgeColor = confidenceLevel == 'high'
        ? AgriColors.forestGreen
        : confidenceLevel == 'medium'
            ? AgriColors.gold
            : AgriColors.danger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ════════════════════════════════════════════════════════════════════
        // STEP 1 — Plant identification result
        // ════════════════════════════════════════════════════════════════════
        _StepLabel(label: 'Step 1 — Plant Identification', isDark: isDark),
        const SizedBox(height: 8),
        plantIdentified
            ? _PlantIdentifiedCard(
                cropName: identifiedCrop,
                confidence: cropConfidence,
                isDark: isDark,
                statedCrop: statedCrop,
              )
            : _PlantNotRecognizedCard(
                bestGuess: identifiedCrop,
                bestGuessConf: cropConfidence,
                candidates: cropCandidates,
                isDark: isDark,
                onSurface: onSurface,
                onSurfaceVariant: onSurfaceVariant,
              ),

        // ── Crop mismatch warning ────────────────────────────────────────────
        if (cropMismatch && mismatchMessage != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AgriColors.danger.withValues(alpha: isDark ? 0.20 : 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AgriColors.danger.withValues(alpha: 0.45)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.swap_horiz_rounded,
                    color: AgriColors.danger, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Crop Mismatch',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AgriColors.danger,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mismatchMessage,
                        style: TextStyle(
                            fontSize: 12, height: 1.45, color: onSurface),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // If the plant wasn't identified stop here — no disease diagnosis
        if (!plantIdentified) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AgriColors.gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AgriColors.gold.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates_rounded,
                    color: AgriColors.gold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'For accurate results, take a clear close-up photo of the '
                    'leaf of a supported crop in good lighting.',
                    style: TextStyle(fontSize: 13, height: 1.45, color: onSurface),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (plantIdentified) ...[
          const SizedBox(height: 16),
          // ════════════════════════════════════════════════════════════════
          // STEP 2 — Disease diagnosis
          // ════════════════════════════════════════════════════════════════
          _StepLabel(label: 'Step 2 — Disease Diagnosis', isDark: isDark),
          const SizedBox(height: 8),

          // Scope / quality warning
          if (scopeWarning != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AgriColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AgriColors.gold.withValues(alpha: 0.40)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AgriColors.gold, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      scopeWarning,
                      style: TextStyle(
                          fontSize: 12, height: 1.45, color: onSurface),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Disease header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  headerColor,
                  headerColor.withValues(alpha: 0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isHealthy
                          ? Icons.check_circle_rounded
                          : Icons.bug_report_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        diseaseName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Chip(
                        label: '${confidence.toStringAsFixed(1)}% confidence'),
                    _Chip(
                      label: confidenceLevel.toUpperCase(),
                      bgAlpha: 0.30,
                      borderColor: Colors.white.withValues(alpha: 0.40),
                      extraBg: confBadgeColor,
                    ),
                    if (result['crop'] != null)
                      _Chip(label: result['crop'].toString(), bgAlpha: 0.20),
                  ],
                ),
              ],
            ),
          ),

          // Other possibilities
          if (alternatives.length > 1) ...[
            const SizedBox(height: 10),
            _AdvisorySection(
              icon: Icons.compare_arrows_rounded,
              title: 'Other Possibilities',
              color: isDark ? AgriColors.sky.withValues(alpha: 0.80) : AgriColors.sky,
              isDark: isDark,
              child: Column(
                children: alternatives.skip(1).map((alt) {
                  final altConf = (alt['confidence'] as num?)?.toDouble() ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            alt['display']?.toString() ??
                                alt['label']?.toString() ?? '',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AgriColors.sky
                                .withValues(alpha: isDark ? 0.60 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${altConf.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AgriColors.sky,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Description
          if (description.isNotEmpty) ...[
            _AdvisorySection(
              icon: Icons.info_outline_rounded,
              title: 'About This Disease',
              color: isDark ? AgriColors.sky.withValues(alpha: 0.80) : AgriColors.sky,
              isDark: isDark,
              child: Text(
                description,
                style: TextStyle(fontSize: 14, height: 1.5, color: onSurface),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Treatment
          if (treatmentSteps.isNotEmpty) ...[
            _AdvisorySection(
              icon: Icons.medical_services_rounded,
              title: 'Treatment',
              color: isDark
                  ? AgriColors.danger.withValues(alpha: 0.80)
                  : AgriColors.danger,
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < treatmentSteps.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            margin: const EdgeInsets.only(top: 1, right: 10),
                            decoration: BoxDecoration(
                              color: AgriColors.danger
                                  .withValues(alpha: isDark ? 0.60 : 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : AgriColors.danger,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              treatmentSteps[i],
                              style: TextStyle(
                                  fontSize: 13, height: 1.45, color: onSurface),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Prevention
          if (prevention.isNotEmpty)
            _AdvisorySection(
              icon: Icons.shield_outlined,
              title: 'Prevention',
              color: isDark
                  ? AgriColors.forestGreen.withValues(alpha: 0.80)
                  : AgriColors.forestGreen,
              isDark: isDark,
              child: Text(
                prevention,
                style: TextStyle(fontSize: 13, height: 1.5, color: onSurface),
              ),
            ),
        ],
      ],
    );
  }

  List<String> _toStringList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String) return [raw];
    return [];
  }

  String _cleanLabel(String label) {
    return label.replaceAll('___', ' — ').replaceAll('_', ' ');
  }
}

// ── Text diagnosis result ──────────────────────────────────────────────────────

class _TextDiagnosisResult extends StatelessWidget {
  const _TextDiagnosisResult({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final diagnosis = result['diagnosis'] as Map<String, dynamic>? ?? result;
    final advisory = result['advisory'] as Map<String, dynamic>? ?? {};
    final diseaseName =
        diagnosis['disease_name']?.toString() ?? 'Assessment Complete';
    final risk = (diagnosis['risk'] as num?)?.toDouble() ?? 0;
    final evidence = diagnosis['evidence'] as List<dynamic>? ?? [];
    final tips = advisory['tips'] as List<dynamic>? ?? [];
    final summary = advisory['summary']?.toString() ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final riskPct = (risk * 100).round();
    final riskColor = risk >= 0.6
        ? AgriColors.danger
        : risk >= 0.3
            ? AgriColors.gold
            : AgriColors.forestGreen;
    final riskLabel =
        risk >= 0.6 ? 'High Risk' : risk >= 0.3 ? 'Moderate' : 'Low Risk';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Risk header ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [riskColor, riskColor.withValues(alpha: 0.75)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                child: Text(
                  '$riskPct%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diseaseName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      riskLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (evidence.isNotEmpty) ...[
          const SizedBox(height: 10),
          _AdvisorySection(
            icon: Icons.list_alt_rounded,
            title: 'Evidence',
            color: isDark
                ? AgriColors.sky.withValues(alpha: 0.80)
                : AgriColors.sky,
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: evidence
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.circle,
                                size: 6, color: AgriColors.sky),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(e.toString(),
                                  style: const TextStyle(fontSize: 13)),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
        if (summary.isNotEmpty || tips.isNotEmpty) ...[
          const SizedBox(height: 10),
          _AdvisorySection(
            icon: Icons.tips_and_updates_rounded,
            title: 'Farm Advisory',
            color: isDark
                ? AgriColors.forestGreen.withValues(alpha: 0.80)
                : AgriColors.forestGreen,
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (summary.isNotEmpty) ...[
                  Text(summary,
                      style:
                          const TextStyle(fontSize: 13, height: 1.5)),
                  if (tips.isNotEmpty) const SizedBox(height: 10),
                ],
                for (final tip in tips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 16, color: AgriColors.forestGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(tip.toString(),
                              style: const TextStyle(
                                  fontSize: 13, height: 1.4)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Shared advisory section card ───────────────────────────────────────────────

// ── Reusable white chip on gradient background ─────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    this.bgAlpha = 0.25,
    this.borderColor,
    this.extraBg,
  });
  final String label;
  final double bgAlpha;
  final Color? borderColor;
  final Color? extraBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (extraBg ?? Colors.white).withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(20),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Step section label ─────────────────────────────────────────────────────────

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: AgriColors.forestGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : AgriColors.forestGreen,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ── Plant identified card (green) ──────────────────────────────────────────────

class _PlantIdentifiedCard extends StatelessWidget {
  const _PlantIdentifiedCard({
    required this.cropName,
    required this.confidence,
    required this.isDark,
    this.statedCrop,
  });
  final String cropName;
  final double confidence;
  final bool isDark;
  final String? statedCrop;

  @override
  Widget build(BuildContext context) {
    // Determine if stated crop matches identified crop
    final hasStated = statedCrop != null && statedCrop!.isNotEmpty;
    final matches = hasStated &&
        (statedCrop!.toLowerCase().contains(cropName.toLowerCase()) ||
            cropName.toLowerCase().contains(statedCrop!.toLowerCase()));
    final mismatch = hasStated && !matches;

    // Green if match/no stated, orange if mismatch
    final gradientColors = mismatch
        ? [AgriColors.gold, AgriColors.gold.withValues(alpha: 0.75)]
        : [AgriColors.forestGreen, AgriColors.leafGreen];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              mismatch ? Icons.warning_amber_rounded : Icons.eco_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mismatch ? 'Detected (not your crop)' : 'Plant Identified',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  cropName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (hasStated && matches) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: const [
                      Icon(Icons.check_circle_rounded,
                          color: Colors.white70, size: 13),
                      SizedBox(width: 4),
                      Text(
                        'Matches your selection',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${confidence.toStringAsFixed(0)}%',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Plant not recognized card (red/amber) ─────────────────────────────────────

class _PlantNotRecognizedCard extends StatelessWidget {
  static const _supportedCrops = [
    'Corn/Maize', 'Tomato', 'Potato', 'Pepper', 'Apple',
    'Grape', 'Strawberry', 'Peach', 'Cherry', 'Soybean',
    'Squash', 'Raspberry', 'Blueberry', 'Orange',
  ];

  const _PlantNotRecognizedCard({
    required this.bestGuess,
    required this.bestGuessConf,
    required this.candidates,
    required this.isDark,
    required this.onSurface,
    required this.onSurfaceVariant,
  });
  final String bestGuess;
  final double bestGuessConf;
  final List<Map<String, dynamic>> candidates;
  final bool isDark;
  final Color onSurface;
  final Color onSurfaceVariant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AgriColors.danger.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AgriColors.danger.withValues(alpha: 0.40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline_rounded,
                  color: AgriColors.danger, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Plant Not Recognized',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            bestGuess.isNotEmpty
                ? 'Closest match: $bestGuess (${bestGuessConf.toStringAsFixed(0)}% — too low to be reliable). '
                    'This model only recognises specific crops listed below.'
                : 'The image does not match any of the supported crops.',
            style: TextStyle(
                fontSize: 12, height: 1.45, color: onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Text(
            'Supported crops:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _supportedCrops
                .map(
                  (c) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AgriColors.forestGreen
                          .withValues(alpha: isDark ? 0.30 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      c,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.white
                            : AgriColors.forestGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Advisory section card ──────────────────────────────────────────────────────

class _AdvisorySection extends StatelessWidget {
  const _AdvisorySection({
    required this.icon,
    required this.title,
    required this.color,
    required this.isDark,
    required this.child,
  });
  final IconData icon;
  final String title;
  final Color color;
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final headerBg =
        isDark ? color.withValues(alpha: 0.80) : color.withValues(alpha: 0.12);
    final headerIcon = isDark ? Colors.white : color;
    final headerText = isDark ? Colors.white : color;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: headerBg,
            child: Row(
              children: [
                Icon(icon, size: 18, color: headerIcon),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: headerText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Error card ─────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AgriColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AgriColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AgriColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
