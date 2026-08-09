import 'package:cached_network_image/cached_network_image.dart';
import 'package:dogmatch/app/di/injection.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum _SelectorVariant { compact, row }

/// Troca do cão ativo ([ActiveDogCubit]), compartilhada por todas as telas
/// em que a escolha muda o que é exibido.
///
/// A troca vale para o app inteiro: o cubit é um singleton e cada tela reage
/// ao seu stream.
class ActiveDogSelector extends StatefulWidget {
  /// AppBar: avatar + nome + seta.
  const ActiveDogSelector.compact({super.key})
      : _variant = _SelectorVariant.compact,
        label = '',
        _fixedDog = null;

  /// Corpo da tela: linha rotulada (ex.: "CURTIR COMO · Thor") com "Trocar".
  const ActiveDogSelector.row({super.key, required this.label})
      : _variant = _SelectorVariant.row,
        _fixedDog = null;

  /// Somente leitura, para o chat: mostra o cão do match (que vem do próprio
  /// match, não da seleção global) sem afordância de troca — trocar aqui
  /// mudaria o contexto da conversa aberta.
  const ActiveDogSelector.readOnly({
    super.key,
    required DogModel dog,
    required this.label,
  })  : _variant = _SelectorVariant.row,
        _fixedDog = dog;

  final String label;

  final _SelectorVariant _variant;
  final DogModel? _fixedDog;

  @override
  State<ActiveDogSelector> createState() => _ActiveDogSelectorState();
}

class _ActiveDogSelectorState extends State<ActiveDogSelector> {
  ActiveDogCubit? _cubit;

  @override
  void initState() {
    super.initState();
    if (widget._fixedDog != null) return;
    final cubit = getIt<ActiveDogCubit>();
    _cubit = cubit;
    cubit.ensureLoaded();
  }

  Future<void> _openSwitcher(ActiveDogState state) async {
    final selected = await showModalBottomSheet<DogModel>(
      context: context,
      showDragHandle: true,
      builder: (_) => _DogSwitcherSheet(
        dogs: state.dogs,
        activeId: state.active?.id,
      ),
    );
    if (selected != null) _cubit?.select(selected);
  }

  Future<void> _openDogForm() async {
    await context.push('/dogs/new');
    await _cubit?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final fixedDog = widget._fixedDog;
    if (fixedDog != null) {
      return _DogRow(dog: fixedDog, label: widget.label, onSwitch: null);
    }
    return BlocBuilder<ActiveDogCubit, ActiveDogState>(
      bloc: _cubit,
      builder: (context, state) {
        final active = state.active;
        if (active == null) {
          return switch (state.status) {
            ActiveDogStatus.initial || ActiveDogStatus.loading =>
              const SizedBox.shrink(),
            ActiveDogStatus.error => _SelectorAction(
                icon: Icons.refresh,
                label: 'Tentar novamente',
                onPressed: () => _cubit?.refresh(),
              ),
            ActiveDogStatus.ready => _SelectorAction(
                icon: Icons.pets,
                label: 'Cadastre um cão',
                onPressed: _openDogForm,
              ),
          };
        }
        final onSwitch = state.canSwitch ? () => _openSwitcher(state) : null;
        return switch (widget._variant) {
          _SelectorVariant.compact => _CompactDog(dog: active, onSwitch: onSwitch),
          _SelectorVariant.row =>
            _DogRow(dog: active, label: widget.label, onSwitch: onSwitch),
        };
      },
    );
  }
}

class _CompactDog extends StatelessWidget {
  const _CompactDog({required this.dog, this.onSwitch});

  final DogModel dog;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DogAvatar(dog: dog, radius: 14),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              dog.name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
          if (onSwitch != null) const Icon(Icons.arrow_drop_down, size: 22),
        ],
      ),
    );
    if (onSwitch == null) {
      return Padding(padding: const EdgeInsets.only(right: 8), child: content);
    }
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: 'Trocar de cão',
        child: InkWell(
          onTap: onSwitch,
          borderRadius: BorderRadius.circular(999),
          child: content,
        ),
      ),
    );
  }
}

class _DogRow extends StatelessWidget {
  const _DogRow({required this.dog, required this.label, this.onSwitch});

  final DogModel dog;
  final String label;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSwitch,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              DogAvatar(dog: dog, radius: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      dog.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (onSwitch != null) ...[
                const SizedBox(width: 8),
                Text(
                  'Trocar',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
                Icon(
                  Icons.expand_more,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectorAction extends StatelessWidget {
  const _SelectorAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _DogSwitcherSheet extends StatelessWidget {
  const _DogSwitcherSheet({required this.dogs, required this.activeId});

  final List<DogModel> dogs;
  final String? activeId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Escolher cão',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Curtidas, matches e busca usam o cão escolhido.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            for (final dog in dogs)
              ListTile(
                leading: DogAvatar(dog: dog, radius: 20),
                title: Text(dog.name),
                subtitle: Text(dog.breed),
                selected: dog.id == activeId,
                trailing: dog.id == activeId
                    ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(dog),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Miniatura circular do cão (foto principal ou pata como fallback).
class DogAvatar extends StatelessWidget {
  const DogAvatar({super.key, required this.dog, this.radius = 16});

  final DogModel dog;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = dog.mainPhotoUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      backgroundImage:
          photoUrl == null ? null : CachedNetworkImageProvider(photoUrl),
      child: photoUrl == null
          ? Icon(
              Icons.pets,
              size: radius,
              color: theme.colorScheme.onPrimaryContainer,
            )
          : null,
    );
  }
}
