import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../base_designs/sitewide/design_main.dart';
import '../../services/auth_service.dart';

/// The sign-up screen for Tiger Den.
///
/// TODO: Add Checkbox for Terms and Conditions acceptance.
class SignUpPage extends StatefulWidget {
  const SignUpPage({
    super.key,
    this.onSignUpSuccess,
    this.onNavigateToLogin,
    this.authService,
  });

  /// Optional callback invoked after successful sign-up and profile creation.
  final VoidCallback? onSignUpSuccess;

  /// Optional callback when the user taps "Already have an account? Log In".
  final VoidCallback? onNavigateToLogin;

  /// Optional custom [AuthService] instance (useful for testing/mocking).
  final AuthService? authService;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

/// Backwards compatibility aliases
typedef SignupPage = SignUpPage;
typedef SignUpScreen = SignUpPage;

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late final AuthService _authService;

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitSignUpForm() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final fullName = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Parse name into first and last name components
    final nameParts = fullName.split(RegExp(r'\s+'));
    final firstName = nameParts.isNotEmpty ? nameParts.first : fullName;
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    final username = email.contains('@')
        ? email.split('@').first
        : fullName.toLowerCase().replaceAll(RegExp(r'\s+'), '_');

    try {
      await _authService.signUp(
        email: email,
        password: password,
        username: username,
        displayName: fullName,
        firstName: firstName,
        lastName: lastName,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account created successfully for $fullName!'),
          backgroundColor: Colors.green.shade700,
        ),
      );

      if (widget.onSignUpSuccess != null) {
        widget.onSignUpSuccess!();
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'An account already exists for this email address.';
          break;
        case 'invalid-email':
          message = 'The email address is not valid.';
          break;
        case 'operation-not-allowed':
          message = 'Email/password sign-up is currently disabled.';
          break;
        case 'weak-password':
          message = 'The password is too weak. Please use at least 6 characters.';
          break;
        default:
          message = e.message ?? 'Sign-up failed. Please try again.';
      }

      if (!mounted) return;
      setState(() => _errorMessage = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = 'An unexpected error occurred during sign up. Please try again.';
      setState(() => _errorMessage = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleNavigateToLogin() {
    if (widget.onNavigateToLogin != null) {
      widget.onNavigateToLogin!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

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
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // App Icon / Branding
                        Center(
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
                        ),
                        SizedBox(height: style.spaceMedium),

                        // Title & Subtitle
                        Text(
                          'Join Tiger Den',
                          textAlign: TextAlign.center,
                          style: style.textTheme.headlineMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: style.spaceSmall),
                        Text(
                          'Create your account to connect and discover events.',
                          textAlign: TextAlign.center,
                          style: style.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: style.spaceLarge),

                        // Error Banner (if any)
                        if (_errorMessage != null) ...[
                          Container(
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
                                    _errorMessage!,
                                    style: style.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: style.spaceMedium),
                        ],

                        // Name Field
                        TextFormField(
                          controller: _nameController,
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          enabled: !_isLoading,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            hintText: 'Jane Doe',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your full name';
                            }
                            if (value.trim().length < 2) {
                              return 'Name must be at least 2 characters';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: style.spaceMedium),

                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          enabled: !_isLoading,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            hintText: 'user@example.com',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email address';
                            }
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(value.trim())) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: style.spaceMedium),

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          textInputAction: TextInputAction.done,
                          enabled: !_isLoading,
                          onFieldSubmitted: (_) => _submitSignUpForm(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Create a password (min. 6 characters)',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                              tooltip: _isPasswordVisible
                                  ? 'Hide password'
                                  : 'Show password',
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please create a password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: style.spaceLarge),

                        // Sign Up Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitSignUpForm,
                            child: _isLoading
                                ? SizedBox(
                                    height: style.s(20),
                                    width: style.s(20),
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Create Account',
                                    style: style.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(height: style.spaceMedium),

                        // Back to Login Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account?',
                              style: style.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            TextButton(
                              onPressed: _isLoading ? null : _handleNavigateToLogin,
                              child: Text(
                                'Log In',
                                style: style.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
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

