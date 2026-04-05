import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_constants.dart';
import 'api_client.dart';

class ChatService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _onlineController = StreamController<List<int>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<List<int>> get onlineStream => _onlineController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Future<void> connect(int groupId) async {
    final token = await ApiClient().getAccessToken();
    if (token == null) return;

    disconnect();

    try {
      final uri = Uri.parse(ApiConstants.groupWs(groupId, token));
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;

      _channel!.stream.listen(
        (data) {
          final payload = jsonDecode(data as String) as Map<String, dynamic>;
          final event = payload['event'] as String;

          switch (event) {
            case 'new_message':
              _messageController.add(payload['data']);
              break;
            case 'typing':
              _typingController.add(payload['data']);
              break;
            case 'member_online':
            case 'member_offline':
              final members = payload['data']['online_members'] as List;
              _onlineController.add(members.cast<int>());
              break;
            case 'message_deleted':
              _messageController.add({
                ...payload['data'],
                '_deleted': true,
              });
              break;
          }
        },
        onDone: () => _isConnected = false,
        onError: (_) => _isConnected = false,
      );
    } catch (_) {
      _isConnected = false;
    }
  }

  void sendMessage({
    required String content,
    String messageType = 'text',
    int? replyToId,
  }) {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add(jsonEncode({
      'type': 'message',
      'content': content,
      'message_type': messageType,
      if (replyToId != null) 'reply_to_id': replyToId,
    }));
  }

  void sendTyping() {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add(jsonEncode({'type': 'typing'}));
  }

  void sendRead() {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add(jsonEncode({'type': 'read'}));
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _onlineController.close();
  }
}