/// Redes sociais suportadas no perfil do cão (ARCHITECTURE §3.5.3).
enum SocialNetwork {
  whatsapp('WhatsApp'),
  instagram('Instagram'),
  pinterest('Pinterest'),
  telegram('Telegram');

  const SocialNetwork(this.label);

  /// Nome exibido na UI (nome próprio da marca — não traduz).
  final String label;
}

/// Monta o deep link de uma rede a partir do valor livre digitado pelo dono
/// (handle, número ou URL — §3.5.3):
///
/// - valor começando com `http(s)://` é usado como está;
/// - WhatsApp: `https://wa.me/<só dígitos>`;
/// - Instagram/Pinterest/Telegram: `https://<host>/<handle sem @>`.
String buildSocialUrl(SocialNetwork network, String value) {
  final trimmed = value.trim();
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return trimmed;
  }
  switch (network) {
    case SocialNetwork.whatsapp:
      return 'https://wa.me/${trimmed.replaceAll(RegExp(r'\D'), '')}';
    case SocialNetwork.instagram:
      return 'https://instagram.com/${_handle(trimmed)}';
    case SocialNetwork.pinterest:
      return 'https://pinterest.com/${_handle(trimmed)}';
    case SocialNetwork.telegram:
      return 'https://t.me/${_handle(trimmed)}';
  }
}

String _handle(String value) =>
    value.startsWith('@') ? value.substring(1) : value;
