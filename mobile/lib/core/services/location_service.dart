import 'dart:async';

import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/auth/data/models/user_model.dart';
import 'package:dogmatch/features/profile/domain/repositories/profile_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:injectable/injectable.dart';

/// Porta fina sobre a API estática do Geolocator para os testes mockarem.
abstract class LocationGateway {
  Future<bool> isLocationServiceEnabled();

  Future<LocationPermission> checkPermission();

  Future<LocationPermission> requestPermission();

  Future<Position> getCurrentPosition();

  Future<bool> openAppSettings();
}

@LazySingleton(as: LocationGateway)
class GeolocatorLocationGateway implements LocationGateway {
  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<Position> getCurrentPosition() => Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}

enum LocationSyncStatus {
  synced,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  error,
}

class LocationSyncResult extends Equatable {
  const LocationSyncResult(this.status, {this.user, this.errorMessage});

  final LocationSyncStatus status;

  /// Usuário devolvido pelo `PATCH /users/me` quando [synced].
  final UserModel? user;

  /// Mensagem PT-BR pronta para a UI quando não sincronizou.
  final String? errorMessage;

  bool get synced => status == LocationSyncStatus.synced;

  @override
  List<Object?> get props => [status, user, errorMessage];
}

/// Fonte única do fluxo de localização: permissão, sincronização da posição
/// no perfil (`PATCH /users/me`) e reação à volta do app (permissão concedida
/// nas configurações do sistema só é vista no `resumed`).
///
/// Regras: sync automático no máximo uma vez por sessão autenticada; pedido
/// de permissão em gesto do usuário ([ensurePermission]) e, quando ausente,
/// uma única vez no início da sessão ([promptPermissionAtSessionStart] —
/// nunca para deniedForever); convite da aba Matches no máximo uma vez por
/// sessão e nunca bloqueante.
@lazySingleton
class LocationService with WidgetsBindingObserver {
  LocationService(this._gateway, this._profileRepository);

  static const String _deniedMessage = 'Permissão de localização negada.';
  static const String _blockedMessage =
      'Permissão de localização bloqueada. Habilite nas configurações do '
      'aplicativo.';
  static const String _gpsOffMessage =
      'Ative o serviço de localização (GPS) e tente novamente.';
  static const String _positionErrorMessage =
      'Não foi possível obter sua localização.';

  final LocationGateway _gateway;
  final ProfileRepository _profileRepository;

  final StreamController<UserModel> _syncedController =
      StreamController<UserModel>.broadcast();

  bool _sessionActive = false;
  bool _syncedThisSession = false;
  bool _inviteOffered = false;
  bool _startupPromptHandled = false;
  UserModel? _lastSyncedUser;
  Future<LocationSyncResult>? _inFlightSync;

  /// Emite o usuário atualizado a cada posição sincronizada no perfil —
  /// cubits presos em "sem localização" escutam para recarregar sozinhos.
  Stream<UserModel> get onLocationSynced => _syncedController.stream;

  /// Início da sessão autenticada: registra o observer de lifecycle e tenta
  /// o sync automático (silencioso — sem permissão, não pede nada).
  void startSession() {
    if (_sessionActive) return;
    _sessionActive = true;
    _resetSessionFlags();
    WidgetsBinding.instance.addObserver(this);
    unawaited(syncToProfile());
  }

  void endSession() {
    if (!_sessionActive) return;
    _sessionActive = false;
    _resetSessionFlags();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cobre a permissão concedida nas configurações do sistema com o app em
    // segundo plano: ao voltar, re-checa e sincroniza sem exigir reinício.
    if (state == AppLifecycleState.resumed &&
        _sessionActive &&
        !_syncedThisSession) {
      unawaited(syncToProfile());
    }
  }

  Future<bool> hasPermission() async =>
      _isGranted(await _gateway.checkPermission());

  /// Lê a posição e envia `PATCH /users/me`. Nunca pede permissão: sem ela,
  /// devolve o status e não toca no sistema. Throttle de uma sincronização
  /// por sessão ([force] ignora, para o refresh manual do Perfil); chamadas
  /// concorrentes compartilham a mesma requisição.
  Future<LocationSyncResult> syncToProfile({bool force = false}) {
    final lastUser = _lastSyncedUser;
    if (_syncedThisSession && !force && lastUser != null) {
      return Future.value(
        LocationSyncResult(LocationSyncStatus.synced, user: lastUser),
      );
    }
    final inFlight = _inFlightSync;
    if (inFlight != null) return inFlight;
    final request = _sync().whenComplete(() => _inFlightSync = null);
    _inFlightSync = request;
    return request;
  }

  /// Fluxo completo disparado por gesto do usuário: pede a permissão se
  /// necessário, trata `deniedForever` (dialog + configurações quando há
  /// [context]) e sincroniza ao conceder — emitindo em [onLocationSynced].
  Future<LocationSyncResult> ensurePermission({
    BuildContext? context,
    bool forceSync = false,
  }) async {
    var permission = await _gateway.checkPermission();
    if (!_isGranted(permission) &&
        permission != LocationPermission.deniedForever) {
      permission = await _gateway.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (context != null && context.mounted) {
        await showLocationSettingsDialog(context);
      }
      return const LocationSyncResult(
        LocationSyncStatus.permissionDeniedForever,
        errorMessage: _blockedMessage,
      );
    }
    if (!_isGranted(permission)) {
      return const LocationSyncResult(
        LocationSyncStatus.permissionDenied,
        errorMessage: _deniedMessage,
      );
    }
    return syncToProfile(force: forceSync);
  }

  /// Pedido único de permissão no início da sessão autenticada (primeira
  /// tela com UI, chamado pelo shell): cobre o app reinstalado — uma conta
  /// com localização já salva no backend nunca cai em `LOCATION_REQUIRED`,
  /// então sem este pedido a posição ficaria desatualizada até o usuário
  /// achar o botão do perfil. `deniedForever` não é incomodado aqui (fica
  /// para os gestos, que abrem o dialog de configurações); negada, a vida
  /// segue — os gestos continuam pedindo como sempre. Concedida ⇒ sincroniza
  /// e emite em [onLocationSynced] (as telas recarregam sozinhas).
  Future<void> promptPermissionAtSessionStart() async {
    if (!_sessionActive || _startupPromptHandled) return;
    _startupPromptHandled = true;
    final permission = await _gateway.checkPermission();
    if (_isGranted(permission) ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    await ensurePermission();
  }

  /// Convite leve da aba Matches (SnackBar com "Ativar"): no máximo uma vez
  /// por sessão e nunca bloqueia a ação que o disparou.
  Future<void> offerLocationInvite(BuildContext context) async {
    if (_inviteOffered || await hasPermission()) return;
    _inviteOffered = true;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
              const Text('Ative a localização para ver cães e matches por '
                  'perto.'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Ativar',
            onPressed: () => unawaited(
              ensurePermission(context: context.mounted ? context : null),
            ),
          ),
        ),
      );
  }

  Future<void> showLocationSettingsDialog(BuildContext context) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permissão de localização'),
        content: const Text(
          'O acesso à localização está bloqueado para o DogMatch. Abra as '
          'configurações do aplicativo e permita a localização para '
          'encontrarmos cães por perto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Abrir configurações'),
          ),
        ],
      ),
    );
    if (open == true) await _gateway.openAppSettings();
  }

  Future<LocationSyncResult> _sync() async {
    final permission = await _gateway.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      return const LocationSyncResult(
        LocationSyncStatus.permissionDeniedForever,
        errorMessage: _blockedMessage,
      );
    }
    if (!_isGranted(permission)) {
      return const LocationSyncResult(
        LocationSyncStatus.permissionDenied,
        errorMessage: _deniedMessage,
      );
    }
    try {
      if (!await _gateway.isLocationServiceEnabled()) {
        return const LocationSyncResult(
          LocationSyncStatus.serviceDisabled,
          errorMessage: _gpsOffMessage,
        );
      }
      final position = await _gateway.getCurrentPosition();
      final user = await _profileRepository.updateProfile(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _syncedThisSession = true;
      _lastSyncedUser = user;
      _syncedController.add(user);
      return LocationSyncResult(LocationSyncStatus.synced, user: user);
    } on ApiException catch (exception) {
      return LocationSyncResult(
        LocationSyncStatus.error,
        errorMessage: exception.message,
      );
    } on Exception {
      return const LocationSyncResult(
        LocationSyncStatus.error,
        errorMessage: _positionErrorMessage,
      );
    }
  }

  void _resetSessionFlags() {
    _syncedThisSession = false;
    _inviteOffered = false;
    _startupPromptHandled = false;
    _lastSyncedUser = null;
  }

  bool _isGranted(LocationPermission permission) =>
      permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse;

  @disposeMethod
  void dispose() {
    if (_sessionActive) WidgetsBinding.instance.removeObserver(this);
    unawaited(_syncedController.close());
  }
}
