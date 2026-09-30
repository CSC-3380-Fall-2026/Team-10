//not sure of code standards yet, but I used this as research https://www.reddit.com/r/FlutterDev/comments/8na00g/how_to_put_themes_in_a_separate_file/
//where universal design will go (color, font size, etc)
import 'package:flutter/material.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Hello World!'))),
    );
  }
}
