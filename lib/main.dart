import 'package:material_ui/material_ui.dart';
import 'screens/home_shell.dart';

void main() {
  runApp(const PostureApp());
}

class PostureApp extends StatelessWidget {
  const PostureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Posture Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}