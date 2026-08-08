import 'package:dogmatch/core/utils/social_links.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Cores e ícones OFICIAIS das marcas de redes sociais (ARCHITECTURE §3.5.3).
///
/// EXCEÇÃO DOCUMENTADA ao invariante "cores só via tema": cores de marca são
/// fixas por natureza (identidade visual de terceiros) e NÃO devem reagir ao
/// tema claro/escuro nem à seed do app — por isso vivem aqui como constantes,
/// e apenas aqui. Nenhuma outra feature deve hardcodar `Color(0x...)`.
class SocialBrand {
  const SocialBrand._();

  static const Color whatsapp = Color(0xFF25D366);
  static const Color instagram = Color(0xFFE4405F);
  static const Color pinterest = Color(0xFFBD081C);
  static const Color telegram = Color(0xFF26A5E4);

  /// Conteúdo (ícone/rótulo) sobre as cores de marca — branco por diretriz
  /// das próprias marcas, também independente do tema.
  static const Color foreground = Colors.white;

  static Color colorOf(SocialNetwork network) {
    switch (network) {
      case SocialNetwork.whatsapp:
        return whatsapp;
      case SocialNetwork.instagram:
        return instagram;
      case SocialNetwork.pinterest:
        return pinterest;
      case SocialNetwork.telegram:
        return telegram;
    }
  }

  /// Ícone da marca (Font Awesome Brands — renderizar com `FaIcon`).
  static FaIconData iconOf(SocialNetwork network) {
    switch (network) {
      case SocialNetwork.whatsapp:
        return FontAwesomeIcons.whatsapp;
      case SocialNetwork.instagram:
        return FontAwesomeIcons.instagram;
      case SocialNetwork.pinterest:
        return FontAwesomeIcons.pinterest;
      case SocialNetwork.telegram:
        return FontAwesomeIcons.telegram;
    }
  }
}
