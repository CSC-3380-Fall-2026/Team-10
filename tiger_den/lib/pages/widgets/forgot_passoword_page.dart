import 'package:flutter/material.dart';

import '../../base_designs/sitewide/design_main.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    this.onPasswordResetSuccess,
    this.onNavigateToLogin,
  });

  /// Optional callback invoked after successful password reset request.
  final VoidCallback? onPasswordResetSuccess;

  /// Optional callback when the user taps "Remembered your password? Log In".
  final VoidCallback? onNavigateToLogin;

  @override
  ForgotPasswordPageState createState() {
    return ForgotPasswordPageState();
  }
}

/// Stores the state and form data for ForgotPasswordPage
class ForgotPasswordPageState extends State<ForgotPasswordPage> {
  /// The key used to validate this form
  final formKey = GlobalKey<FormState>();

  /// The controller for the username field
  TextEditingController usernameController = TextEditingController();
  /// The controller for the reset code field
  TextEditingController codeController = TextEditingController();

  /// Whether a network or processing action is underway
  bool isLoading = false;
  /// The current error message displayed in the banner, if any
  String? errorMessage;

  /// Initializes state
  @override
  void initState() {
    super.initState();
  }

  /// Disposes controllers when finished, implemented when exiting page
  @override
  void dispose() {
    usernameController.dispose();
    codeController.dispose();
    super.dispose();
  }

  /// Sends the password reset code using the entered username
  Future<void> submitSendCodeForm() async {
    FocusScope.of(context).unfocus();

    if (usernameController.text.trim().isEmpty) {
      setState(() {
        errorMessage = 'Please enter your username';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final username = usernameController.text.trim();

    try {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset code sent for $username!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = 'An unexpected error occurred. Please try again.';
      setState(() => errorMessage = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  /// Validates the reset code input and completes the verification process
  Future<void> submitVerifyCodeForm() async {
    FocusScope.of(context).unfocus();

    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Code verified successfully!'),
          backgroundColor: Colors.green.shade700,
        ),
      );

      if (widget.onPasswordResetSuccess != null) {
        widget.onPasswordResetSuccess!();
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      final message = 'An unexpected error occurred during verification. Please try again.';
      setState(() => errorMessage = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  /// Handles navigation back to the login screen
  void navigateToLogin() {
    if (widget.onNavigateToLogin != null) {
      widget.onNavigateToLogin!();
      ///CHANGE
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// Builds the app icon (idk this was in kade's)
  Widget buildIcon() {
    final style = context.style;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        width: style.s(72),
        height: style.s(72),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.pets,
          size: style.s(40),
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  /// Builds the header titles
  Widget buildHeaderTitle() {
    final style = context.style;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Text(
          'Forgot Password',
          textAlign: TextAlign.center,
          style: style.textTheme.headlineMedium?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: style.spaceSmall),
        Text(
          'Enter your username to receive and verify your reset code.',
          textAlign: TextAlign.center,
          style: style.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Builds the error banner container if an error message exists
  Widget buildErrorBanner() {
    final style = context.style;
    final colorScheme = Theme.of(context).colorScheme;

    if (errorMessage == null) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(style.spaceSmall),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(style.radius),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: colorScheme.onErrorContainer,
            size: style.s(20),
          ),
          SizedBox(width: style.spaceSmall),
          Expanded(
            child: Text(
              errorMessage!,
              style: style.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the username input field
  Widget buildUsernameField() {
    return TextFormField(
      controller: usernameController,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.next,
      enabled: !isLoading,
      decoration: const InputDecoration(
        labelText: 'Username',
        hintText: 'Enter your username',
        prefixIcon: Icon(Icons.person_outline),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your username';
        }
        return null;
      },
    );
  }

  /// Builds the button used to request/send the reset code
  Widget buildSendCodeButton() {
    final style = context.style;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? null : submitSendCodeForm,
        child: Text(
          'Send Code',
          style: style.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Builds the reset code input field
  Widget buildCodeField() {
    return TextFormField(
      controller: codeController,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      enabled: !isLoading,
      onFieldSubmitted: (_) => submitVerifyCodeForm(),
      decoration: const InputDecoration(
        labelText: 'Reset Code',
        hintText: 'Enter code here',
        prefixIcon: Icon(Icons.lock_reset_outlined),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter the reset code';
        }
        if (value.trim().length < 4) {
          return 'Please enter a valid reset code';
        }
        return null;
      },
    );
  }

  /// Builds the button used to verify the entered code
  Widget buildVerifyCodeButton() {
    final style = context.style;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : submitVerifyCodeForm,
        child: isLoading
            ? SizedBox(
                height: style.s(20),
                width: style.s(20),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Verify Code',
                style: style.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  /// Builds back to login 
  Widget buildLoginNavigation() {
    final style = context.style;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Remembered your password?',
          style: style.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          onPressed: isLoading ? null : navigateToLogin,
          child: Text(
            'Log In',
            style: style.textTheme.bodyMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the form
  @override
  Widget build(BuildContext context) {
    // Access sitewide design variables from design_main.dart
    final style = context.style;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Responsive form container max width for medium and expanded screens
    final isCompact = style.screen == ScreenSize.compact;
    final maxCardWidth = isCompact ? double.infinity : 460.0;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: style.pageMargin,
              vertical: style.spaceLarge,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxCardWidth),
              child: Card(
                elevation: isCompact ? 0 : 2,
                color: isCompact ? Colors.transparent : null,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(style.radius),
                  side: isCompact
                      ? BorderSide.none
                      : BorderSide(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(
                    isCompact ? style.spaceSmall : style.spaceLarge,
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        buildIcon(),
                        SizedBox(height: style.spaceMedium),
                        buildHeaderTitle(),
                        SizedBox(height: style.spaceLarge),
                        buildErrorBanner(),
                        if (errorMessage != null)
                          SizedBox(height: style.spaceMedium),
                        buildUsernameField(),
                        SizedBox(height: style.spaceMedium),
                        buildSendCodeButton(),
                        SizedBox(height: style.spaceLarge),
                        buildCodeField(),
                        SizedBox(height: style.spaceMedium),
                        buildVerifyCodeButton(),
                        SizedBox(height: style.spaceMedium),
                        buildLoginNavigation(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}