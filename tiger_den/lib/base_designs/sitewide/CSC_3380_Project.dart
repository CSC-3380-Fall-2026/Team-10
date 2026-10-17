import 'package:flutter/material.dart';

enum ScreenSize { compact, medium, expanded }

class AppStyle {

  final double width;
  static const double _designWidth = 390;
  static const double maxContentWidth = 1200;

  AppStyle._(this.width);
  
  factory AppStyle.of(BuildContext context) =>
      AppStyle._(MediaQuery.sizeOf(context).width);
  
  ScreenSize get screen => width < 600
      ? ScreenSize.compact
      : width < 1024
          ? ScreenSize.medium
          : ScreenSize.expanded;

  double get scale => (width / _designWidth).clamp(0.85, 1.4);
  double s(double value) => value * scale;

  double get spaceExraSmall => s(4);
  double get spaceSmall => s(8);
  double get spaceMedium => s(16);
  double get spaceLarge => s(24);
  double get spaceExtraLarge => s(32);

  double get pageMargin => switch (screen) {
        ScreenSize.compact => 16,
        ScreenSize.medium => 32,
        ScreenSize.expanded => 64,
      };

  double get radius => s(12);

  static const String fontFamily = 'Roboto'; // TODO: replace font

  TextTheme get textTheme => TextTheme(
        displayLarge: _t(40, FontWeight.w700),
        headlineMedium: _t(28, FontWeight.w700),
        titleLarge: _t(22, FontWeight.w600),
        titleMedium: _t(18, FontWeight.w600),
        bodyLarge: _t(16, FontWeight.w400),
        bodyMedium: _t(14, FontWeight.w400),
        labelLarge: _t(14, FontWeight.w600),
        bodySmall: _t(12, FontWeight.w400),
      );

  TextStyle _t(double size, FontWeight weight) => TextStyle(fontFamily: fontFamily, fontSize: s(size),fontWeight: weight,);

  ThemeData get theme => ThemeData(
        useMaterial3: true,
        fontFamily: fontFamily,
        textTheme: textTheme,
        // TODO: replace colors
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        cardTheme: CardThemeData(
          margin: EdgeInsets.all(spaceSmall),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: spaceLarge,
              vertical: spaceMedium * 0.75,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          contentPadding: EdgeInsets.all(spaceMedium),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      );
}

extension AppStyleContext on BuildContext {
  AppStyle get style => AppStyle.of(this);
}

class AppPage extends StatelessWidget {
  const AppPage({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppStyle.maxContentWidth),
          child: Padding(
            padding: EdgeInsets.all(context.style.pageMargin),
            child: child,
          ),
        ),
      ),
    );
  }
}
