import 'package:flutter/material.dart';
import 'package:nino/widgets/background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  SignUpScreenState createState() => SignUpScreenState();
}

class SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;

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

  Future<void> signUpUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      final response = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        data: {
          'name': nameController.text.trim(),
          'phone': phoneController.text.trim(),
        },
      );

      if (!mounted) return;

      if (response.user != null) {
        // If you already have a DB trigger that creates profiles, you can remove this upsert.
        await supabase.from('profiles').upsert({
          'id': response.user!.id,
          'name': nameController.text.trim(),
          'phone_number': phoneController.text.trim(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Account created successfully!')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('❌ Signup failed')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('⚠ Error: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Background(),
          SafeArea(
            child: Form(
              key: _formKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Create Your Account",
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color.fromRGBO(0, 145, 110, 1),
                              ),
                            ),
                            const SizedBox(height: 24),

                            TextFormField(
                              controller: nameController,
                              decoration: _inputDecoration("Name"),
                              validator: (val) => val != null && val.isNotEmpty
                                  ? null
                                  : "Name is required",
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: _inputDecoration("Phone Number"),
                              validator: (val) => val != null && val.length > 5
                                  ? null
                                  : "Invalid phone number",
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDecoration("Email"),
                              validator: (val) => val != null && val.contains("@")
                                  ? null
                                  : "Invalid email",
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: passwordController,
                              obscureText: true,
                              decoration: _inputDecoration("Password"),
                              validator: (val) => val != null && val.length >= 6
                                  ? null
                                  : "Password must be at least 6 characters",
                            ),

                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : signUpUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color.fromRGBO(246, 251, 250, 1),
                                  foregroundColor:
                                      const Color.fromRGBO(0, 145, 110, 1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: isLoading
                                    ? const CircularProgressIndicator(
                                        color: Color.fromRGBO(0, 145, 110, 1),
                                      )
                                    : const Text(
                                        'Sign Up',
                                        style: TextStyle(fontSize: 18),
                                      ),
                              ),
                            ),

                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                "Already have an account? Log in",
                                style: TextStyle(
                                  color: Color.fromRGBO(0, 145, 110, 1),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}