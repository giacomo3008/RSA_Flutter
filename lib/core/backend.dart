import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

/// Future remote boundary. Authorization and agent orchestration run server-side.
/// The demo does not instantiate this adapter or require any credentials.
abstract interface class CareBackend {
  Future<List<CareEvent>> getEvents(String wardId);
  Future<CareEvent> createEvent(String wardId, EventDraft draft);
  Future<void> takeCharge(String eventId);
  Future<List<Message>> getMessages(String conversationId);
  Future<AssistantAnswer> askAssistant(String wardId, String question);
}

class BackendFailure implements Exception {
  final int status;
  final String message;
  const BackendFailure(this.status, this.message);
  @override
  String toString() => message;
}

/// Example JSON contract, to agree with the authenticated FastAPI application.
/// A production session adapter supplies short-lived app tokens, never model keys.
class FastApiBackend implements CareBackend {
  final Uri baseUri;
  final http.Client client;
  final Future<String?> Function() sessionToken;
  FastApiBackend({
    required this.baseUri,
    required this.client,
    required this.sessionToken,
  }) {
    if (baseUri.scheme != 'https') {
      throw ArgumentError('The remote care backend requires HTTPS.');
    }
  }
  Future<dynamic> _request(
    String method,
    String path, {
    Object? body,
    String? idempotencyKey,
  }) async {
    final token = await sessionToken();
    final request = http.Request(method, baseUri.resolve(path));
    request.headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (idempotencyKey != null) {
      request.headers['Idempotency-Key'] = idempotencyKey;
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await http.Response.fromStream(await client.send(request));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendFailure(
        response.statusCode,
        response.statusCode == 403
            ? 'You do not have permission to access this record.'
            : 'The care service could not complete this request.',
      );
    }
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }

  @override
  Future<List<CareEvent>> getEvents(String wardId) async =>
      ((await _request('GET', 'wards/${Uri.encodeComponent(wardId)}/events'))
              as List)
          .map((v) => CareEvent.fromJson(objectMap(v)))
          .toList();
  @override
  Future<CareEvent> createEvent(String wardId, EventDraft draft) async =>
      CareEvent.fromJson(
        objectMap(
          await _request(
            'POST',
            'wards/${Uri.encodeComponent(wardId)}/events',
            body: draft.toJson(),
            idempotencyKey: draft.idempotencyKey,
          ),
        ),
      );
  @override
  Future<void> takeCharge(String eventId) async {
    await _request('POST', 'events/${Uri.encodeComponent(eventId)}/claim');
  }

  @override
  Future<List<Message>> getMessages(String conversationId) async =>
      ((await _request(
                'GET',
                'conversations/${Uri.encodeComponent(conversationId)}/messages',
              ))
              as List)
          .map((v) => Message.fromJson(objectMap(v)))
          .toList();
  @override
  Future<AssistantAnswer> askAssistant(String wardId, String question) async {
    final result = objectMap(
      await _request(
        'POST',
        'assistant',
        body: {'wardId': wardId, 'question': question},
      ),
    );
    return AssistantAnswer(
      result['text'] as String,
      strings(result['sourceEventIds']),
    );
  }
}
