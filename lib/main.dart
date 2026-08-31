import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/storage/key_value_store.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/auth/infrastructure/supabase_auth_gateway.dart';
import 'features/profile/application/learning_providers.dart';
import 'features/profile/infrastructure/supabase_learning_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 接続情報が無いまま起動すると、保存できていないのに動いているように見える。
  // 既定値を持たせず、ここで止める。
  final configErrors = AppConfig.validate();
  if (configErrors.isNotEmpty) {
    runApp(ConfigErrorApp(errors: configErrors));
    return;
  }

  SupabaseClient? client;
  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );
    client = Supabase.instance.client;
  } catch (error) {
    // 初期化に失敗してもローカル保存だけで動かす（オフラインファースト）。
    debugPrint('Supabase の初期化に失敗しました: $error');
  }

  final supabase = client;
  runApp(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(
          SharedPreferencesKeyValueStore(),
        ),
        if (supabase != null) ...[
          authGatewayProvider.overrideWithValue(SupabaseAuthGateway(supabase)),
          remoteLearningStoreProvider.overrideWithValue(
            SupabaseLearningStore(supabase),
          ),
        ],
      ],
      child: const AiPokerCoachApp(),
    ),
  );
}
