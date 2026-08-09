import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/core/network/file_uploader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late FileUploader uploader;

  setUp(() {
    dio = _MockDio();
    uploader = FileUploader(dio);
  });

  test('recusa arquivo acima de 20 MB sem chamar a API', () async {
    await expectLater(
      uploader.uploadBytes(
        bytes: Uint8List(maxUploadBytes + 1),
        contentType: 'image/jpeg',
        folder: 'dogs',
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('20 MB'),
        ),
      ),
    );
    verifyNever(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')));
  });

  group('guessImageContentType', () {
    test('mapeia extensões conhecidas e usa jpeg como padrão', () {
      expect(FileUploader.guessImageContentType('a/b/foto.PNG'), 'image/png');
      expect(FileUploader.guessImageContentType('foto.webp'), 'image/webp');
      expect(FileUploader.guessImageContentType('foto.jpeg'), 'image/jpeg');
      expect(FileUploader.guessImageContentType('sem-extensao'), 'image/jpeg');
    });
  });
}
