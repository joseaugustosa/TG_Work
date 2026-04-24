import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_shell_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Cache local do Firestore no Windows tem casos de falha/crash com listeners
  // (ex.: flutterfire#13145). Desativar persistência evita histórico vazio ou erros silenciosos.
  if (defaultTargetPlatform == TargetPlatform.windows) {
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
  }
  runApp(const TGWorkApp());
}

class TGWorkApp extends StatelessWidget {
  const TGWorkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TG Work',
      debugShowCheckedModeBanner: false,
      // Mesmo comportamento que no Android: arrastar listas com rato/trackpad no Windows.
      scrollBehavior: MaterialScrollBehavior().copyWith(
        dragDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const HomeShellScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
