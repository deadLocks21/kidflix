import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/update_profile_included_lower_ages.usecase.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/pages/profile_management/widgets/age_category_picker.widget.dart';

/// Settings sub-page where the active profile picks which strictly-lower
/// age categories it wants to see on the homepage in addition to its own.
///
/// Persisted server-side via `PATCH /profiles/{id}` (auto-édition) — see
/// `AGE_INCLUSION_FEATURE.md`.
class IncludedLowerAgesEditPage extends ConsumerStatefulWidget {
  const IncludedLowerAgesEditPage({super.key});

  @override
  ConsumerState<IncludedLowerAgesEditPage> createState() =>
      _IncludedLowerAgesEditPageState();
}

class _IncludedLowerAgesEditPageState
    extends ConsumerState<IncludedLowerAgesEditPage> {
  Set<AgeCategory>? _selected;
  bool _submitting = false;

  void _ensurePrefilled(Profile profile) {
    _selected ??= profile.includedLowerAgeCategories.toSet();
  }

  Future<void> _submit(Profile profile) async {
    setState(() => _submitting = true);
    final controller = ref.read(sessionControllerProvider.notifier);
    final ordered = AgeCategory.values
        .where((c) => _selected!.contains(c))
        .toList(growable: false);
    final result = await controller.updateProfileIncludedLowerAges(
      profileId: profile.id,
      categories: ordered,
    );
    if (!mounted) return;
    switch (result) {
      case UpdateProfileIncludedLowerAgesSuccess():
        context.pop();
      case UpdateProfileIncludedLowerAgesUnknownProfile():
        _showSnack('Profil introuvable');
        setState(() => _submitting = false);
      case UpdateProfileIncludedLowerAgesInvalidState():
        _showSnack('État invalide');
        setState(() => _submitting = false);
      case UpdateProfileIncludedLowerAgesInvalidCategories():
        _showSnack('Sélection invalide');
        setState(() => _submitting = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(
      sessionControllerProvider.select(
        (s) => s is ProfileSelected ? s.profile : null,
      ),
    );
    if (profile == null) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }
    _ensurePrefilled(profile);

    final lowerCategories = AgeCategory.values
        .where((c) => c.index < profile.ageCategory.index)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Tranches d\'âge à afficher')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: lowerCategories.isEmpty
                ? const _EmptyState()
                : _Body(
                    ownLabel: AgeCategoryPicker.labelFor(profile.ageCategory),
                    lowerCategories: lowerCategories,
                    selected: _selected!,
                    submitting: _submitting,
                    onToggle: (c, on) {
                      if (_submitting) return;
                      setState(() {
                        if (on) {
                          _selected!.add(c);
                        } else {
                          _selected!.remove(c);
                        }
                      });
                    },
                    onSubmit: () => _submit(profile),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final String ownLabel;
  final List<AgeCategory> lowerCategories;
  final Set<AgeCategory> selected;
  final bool submitting;
  final void Function(AgeCategory, bool) onToggle;
  final VoidCallback onSubmit;

  const _Body({
    required this.ownLabel,
    required this.lowerCategories,
    required this.selected,
    required this.submitting,
    required this.onToggle,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'En plus des contenus « $ownLabel », tu peux ajouter les '
            'tranches d\'âge inférieures que tu souhaites voir sur ta home.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final c in lowerCategories)
                  CheckboxListTile(
                    title: Text(AgeCategoryPicker.labelFor(c)),
                    value: selected.contains(c),
                    onChanged: submitting
                        ? null
                        : (v) => onToggle(c, v ?? false),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: submitting ? null : onSubmit,
            child: submitting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Aucune tranche d\'âge inférieure n\'est disponible pour ton profil.',
        textAlign: TextAlign.center,
      ),
    );
  }
}
