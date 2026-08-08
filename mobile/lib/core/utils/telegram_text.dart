import 'package:flutter/material.dart';

/// Formatação leve estilo Telegram usada nos posts da página do cão
/// (ARCHITECTURE §3.5.2): `**negrito**`, `__itálico__`, `~~riscado~~` e
/// `` `mono` ``. O texto é armazenado cru pela API e renderizado aqui.
///
/// Regras do parser:
/// - tokens não fechados (ou com conteúdo vazio) viram texto literal;
/// - sem aninhamento: os tokens são consumidos sequencialmente, e o conteúdo
///   de um token é emitido como está (marcadores internos ficam literais);
/// - quebras de linha são preservadas.
List<InlineSpan> parseTelegramSpans(
  String text,
  TextStyle base, {
  Color? monoBackground,
}) {
  const delimiters = ['**', '__', '~~', '`'];
  final spans = <InlineSpan>[];
  final literal = StringBuffer();

  void flushLiteral() {
    if (literal.isEmpty) return;
    spans.add(TextSpan(text: literal.toString(), style: base));
    literal.clear();
  }

  var index = 0;
  while (index < text.length) {
    String? delimiter;
    for (final candidate in delimiters) {
      if (text.startsWith(candidate, index)) {
        delimiter = candidate;
        break;
      }
    }
    if (delimiter == null) {
      literal.write(text[index]);
      index++;
      continue;
    }
    final contentStart = index + delimiter.length;
    final close = text.indexOf(delimiter, contentStart);
    if (close == -1 || close == contentStart) {
      // Não fechado ou vazio (ex.: `****`): o marcador vira texto literal.
      literal.write(delimiter);
      index = contentStart;
      continue;
    }
    flushLiteral();
    spans.add(
      TextSpan(
        text: text.substring(contentStart, close),
        style: _styleFor(delimiter, base, monoBackground),
      ),
    );
    index = close + delimiter.length;
  }
  flushLiteral();
  return spans;
}

TextStyle _styleFor(String delimiter, TextStyle base, Color? monoBackground) {
  switch (delimiter) {
    case '**':
      return base.copyWith(fontWeight: FontWeight.bold);
    case '__':
      return base.copyWith(fontStyle: FontStyle.italic);
    case '~~':
      return base.copyWith(decoration: TextDecoration.lineThrough);
    default: // `mono`
      return base.copyWith(
        fontFamily: 'monospace',
        backgroundColor: monoBackground,
      );
  }
}

/// Texto com a formatação Telegram-like renderizada ([parseTelegramSpans]).
/// O trecho `mono` ganha fundo sutil (`surfaceContainerHighest`).
class TelegramText extends StatelessWidget {
  const TelegramText(this.text, {super.key, this.style});

  final String text;

  /// Estilo base; default = estilo do [DefaultTextStyle] atual.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = style ?? DefaultTextStyle.of(context).style;
    return Text.rich(
      TextSpan(
        children: parseTelegramSpans(
          text,
          base,
          monoBackground: theme.colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}
