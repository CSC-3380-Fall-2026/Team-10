import 'package:flutter/material.dart';

import '../sitewide/design_main.dart';
import 'input_decoration.dart';

/// The app's standard checkbox: a purple box with a label next to it.
/// Tapping the label also toggles the box.
///
/// Basic:
///   AppCheckbox(
///     label: 'All-day event',
///     value: allDay,
///     onChanged: (value) => setState(() => allDay = value),
///   )
///
/// Must be checked to submit the form (e.g. terms and conditions):
///   AppCheckbox(
///     label: 'I agree to the Terms and Conditions',
///     value: agreed,
///     mustBeChecked: true,
///     onChanged: (value) => setState(() => agreed = value),
///   )
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.mustBeChecked = false,
    this.errorText = 'This box must be checked',
    this.enabled = true,
  });

  /// Text next to the box.
  final String label;

  /// Whether the box is checked.
  final bool value;

  /// Called with the new value when the user taps it.
  final ValueChanged<bool> onChanged;

  /// Optional smaller gray text under the label.
  final String? subtitle;

  /// If true, the form won't submit until this is checked.
  final bool mustBeChecked;

  /// Message shown when [mustBeChecked] is true and the box isn't checked.
  final String errorText;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final style = context.style;
    final textTheme = Theme.of(context).textTheme;
    final errorColor = Theme.of(context).colorScheme.error;

    return FormField<bool>(
      initialValue: value,
      validator: (_) => mustBeChecked && !value ? errorText : null,
      builder: (field) {
        void toggle() {
          final newValue = !value;
          field.didChange(newValue); // clears the error once it's checked
          onChanged(newValue);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: enabled ? toggle : null,
              borderRadius: BorderRadius.circular(style.radius),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: style.spaceExtraSmall),
                child: Row(
                  crossAxisAlignment: subtitle == null
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: value,
                      onChanged: enabled ? (_) => toggle() : null,
                      activeColor: AppColors.purple,
                      checkColor: AppColors.white,
                      side: BorderSide(
                        color: field.hasError
                            ? errorColor
                            : (enabled
                                ? AppInputColors.label
                                : AppInputColors.disabled),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(width: style.spaceExtraSmall),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: subtitle == null ? 0 : style.spaceSmall * 1.5,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: textTheme.bodyLarge?.copyWith(
                                color: enabled
                                    ? AppInputColors.text
                                    : AppInputColors.hint,
                              ),
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppInputColors.label,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (field.hasError)
              Padding(
                padding: EdgeInsets.only(left: style.spaceMedium),
                child: Text(
                  field.errorText!,
                  style: textTheme.bodySmall?.copyWith(color: errorColor),
                ),
              ),
          ],
        );
      },
    );
  }
}
