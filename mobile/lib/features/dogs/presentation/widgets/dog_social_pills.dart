import 'package:dogmatch/core/theme/social_brand.dart';
import 'package:dogmatch/core/utils/social_links.dart';
import 'package:dogmatch/features/dogs/data/models/dog_social_model.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pills das redes sociais do cão (§3.5.3): fundo na cor oficial da marca
/// ([SocialBrand]), ícone da marca + rótulo em branco. Só renderiza as redes
/// preenchidas; toque abre o deep link ([buildSocialUrl]) no app externo.
class DogSocialPills extends StatelessWidget {
  const DogSocialPills({super.key, required this.social});

  final DogSocialModel social;

  List<(SocialNetwork, String)> get _entries => [
        for (final (network, value) in [
          (SocialNetwork.whatsapp, social.whatsapp),
          (SocialNetwork.instagram, social.instagram),
          (SocialNetwork.pinterest, social.pinterest),
          (SocialNetwork.telegram, social.telegram),
        ])
          if (value != null && value.trim().isNotEmpty) (network, value),
      ];

  Future<void> _open(
    BuildContext context,
    SocialNetwork network,
    String value,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(buildSocialUrl(network, value)),
        mode: LaunchMode.externalApplication,
      );
    } on Exception {
      opened = false;
    }
    if (!opened) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o link')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    if (entries.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (network, value) in entries)
          Material(
            color: SocialBrand.colorOf(network),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () => _open(context, network, value),
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      SocialBrand.iconOf(network),
                      size: 16,
                      color: SocialBrand.foreground,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      network.label,
                      style: const TextStyle(
                        color: SocialBrand.foreground,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
