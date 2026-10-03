import 'api_service.dart';

/// Injectable transport keeps chat tests independent of real accounts/providers.
class ChatService {
  const ChatService();
  Future<Map<String, dynamic>> get(String url) => ApiService.secureGet(url);
  Future<Map<String, dynamic>> post(String url, Map<String, dynamic> body) =>
      ApiService.securePost(url, body);
  Future<Map<String, dynamic>> put(String url, Map<String, dynamic> body) =>
      ApiService.securePut(url, body: body);
  Future<Map<String, dynamic>> delete(String url) =>
      ApiService.secureDelete(url);
}
