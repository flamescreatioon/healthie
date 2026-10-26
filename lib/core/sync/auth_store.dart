/// Holds the Sanctum bearer token in memory for the sync layer.
///
/// Production wiring persists the token in secure storage and surfaces it via
/// this interface; tests inject an in-memory fake. The token never appears in
/// logs — only the Authorization header carries it.
library;

/// Provides the current bearer token, or null when signed out.
abstract interface class AuthTokenStore {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<void> clearToken();
}

/// Non-persistent store for tests and previews.
class InMemoryAuthTokenStore implements AuthTokenStore {
  String? _token;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async {
    _token = token;
  }

  @override
  Future<void> clearToken() async {
    _token = null;
  }
}
