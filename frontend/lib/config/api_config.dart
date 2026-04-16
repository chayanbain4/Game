class ApiConfig {
  static String get baseUrl => String.fromEnvironment(
        'API_URL',
        defaultValue: bool.fromEnvironment('dart.vm.product')
            ? 'https://game.iwebgenics.com'
            : 'http://10.0.2.2:4017',
      );
}