import 'package:flutter/material.dart';
import 'package:kidflix/core/domain/model/profile.dart';

/// Dropdown liant une [AgeCategory] à son libellé FR.
class AgeCategoryPicker extends StatelessWidget {
  final AgeCategory value;
  final ValueChanged<AgeCategory> onChanged;

  const AgeCategoryPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static String labelFor(AgeCategory category) => switch (category) {
    AgeCategory.bebe => 'Bébé',
    AgeCategory.enfant => 'Enfant',
    AgeCategory.ado => 'Ado',
    AgeCategory.jeuneAdulte => 'Jeune adulte',
    AgeCategory.adulte => 'Adulte',
  };

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<AgeCategory>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Catégorie d\'âge',
        border: OutlineInputBorder(),
      ),
      items: AgeCategory.values
          .map(
            (c) => DropdownMenuItem(value: c, child: Text(labelFor(c))),
          )
          .toList(growable: false),
      onChanged: (c) {
        if (c != null) onChanged(c);
      },
    );
  }
}
