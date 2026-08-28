import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:business_management_system/core/network/api_client.dart';

/// One scripted HTTP outcome, consumed in registration order.
class ScriptedResponse {
  const ScriptedResponse(this.status, [this.body = '{}']);

  final int status;
  final String body;
}

/// One recorded request: immutable copies of what actually left the client.
class RecordedRequest {
  const RecordedRequest(this.method, this.path, this.headers, [this.body]);

  final String method;
  final String path;
  final Map<String, dynamic> headers;

  /// Decoded UTF-8 request body, when one was sent.
  final String? body;
}

/// Deterministic [HttpClientAdapter] that records every outgoing request and
/// replays [responses] sequentially. The last response repeats once exhausted.
class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this.responses);

  final List<ScriptedResponse> responses;
  final List<RecordedRequest> requests = [];
  int _cursor = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    String? body;
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      body = chunks.isEmpty
          ? null
          : utf8.decode(chunks.expand((c) => c).toList(), allowMalformed: true);
    }
    requests.add(
      RecordedRequest(
        options.method,
        options.uri.toString(),
        Map<String, dynamic>.of(options.headers),
        body,
      ),
    );
    final step = responses[_cursor.clamp(0, responses.length - 1)];
    _cursor++;
    return ResponseBody.fromString(
      step.body,
      step.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Shared in-memory [TokenStore] for tests.
class InMemoryTokenStore implements TokenStore {
  String? accessToken;
  String? refreshToken;
  int writeCount = 0;
  int clearCount = 0;

  @override
  Future<void> clear() async {
    clearCount++;
    accessToken = null;
    refreshToken = null;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    writeCount++;
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }
}
