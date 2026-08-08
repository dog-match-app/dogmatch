import 'package:dogmatch/core/utils/date_input.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _value(String text, [int? offset]) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset ?? text.length),
    );

void main() {
  group('BrDateInputFormatter', () {
    late BrDateInputFormatter formatter;

    setUp(() => formatter = BrDateInputFormatter());

    TextEditingValue type(String oldText, String newText) =>
        formatter.formatEditUpdate(_value(oldText), _value(newText));

    test('digitação progressiva insere as barras após dia e mês', () {
      var result = type('', '1');
      expect(result.text, '1');
      expect(result.selection.baseOffset, 1);

      result = type('1', '12');
      expect(result.text, '12/');
      expect(result.selection.baseOffset, 3);

      result = type('12/', '12/0');
      expect(result.text, '12/0');
      expect(result.selection.baseOffset, 4);

      result = type('12/0', '12/08');
      expect(result.text, '12/08/');
      expect(result.selection.baseOffset, 6);

      result = type('12/08/', '12/08/2');
      expect(result.text, '12/08/2');
      expect(result.selection.baseOffset, 7);

      result = type('12/08/2', '12/08/2024');
      expect(result.text, '12/08/2024');
      expect(result.selection.baseOffset, 10);
    });

    test('apagar remove a barra automática sem reinseri-la', () {
      // Backspace em "12/" (a barra some e o cursor fica após o "2").
      var result = type('12/', '12');
      expect(result.text, '12');
      expect(result.selection.baseOffset, 2);

      // Backspace em "12/08/".
      result = type('12/08/', '12/08');
      expect(result.text, '12/08');
      expect(result.selection.baseOffset, 5);

      // Backspace num dígito comum ("12/08" → "12/0").
      result = type('12/08', '12/0');
      expect(result.text, '12/0');
      expect(result.selection.baseOffset, 4);

      // Apagar tudo.
      result = type('12/08/2024', '');
      expect(result.text, '');
      expect(result.selection.baseOffset, 0);
    });

    test('colar apenas dígitos formata a data completa', () {
      final result = type('', '12082020');
      expect(result.text, '12/08/2020');
      expect(result.selection.baseOffset, 10);
    });

    test('ignora não dígitos e limita a 10 caracteres', () {
      var result = type('', '12a/08.2020xyz');
      expect(result.text, '12/08/2020');

      // Dígito extra além de dd/MM/yyyy é descartado.
      result = type('12/08/2020', '12/08/20205');
      expect(result.text, '12/08/2020');
      expect(result.selection.baseOffset, 10);
    });
  });

  group('tryParseBrDate', () {
    test('aceita data válida de calendário', () {
      expect(tryParseBrDate('12/08/2020'), DateTime(2020, 8, 12));
    });

    test('aceita 29/02 em ano bissexto', () {
      expect(tryParseBrDate('29/02/2024'), DateTime(2024, 2, 29));
    });

    test('rejeita 29/02 fora de ano bissexto', () {
      expect(tryParseBrDate('29/02/2023'), isNull);
    });

    test('rejeita datas inexistentes no calendário', () {
      expect(tryParseBrDate('31/02/2024'), isNull);
      expect(tryParseBrDate('31/04/2024'), isNull);
      expect(tryParseBrDate('00/05/2024'), isNull);
      expect(tryParseBrDate('15/13/2024'), isNull);
      expect(tryParseBrDate('15/00/2024'), isNull);
    });

    test('rejeita texto incompleto ou fora da máscara', () {
      expect(tryParseBrDate(''), isNull);
      expect(tryParseBrDate('12/08'), isNull);
      expect(tryParseBrDate('12/08/20'), isNull);
      expect(tryParseBrDate('1/8/2020'), isNull);
      expect(tryParseBrDate('aa/bb/cccc'), isNull);
    });

    test('não rejeita futuro — a regra fica com o chamador', () {
      final future = DateTime.now().add(const Duration(days: 365 * 2));
      final parsed = tryParseBrDate(formatBrDate(future));
      expect(parsed, isNotNull);
      expect(parsed!.isAfter(DateTime.now()), isTrue);
    });
  });

  group('formatBrDate', () {
    test('formata com zeros à esquerda', () {
      expect(formatBrDate(DateTime(2024, 2, 5)), '05/02/2024');
      expect(formatBrDate(DateTime(1995, 12, 31)), '31/12/1995');
    });
  });
}
