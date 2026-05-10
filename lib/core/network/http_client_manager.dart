import 'package:http/http.dart' as http;

class HttpClientManager {
  static http.Client _client = http.Client();

  static http.Client get client => _client;

  static void reset() {
    _client.close();
    _client = http.Client();
  }
}
