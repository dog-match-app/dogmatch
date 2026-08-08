import 'package:dogmatch/core/utils/telegram_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = TextStyle(fontSize: 14);

  List<TextSpan> parse(String text, {Color? monoBackground}) =>
      parseTelegramSpans(text, base, monoBackground: monoBackground)
          .cast<TextSpan>();

  group('parseTelegramSpans', () {
    test('texto sem tokens vira um único span com o estilo base', () {
      final spans = parse('olá, mundo');
      expect(spans, hasLength(1));
      expect(spans.single.text, 'olá, mundo');
      expect(spans.single.style?.fontWeight, isNull);
      expect(spans.single.style?.fontStyle, isNull);
    });

    test('**negrito** aplica fontWeight.bold só ao trecho', () {
      final spans = parse('a **b** c');
      expect(spans.map((s) => s.text), ['a ', 'b', ' c']);
      expect(spans[0].style?.fontWeight, isNull);
      expect(spans[1].style?.fontWeight, FontWeight.bold);
      expect(spans[2].style?.fontWeight, isNull);
    });

    test('__itálico__ aplica fontStyle.italic', () {
      final spans = parse('__leve__');
      expect(spans.single.text, 'leve');
      expect(spans.single.style?.fontStyle, FontStyle.italic);
    });

    test('~~riscado~~ aplica lineThrough', () {
      final spans = parse('~~era assim~~');
      expect(spans.single.text, 'era assim');
      expect(spans.single.style?.decoration, TextDecoration.lineThrough);
    });

    test('`mono` usa monospace com o fundo informado', () {
      final spans = parse('`code`', monoBackground: Colors.black12);
      expect(spans.single.text, 'code');
      expect(spans.single.style?.fontFamily, 'monospace');
      expect(spans.single.style?.backgroundColor, Colors.black12);
    });

    test('token não fechado vira texto literal', () {
      final spans = parse('**aberto');
      expect(spans, hasLength(1));
      expect(spans.single.text, '**aberto');
      expect(spans.single.style?.fontWeight, isNull);
    });

    test('token com conteúdo vazio (****) vira texto literal', () {
      final spans = parse('****');
      expect(spans.map((s) => s.text).join(), '****');
      expect(spans.every((s) => s.style?.fontWeight == null), isTrue);
    });

    test('tokens sequenciais de tipos diferentes na mesma linha', () {
      final spans = parse('**a** e __b__');
      expect(spans.map((s) => s.text), ['a', ' e ', 'b']);
      expect(spans[0].style?.fontWeight, FontWeight.bold);
      expect(spans[2].style?.fontStyle, FontStyle.italic);
    });

    test('sem aninhamento: marcador interno fica literal dentro do externo',
        () {
      final spans = parse('**a __b__ c**');
      expect(spans, hasLength(1));
      expect(spans.single.text, 'a __b__ c');
      expect(spans.single.style?.fontWeight, FontWeight.bold);
      expect(spans.single.style?.fontStyle, isNull);
    });

    test('quebras de linha são preservadas', () {
      final spans = parse('linha1\n**linha2**\nfim');
      expect(spans.map((s) => s.text), ['linha1\n', 'linha2', '\nfim']);
      expect(spans[1].style?.fontWeight, FontWeight.bold);
    });
  });
}
