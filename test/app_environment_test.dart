import 'package:flutter_test/flutter_test.dart';
import 'package:stickr/config/app_environment.dart';

void main() {
  test('accepts complete API environment configuration', () {
    expect(
      () => AppEnvironment.validateRequired(
        giphyKey: 'giphy-key',
        apifyToken: 'apify-token',
      ),
      returnsNormally,
    );
  });

  test('reports every missing required environment variable', () {
    expect(
      () => AppEnvironment.validateRequired(giphyKey: '', apifyToken: ' '),
      throwsA(
        isA<EnvironmentConfigurationException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('GIPHY_API_KEY'),
            contains('APIFY_API_TOKEN'),
            contains('--dart-define'),
          ),
        ),
      ),
    );
  });
}
