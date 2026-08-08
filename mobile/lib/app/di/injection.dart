import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'package:dogmatch/app/di/injection.config.dart';

final GetIt getIt = GetIt.instance;

/// Configura o get_it com os registros gerados pelo injectable
/// (`injection.config.dart`, gerado via build_runner).
@InjectableInit(initializerName: 'init')
void configureDependencies() => getIt.init();
