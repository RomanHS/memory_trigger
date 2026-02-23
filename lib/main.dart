import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/repositories/word_repository_impl.dart';
import 'presentation/providers/word_provider.dart';
import 'presentation/pages/home_page.dart';

void main() {
  // Initialize repository
  final wordRepository = WordRepositoryImpl();

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => WordProvider(wordRepository))],
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Trigger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF), brightness: Brightness.dark),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomePage(),
    );
  }
}
