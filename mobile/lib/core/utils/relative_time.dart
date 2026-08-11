import 'package:intl/intl.dart';

/// Horário relativo curto em PT-BR: "agora", "5 min", "3 h", "2 d" e, com
/// mais de uma semana, a data (`dd/MM/yyyy`). Compartilhado pela lista de
/// matches e pelos cards de curtidas.
String relativeTimeLabel(DateTime dateTime) {
  final difference = DateTime.now().difference(dateTime.toLocal());
  if (difference.inMinutes < 1) return 'agora';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min';
  if (difference.inHours < 24) return '${difference.inHours} h';
  if (difference.inDays < 7) return '${difference.inDays} d';
  return DateFormat('dd/MM/yyyy').format(dateTime.toLocal());
}

/// Frase "curtiu há X" do card de curtida recebida: "Curtiu agora",
/// "Curtiu há 3 h" ou "Curtiu em 12/03/2026" (quando só resta a data).
String likedAgoLabel(DateTime likedAt) {
  final label = relativeTimeLabel(likedAt);
  if (label == 'agora') return 'Curtiu agora';
  if (label.contains('/')) return 'Curtiu em $label';
  return 'Curtiu há $label';
}
