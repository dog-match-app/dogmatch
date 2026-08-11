import 'package:flutter/material.dart';

/// Campo de texto padrão do app, com alternância de visibilidade para senhas.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.fieldKey,
    this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.prefixIcon,
    this.maxLines = 1,
    this.enabled = true,
    this.onFieldSubmitted,
  });

  /// Key do [TextFormField] interno — permite ao form consultar o
  /// [FormFieldState] (ex.: rolar até o primeiro campo com erro).
  final GlobalKey<FormFieldState<String>>? fieldKey;

  final TextEditingController? controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final int maxLines;
  final bool enabled;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final obscured = widget.obscureText && _obscured;
    return TextFormField(
      key: widget.fieldKey,
      controller: widget.controller,
      obscureText: obscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      validator: widget.validator,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      enabled: widget.enabled,
      onFieldSubmitted: widget.onFieldSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
        suffixIcon: widget.obscureText
            ? IconButton(
                tooltip: obscured ? 'Mostrar senha' : 'Ocultar senha',
                icon: Icon(
                  obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : null,
      ),
    );
  }
}
