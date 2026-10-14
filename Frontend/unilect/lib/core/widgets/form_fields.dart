import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Password input with show/hide toggle and accessible labels.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
    this.errorText,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String> autofillHints;
  final String? errorText;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      enableSuggestions: false,
      autocorrect: false,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _obscure ? l.showPassword : l.hidePassword,
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

/// Shared validators returning localized messages.
abstract final class Validators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? Function(String?) required(BuildContext context) =>
      (v) =>
          (v == null || v.trim().isEmpty) ? context.l10n.fieldRequired : null;

  static String? Function(String?) email(BuildContext context) => (v) {
    if (v == null || v.trim().isEmpty) return context.l10n.fieldRequired;
    return _email.hasMatch(v.trim()) ? null : context.l10n.emailInvalid;
  };

  static String? Function(String?) minLength(BuildContext context, int n) =>
      (v) {
        if (v == null || v.trim().isEmpty) return context.l10n.fieldRequired;
        return v.trim().length < n ? context.l10n.minChars(n) : null;
      };

  /// Mirrors the server's main password rules (min 10 characters, not only
  /// digits); the server also rejects common passwords and ones similar to
  /// the account's details.
  static String? Function(String?) newPassword(BuildContext context) => (v) {
    if (v == null || v.isEmpty) return context.l10n.fieldRequired;
    final weak = v.length < 10 || RegExp(r'^\d+$').hasMatch(v);
    return weak ? context.l10n.passwordRules : null;
  };
}
