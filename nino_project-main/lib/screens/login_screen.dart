import 'package:flutter/material.dart';
import 'package:nino/screens/main_shell.dart';
import 'package:nino/widgets/background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String email = '', password = '';
  bool isLoading = false;

  Future<void> _showErrorDialog(String title, String message) async {
    if (!mounted) return;

    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  String _friendlyAuthErrorMessage(Object e) {
    final msg = e.toString().toLowerCase();

    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials') ||
        (msg.contains('invalid') && msg.contains('credentials'))) {
      return "Wrong email or password. Please try again.";
    }

    if (msg.contains('email not confirmed')) {
      return "Your email is not confirmed. Please check your inbox and confirm your email.";
    }

    if (msg.contains('user not found')) {
      return "No account found with this email.";
    }

    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('timeout')) {
      return "Connection problem. Please check your internet and try again.";
    }

    if (msg.contains('rate limit') || msg.contains('too many requests')) {
      return "Too many attempts. Please wait a moment and try again.";
    }

    return "Login failed. Please try again.";
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (res.user != null) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Success"),
            content: const Text("Login successful ✅"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Continue"),
              ),
            ],
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    } catch (e) {
      final friendly = _friendlyAuthErrorMessage(e);
      await _showErrorDialog("Login Failed", friendly);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withOpacity(0.9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color.fromRGBO(0, 145, 110, 1),
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 2,
        ),
      ),
      labelStyle: const TextStyle(
        color: Color.fromRGBO(0, 145, 110, 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Background(),
          Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Welcome Back!",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(0, 145, 110, 1),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    decoration: _inputDecoration("Email"),
                    validator: (val) =>
                        val != null && val.contains("@")
                            ? null
                            : "Invalid email",
                    onChanged: (val) => email = val,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: _inputDecoration("Password"),
                    obscureText: true,
                    validator: (val) =>
                        val != null && val.length >= 6
                            ? null
                            : "Password too short",
                    onChanged: (val) => password = val,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(246, 251, 250, 1),
                        foregroundColor: const Color.fromRGBO(0, 145, 110, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(
                              color: Color.fromRGBO(0, 145, 110, 1),
                            )
                          : const Text(
                              "Login",
                              style: TextStyle(fontSize: 18),
                            ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/signup');
                    },
                    child: const Text(
                      "Don't have an account? Sign up",
                      style: TextStyle(
                        color: Color.fromRGBO(0, 145, 110, 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}