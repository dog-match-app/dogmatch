import 'package:dogmatch/core/utils/social_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildSocialUrl', () {
    test('whatsapp: número com máscara vira wa.me só com dígitos', () {
      expect(
        buildSocialUrl(SocialNetwork.whatsapp, '+55 11 90000-0000'),
        'https://wa.me/5511900000000',
      );
    });

    test('instagram: handle com @ perde o @', () {
      expect(
        buildSocialUrl(SocialNetwork.instagram, '@luna_dog'),
        'https://instagram.com/luna_dog',
      );
    });

    test('pinterest: handle sem @ é usado direto', () {
      expect(
        buildSocialUrl(SocialNetwork.pinterest, 'luna'),
        'https://pinterest.com/luna',
      );
    });

    test('telegram: monta t.me com o handle', () {
      expect(
        buildSocialUrl(SocialNetwork.telegram, '@lunapets'),
        'https://t.me/lunapets',
      );
    });

    test('URL https completa é usada como está', () {
      expect(
        buildSocialUrl(
          SocialNetwork.instagram,
          'https://instagram.com/perfil.da.luna',
        ),
        'https://instagram.com/perfil.da.luna',
      );
    });

    test('URL http completa também é preservada (com espaços nas pontas)', () {
      expect(
        buildSocialUrl(SocialNetwork.whatsapp, '  http://wa.me/551190000  '),
        'http://wa.me/551190000',
      );
    });
  });
}
