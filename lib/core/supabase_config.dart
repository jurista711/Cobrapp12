import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://jyyioyoaupzuwljzwbyc.supabase.co';
const supabasePublishableKey = 'sb_publishable_8qBZB08TVgAZegkYXzXSxw_hsS-4qA2';

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: true,
      detectSessionInUri: true,
    ),
  );
}

SupabaseClient get supabase => Supabase.instance.client;
