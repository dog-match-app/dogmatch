import 'package:cached_network_image/cached_network_image.dart';
import 'package:dogmatch/app/di/injection.dart';
import 'package:dogmatch/core/network/file_uploader.dart';
import 'package:dogmatch/core/utils/date_input.dart';
import 'package:dogmatch/core/widgets/app_text_field.dart';
import 'package:dogmatch/core/widgets/empty_state.dart';
import 'package:dogmatch/core/widgets/loading_indicator.dart';
import 'package:dogmatch/core/widgets/primary_button.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/data/models/dog_social_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_enums.dart';
import 'package:dogmatch/features/dogs/presentation/cubit/my_dogs_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// Criação (`/dogs/new`) e edição (`/dogs/:id/edit`) de um cão.
///
/// Após criar, o formulário permanece aberto em modo edição para permitir
/// adicionar fotos imediatamente.
class DogFormPage extends StatelessWidget {
  const DogFormPage({super.key, this.dogId, this.initialDog});

  final String? dogId;
  final DogModel? initialDog;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<MyDogsCubit>();
        if (dogId != null) {
          cubit.loadForEdit(dogId!, initial: initialDog);
        }
        return cubit;
      },
      child: _DogFormView(dogId: dogId),
    );
  }
}

class _DogFormView extends StatefulWidget {
  const _DogFormView({required this.dogId});

  final String? dogId;

  bool get isCreating => dogId == null;

  @override
  State<_DogFormView> createState() => _DogFormViewState();
}

class _DogFormViewState extends State<_DogFormView> {
  static const int _maxPhotos = 6;

  /// Ano mínimo aceito para a data de nascimento.
  static const int _minBirthYear = 1995;

  final _formKey = GlobalKey<FormState>();

  /// Keys dos campos COM validator, na ordem visual do formulário — usadas
  /// para rolar até o primeiro erro após uma tentativa de salvar.
  final _nameFieldKey = GlobalKey<FormFieldState<String>>();
  final _breedFieldKey = GlobalKey<FormFieldState<String>>();
  final _birthDateFieldKey = GlobalKey<FormFieldState<String>>();

  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _bioController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _instagramController = TextEditingController();
  final _pinterestController = TextEditingController();
  final _telegramController = TextEditingController();
  final _birthDateFocusNode = FocusNode();
  final _imagePicker = ImagePicker();

  /// Ativado na primeira tentativa de salvar: os campos passam a revalidar
  /// a cada interação — corrigir um erro o faz sumir sem novo Salvar.
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  DogSex _sex = DogSex.male;
  DogSize _size = DogSize.medium;
  DogIntent _intent = DogIntent.both;
  bool _neutered = false;
  bool _pedigree = false;
  bool _prefilled = false;

  /// O cão vindo via `extra` é emitido de forma síncrona dentro do `create`
  /// do BlocProvider — antes de o BlocConsumer assinar o stream —, então o
  /// listener nunca vê esse estado. O preenchimento inicial precisa ler o
  /// estado atual aqui; o listener cobre apenas o fallback (`GET /dogs/:id`).
  @override
  void initState() {
    super.initState();
    final editingDog = context.read<MyDogsCubit>().state.editingDog;
    if (editingDog != null) _prefill(editingDog);
    _birthDateFocusNode.addListener(_onBirthDateFocusChange);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _birthDateController.dispose();
    _bioController.dispose();
    _whatsappController.dispose();
    _instagramController.dispose();
    _pinterestController.dispose();
    _telegramController.dispose();
    _birthDateFocusNode.dispose();
    super.dispose();
  }

  /// A data revalida também ao PERDER o foco (além de a cada dígito, via
  /// autovalidate) — nunca sobra erro velho depois de corrigir o campo.
  void _onBirthDateFocusChange() {
    if (!_birthDateFocusNode.hasFocus &&
        _autovalidateMode != AutovalidateMode.disabled) {
      _birthDateFieldKey.currentState?.validate();
    }
  }

  void _prefill(DogModel dog) {
    if (_prefilled) return;
    _prefilled = true;
    _nameController.text = dog.name;
    _breedController.text = dog.breed;
    _birthDateController.text = formatBrDate(dog.birthDate);
    _bioController.text = dog.bio ?? '';
    _whatsappController.text = dog.social?.whatsapp ?? '';
    _instagramController.text = dog.social?.instagram ?? '';
    _pinterestController.text = dog.social?.pinterest ?? '';
    _telegramController.text = dog.social?.telegram ?? '';
    _sex = dog.sex;
    _size = dog.size;
    _intent = dog.intent;
    _neutered = dog.neutered;
    _pedigree = dog.pedigree;
  }

  /// Calendário como atalho: lê/escreve no MESMO controller do campo de
  /// texto (fonte única da data).
  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(_minBirthYear);
    final lastDate = DateTime(now.year, now.month, now.day);
    var initialDate = tryParseBrDate(_birthDateController.text) ??
        DateTime(now.year - 2, now.month, now.day);
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Data de nascimento',
    );
    if (picked == null) return;
    final formatted = formatBrDate(picked);
    _birthDateController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String? _validateBirthDate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Informe a data de nascimento.';
    final date = tryParseBrDate(text);
    if (date == null) return 'Data inválida';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (date.isAfter(today)) return 'A data não pode ser no futuro';
    if (date.year < _minBirthYear) return 'Confira o ano';
    return null;
  }

  /// Objeto `social` completo do form: campo vazio vira `null` (no PATCH,
  /// `null` limpa a rede correspondente).
  DogSocialModel _buildSocial() {
    String? clean(TextEditingController controller) {
      final value = controller.text.trim();
      return value.isEmpty ? null : value;
    }

    return DogSocialModel(
      whatsapp: clean(_whatsappController),
      instagram: clean(_instagramController),
      pinterest: clean(_pinterestController),
      telegram: clean(_telegramController),
    );
  }

  /// Rola o formulário até o primeiro campo inválido (na ordem visual),
  /// alinhado ao topo com folga — um erro fora da viewport nunca fica
  /// invisível após o Salvar.
  void _scrollToFirstInvalidField() {
    for (final key in [_nameFieldKey, _breedFieldKey, _birthDateFieldKey]) {
      final field = key.currentState;
      if (field == null || !field.hasError) continue;
      final fieldContext = key.currentContext;
      if (fieldContext != null) {
        Scrollable.ensureVisible(
          fieldContext,
          alignment: 0.08,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    }
  }

  void _submit(DogModel? editingDog) {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState!.validate();
    if (_autovalidateMode == AutovalidateMode.disabled) {
      setState(
        () => _autovalidateMode = AutovalidateMode.onUserInteraction,
      );
    }
    if (!valid) {
      _scrollToFirstInvalidField();
      return;
    }
    // O validator garante uma data completa e válida.
    final birthDate = tryParseBrDate(_birthDateController.text);
    if (birthDate == null) return;
    final cubit = context.read<MyDogsCubit>();
    final bio = _bioController.text.trim();
    if (editingDog == null) {
      cubit.create(
        name: _nameController.text.trim(),
        breed: _breedController.text.trim(),
        sex: _sex,
        birthDate: birthDate,
        size: _size,
        intent: _intent,
        bio: bio.isEmpty ? null : bio,
        neutered: _neutered,
        pedigree: _pedigree,
        social: _buildSocial(),
      );
    } else {
      cubit.update(
        editingDog.id,
        name: _nameController.text.trim(),
        breed: _breedController.text.trim(),
        sex: _sex,
        birthDate: birthDate,
        size: _size,
        intent: _intent,
        bio: bio,
        neutered: _neutered,
        pedigree: _pedigree,
        social: _buildSocial(),
      );
    }
  }

  Future<void> _addPhoto(DogModel dog) async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    context.read<MyDogsCubit>().addPhoto(
          dogId: dog.id,
          bytes: bytes,
          contentType: picked.mimeType ??
              FileUploader.guessImageContentType(picked.name),
        );
  }

  Future<void> _confirmDelete(DogModel dog) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir cão'),
        content: Text(
          'Excluir ${dog.name}? Os matches e conversas dele serão perdidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<MyDogsCubit>().delete(dog.id);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<MyDogsCubit, MyDogsState>(
      listener: (context, state) {
        if (state.errorMessage != null) _showSnackBar(state.errorMessage!);
        if (state.successMessage != null) _showSnackBar(state.successMessage!);
        if (state.deleted) context.pop();
        final editingDog = state.editingDog;
        if (editingDog != null) _prefill(editingDog);
        if (state.savedDog != null && !widget.isCreating) {
          // Em edição, salvar fecha o formulário.
          context.pop();
        }
      },
      builder: (context, state) {
        final editingDog = state.editingDog;
        final isEditing = editingDog != null;
        if (!widget.isCreating && editingDog == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Editar cão')),
            body: state.status == MyDogsStatus.error
                ? EmptyState(
                    icon: Icons.error_outline,
                    title: 'Não foi possível carregar o cão',
                    message: state.errorMessage,
                    actionLabel: 'Tentar novamente',
                    onAction: () => context
                        .read<MyDogsCubit>()
                        .loadForEdit(widget.dogId!),
                  )
                : const LoadingIndicator(),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(isEditing ? 'Editar cão' : 'Novo cão'),
            actions: [
              if (isEditing)
                IconButton(
                  tooltip: 'Excluir cão',
                  icon: const Icon(Icons.delete_outline),
                  onPressed:
                      state.saving ? null : () => _confirmDelete(editingDog),
                ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                autovalidateMode: _autovalidateMode,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isEditing) ...[
                      Text('Fotos', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Até $_maxPhotos fotos. A primeira é a principal.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PhotoGrid(
                        dog: editingDog,
                        busy: state.photoBusy,
                        maxPhotos: _maxPhotos,
                        onAdd: () => _addPhoto(editingDog),
                        onDelete: (photoId) =>
                            context.read<MyDogsCubit>().deletePhoto(
                                  dogId: editingDog.id,
                                  photoId: photoId,
                                ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: const Icon(Icons.auto_stories_outlined),
                          title: const Text('Página do cão (posts)'),
                          subtitle: Text(
                            'Monte a página de ${editingDog.name} com até 10 '
                            'posts',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(
                            '/dogs/${editingDog.id}/posts',
                            extra: editingDog,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    AppTextField(
                      fieldKey: _nameFieldKey,
                      controller: _nameController,
                      label: 'Nome',
                      prefixIcon: Icons.pets,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Informe o nome do cão.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      fieldKey: _breedFieldKey,
                      controller: _breedController,
                      label: 'Raça',
                      prefixIcon: Icons.badge_outlined,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Informe a raça.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Text('Sexo', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SegmentedButton<DogSex>(
                      segments: [
                        for (final sex in DogSex.values)
                          ButtonSegment(
                            value: sex,
                            label: Text(sex.labelPtBr),
                            icon: Icon(
                              sex == DogSex.male
                                  ? Icons.male
                                  : Icons.female,
                            ),
                          ),
                      ],
                      selected: {_sex},
                      onSelectionChanged: (selection) =>
                          setState(() => _sex = selection.first),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: _birthDateFieldKey,
                      controller: _birthDateController,
                      focusNode: _birthDateFocusNode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [BrDateInputFormatter()],
                      textInputAction: TextInputAction.next,
                      validator: _validateBirthDate,
                      decoration: InputDecoration(
                        labelText: 'Data de nascimento',
                        hintText: 'dd/mm/aaaa',
                        prefixIcon: const Icon(Icons.cake_outlined),
                        suffixIcon: IconButton(
                          tooltip: 'Escolher no calendário',
                          icon: const Icon(Icons.calendar_today_outlined),
                          onPressed: _pickBirthDate,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<DogSize>(
                      initialValue: _size,
                      decoration: const InputDecoration(
                        labelText: 'Porte',
                        prefixIcon: Icon(Icons.straighten_outlined),
                      ),
                      items: [
                        for (final size in DogSize.values)
                          DropdownMenuItem(
                            value: size,
                            child: Text(size.labelPtBr),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _size = value);
                      },
                    ),
                    const SizedBox(height: 24),
                    Text('Intenção', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final intent in DogIntent.values)
                          ChoiceChip(
                            label: Text(intent.labelPtBr),
                            selected: _intent == intent,
                            onSelected: (_) =>
                                setState(() => _intent = intent),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _bioController,
                      label: 'Bio',
                      hint: 'Personalidade, vacinas, o que ele adora...',
                      prefixIcon: Icons.notes_outlined,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Castrado'),
                      value: _neutered,
                      onChanged: (value) => setState(() => _neutered = value),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Pedigree'),
                      value: _pedigree,
                      onChanged: (value) => setState(() => _pedigree = value),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Redes sociais do cão (opcional)',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aparecem no perfil como botões de contato — pode ser '
                      'a rede do cão ou a sua.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SocialField(
                      controller: _whatsappController,
                      label: 'WhatsApp',
                      hint: '+55 11 90000-0000',
                      icon: FontAwesomeIcons.whatsapp,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _SocialField(
                      controller: _instagramController,
                      label: 'Instagram',
                      hint: '@usuario ou link',
                      icon: FontAwesomeIcons.instagram,
                    ),
                    const SizedBox(height: 16),
                    _SocialField(
                      controller: _pinterestController,
                      label: 'Pinterest',
                      hint: '@usuario ou link',
                      icon: FontAwesomeIcons.pinterest,
                    ),
                    const SizedBox(height: 16),
                    _SocialField(
                      controller: _telegramController,
                      label: 'Telegram',
                      hint: '@usuario ou link',
                      icon: FontAwesomeIcons.telegram,
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: isEditing ? 'Salvar' : 'Cadastrar',
                      loading: state.saving,
                      onPressed: () => _submit(editingDog),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Campo de rede social do cão: valor livre (≤100 — handle, número ou URL,
/// §3.5.3) com o ícone da marca como prefixo.
class _SocialField extends StatelessWidget {
  const _SocialField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final FaIconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: 100,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        prefixIcon: FaIcon(icon),
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.dog,
    required this.busy,
    required this.maxPhotos,
    required this.onAdd,
    required this.onDelete,
  });

  final DogModel dog;
  final bool busy;
  final int maxPhotos;
  final VoidCallback onAdd;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photos = dog.sortedPhotos;
    final canAdd = photos.length < maxPhotos && !busy;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final photo in photos)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: photo.url,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  errorWidget: (_, _, _) => ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: InkWell(
                    onTap: busy ? null : () => onDelete(photo.id),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          theme.colorScheme.surface.withValues(alpha: 0.85),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (photos.length < maxPhotos)
          InkWell(
            onTap: canAdd ? onAdd : null,
            borderRadius: BorderRadius.circular(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.add_a_photo_outlined,
                        color: theme.colorScheme.primary,
                      ),
              ),
            ),
          ),
      ],
    );
  }
}
