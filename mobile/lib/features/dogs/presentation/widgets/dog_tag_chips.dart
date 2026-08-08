import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_enums.dart';
import 'package:flutter/material.dart';

/// Visual dos chips de tag de um cão.
///
/// - [filled]: sobre superfícies do tema (cards de lista, perfil do dono);
/// - [overlay]: sobre foto com gradiente escuro (deck do discovery).
enum DogTagChipStyle { filled, overlay }

/// Chip de tag com indicador de categoria (ícone) + rótulo — a UI nunca
/// mostra um valor solto sem sinalizar a que categoria pertence.
class DogTagChip extends StatelessWidget {
  const DogTagChip({
    super.key,
    required this.icon,
    required this.label,
    this.style = DogTagChipStyle.filled,
  });

  final IconData icon;
  final String label;
  final DogTagChipStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overlay = style == DogTagChipStyle.overlay;
    final background =
        overlay ? Colors.white24 : theme.colorScheme.secondaryContainer;
    final foreground =
        overlay ? Colors.white : theme.colorScheme.onSecondaryContainer;
    final textStyle = overlay
        ? theme.textTheme.labelMedium?.copyWith(color: foreground)
        : theme.textTheme.labelSmall?.copyWith(color: foreground);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: overlay ? 14 : 12, color: foreground),
          const SizedBox(width: 4),
          Text(label, style: textStyle),
        ],
      ),
    );
  }
}

/// Chip de idade do cão (ex.: "8 meses", "2 anos") com o bolo como
/// indicador da categoria.
class DogAgeChip extends StatelessWidget {
  const DogAgeChip({
    super.key,
    required this.dog,
    this.style = DogTagChipStyle.filled,
  });

  final DogModel dog;
  final DogTagChipStyle style;

  @override
  Widget build(BuildContext context) {
    return DogTagChip(
      icon: Icons.cake_outlined,
      label: dog.ageLongLabel,
      style: style,
    );
  }
}

/// Ícone de cada intenção simples exibida como tag.
IconData dogIntentIcon(DogIntent intent) =>
    intent == DogIntent.breeding ? Icons.favorite : Icons.pets;

/// Chips de intenção prontos para espalhar num [Wrap]/[Row]:
/// BREEDING → "Cruzamento" (coração); FRIENDSHIP → "Amizade" (pata);
/// BOTH → os DOIS chips. Mapeamento único para toda a UI.
List<Widget> dogIntentChips(
  DogIntent intent, {
  DogTagChipStyle style = DogTagChipStyle.filled,
}) {
  return [
    for (final value in intent.displayIntents)
      DogTagChip(
        icon: dogIntentIcon(value),
        label: value.labelPtBr,
        style: style,
      ),
  ];
}
