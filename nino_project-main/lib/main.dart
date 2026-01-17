import 'package:flutter/material.dart';
import 'package:nino/screens/getstartedscreen.dart';
import 'package:nino/screens/main_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nino/services/notification_service.dart';
import 'screens/signup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_page.dart';
import 'screens/child_info_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://owkodmavknzaxranlqeh.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im93a29kbWF2a256YXhyYW5scWVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyMzc5MTAsImV4cCI6MjA3NzgxMzkxMH0.mOeG1VtOIhjgmSgNHJ_hEasJ9ucoWJFgvuylBNGXUZ8',
  );

  await NotificationService.initialize();



  runApp(const NinoApp());
}

class NinoApp extends StatelessWidget {
  const NinoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nino App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthGate(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => const HomePage(),
        '/child_info': (context) => const ChildInfoPage(),
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    final session = _supabase.auth.currentSession;
    if (session != null) {
      return const MainShell();
    }
    return const Getstartedscreen();
  }
}
