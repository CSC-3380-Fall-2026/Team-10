import 'package:flutter/material.dart';

import '../sitewide/design_main.dart';
import 'input_decoration.dart';

/// One choice in an [AppDropdown]: the [value] your code uses, and the
/// [label] the user sees.
class AppDropdownOption<T> {
  const AppDropdownOption(T this.value, String this.label);

  final T value;
  final String label;
}

/// The app's standard dropdown. It matches AppTextField and works with
/// `Form` validation (unlike DropdownMenu).
///
/// ```dart
///   AppDropdown<String>(
///     label: 'Event Type',
///     isRequired: true,
///     value: selectedType,
///     options: const [
///       AppDropdownOption('official', 'Official club event'),
///       AppDropdownOption('casual', 'Casual event'),
///     ],
///     onChanged: (value) => setState(() => selectedType = value),
///   )
///
/// [value] is the starting selection. To change the selection from code
/// later, give the dropdown a new `key` so it rebuilds with the new value.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    Key? super.key,
    required String this.label,
    required List<AppDropdownOption<T>> this.options,
    required void Function(T?) this.onChanged,
    T? this.value,
    String? this.hint,
    String? this.helperText,
    bool this.isRequired = false,
    String? Function(T?)? this.validator,
    bool this.enabled = true,
    IconData? this.prefixIcon,
  });

  /// Text shown on the field, e.g. "Category".
  final String label;

  /// The choices to show.
  final List<AppDropdownOption<T>> options;

  /// Called with the new value when the user picks something.
  final ValueChanged<T?> onChanged;

  /// The starting selection (null = nothing selected).
  final T? value;

  /// Gray placeholder shown while nothing is selected.
  final String? hint;

  /// Small gray note under the field.
  final String? helperText;

  /// If true, adds a * to the label and won't let the form submit with
  /// nothing selected.
  final bool isRequired;

  /// Extra checks. Return an error message, or null if the value is OK.
  final FormFieldValidator<T>? validator;

  final bool enabled;
  final IconData? prefixIcon;

  String? _validate(T? value) {
    if (isRequired && value == null) {
      return 'Please select ${label.toLowerCase()}';
    }
    return validator?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final AppStyle style = context.style;
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: <DropdownMenuItem<T>>[
        for (final AppDropdownOption<T> option in options)
          DropdownMenuItem<T>(
            value: option.value,
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: enabled ? onChanged : null,
      validator: _validate,
      decoration: appInputDecoration(
        context,
        label: label,
        hint: hint,
        helperText: helperText,
        isRequired: isRequired,
        prefixIcon: prefixIcon,
      ),
      style: appInputTextStyle(context),
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      iconEnabledColor: AppColors.purple,
      iconDisabledColor: AppInputColors.disabled,
      dropdownColor: AppColors.white,
      borderRadius: BorderRadius.circular(style.radius),
      menuMaxHeight: 320,
    );
  }
}
