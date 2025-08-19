import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'splash_screen.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  Widget initialScreen = const SplashScreen();
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    initialScreen = ChatScreen();
  } else {
    initialScreen = LoginScreen();
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MyApp(initialScreen: initialScreen),
    ),
  );
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme(bool isOn) {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;

  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ZenBot',
      themeMode: themeProvider.themeMode,
      theme: ThemeData.light().copyWith(scaffoldBackgroundColor: Colors.grey[100]),
      darkTheme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.grey[900]),
      home: initialScreen,
      routes: {
        '/login': (context) => LoginScreen(),
        '/chat': (context) => ChatScreen(),
      },
    );
  }
}