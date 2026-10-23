import 'package:flutter/material.dart';

import '../sitewide/design_main.dart';
import 'input_decoration.dart';

/// The app's standard text box. Use this instead of TextFormField so every
/// form looks the same.
///
/// Basic:
///   AppTextField(label: 'Event Title', controller: titleController, isRequired: true)
///
/// Email:
///   AppTextField(
///     label: 'Email',
///     hint: 'user@example.com',
///     keyboardType: TextInputType.emailAddress,
///     prefixIcon: Icons.email_outlined,
///   )
///
/// Password (adds a show/hide eye button):
///   AppTextField(label: 'Password', isPassword: true, isRequired: true)
///
/// Multi-line (e.g. a description):
///   AppTextField(label: 'Description', maxLines: 4, maxLength: 500)
///
/// Put fields inside a `Form` and call `formKey.currentState!.validate()` to
/// check them. Required fields automatically show "<label> is required" when
/// empty; [validator] can add extra rules on top.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.helperText,
    this.isRequired = false,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.isPassword = false,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.enabled = true,
    this.onChanged,
    this.autofillHints,
  })  : assert(controller == null || initialValue == null,
            'Use either controller or initialValue, not both.'),
        assert(!isPassword || maxLines == 1,
            'Password fields must be a single line.');

  /// Text shown on the field, e.g. "Email".
  final String label;

  /// Reads/sets the text. Use either this or [initialValue].
  final TextEditingController? controller;

  /// Starting text when not using a [controller].
  final String? initialValue;

  /// Gray placeholder shown while the field is empty.
  final String? hint;

  /// Small gray note under the field.
  final String? helperText;

  /// If true, adds a * to the label and won't let the form submit while empty.
  final bool isRequired;

  /// Extra checks. Return an error message, or null if the value is OK.
  final FormFieldValidator<String>? validator;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  /// Hides the text and adds a show/hide button.
  final bool isPassword;

  /// More than 1 makes a taller, multi-line box.
  final int maxLines;

  /// Shows a character counter and stops typing at this many characters.
  final int? maxLength;

  final IconData? prefixIcon;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscured = true;

  String? _validate(String? value) {
    if (widget.isRequired && (value == null || value.trim().isEmpty)) {
      return '${widget.label} is required';
    }
    return widget.validator?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final passwordToggle = widget.isPassword
        ? IconButton(
            tooltip: _obscured ? 'Show password' : 'Hide password',
            icon: Icon(_obscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscured = !_obscured),
          )
        : null;

    return TextFormField(
      controller: widget.controller,
      initialValue: widget.initialValue,
      decoration: appInputDecoration(
        context,
        label: widget.label,
        hint: widget.hint,
        helperText: widget.helperText,
        isRequired: widget.isRequired,
        prefixIcon: widget.prefixIcon,
        suffixIcon: passwordToggle,
      ),
      style: appInputTextStyle(context),
      cursorColor: AppColors.purple,
      validator: _validate,
      keyboardType: widget.isPassword
          ? TextInputType.visiblePassword
          : (widget.keyboardType ??
              (widget.maxLines > 1 ? TextInputType.multiline : null)),
      textInputAction: widget.textInputAction,
      obscureText: widget.isPassword && _obscured,
      enableSuggestions: !widget.isPassword,
      autocorrect: !widget.isPassword,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      autofillHints: widget.autofillHints,
    );
  }
}
