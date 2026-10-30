import 'package:flutter/material.dart';

import '../base_designs/input_field_design/app_checkbox.dart';
import '../base_designs/input_field_design/app_dropdown.dart';
import '../base_designs/input_field_design/app_text_field.dart';
import '../base_designs/sitewide/design_main.dart';

/// A test-only page that shows every standard form input, so the team can
/// see how they look and try validation.
///
/// Run it with (from the tiger_den folder):
///   flutter run -t lib/dev/form_styles_preview_main.dart -d emulator-5554
///
/// The normal app (lib/main.dart) is not affected. No Firebase needed.
void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => Theme(
        data: context.style.theme,
        child: child!,
      ),
      home: const FormStylesPreviewPage(),
    ),
  );
}

class FormStylesPreviewPage extends StatefulWidget {
  const FormStylesPreviewPage({super.key});

  @override
  State<FormStylesPreviewPage> createState() => _FormStylesPreviewPageState();
}

class _FormStylesPreviewPageState extends State<FormStylesPreviewPage> {
  final _formKey = GlobalKey<FormState>();
  String? _category;
  String? _visibility = 'public';
  bool _allDay = false;
  bool _agreed = false;

  void _submit() {
    final valid = _formKey.currentState!.validate();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(valid
          ? 'Everything is valid!'
          : 'Some fields need fixing (see the red messages).'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final style = context.style;
    final gap = SizedBox(height: style.spaceMedium);

    Widget heading(String text) => Padding(
          padding: EdgeInsets.only(
              top: style.spaceLarge, bottom: style.spaceSmall),
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Form Styles (dev only)')),
      body: MainApp(
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              heading('Text boxes'),
              const AppTextField(
                label: 'Full Name',
                hint: 'Jane Doe',
                isRequired: true,
                prefixIcon: Icons.person_outline,
              ),
              gap,
              AppTextField(
                label: 'Email',
                hint: 'user@example.com',
                isRequired: true,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
                validator: (value) =>
                    value!.contains('@') ? null : 'Enter a valid email',
              ),
              gap,
              const AppTextField(
                label: 'Password',
                isPassword: true,
                isRequired: true,
                prefixIcon: Icons.lock_outline,
              ),
              gap,
              const AppTextField(
                label: 'Description',
                hint: 'Tell people about your event',
                helperText: 'Optional',
                maxLines: 4,
                maxLength: 300,
              ),
              gap,
              const AppTextField(
                label: 'Disabled field',
                initialValue: 'You can\'t edit this',
                enabled: false,
              ),

              heading('Dropdowns'),
              AppDropdown<String>(
                label: 'Category',
                hint: 'Choose one',
                isRequired: true,
                value: _category,
                prefixIcon: Icons.category_outlined,
                options: const [
                  AppDropdownOption('academic', 'Academic'),
                  AppDropdownOption('sport', 'Sports'),
                  AppDropdownOption('cultural', 'Cultural'),
                  AppDropdownOption('social', 'Social'),
                ],
                onChanged: (value) => setState(() => _category = value),
              ),
              gap,
              AppDropdown<String>(
                label: 'Visibility',
                value: _visibility,
                options: const [
                  AppDropdownOption('public', 'Public'),
                  AppDropdownOption('membersOnly', 'Members only'),
                ],
                onChanged: (value) => setState(() => _visibility = value),
              ),
              gap,
              AppDropdown<String>(
                label: 'Disabled dropdown',
                value: 'a',
                enabled: false,
                options: const [AppDropdownOption('a', 'Can\'t change this')],
                onChanged: (_) {},
              ),

              heading('Checkboxes'),
              AppCheckbox(
                label: 'All-day event',
                value: _allDay,
                onChanged: (value) => setState(() => _allDay = value),
              ),
              AppCheckbox(
                label: 'I agree to the Terms and Conditions',
                subtitle: 'Required to submit',
                value: _agreed,
                mustBeChecked: true,
                errorText: 'You must agree to continue',
                onChanged: (value) => setState(() => _agreed = value),
              ),
              AppCheckbox(
                label: 'Disabled checkbox',
                value: true,
                enabled: false,
                onChanged: (_) {},
              ),

              SizedBox(height: style.spaceLarge),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Check form'),
              ),
              SizedBox(height: style.spaceExtraLarge),
            ],
          ),
        ),
      ),
    );
  }
}
