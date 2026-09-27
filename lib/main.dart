import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'controllers/request_provider.dart';
import 'controllers/notification_provider.dart';
import 'controllers/advocate_clerk_provider.dart';
import 'controllers/lawyer_provider.dart';
import 'controllers/filing_chat_provider.dart';
import 'theme/app_theme.dart';
import 'views/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://ybgtoaewzrjdlogxjoam.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InliZ3RvYWV3enJqZGxvZ3hqb2FtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk1MjkxODUsImV4cCI6MjEwNTEwNTE4NX0.ee7KZSt6aekieO4OfmL0DqavqTsmBOrU6u2Z00EThhM',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RequestProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => AdvocateClerkProvider()),
        ChangeNotifierProvider(create: (_) => LawyerProvider()),
        ChangeNotifierProvider(create: (_) => FilingChatProvider()),
      ],
      child: const JusticeConnectApp(),
    ),
  );
}

final supabase = Supabase.instance.client;

class JusticeConnectApp extends StatelessWidget {
  const JusticeConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JusticeConnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
