import 'package:dogmatch/features/dogs/domain/entities/dog_enums.dart';
import 'package:dogmatch/features/search/domain/entities/search_filters.dart';
import 'package:flutter/material.dart';

/// Bottom sheet de filtros da busca. Mantém estado local e devolve o
/// [SearchFilters] montado via `Navigator.pop(context, filters)` ao aplicar
/// (o chamador repassa ao SearchCubit).
class SearchFilterSheet extends StatefulWidget {
  const SearchFilterSheet({super.key, required this.initial});

  final SearchFilters initial;

  @override
  State<SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<SearchFilterSheet> {
  static const int _ageMin = 0;
  static const int _ageMax = 20;
  static const double _radiusMin = 5;
  static const double _radiusMax = 200;

  late DogSex? _sex = widget.initial.sex;
  late Set<DogSize> _sizes = {...widget.initial.sizes};
  late DogIntent? _intent = widget.initial.intent;
  late RangeValues _ageRange = RangeValues(
    (widget.initial.ageMinYears ?? _ageMin).clamp(_ageMin, _ageMax).toDouble(),
    (widget.initial.ageMaxYears ?? _ageMax).clamp(_ageMin, _ageMax).toDouble(),
  );
  late bool _filterByDistance = widget.initial.radiusKm != null;
  late double _radiusKm =
      (widget.initial.radiusKm ?? 50).clamp(_radiusMin, _radiusMax).toDouble();
  late bool _neutered = widget.initial.neutered ?? false;
  late bool _pedigree = widget.initial.pedigree ?? false;
  late SearchOrderBy? _orderBy = widget.initial.orderBy;

  String get _ageLabel {
    final start = _ageRange.start.round();
    final end = _ageRange.end.round();
    if (start == _ageMin && end == _ageMax) return 'Qualquer';
    if (end == _ageMax) return '${start}a ou mais';
    if (start == _ageMin) return 'até ${end}a';
    return '${start}a – ${end}a';
  }

  SearchFilters _buildResult() {
    final start = _ageRange.start.round();
    final end = _ageRange.end.round();
    return SearchFilters(
      q: widget.initial.q,
      sex: _sex,
      sizes: _sizes,
      intent: _intent,
      ageMinYears: start > _ageMin ? start : null,
      ageMaxYears: end < _ageMax ? end : null,
      neutered: _neutered ? true : null,
      pedigree: _pedigree ? true : null,
      radiusKm: _filterByDistance ? _radiusKm.round() : null,
      orderBy: _orderBy,
    );
  }

  void _clear() {
    setState(() {
      _sex = null;
      _sizes = {};
      _intent = null;
      _ageRange = RangeValues(_ageMin.toDouble(), _ageMax.toDouble());
      _filterByDistance = false;
      _radiusKm = 50;
      _neutered = false;
      _pedigree = false;
      _orderBy = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeCount = _buildResult().activeCount;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text('Filtros', style: theme.textTheme.titleLarge),
                  ),
                  const _SectionTitle('Sexo'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final option in <DogSex?>[null, ...DogSex.values])
                        ChoiceChip(
                          label: Text(option?.labelPtBr ?? 'Todos'),
                          selected: _sex == option,
                          onSelected: (_) => setState(() => _sex = option),
                        ),
                    ],
                  ),
                  const _SectionTitle('Porte'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final size in DogSize.values)
                        FilterChip(
                          label: Text(size.labelPtBr),
                          selected: _sizes.contains(size),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _sizes.add(size);
                            } else {
                              _sizes.remove(size);
                            }
                          }),
                        ),
                    ],
                  ),
                  const _SectionTitle('Intenção'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final option in <DogIntent?>[
                        null,
                        DogIntent.breeding,
                        DogIntent.friendship,
                      ])
                        ChoiceChip(
                          label: Text(option?.labelPtBr ?? 'Todas'),
                          selected: _intent == option,
                          onSelected: (_) => setState(() => _intent = option),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      const Expanded(child: _SectionTitle('Idade')),
                      Text(
                        _ageLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: _ageRange,
                    min: _ageMin.toDouble(),
                    max: _ageMax.toDouble(),
                    divisions: _ageMax - _ageMin,
                    labels: RangeLabels(
                      '${_ageRange.start.round()}a',
                      '${_ageRange.end.round()}a',
                    ),
                    onChanged: (values) =>
                        setState(() => _ageRange = values),
                  ),
                  const _SectionTitle('Distância'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Filtrar por distância'),
                    subtitle: Text(
                      _filterByDistance
                          ? 'Até ${_radiusKm.round()} km'
                          : 'Sem limite',
                    ),
                    value: _filterByDistance,
                    onChanged: (value) =>
                        setState(() => _filterByDistance = value),
                  ),
                  if (_filterByDistance)
                    Slider(
                      value: _radiusKm,
                      min: _radiusMin,
                      max: _radiusMax,
                      divisions: ((_radiusMax - _radiusMin) / 5).round(),
                      label: '${_radiusKm.round()} km',
                      onChanged: (value) =>
                          setState(() => _radiusKm = value),
                    ),
                  const _SectionTitle('Características'),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Castrado'),
                        selected: _neutered,
                        onSelected: (selected) =>
                            setState(() => _neutered = selected),
                      ),
                      FilterChip(
                        label: const Text('Pedigree'),
                        selected: _pedigree,
                        onSelected: (selected) =>
                            setState(() => _pedigree = selected),
                      ),
                    ],
                  ),
                  const _SectionTitle('Ordenar por'),
                  SegmentedButton<SearchOrderBy>(
                    segments: [
                      for (final option in SearchOrderBy.values)
                        ButtonSegment(
                          value: option,
                          label: Text(option.labelPtBr),
                          icon: Icon(
                            option == SearchOrderBy.distance
                                ? Icons.near_me_outlined
                                : Icons.schedule,
                          ),
                        ),
                    ],
                    selected: {?_orderBy},
                    emptySelectionAllowed: true,
                    onSelectionChanged: (selection) => setState(
                      () => _orderBy =
                          selection.isEmpty ? null : selection.first,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                TextButton(
                  onPressed: _clear,
                  child: const Text('Limpar'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_buildResult()),
                    child: Text(
                      activeCount > 0
                          ? 'Aplicar ($activeCount)'
                          : 'Aplicar',
                    ),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
