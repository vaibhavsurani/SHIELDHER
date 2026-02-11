import 'package:flutter/material.dart';
import 'package:shieldher/services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  final void Function()? onTap;
  const SignupScreen({super.key, this.onTap});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  String? _passwordError;
  String? _usernameError;
  bool _isLoading = false;

  void _validatePasswordRealtime(String password) {
    setState(() {
      _passwordError = AuthService.validatePassword(password);
    });
  }

  void signup() async {
    // Validate all fields
    if (_nameController.text.trim().isEmpty ||
        _usernameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text("Missing Fields"),
          content: Text("Please fill in all the details to continue."),
        ),
      );
      return;
    }

    // Validate username format
    final username = _usernameController.text.trim();
    if (username.length < 3) {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text("Invalid Username"),
          content: Text("Username must be at least 3 characters."),
        ),
      );
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text("Invalid Username"),
          content: Text("Username can only contain letters, numbers, and underscores."),
        ),
      );
      return;
    }

    // Validate password strength
    final passwordError = AuthService.validatePassword(_passwordController.text);
    if (passwordError != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Weak Password"),
          content: Text(passwordError),
        ),
      );
      return;
    }

    // Make sure passwords match
    if (_passwordController.text != _confirmPasswordController.text) {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text("Passwords Mismatch"),
          content: Text("The passwords you entered do not match."),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signUpWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
        _phoneController.text.trim(),
        _usernameController.text.trim(),
      );
      if (mounted) {
        setState(() => _isLoading = false);
        // Show verification email sent message
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Account Created!"),
            content: const Text(
              "Please check your email for a verification link to complete your registration.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Pop dialog
                  Navigator.pop(context); // Go back to login
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Error"),
            content: Text(e.toString()),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: Stack(
            children: [
              // Top decorative curve (Smaller on signup to fit more content)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 200,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFC2185B), Color(0xFFAD1457)], // Updated to match navbar dark pinks
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                              // Small logo in header
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  'assets/logo.png',
                                  height: 40,
                                  width: 40,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                          ),
                          // Removed SizedBox to pull text up
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 10), 
                              child: Text(
                                "Create Account",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Signup Form
              Positioned(
                top: 140, // Reverted to 140 as requested (don't move the box)
                left: 20,
                right: 20,
                bottom: 20, 
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        _buildTextField(
                          controller: _nameController,
                          hint: "Full Name",
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 16),
                        
                        // Username
                        _buildTextField(
                          controller: _usernameController,
                          hint: "Username",
                          icon: Icons.alternate_email,
                          errorText: _usernameError,
                          helperText: "Used for invites",
                          onChanged: (value) {
                            setState(() {
                              if (value.length > 0 && value.length < 3) {
                                _usernameError = 'Min 3 chars';
                              } else if (!RegExp(r'^[a-zA-Z0-9_]*$').hasMatch(value)) {
                                _usernameError = 'Letters, numbers, _ only';
                              } else {
                                _usernameError = null;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Email
                        _buildTextField(
                          controller: _emailController,
                          hint: "Email",
                          icon: Icons.email_outlined,
                          inputType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        
                        // Phone
                        _buildTextField(
                          controller: _phoneController,
                          hint: "Phone Number",
                          icon: Icons.phone_outlined,
                          inputType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        
                        // Password
                        _buildTextField(
                          controller: _passwordController,
                          hint: "Password",
                          icon: Icons.lock_outline,
                          isPassword: true,
                          errorText: _passwordError,
                          onChanged: _validatePasswordRealtime,
                        ),
                        const SizedBox(height: 16),
                        
                        // Confirm Password
                        _buildTextField(
                          controller: _confirmPasswordController,
                          hint: "Confirm Password",
                          icon: Icons.lock_outline,
                          isPassword: true,
                        ),
                        const SizedBox(height: 30),
                  
                        // Sign Up Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : signup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC2185B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    "Sign Up",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Google Sign Up
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                               try {
                                 await _authService.signInWithGoogle();
                                 // AuthGate handles navigation
                               } catch (e) {
                                 if (mounted) {
                                   ScaffoldMessenger.of(context).showSnackBar(
                                     SnackBar(content: Text("Google Sign-In Error: $e")),
                                   );
                                 }
                               }
                            },
                            icon: Image.network(
                              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
                               height: 20,
                            ),
                            label: const Text(
                              "Sign up with Google",
                              style: TextStyle(color: Colors.black87),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                              side: const BorderSide(color: Color(0xFFEEEEEE)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        
                        // Login Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Already have an account? ",
                              style: TextStyle(color: Colors.grey),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                              },
                              child: const Text(
                                "Login",
                                style: TextStyle(
                                  color: Color(0xFFC2185B),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType inputType = TextInputType.text,
    String? errorText,
    String? helperText,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: inputType,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.black87), // Fix white text issue
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade600),
            prefixIcon: Icon(icon, color: const Color(0xFFC2185B)),
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            errorText: errorText,
            helperText: helperText,
            helperStyle: const TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }
}
