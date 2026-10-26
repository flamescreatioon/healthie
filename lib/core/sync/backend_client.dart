/// The HTTP client the sync layer uses to talk to the Laravel backend.
///
/// One class, one base URL, one token. Bearer auth on every request, never a
/// health value in the URL, never a token in a log.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../error/app_failure.dart';
import 'sync_models.dart';

class BackendClient {
  BackendClient({
    required String baseUrl,
    required this.tokenProvider,
    http.Client? httpClient,
  })  : _baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _http = httpClient ?? http.Client();

  final String _baseUrl;

  /// Returns the stored Sanctum bearer token, or null when signed out.
  final Future<String?> Function() tokenProvider;
  final http.Client _http;

  /// `POST /api/v1/sync/upload` with the outbox batch.
  Future<({List<SyncUploadResult> results, SyncWatermark watermark})>
      uploadBatch(List<Map<String, dynamic>> rows) async {
    final body = await _post(
      '/api/v1/sync/upload',
      <String, dynamic>{'rows': rows},
    );
    final results = (body['results']! as List)
        .map(
          (result) => SyncUploadResult.fromJson(
            Map<String, dynamic>.from(result as Map),
          ),
        )
        .toList();
    return (results: results, watermark: SyncWatermark.fromJson(body));
  }

  /// `GET /api/v1/sync/changes?since=` — the ordered changelog.
  Future<({List<RemoteChange> changes, SyncWatermark watermark})>
      fetchChanges(DateTime? since) async {
    final query = since == null
        ? ''
        : '?since=${Uri.encodeComponent(since.toUtc().toIso8601String())}';
    final body = await _get('/api/v1/sync/changes$query');
    final changes = (body['changes']! as List)
        .map(
          (change) => RemoteChange.fromJson(
            Map<String, dynamic>.from(change as Map),
          ),
        )
        .toList();
    return (changes: changes, watermark: SyncWatermark.fromJson(body));
  }

  /// `POST /api/v1/auth/register` — creates the account, returns the token.
  Future<({Map<String, dynamic> user, String token})> register({
    required String name,
    required String email,
    required String password,
    String? displayName,
  }) async {
    final body = await _post('/api/v1/auth/register', <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': password,
      if (displayName != null) 'display_name': displayName,
    });
    return (
      user: Map<String, dynamic>.from(body['user']! as Map),
      token: body['token']! as String,
    );
  }

  /// `POST /api/v1/auth/login` — returns the token for an existing account.
  Future<({Map<String, dynamic> user, String token})> login({
    required String email,
    required String password,
  }) async {
    final body = await _post('/api/v1/auth/login', <String, dynamic>{
      'email': email,
      'password': password,
    });
    return (
      user: Map<String, dynamic>.from(body['user']! as Map),
      token: body['token']! as String,
    );
  }

  /// `POST /api/v1/auth/logout` — revokes the current token.
  Future<void> logout() async {
    await _post('/api/v1/auth/logout', <String, dynamic>{});
  }

  /// `DELETE /api/v1/account` — password-confirmed, irreversible.
  Future<void> deleteAccount({required String password}) async {
    await _delete('/api/v1/account', <String, dynamic>{'password': password});
  }

  /// `GET /api/v1/exports/measurements` — JSON payload with reference.
  Future<Map<String, dynamic>> exportMeasurements({
    String? from,
    String? to,
    String? metricType,
  }) async {
    final params = <String, String>{
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (metricType != null) 'metric_type': metricType,
    };
    final query = params.entries
        .map(
          (entry) => '${entry.key}=${Uri.encodeComponent(entry.value)}',
        )
        .join('&');
    final suffix = query.isEmpty ? '' : '?$query';
    return _get('/api/v1/exports/measurements$suffix');
  }

  void close() => _http.close();

  Future<Map<String, dynamic>> _get(String path) async {
    return _send(() async {
      final token = await _requireToken();
      final response = await _http
          .get(
            Uri.parse('$_baseUrl$path'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 30));
      return _decode(response);
    });
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    return _send(() async {
      final isAuth = path.startsWith('/api/v1/auth/');
      final token = isAuth ? await tokenProvider() : await _requireToken();
      final response = await _http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: _headers(token),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));
      return _decode(response);
    });
  }

  Future<Map<String, dynamic>> _delete(
    String path,
    Map<String, dynamic> payload,
  ) async {
    return _send(() async {
      final token = await _requireToken();
      final response = await _http
          .delete(
            Uri.parse('$_baseUrl$path'),
            headers: _headers(token),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));
      return _decode(response);
    });
  }

  Map<String, String> _headers(String? token) {
    return <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<String> _requireToken() async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw const SyncFailure('Sign in to sync your data.', isRetryable: false);
    }
    return token;
  }

  /// Maps transport and HTTP failures onto the app's failure hierarchy.
  ///
  /// Retryable (network/5xx/429) bubble up as [SyncFailure] and stay queued;
  /// permanent rejections (400/403/422) become [SyncPermanentFailure] so the
  /// caller can quarantine the row instead of retrying it forever.
  Future<Map<String, dynamic>> _send(
    Future<Map<String, dynamic>> Function() call,
  ) async {
    try {
      return await call();
    } on TimeoutException catch (error) {
      throw SyncFailure('The request timed out.', cause: error);
    } on SocketException catch (error) {
      throw SyncFailure('No connection to the server.', cause: error);
    } on HttpException catch (error) {
      throw SyncFailure('Could not reach the server.', cause: error);
    } on SyncPermanentFailure {
      rethrow;
    } on SyncFailure {
      rethrow;
    } on Object catch (error) {
      // Anything unexpected (including a malformed payload) is retryable:
      // the local data is safe and the next trigger tries again.
      throw SyncFailure('Sync failed.', cause: error);
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode == 401) {
      throw const SyncFailure(
        'Your session has expired. Sign in again.',
        isRetryable: false,
      );
    }
    if (response.statusCode == 429 ||
        (response.statusCode >= 500 && response.statusCode < 600)) {
      throw SyncFailure(
        'The server is busy. Will retry.',
        cause: response.statusCode,
      );
    }
    if (response.statusCode == 400 ||
        response.statusCode == 403 ||
        response.statusCode == 422) {
      throw SyncPermanentFailure(
        'The server rejected this change.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SyncFailure('Unexpected response.', cause: response.statusCode);
    }
    return Map<String, dynamic>.from(
      jsonDecode(response.body) as Map,
    );
  }
}
