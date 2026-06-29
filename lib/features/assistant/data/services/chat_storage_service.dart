import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_test2/core/services/secure_storage_service.dart';

class ChatStorageService {
  static const String _key = 'saved_chats';

  String _fixMojibake(String s) {
    if (!s.contains('Ø') && !s.contains('Ù')) return s;
    try {
      return utf8.decode(latin1.encode(s));
    } catch (_) {
      return s;
    }
  }

  Map<String, dynamic> _normalizeChat(Map<String, dynamic> chat) {
    final title = (chat['title'] ?? '').toString();
    final fixedTitle = _fixMojibake(title);

    final msgs = chat['messages'];
    if (msgs is List) {
      final fixedMsgs = msgs
          .whereType<Map>()
          .map((m) {
            final mm = Map<String, dynamic>.from(m);
            final text = (mm['text'] ?? '').toString();
            mm['text'] = _fixMojibake(text);
            return mm;
          })
          .toList();
      return {
        ...chat,
        'title': fixedTitle,
        'messages': fixedMsgs,
      };
    }

    return {
      ...chat,
      'title': fixedTitle,
    };
  }

  /// Strict validation of deserialized JSON models to prevent insecure deserialization exploitation
  bool _isValidChat(Map<String, dynamic> chat) {
    if (chat['id'] == null || chat['id'].toString().trim().isEmpty) return false;
    if (chat['title'] == null) return false;
    return true;
  }

  Future<List<Map<String, dynamic>>> getChats() async {
    // 1. Check for legacy plaintext chats in SharedPreferences (Migration path)
    final prefs = await SharedPreferences.getInstance();
    String? str = prefs.getString(_key);
    
    if (str != null) {
      // Migrate legacy plaintext data into secure encrypted storage
      await SecureStorageService.instance.write(_key, str);
      await prefs.remove(_key); // Clean up legacy plaintext key
    } else {
      // Read from secure encrypted storage
      str = await SecureStorageService.instance.read(_key);
    }
    
    if (str == null || str.trim().isEmpty) return [];
    
    try {
      final decoded = jsonDecode(str);
      if (decoded is! List) return [];
      
      final list = <Map<String, dynamic>>[];
      for (final item in decoded) {
        if (item is Map) {
          final chat = Map<String, dynamic>.from(item);
          if (_isValidChat(chat)) {
            list.add(_normalizeChat(chat));
          }
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getChatsDeduped({String query = ''}) async {
    final chats = await getChats();
    final q = query.trim().toLowerCase();

    Map<String, dynamic> normalizeTime(Map<String, dynamic> c) {
      final t = (c['updatedAt'] ?? c['updated_at'] ?? '').toString();
      DateTime? dt;
      if (t.isNotEmpty) {
        dt = DateTime.tryParse(t);
      }
      return {
        ...c,
        '_updated': (dt ?? DateTime.fromMillisecondsSinceEpoch(0)).millisecondsSinceEpoch,
      };
    }

    final normalized = chats.map(normalizeTime).toList();
    normalized.sort((a, b) => (b['_updated'] as int).compareTo(a['_updated'] as int));

    final byTitle = <String, Map<String, dynamic>>{};
    final seenNoTitle = <String>{};
    for (final c in normalized) {
      final title = (c['title'] ?? '').toString().trim();
      final id = (c['id'] ?? '').toString();
      if (q.isNotEmpty && !title.toLowerCase().contains(q)) {
        continue;
      }
      if (title.isEmpty) {
        if (id.isNotEmpty && !seenNoTitle.contains(id)) {
          seenNoTitle.add(id);
          byTitle['__id__$id'] = c;
        }
        continue;
      }

      final key = title;
      final existing = byTitle[key];
      if (existing == null) {
        byTitle[key] = c;
      } else {
        final a = existing['_updated'] as int;
        final b = c['_updated'] as int;
        if (b > a) byTitle[key] = c;
      }
    }

    final out = byTitle.values.toList();
    out.sort((a, b) => (b['_updated'] as int).compareTo(a['_updated'] as int));
    return out.map((c) {
      final copy = Map<String, dynamic>.from(c);
      copy.remove('_updated');
      return copy;
    }).toList();
  }

  Future<void> saveChat(Map<String, dynamic> chat) async {
    final chats = await getChats();
    final index = chats.indexWhere((c) => c['id'] == chat['id']);
    if (index >= 0) { 
      chats[index] = chat; 
    } else { 
      chats.insert(0, chat); 
    }
    
    // Save to secure encrypted storage
    await SecureStorageService.instance.write(_key, jsonEncode(chats));
  }

  Future<void> deleteChat(String id) async {
    final chats = await getChats();
    chats.removeWhere((c) => c['id'] == id);
    
    // Update secure encrypted storage
    await SecureStorageService.instance.write(_key, jsonEncode(chats));
  }
}
