import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nissie_ideal_shelters/core/constants/app_strings.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';

class ChatConversationSummary {
  final String conversationId;
  final String clientName;
  final String? clientPhone;
  final String? clientEmail;
  final String? propertyTitle;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final String? assignedToId;
  final String? assignedToName;
  final String status; // 'open', 'in_progress', 'resolved', 'closed'
  final String? internalNotes;

  const ChatConversationSummary({
    required this.conversationId,
    required this.clientName,
    this.clientPhone,
    this.clientEmail,
    this.propertyTitle,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    this.assignedToId,
    this.assignedToName,
    this.status = 'open',
    this.internalNotes,
  });

  ChatConversationSummary copyWith({
    String? conversationId,
    String? clientName,
    String? clientPhone,
    String? clientEmail,
    String? propertyTitle,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    String? assignedToId,
    String? assignedToName,
    String? status,
    String? internalNotes,
  }) {
    return ChatConversationSummary(
      conversationId: conversationId ?? this.conversationId,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      clientEmail: clientEmail ?? this.clientEmail,
      propertyTitle: propertyTitle ?? this.propertyTitle,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      assignedToId: assignedToId ?? this.assignedToId,
      assignedToName: assignedToName ?? this.assignedToName,
      status: status ?? this.status,
      internalNotes: internalNotes ?? this.internalNotes,
    );
  }
}

class SupportChatState {
  final List<SupportMessage> currentMessages;
  final List<ChatConversationSummary> adminConversations;
  final bool isLoading;
  final bool isSending;
  final String? activeConversationId;
  final String? clientSessionId;
  final String? errorMessage;
  final int totalUnreadForAdmin;

  const SupportChatState({
    this.currentMessages = const [],
    this.adminConversations = const [],
    this.isLoading = false,
    this.isSending = false,
    this.activeConversationId,
    this.clientSessionId,
    this.errorMessage,
    this.totalUnreadForAdmin = 0,
  });

  SupportChatState copyWith({
    List<SupportMessage>? currentMessages,
    List<ChatConversationSummary>? adminConversations,
    bool? isLoading,
    bool? isSending,
    String? activeConversationId,
    String? clientSessionId,
    String? errorMessage,
    int? totalUnreadForAdmin,
  }) {
    return SupportChatState(
      currentMessages: currentMessages ?? this.currentMessages,
      adminConversations: adminConversations ?? this.adminConversations,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      activeConversationId: activeConversationId ?? this.activeConversationId,
      clientSessionId: clientSessionId ?? this.clientSessionId,
      errorMessage: errorMessage,
      totalUnreadForAdmin: totalUnreadForAdmin ?? this.totalUnreadForAdmin,
    );
  }
}

class SupportChatNotifier extends Notifier<SupportChatState> {
  late SupabaseService _supabaseService;
  RealtimeChannel? _clientChannel;
  RealtimeChannel? _adminChannel;
  RealtimeChannel? _adminConvChannel;
  static const _storage = FlutterSecureStorage();
  static const _sessionKey = 'nissie_client_chat_session_id';

  @override
  SupportChatState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);

    Future.microtask(() => _initializeClientSession());

    ref.onDispose(() {
      _clientChannel?.unsubscribe();
      _adminChannel?.unsubscribe();
      _adminConvChannel?.unsubscribe();
    });

    return const SupportChatState();
  }

  Future<void> _initializeClientSession() async {
    final authProfile = ref.read(authProvider).profile;
    if (authProfile != null) {
      state = state.copyWith(clientSessionId: authProfile.id);
      return;
    }

    try {
      var savedId = await _storage.read(key: _sessionKey);
      if (savedId == null || savedId.isEmpty) {
        savedId = 'guest_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecondsSinceEpoch % 10000)}';
        await _storage.write(key: _sessionKey, value: savedId);
      }
      state = state.copyWith(clientSessionId: savedId);
    } catch (_) {
      state = state.copyWith(clientSessionId: 'guest_${DateTime.now().millisecondsSinceEpoch}');
    }
  }

  /// Resolve current conversation ID for client
  String getClientConversationId() {
    final authProfile = ref.read(authProvider).profile;
    if (authProfile != null) {
      return authProfile.id;
    }
    return state.clientSessionId ?? 'guest_default';
  }

  /// ── CLIENT METHODS ──

  /// Load messages for a given conversation (client or admin active chat)
  Future<void> openConversation(String conversationId, {bool isAdmin = false}) async {
    state = state.copyWith(
      isLoading: true,
      activeConversationId: conversationId,
      errorMessage: null,
    );

    _clientChannel?.unsubscribe();

    try {
      final client = _supabaseService.client;
      final response = await client
          .from('support_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      final list = (response as List<dynamic>)
          .map((item) => SupportMessage.fromJson(item as Map<String, dynamic>))
          .toList();

      state = state.copyWith(currentMessages: list, isLoading: false);

      // Mark incoming messages as read
      if (!isAdmin) {
        await client
            .from('support_messages')
            .update({'is_read_by_client': true})
            .eq('conversation_id', conversationId)
            .eq('sender_role', 'admin')
            .eq('is_read_by_client', false);
      } else {
        await client
            .from('support_messages')
            .update({'is_read_by_admin': true})
            .eq('conversation_id', conversationId)
            .eq('sender_role', 'client')
            .eq('is_read_by_admin', false);
        _refreshAdminConversations();
      }

      // Realtime subscription
      _clientChannel = client
          .channel('public:support_messages:conversation_id=eq.$conversationId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'support_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: conversationId,
            ),
            callback: (payload) {
              final newRow = payload.newRecord;
              if (newRow.isEmpty) return;
              try {
                final message = SupportMessage.fromJson(newRow);
                final existsIndex = state.currentMessages.indexWhere((m) => m.id == message.id);
                if (existsIndex >= 0) {
                  final updated = List<SupportMessage>.from(state.currentMessages);
                  updated[existsIndex] = message;
                  state = state.copyWith(currentMessages: updated);
                } else {
                  state = state.copyWith(currentMessages: [...state.currentMessages, message]);
                }
              } catch (e) {
                debugPrint('Realtime message parse error: $e');
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Failed to load chat messages: $e');
      state = state.copyWith(isLoading: false, errorMessage: 'Could not load messages.');
    }
  }

  /// Send message from client to Nissie Support
  Future<bool> sendClientMessage({
    required String message,
    String? propertyId,
    String? propertyTitle,
    String? clientName,
    String? clientPhone,
    String? clientEmail,
  }) async {
    final text = message.trim();
    if (text.isEmpty) return false;

    final convId = state.activeConversationId ?? getClientConversationId();
    final profile = ref.read(authProvider).profile;
    final name = clientName?.isNotEmpty == true
        ? clientName!
        : (profile?.fullName?.isNotEmpty == true ? profile!.fullName! : 'Client');
    final phone = clientPhone?.isNotEmpty == true ? clientPhone : profile?.phone;
    final email = clientEmail?.isNotEmpty == true ? clientEmail : profile?.email;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = SupportMessage(
      id: tempId,
      conversationId: convId,
      senderId: profile?.id ?? convId,
      senderRole: 'client',
      senderName: name,
      senderPhone: phone,
      senderEmail: email,
      propertyId: propertyId,
      propertyTitle: propertyTitle,
      message: text,
      isReadByAdmin: false,
      isReadByClient: true,
      createdAt: DateTime.now(),
    );

    // Optimistic UI update
    state = state.copyWith(
      currentMessages: [...state.currentMessages, tempMsg],
      isSending: true,
      errorMessage: null,
    );

    try {
      final client = _supabaseService.client;
      final row = tempMsg.toJson();
      final inserted = await client.from('support_messages').insert(row).select().single();
      final savedMessage = SupportMessage.fromJson(inserted);

      final updated = state.currentMessages.map((m) => m.id == tempId ? savedMessage : m).toList();
      state = state.copyWith(currentMessages: updated, isSending: false);

      // Auto-upsert into support_conversations metadata
      try {
        await client.from('support_conversations').upsert({
          'conversation_id': convId,
          'client_name': name,
          'client_phone': phone,
          'client_email': email,
          'property_title': propertyTitle,
          'last_message': text,
          'last_message_time': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'conversation_id');
      } catch (_) {}

      // Auto-register lead in Supabase so Admin sees this inquiry under Leads & Inquiries
      if (phone != null && phone.isNotEmpty) {
        _supabaseService.submitPublicLead(
          companyId: AppStrings.defaultCompanyId,
          propertyId: propertyId,
          buyerName: name,
          buyerPhone: phone,
          buyerEmail: email,
          notes: 'Live chat inquiry: $text',
          consentText: 'Submitted via in-app live chat.',
        ).catchError((_) => '');
      }

      return true;
    } catch (e) {
      debugPrint('Failed to send client message: $e');
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Failed to send. Please check connection or reach us on WhatsApp.',
      );
      return false;
    }
  }

  /// ── ADMIN METHODS ──

  /// Load all client conversations for Admin Support Inbox
  Future<void> loadAdminInbox() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _refreshAdminConversations();
      state = state.copyWith(isLoading: false);
      _subscribeAdminRealtime();
    } catch (e) {
      debugPrint('Error loading admin inbox: $e');
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to load conversations.');
    }
  }

  Future<void> _refreshAdminConversations() async {
    try {
      final client = _supabaseService.client;
      final response = await client
          .from('support_messages')
          .select()
          .order('created_at', ascending: false)
          .limit(300);

      final list = (response as List<dynamic>)
          .map((item) => SupportMessage.fromJson(item as Map<String, dynamic>))
          .toList();

      // Fetch metadata from support_conversations (assignee, status, notes)
      final Map<String, Map<String, dynamic>> convMeta = {};
      try {
        final convResponse = await client.from('support_conversations').select();
        for (final row in (convResponse as List<dynamic>)) {
          if (row is Map<String, dynamic> && row['conversation_id'] != null) {
            convMeta[row['conversation_id'].toString()] = row;
          }
        }
      } catch (_) {
        // Table might not exist yet or offline, continue gracefully
      }

      final Map<String, List<SupportMessage>> grouped = {};
      for (final msg in list) {
        grouped.putIfAbsent(msg.conversationId, () => []).add(msg);
      }

      final List<ChatConversationSummary> summaries = [];
      int unreadTotal = 0;

      grouped.forEach((convId, msgs) {
        msgs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final lastMsg = msgs.first;
        final clientMsg = msgs.firstWhere((m) => m.isFromClient, orElse: () => lastMsg);
        final unread = msgs.where((m) => m.isFromClient && !m.isReadByAdmin).length;
        unreadTotal += unread;
        final meta = convMeta[convId];

        summaries.add(ChatConversationSummary(
          conversationId: convId,
          clientName: meta?['client_name'] ?? clientMsg.senderName,
          clientPhone: meta?['client_phone'] ?? clientMsg.senderPhone,
          clientEmail: meta?['client_email'] ?? clientMsg.senderEmail,
          propertyTitle: meta?['property_title'] ?? clientMsg.propertyTitle,
          lastMessage: lastMsg.message,
          lastMessageTime: lastMsg.createdAt,
          unreadCount: unread,
          assignedToId: meta?['assigned_to_id'],
          assignedToName: meta?['assigned_to_name'],
          status: meta?['status'] ?? 'open',
          internalNotes: meta?['internal_notes'],
        ));
      });

      summaries.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

      state = state.copyWith(
        adminConversations: summaries,
        totalUnreadForAdmin: unreadTotal,
      );
    } catch (e) {
      debugPrint('Error refreshing admin conversations: $e');
    }
  }

  void _subscribeAdminRealtime() {
    _adminChannel?.unsubscribe();
    _adminConvChannel?.unsubscribe();
    final client = _supabaseService.client;

    _adminChannel = client
        .channel('public:support_messages:admin_inbox')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'support_messages',
          callback: (_) {
            _refreshAdminConversations();
          },
        )
        .subscribe();

    _adminConvChannel = client
        .channel('public:support_conversations:admin_inbox')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'support_conversations',
          callback: (_) {
            _refreshAdminConversations();
          },
        )
        .subscribe();
  }

  /// Claim or assign a conversation to an agent
  Future<bool> assignConversation({
    required String conversationId,
    required String? agentId,
    required String? agentName,
    String? status,
  }) async {
    try {
      final client = _supabaseService.client;
      final payload = {
        'conversation_id': conversationId,
        'assigned_to_id': agentId,
        'assigned_to_name': agentName,
        'status': status ?? (agentId != null ? 'in_progress' : 'open'),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await client.from('support_conversations').upsert(payload, onConflict: 'conversation_id');
      await _refreshAdminConversations();
      return true;
    } catch (e) {
      debugPrint('Error assigning conversation: $e');
      return false;
    }
  }

  /// Update conversation lifecycle status ('open', 'in_progress', 'resolved', 'closed')
  Future<bool> updateStatus({
    required String conversationId,
    required String newStatus,
  }) async {
    try {
      final client = _supabaseService.client;
      await client.from('support_conversations').upsert({
        'conversation_id': conversationId,
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'conversation_id');
      await _refreshAdminConversations();
      return true;
    } catch (e) {
      debugPrint('Error updating status: $e');
      return false;
    }
  }

  /// Update internal staff notes on conversation
  Future<bool> updateInternalNotes({
    required String conversationId,
    required String notes,
  }) async {
    try {
      final client = _supabaseService.client;
      await client.from('support_conversations').upsert({
        'conversation_id': conversationId,
        'internal_notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'conversation_id');
      await _refreshAdminConversations();
      return true;
    } catch (e) {
      debugPrint('Error updating internal notes: $e');
      return false;
    }
  }

  /// Send reply from Admin to Client
  Future<bool> sendAdminReply({
    required String conversationId,
    required String message,
  }) async {
    final text = message.trim();
    if (text.isEmpty) return false;

    final profile = ref.read(authProvider).profile;
    final adminName = profile?.fullName?.isNotEmpty == true ? profile!.fullName! : 'Nissie Desk Officer';

    state = state.copyWith(isSending: true);

    try {
      final client = _supabaseService.client;
      final row = {
        'conversation_id': conversationId,
        'sender_id': profile?.id ?? 'admin',
        'sender_role': 'admin',
        'sender_name': adminName,
        'message': text,
        'is_read_by_admin': true,
        'is_read_by_client': false,
      };

      final inserted = await client.from('support_messages').insert(row).select().single();
      final savedMessage = SupportMessage.fromJson(inserted);

      // Upsert last message into support_conversations
      try {
        await client.from('support_conversations').upsert({
          'conversation_id': conversationId,
          'last_message': text,
          'last_message_time': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'conversation_id');
      } catch (_) {}

      if (state.activeConversationId == conversationId) {
        state = state.copyWith(
          currentMessages: [...state.currentMessages, savedMessage],
          isSending: false,
        );
      } else {
        state = state.copyWith(isSending: false);
      }

      _refreshAdminConversations();
      return true;
    } catch (e) {
      debugPrint('Failed to send admin reply: $e');
      state = state.copyWith(isSending: false, errorMessage: 'Failed to send reply.');
      return false;
    }
  }
}

final supportChatProvider = NotifierProvider<SupportChatNotifier, SupportChatState>(() {
  return SupportChatNotifier();
});
