import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../base_designs/sitewide/design_main.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    this.onPasswordResetSuccess,
    this.onNavigateToLogin,
  });

  ///Optional callback invoked after successful password reset request.
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
  ///The key used to validate this form
  final formKey = GlobalKey<FormState>();
  ///auth_service for password reset logic
  AuthService authService = AuthService();
  /// The controller for the email field
  TextEditingController emailController = TextEditingController();


  ///Whether we are done loading or not
  bool isLoading = false;
  ///The current error message displayed in the banner
  String? errorMessage;


  

  /// Initializes state
  @override
  void initState() {
    super.initState();
  }

  /// Disposes controllers when finished, implemented when exiting page
  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }


  
  /// Sends the password reset link using the entered email
  Future<void> submitSendLinkForm() async {
    FocusScope.of(context).unfocus();
    if (!formKey.currentState!.validate()) return;
    if (emailController.text.trim().isEmpty) {
      setState(() {
        errorMessage = 'Please enter your email';
      });
      return;
    } else if (!authService.getEmailPattern().hasMatch(emailController.text.trim())){
      setState(() {
        errorMessage = 'Please enter a valid email';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final email = emailController.text.trim();

    try {
      await authService.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset link sent for $email, if an account exists for it.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = 'Error: $e\nAn unexpected error occurred. Please try again.';
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


  ///Handles navigation back to the login screen
  void navigateToLogin() {
    if (widget.onNavigateToLogin != null) {
      widget.onNavigateToLogin!();
      ///CHANGE
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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

  ///Builds the app icon (idk this was in kade's)
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
          'Enter your email to reset your password and send the reset-password link to your email.',
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

  ///Builds the email input field
  Widget buildEmailField() {
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      enabled: !isLoading,
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 16,
      ),
      cursorColor: colorScheme.primary,
      decoration: const InputDecoration(
        labelText: 'Email',
        hintText: 'Enter your email',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.person_outline),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your email';
        }
        return null;
      },
    );
  }

  /// Builds the button used to request/send the reset link
  Widget buildSendLinkButton() {
    final style = context.style;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? null : submitSendLinkForm,
        child: Text(
          'Send Reset Link',
          style: style.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

 

  /// Builds the form
  @override
  Widget build(BuildContext context) { 
    final style = context.style;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                        buildEmailField(),
                        SizedBox(height: style.spaceMedium),
                        buildSendLinkButton(),
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