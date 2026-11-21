
import 'package:material_ui/material_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';
import 'auth_service.dart';
import 'change_password_screen.dart';
import 'admin/admin_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;

  Future<void> _register() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Member Registration'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email / Login ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Register'),
          ),
        ],
      ),
    );
    if (result != true) return;
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    if (name.isEmpty || !email.contains('@') || password.length < 12) {
      _showMessage(
        'Enter a valid name, email and password of at least 12 characters.',
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email,
        'role': 'member',
        'accountStatus': 'pending',
        'approvalStatus': 'pending',
        'mustChangePassword': false,
        'locked': false,
        'registeredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      _showMessage(
        'Registration submitted. Wait for administrator approval.',
      );
    } on FirebaseAuthException catch (error) {
      _showMessage(error.message ?? 'Registration failed.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    final email = _loginController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter Login ID and Password.');
      return;
    }

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
      final member = await AuthService.instance.getCurrentMember();
      if (member == null) {
        await FirebaseAuth.instance.signOut();
        _showMessage('This account is not registered in the application.');
        return;
      }
      if (member.locked) {
        await FirebaseAuth.instance.signOut();
        _showMessage(
          'Your account is locked. Please contact the administrator.',
        );
        return;
      }
      if (member.accountStatus == 'pending' ||
          member.approvalStatus == 'pending') {
        await FirebaseAuth.instance.signOut();
        _showMessage('Your registration is pending administrator approval.');
        return;
      }
      if (member.accountStatus == 'suspended' ||
          member.accountStatus == 'rejected' ||
          member.approvalStatus == 'rejected') {
        await FirebaseAuth.instance.signOut();
        _showMessage('Your account is not approved for application access.');
        return;
      }
      await AuthService.instance.recordLoginActivity(member.uid);
      if (!mounted) return;
      if (member.mustChangePassword) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ChangePasswordScreen(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                member.isAdmin ? const AdminDashboard() : const HomeScreen(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final generic = switch (e.code) {
        'invalid-credential' ||
        'invalid-email' ||
        'user-disabled' ||
        'too-many-requests' ||
        'network-request-failed' => 'Login failed. Check your credentials and try again.',
        _ => 'Login failed. Please try again.',
      };
      _showMessage(generic);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      final message = switch (e.plugin) {
        'cloud_firestore' =>
          'Account profile could not be loaded. Network or authorization error: ${e.code}.',
        'cloud_functions' =>
          'Secure account service error: ${e.code}.',
        _ => 'Firebase error: ${e.code}.',
      };
      _showMessage(message);
    } catch (e) {
      if (!mounted) return;
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      _showMessage('Something went wrong: ${e.runtimeType}.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEB),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 4,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.how_to_vote_rounded,
                    size: 65,
                    color: Color(0xFFEAB308),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'TDP Voter Search',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Login to Continue',
                    style: TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _loginController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Login ID',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD600),
                        foregroundColor: const Color(0xFF111827),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator()
                          : const Text(
                              'LOGIN',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loading ? null : _register,
                    child: const Text('Register as a member'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
