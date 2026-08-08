import 'package:flutter/services.dart';

/// Máscara de data BR (`dd/mm/aaaa`) para campos de texto.
///
/// Aceita apenas dígitos, insere `/` automaticamente após o dia e o mês
/// (`12` → `12/`, `1208` → `12/08/`), limita a 10 caracteres e mantém o
/// cursor coerente tanto ao digitar quanto ao apagar (ao apagar, a barra
/// final não é reinserida — senão seria impossível voltar).
class BrDateInputFormatter extends TextInputFormatter {
  static final RegExp _nonDigits = RegExp(r'[^0-9]');

  /// Quantidade máxima de dígitos de `ddmmaaaa`.
  static const int _maxDigits = 8;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final rawDigits = newValue.text.replaceAll(_nonDigits, '');
    final digits = rawDigits.length > _maxDigits
        ? rawDigits.substring(0, _maxDigits)
        : rawDigits;
    final isDeleting = newValue.text.length < oldValue.text.length;

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      final completesDayOrMonth = i == 1 || i == 3;
      final isLastDigit = i == digits.length - 1;
      // Barra automática após dia/mês completos; ao apagar, a barra final
      // fica de fora para o backspace conseguir remover o dígito anterior.
      if (completesDayOrMonth && (!isLastDigit || !isDeleting)) {
        buffer.write('/');
      }
    }
    final text = buffer.toString();

    // Cursor: conta os dígitos antes do cursor no valor cru e reposiciona
    // após o mesmo dígito no texto formatado. Ao digitar, o cursor pula a
    // barra recém-inserida; ao apagar, permanece antes dela.
    final selectionEnd = newValue.selection.end.clamp(0, newValue.text.length);
    var digitsBeforeCursor = 0;
    for (var i = 0; i < selectionEnd; i++) {
      if (!_nonDigits.hasMatch(newValue.text[i])) digitsBeforeCursor++;
    }
    if (digitsBeforeCursor > _maxDigits) digitsBeforeCursor = _maxDigits;

    var offset = digitsBeforeCursor;
    if (isDeleting) {
      if (digitsBeforeCursor > 2) offset++;
      if (digitsBeforeCursor > 4) offset++;
    } else {
      if (digitsBeforeCursor >= 2) offset++;
      if (digitsBeforeCursor >= 4) offset++;
    }
    if (offset > text.length) offset = text.length;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// Parse estrito de `dd/MM/yyyy`.
///
/// Devolve `null` para textos incompletos e para datas inexistentes no
/// calendário (`31/02/2024`, mês 13 etc.). Não rejeita datas futuras — essa
/// regra fica com o chamador (validators têm mensagens próprias).
DateTime? tryParseBrDate(String input) {
  final match =
      RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(input.trim());
  if (match == null) return null;
  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  if (day < 1 || month < 1 || month > 12) return null;
  final date = DateTime(year, month, day);
  // DateTime "rola" datas inválidas (31/02 → 03/03); se rolou, era inválida.
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

/// Formata [date] como `dd/MM/yyyy` (inverso de [tryParseBrDate]).
String formatBrDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString().padLeft(4, '0');
  return '$day/$month/$year';
}
