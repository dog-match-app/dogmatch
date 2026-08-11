import 'package:dogmatch/features/discovery/data/models/discovery_card_model.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_enums.dart';
import 'package:dogmatch/features/search/data/models/search_card_model.dart';
import 'package:flutter_test/flutter_test.dart';

DogModel _makeDog() => DogModel(
  id: 'dog-1',
  ownerId: 'owner-1',
  name: 'Luna',
  breed: 'Border Collie',
  sex: DogSex.female,
  birthDate: DateTime.utc(2024, 3, 10),
  size: DogSize.medium,
  intent: DogIntent.both,
  createdAt: DateTime.utc(2026),
);

void main() {
  group('SearchCardModel.fromDiscoveryCard', () {
    test('preserva dog, distanceKm e owner do card do deck', () {
      final dog = _makeDog();
      final card = SearchCardModel.fromDiscoveryCard(
        DiscoveryCardModel(
          dog: dog,
          distanceKm: 2.3,
          owner: const DiscoveryOwnerModel(
            id: 'owner-1',
            name: 'Tutora',
            city: 'São Paulo',
            avatarUrl: 'https://cdn.example.com/avatar.jpg',
          ),
        ),
      );

      expect(card.dog, same(dog));
      expect(card.distanceKm, 2.3);
      expect(card.owner.id, 'owner-1');
      expect(card.owner.name, 'Tutora');
      expect(card.owner.city, 'São Paulo');
      expect(card.owner.avatarUrl, 'https://cdn.example.com/avatar.jpg');
    });

    test(
      'nasce sem perspectiva: myAction nulo, matched falso, isMine falso',
      () {
        final card = SearchCardModel.fromDiscoveryCard(
          DiscoveryCardModel(
            dog: _makeDog(),
            distanceKm: 0.4,
            owner: const DiscoveryOwnerModel(id: 'owner-1', name: 'Tutora'),
          ),
        );

        expect(card.myAction, isNull);
        expect(card.hasMyAction, isFalse);
        expect(card.matched, isFalse);
        expect(card.isMatched, isFalse);
        expect(card.isMine, isFalse);
      },
    );

    test('owner sem cidade/avatar mantém os campos opcionais nulos', () {
      final card = SearchCardModel.fromDiscoveryCard(
        DiscoveryCardModel(
          dog: _makeDog(),
          distanceKm: 12,
          owner: const DiscoveryOwnerModel(id: 'owner-1', name: 'Tutora'),
        ),
      );

      expect(card.owner.city, isNull);
      expect(card.owner.avatarUrl, isNull);
      // Distância veio do deck, então o label continua disponível no detalhe.
      expect(card.distanceLabel, '12,0 km');
    });
  });
}
