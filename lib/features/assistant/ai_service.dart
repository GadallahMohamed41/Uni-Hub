import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_config.dart';

class AiApiException implements Exception {
  final int? statusCode;
  final String message;
  const AiApiException({required this.message, this.statusCode});

  @override
  String toString() => statusCode == null ? message : '$message (status $statusCode)';
}

class AiService {
  final String _base = AiConfig.baseUrl;
  String? _cachedEndpoint;
  final List<String> _responseKeys = ['answer', 'reply', 'text', 'output', 'response'];


  String _fixMojibake(String s) {
    try {
      return utf8.decode(latin1.encode(s));
    } catch (_) {
      return s;
    }
  }

  String _normalizeWhitespace(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();


  Future<bool> health() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_base/health'),
            headers: const {
              'Accept': 'application/json',
              'User-Agent': 'UniHub/1.0',
            },
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<String> reply({required String sessionId, required String message}) async {
    final first = await _postChat(sessionId: sessionId, message: message);
    final fixedFirst = _normalizeWhitespace(_fixMojibake(first));
    if (fixedFirst.isNotEmpty) return fixedFirst;
    throw const AiApiException(message: 'Empty response from AI API');
  }

  Future<String> _postChat({required String sessionId, required String message}) async {
    final ep = (_cachedEndpoint ?? AiConfig.endpoint).isNotEmpty ? (_cachedEndpoint ?? AiConfig.endpoint) : '/chat';
    final uri = Uri.parse('$_base$ep');
    http.Response res;
    try {
      res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
              'User-Agent': 'UniHub/1.0',
            },
            body: jsonEncode({'session_id': sessionId, 'message': message}),
          )
          .timeout(const Duration(seconds: 18));
    } catch (e) {
      throw AiApiException(message: e.toString());
    }

    final raw = utf8.decode(res.bodyBytes);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = _safeDecode(raw);
      final text = decoded != null ? _extractText(decoded) : raw.trim();
      if (text.isNotEmpty) {
        _cachedEndpoint = ep;
        return text;
      }
      throw const AiApiException(message: 'Empty response from AI API');
    }

    throw AiApiException(message: raw.isNotEmpty ? raw : 'AI API error', statusCode: res.statusCode);
  }

  Map<String, dynamic>? _safeDecode(String s) {
    try {
      final m = jsonDecode(s);
      return m is Map<String, dynamic> ? m : null;
    } catch (_) {
      return null;
    }
  }

  String _extractText(Map<String, dynamic>? body) {
    if (body == null) return '';
    for (final k in _responseKeys) {
      final v = body[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    if (body.values.isNotEmpty) {
      final first = body.values.first;
      if (first is String) return first;
    }
    return '';
  }
}
