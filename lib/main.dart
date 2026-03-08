import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/ai/chat_service.dart';
import 'core/models/student.dart';
import 'core/models/parent_data.dart';
import 'features/home/home_screen.dart';
import 'features/auth/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KawanBelajarApp());
}

class KawanBelajarApp extends StatelessWidget {
  const KawanBelajarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StudentProvider()),
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) {
          final provider = ParentDataProvider();
          provider.load();
          return provider;
        }),
      ],
      child: MaterialApp(
        title: 'Kawan Belajar',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4CAF50),
            primary: const Color(0xFF4CAF50),
            secondary: const Color(0xFFFF9800),
            surface: const Color(0xFFFFF8E1),
          ),
          textTheme: GoogleFonts.poppinsTextTheme(),
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final student = context.watch<StudentProvider>();
    if (student.isLoggedIn) {
      return const HomeScreen();
    }
    return const LoginScreen();
  }
}
