import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
   //Global key
   final _formKey = GlobalKey<FormState>();

  // TextEditingController to get email and password values
    final TextEditingController _emailController = TextEditingController();
    final TextEditingController _passwordController = TextEditingController();

  @override
  // Wiping data when the widget is destroyed
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLoginForm() async {
    // Validates form, still need to link to Firebase when ready
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
    }
  }

  @override
  //building the actual page now
  Widget build(BuildContext context) {
    
  }

}