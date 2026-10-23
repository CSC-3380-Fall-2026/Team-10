import 'package:flutter/material.dart';

import '../sitewide/design_main.dart';

/// Colors shared by every form input, so all text boxes, dropdowns and
/// checkboxes look the same. Brand colors (purple/yellow) come from
/// [AppColors] in design_main.dart.
class AppInputColors {
  AppInputColors._();

  /// Text the user types / selects.
  static const Color text = Color(0xFF1C1B1F);

  /// Field labels (e.g. "Email").
  static const Color label = Color(0xFF616161);

  /// Placeholder hints (e.g. "user@example.com").
  static const Color hint = Color(0xFF9E9E9E);

  /// Outline of a field that isn't selected.
  static const Color border = Color(0xFFBDBDBD);

  /// Outline and text of a disabled field.
  static const Color disabled = Color(0xFFE0E0E0);
}

/// The standard look for every text box and dropdown in the app:
/// white rounded box, gray outline, purple outline + label when selected,
/// red outline + message when there's an error.
///
/// Used by AppTextField and AppDropdown. You normally don't need to call
/// this yourself, but you can for a custom field that should match:
///   decoration: appInputDecoration(context, label: 'Room number'),
InputDecoration appInputDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  String? helperText,
  bool isRequired = false,
  IconData? prefixIcon,
  Widget? suffixIcon,
}) {
  final style = context.style;
  final errorColor = Theme.of(context).colorScheme.error;

  OutlineInputBorder outline(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(style.radius),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    // Required fields get a * after their label.
    labelText: isRequired ? '$label *' : label,
    hintText: hint,
    helperText: helperText,
    prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.white,
    contentPadding: EdgeInsets.symmetric(
      horizontal: style.spaceMedium,
      vertical: style.spaceMedium * 0.75,
    ),
    labelStyle: const TextStyle(color: AppInputColors.label),
    floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
      if (states.contains(WidgetState.error)) {
        return TextStyle(color: errorColor);
      }
      if (states.contains(WidgetState.focused)) {
        return const TextStyle(color: AppColors.purple);
      }
      return const TextStyle(color: AppInputColors.label);
    }),
    hintStyle: const TextStyle(color: AppInputColors.hint),
    prefixIconColor: WidgetStateColor.resolveWith(
      (states) => states.contains(WidgetState.focused)
          ? AppColors.purple
          : AppInputColors.label,
    ),
    border: outline(AppInputColors.border),
    enabledBorder: outline(AppInputColors.border),
    focusedBorder: outline(AppColors.purple, 2),
    errorBorder: outline(errorColor),
    focusedErrorBorder: outline(errorColor, 2),
    disabledBorder: outline(AppInputColors.disabled),
  );
}

/// The standard text style for what the user types or selects.
TextStyle? appInputTextStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppInputColors.text);
