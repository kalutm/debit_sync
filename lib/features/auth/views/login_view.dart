import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';

// ── Local form-state model ─────────────────────────────────────────────────────

enum _AuthMode { signIn, signUp }

// ── View ───────────────────────────────────────────────────────────────────────

/// Full-screen authentication view supporting Email/Password Sign-In,
/// account creation, and Google Sign-In.
///
/// Uses [ConsumerStatefulWidget] so that form controllers, loading flags, and
/// the sign-in/sign-up toggle are kept as genuinely local (ephemeral) UI state
/// while the [AuthRepository] is injected via Riverpod.
///
/// On successful authentication [authStateProvider] emits a non-null user,
/// which triggers [appRouterProvider]'s redirect guard to navigate automatically
/// to [AppRoutes.home] — no explicit navigation call is needed here.
class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView>
    with SingleTickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────────────────────

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  // ── Local state ───────────────────────────────────────────────────────────────

  _AuthMode _mode = _AuthMode.signIn;
  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

  bool get _isAnyLoading => _isEmailLoading || _isGoogleLoading;

  // ── Lifecycle ─────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // ── Handlers ──────────────────────────────────────────────────────────────────

  void _toggleMode() {
    setState(() {
      _mode = _mode == _AuthMode.signIn ? _AuthMode.signUp : _AuthMode.signIn;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _handleEmailAuth() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isEmailLoading = true);

    try {
      final repo = ref.read(authRepositoryProvider);

      if (_mode == _AuthMode.signIn) {
        await repo.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await repo.createAccount(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );
      }
      // Success: GoRouter redirect guard fires automatically.
    } on FirebaseAuthException catch (e) {
      _showError(_friendlyAuthMessage(e));
    } catch (e) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isEmailLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);

    try {
      final result = await ref.read(authRepositoryProvider).signInWithGoogle();
      if (result == null && mounted) {
        // User cancelled the picker — no error shown, just restore state.
        setState(() => _isGoogleLoading = false);
      }
      // Success: GoRouter redirect guard fires automatically.
    } on FirebaseAuthException catch (e) {
      _showError(_friendlyAuthMessage(e));
    } catch (e) {
      _showError('Google Sign-In failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  /// Converts a [FirebaseAuthException] code into a human-readable message.
  String _friendlyAuthMessage(FirebaseAuthException e) {
    return switch (e.code) {
      'invalid-email' => 'That email address is not valid.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' => 'No account found for this email.',
      'wrong-password' => 'Incorrect password. Please try again.',
      'invalid-credential' => 'Incorrect email or password.',
      'email-already-in-use' => 'An account already exists for this email.',
      'weak-password' => 'Password must be at least 6 characters.',
      'operation-not-allowed' => 'This sign-in method is not enabled.',
      'too-many-requests' => 'Too many attempts. Please wait and try again.',
      'network-request-failed' => 'No internet connection.',
      _ => e.message ?? 'Authentication failed.',
    };
  }

  // ── Validators ────────────────────────────────────────────────────────────────

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required.';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email address.';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required.';
    if (v.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Name is required.';
    if (v.trim().length < 2) return 'Name must be at least 2 characters.';
    return null;
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isSignUp = _mode == _AuthMode.signUp;

    return Scaffold(
      // No AppBar — full-bleed design.
      body: Stack(
        children: [
          // ── Background gradient ──────────────────────────────────────────────
          _SolidBackground(colorScheme: colorScheme),

          // ── Scrollable content ───────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── App logo & title ───────────────────────────────────
                      _AppHeader(
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: 40),

                      // ── Form card ──────────────────────────────────────────
                      _FormCard(
                        colorScheme: colorScheme,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Mode label
                              Text(
                                isSignUp ? 'Create Account' : 'Welcome back',
                                style: textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isSignUp
                                    ? 'Sign up to start tracking debts with friends.'
                                    : 'Sign in to your DebitSync account.',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.outline,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Name field (sign-up only) with AnimatedSize
                              AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                child: isSignUp
                                    ? Column(
                                        children: [
                                          _FieldLabel(
                                            label: 'Full Name',
                                            colorScheme: colorScheme,
                                          ),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            controller: _nameController,
                                            enabled: !_isAnyLoading,
                                            textCapitalization:
                                                TextCapitalization.words,
                                            textInputAction:
                                                TextInputAction.next,
                                            decoration: _inputDecoration(
                                              hint: 'Your full name',
                                              icon: Icons.person_outline,
                                              colorScheme: colorScheme,
                                            ),
                                            validator: _validateName,
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      )
                                    : const SizedBox.shrink(),
                              ),

                              // Email
                              _FieldLabel(
                                label: 'Email Address',
                                colorScheme: colorScheme,
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _emailController,
                                enabled: !_isAnyLoading,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                decoration: _inputDecoration(
                                  hint: 'Your email',
                                  icon: Icons.email_outlined,
                                  colorScheme: colorScheme,
                                ),
                                validator: _validateEmail,
                              ),
                              const SizedBox(height: 16),

                              // Password
                              _FieldLabel(
                                label: 'Password',
                                colorScheme: colorScheme,
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _passwordController,
                                enabled: !_isAnyLoading,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleEmailAuth(),
                                decoration:
                                    _inputDecoration(
                                      hint: isSignUp
                                          ? 'Min. 6 characters'
                                          : 'Your password',
                                      icon: Icons.lock_outline,
                                      colorScheme: colorScheme,
                                    ).copyWith(
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: colorScheme.outline,
                                        ),
                                        onPressed: () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                      ),
                                    ),
                                validator: _validatePassword,
                              ),
                              const SizedBox(height: 28),

                              // Primary CTA button
                              _PrimaryButton(
                                label: isSignUp ? 'Create Account' : 'Sign In',
                                isLoading: _isEmailLoading,
                                isDisabled: _isGoogleLoading,
                                onPressed: _handleEmailAuth,
                                colorScheme: colorScheme,
                              ),
                              const SizedBox(height: 20),

                              // Divider
                              _OrDivider(colorScheme: colorScheme),
                              const SizedBox(height: 20),

                              // Google Sign-In button
                              _GoogleButton(
                                isLoading: _isGoogleLoading,
                                isDisabled: _isEmailLoading,
                                onPressed: _handleGoogleSignIn,
                                colorScheme: colorScheme,
                              ),
                              const SizedBox(height: 24),

                              // Mode toggle
                              _ModeToggle(
                                isSignUp: isSignUp,
                                onToggle: _isAnyLoading ? null : _toggleMode,
                                colorScheme: colorScheme,
                                textTheme: textTheme,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required ColorScheme colorScheme,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: colorScheme.primary.withAlpha(180)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────
// Broken into private widgets to keep build() readable and to enable
// fine-grained rebuilds.

class _SolidBackground extends StatelessWidget {
  const _SolidBackground({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final isDark = colorScheme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface
            : colorScheme.surfaceContainerLowest,
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(isDark ? 50 : 30),
        ),
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({required this.colorScheme, required this.textTheme});

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Icon container with glow effect
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(
                  colorScheme.brightness == Brightness.dark ? 55 : 10,
                ),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Image.asset('assets/logo.png', width: 20.0, height: 20),
        ),
        const SizedBox(height: 20),
        Text(
          'DebitSync',
          style: textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Zero-trust P2P debt tracking',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.outline,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.colorScheme, required this.child});

  final ColorScheme colorScheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = colorScheme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withAlpha(200)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(isDark ? 60 : 40),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 60 : 15),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.colorScheme});

  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.isDisabled,
    required this.onPressed,
    required this.colorScheme,
  });

  final String label;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final buttonColor = isDisabled || isLoading
        ? colorScheme.primary.withAlpha(140)
        : colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: buttonColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDisabled || isLoading
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(12),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: FilledButton(
        onPressed: (isLoading || isDisabled) ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isLoading
              ? SizedBox(
                  key: const ValueKey('loading'),
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colorScheme.onPrimary,
                  ),
                )
              : Text(
                  key: ValueKey(label),
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(color: colorScheme.outlineVariant, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.outline,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: colorScheme.outlineVariant, thickness: 1),
        ),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({
    required this.isLoading,
    required this.isDisabled,
    required this.onPressed,
    required this.colorScheme,
  });

  final bool isLoading;
  final bool isDisabled;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: (isLoading || isDisabled) ? null : onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1.5),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isLoading
            ? SizedBox(
                key: const ValueKey('g_loading'),
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colorScheme.primary,
                ),
              )
            : Row(
                key: const ValueKey('g_label'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google "G" mark — coloured circle with bold G
                  Image.asset('assets/google_logo.png', height: 20.0),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.isSignUp,
    required this.onToggle,
    required this.colorScheme,
    required this.textTheme,
  });

  final bool isSignUp;
  final VoidCallback? onToggle;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isSignUp ? 'Already have an account?' : "Don't have an account?",
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onToggle,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: textTheme.bodyMedium!.copyWith(
              color: onToggle != null
                  ? colorScheme.primary
                  : colorScheme.primary.withAlpha(100),
              fontWeight: FontWeight.w700,
            ),
            child: Text(isSignUp ? 'Sign In' : 'Sign Up'),
          ),
        ),
      ],
    );
  }
}
