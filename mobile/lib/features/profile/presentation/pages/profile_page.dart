import 'package:cached_network_image/cached_network_image.dart';
import 'package:dogmatch/app/di/injection.dart';
import 'package:dogmatch/core/network/file_uploader.dart';
import 'package:dogmatch/core/widgets/app_text_field.dart';
import 'package:dogmatch/core/widgets/empty_state.dart';
import 'package:dogmatch/core/widgets/loading_indicator.dart';
import 'package:dogmatch/core/widgets/primary_button.dart';
import 'package:dogmatch/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/presentation/cubit/my_dogs_cubit.dart';
import 'package:dogmatch/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<ProfileCubit>()..load()),
        BlocProvider(create: (_) => getIt<MyDogsCubit>()..load()),
      ],
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();
  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    context.read<ProfileCubit>().uploadAvatar(
          bytes: bytes,
          contentType: picked.mimeType ??
              FileUploader.guessImageContentType(picked.name),
        );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Tem certeza de que deseja sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<AuthBloc>().add(const AuthLogoutRequested());
    }
  }

  Future<void> _openDogForm({DogModel? dog}) async {
    if (dog == null) {
      await context.push('/dogs/new');
    } else {
      await context.push('/dogs/${dog.id}/edit', extra: dog);
    }
    if (!mounted) return;
    context.read<MyDogsCubit>().load();
    context.read<ProfileCubit>().load();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: BlocConsumer<ProfileCubit, ProfileState>(
        listener: (context, state) {
          if (state.errorMessage != null) _showSnackBar(state.errorMessage!);
          if (state.successMessage != null) {
            _showSnackBar(state.successMessage!);
          }
          if (state.status == ProfileStatus.loaded && state.user != null) {
            final user = state.user!;
            if (_nameController.text.isEmpty) {
              _nameController.text = user.name;
            }
            if (_cityController.text.isEmpty && user.city != null) {
              _cityController.text = user.city!;
            }
            if (_bioController.text.isEmpty && user.bio != null) {
              _bioController.text = user.bio!;
            }
          }
        },
        builder: (context, state) {
          if (state.status == ProfileStatus.loading && state.user == null) {
            return const LoadingIndicator();
          }
          if (state.status == ProfileStatus.error && state.user == null) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Não foi possível carregar seu perfil',
              message: state.errorMessage,
              actionLabel: 'Tentar novamente',
              onAction: () => context.read<ProfileCubit>().load(),
            );
          }
          final user = state.user;
          if (user == null) return const LoadingIndicator();

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      backgroundImage: user.avatarUrl == null
                          ? null
                          : CachedNetworkImageProvider(user.avatarUrl!),
                      child: state.uploadingAvatar
                          ? const CircularProgressIndicator()
                          : user.avatarUrl == null
                              ? Icon(
                                  Icons.person,
                                  size: 56,
                                  color:
                                      theme.colorScheme.onPrimaryContainer,
                                )
                              : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: IconButton.filled(
                        tooltip: 'Alterar foto',
                        onPressed:
                            state.uploadingAvatar ? null : _pickAvatar,
                        icon: const Icon(Icons.photo_camera_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  user.email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AppTextField(
                controller: _nameController,
                label: 'Nome',
                prefixIcon: Icons.person_outline,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _cityController,
                label: 'Cidade',
                prefixIcon: Icons.location_city_outlined,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _bioController,
                label: 'Bio',
                hint: 'Conte um pouco sobre você e seus cães',
                prefixIcon: Icons.notes_outlined,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Salvar alterações',
                loading: state.saving,
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  context.read<ProfileCubit>().saveProfile(
                        name: _nameController.text.trim(),
                        city: _cityController.text.trim(),
                        bio: _bioController.text.trim(),
                      );
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: state.updatingLocation
                    ? null
                    : () => context.read<ProfileCubit>().useMyLocation(),
                icon: state.updatingLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: const Text('Usar minha localização'),
              ),
              if (user.hasLocation)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Localização definida '
                    '(${user.latitude!.toStringAsFixed(4)}, '
                    '${user.longitude!.toStringAsFixed(4)})',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              Text('Meus cães', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              BlocBuilder<MyDogsCubit, MyDogsState>(
                builder: (context, dogsState) {
                  if (dogsState.status == MyDogsStatus.loading) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: LoadingIndicator(),
                    );
                  }
                  if (dogsState.dogs.isEmpty) {
                    return Text(
                      'Você ainda não cadastrou nenhum cão.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final dog in dogsState.dogs)
                        Card(
                          child: ListTile(
                            onTap: () =>
                                context.push('/search/dogs/${dog.id}'),
                            leading: CircleAvatar(
                              backgroundImage: dog.mainPhotoUrl == null
                                  ? null
                                  : CachedNetworkImageProvider(
                                      dog.mainPhotoUrl!,
                                    ),
                              child: dog.mainPhotoUrl == null
                                  ? const Icon(Icons.pets)
                                  : null,
                            ),
                            title: Text(dog.name),
                            subtitle: Text(
                              '${dog.breed} · ${dog.sex.labelPtBr}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Página do cão (posts)',
                                  icon:
                                      const Icon(Icons.auto_stories_outlined),
                                  onPressed: () => context.push(
                                    '/dogs/${dog.id}/posts',
                                    extra: dog,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Editar',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _openDogForm(dog: dog),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () => _openDogForm(),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar cão'),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: _confirmLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
              ),
            ],
          );
        },
      ),
    );
  }
}
