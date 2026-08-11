import 'package:flutter/material.dart';

/// Bottom sheet do raio máximo de sugestões do Descobrir. Mantém estado
/// local e devolve o valor em km via `Navigator.pop(context, km)` no
/// Aplicar; Cancelar/dismiss devolvem `null` (o chamador repassa ao
/// DiscoveryCubit, que persiste e recarrega o deck).
class DiscoveryRadiusSheet extends StatefulWidget {
  const DiscoveryRadiusSheet({super.key, required this.initialRadiusKm});

  /// Limites do controle (contrato §3.5: raio configurável, padrão 50 km).
  static const int minRadiusKm = 5;
  static const int maxRadiusKm = 200;

  final int initialRadiusKm;

  @override
  State<DiscoveryRadiusSheet> createState() => _DiscoveryRadiusSheetState();
}

class _DiscoveryRadiusSheetState extends State<DiscoveryRadiusSheet> {
  /// Passo do slider (5 em 5 km — precisão maior não muda o resultado).
  static const int _stepKm = 5;

  late double _radiusKm = widget.initialRadiusKm
      .clamp(DiscoveryRadiusSheet.minRadiusKm, DiscoveryRadiusSheet.maxRadiusKm)
      .toDouble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = _radiusKm.round();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Raio de sugestões',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'Sugerir cães até $radius km',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _radiusKm,
              min: DiscoveryRadiusSheet.minRadiusKm.toDouble(),
              max: DiscoveryRadiusSheet.maxRadiusKm.toDouble(),
              divisions: (DiscoveryRadiusSheet.maxRadiusKm -
                      DiscoveryRadiusSheet.minRadiusKm) ~/
                  _stepKm,
              label: '$radius km',
              onChanged: (value) => setState(() => _radiusKm = value),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${DiscoveryRadiusSheet.minRadiusKm} km',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                Text(
                  '${DiscoveryRadiusSheet.maxRadiusKm} km',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(radius),
                      child: const Text('Aplicar'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
