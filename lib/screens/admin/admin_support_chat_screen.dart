import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/utils/navigation_helpers.dart';
import 'package:nissie_ideal_shelters/providers/support_chat_provider.dart';

class AdminSupportChatScreen extends ConsumerStatefulWidget {
  const AdminSupportChatScreen({super.key});

  @override
  ConsumerState<AdminSupportChatScreen> createState() => _AdminSupportChatScreenState();
}

class _AdminSupportChatScreenState extends ConsumerState<AdminSupportChatScreen> {
  final _searchController = TextEditingController();
  final _replyController = TextEditingController();
  final _scrollController = ScrollController();

  String? _selectedConversationId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(supportChatProvider.notifier).loadAdminInbox();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _selectConversation(String convId) {
    setState(() => _selectedConversationId = convId);
    ref.read(supportChatProvider.notifier).openConversation(convId, isAdmin: true);
    _scrollToBottom();
  }

  Future<void> _handleSendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _selectedConversationId == null) return;

    _replyController.clear();
    final ok = await ref.read(supportChatProvider.notifier).sendAdminReply(
      conversationId: _selectedConversationId!,
      message: text,
    );

    if (ok) {
      _scrollToBottom();
    }
  }

  Future<void> _callClient(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsAppClient(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(supportChatProvider);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    // Filter conversations
    final filtered = chatState.adminConversations.where((c) {
      final q = _searchQuery.toLowerCase();
      return c.clientName.toLowerCase().contains(q) ||
          (c.clientPhone?.toLowerCase().contains(q) ?? false) ||
          (c.propertyTitle?.toLowerCase().contains(q) ?? false) ||
          c.lastMessage.toLowerCase().contains(q);
    }).toList();

    return SafeBackScope(
      fallbackRoute: '/admin/dashboard',
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          foregroundColor: const Color(0xFF0F172A),
          title: Row(
            children: [
              const Icon(Icons.forum_outlined, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              const Text(
                'Live Support Inbox',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(width: 10),
              if (chatState.totalUnreadForAdmin > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${chatState.totalUnreadForAdmin} new',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh Inbox',
              onPressed: () => ref.read(supportChatProvider.notifier).loadAdminInbox(),
            ),
          ],
        ),
        body: isDesktop
            ? Row(
                children: [
                  // Left Conversations List
                  SizedBox(
                    width: 380,
                    child: _buildConversationsList(filtered, chatState.isLoading),
                  ),
                  const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),
                  // Right Chat Area
                  Expanded(
                    child: _selectedConversationId == null
                        ? _buildNoConversationSelected()
                        : _buildActiveChatArea(chatState),
                  ),
                ],
              )
            : (_selectedConversationId == null
                ? _buildConversationsList(filtered, chatState.isLoading)
                : _buildActiveChatArea(chatState, onBack: () => setState(() => _selectedConversationId = null))),
      ),
    );
  }

  Widget _buildConversationsList(List<ChatConversationSummary> list, bool isLoading) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search client, phone, or listing...',
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: isLoading && list.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.mark_chat_unread_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            const Text(
                              'No conversations yet',
                              style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, indent: 68),
                        itemBuilder: (context, index) {
                          final item = list[index];
                          final isSelected = item.conversationId == _selectedConversationId;
                          final timeStr = DateFormat('dd MMM, hh:mm a').format(item.lastMessageTime);

                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: const Color(0xFFF1F5F9),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Text(
                                item.clientName.isNotEmpty ? item.clientName[0].toUpperCase() : 'C',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.clientName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: item.unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                                      fontSize: 14,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                Text(
                                  timeStr,
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.propertyTitle != null) ...[
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.propertyTitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 10, color: Colors.blue.shade900, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 3),
                                Text(
                                  item.lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: item.unreadCount > 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                    fontWeight: item.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                            trailing: item.unreadCount > 0
                                ? Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${item.unreadCount}',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                : null,
                            onTap: () => _selectConversation(item.conversationId),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoConversationSelected() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 64, color: Color(0xFF94A3B8)),
          SizedBox(height: 14),
          Text(
            'Select a conversation to reply',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
          ),
          SizedBox(height: 4),
          Text(
            'Live client messages from the app will show here in real time.',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChatArea(SupportChatState chatState, {VoidCallback? onBack}) {
    final activeConv = chatState.adminConversations.where(
      (c) => c.conversationId == _selectedConversationId,
    ).firstOrNull;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Top Active Client Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                if (onBack != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: onBack,
                  ),
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(
                    activeConv?.clientName.isNotEmpty == true ? activeConv!.clientName[0].toUpperCase() : 'C',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeConv?.clientName ?? 'Client',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                      if (activeConv?.clientPhone != null)
                        Text(
                          activeConv!.clientPhone!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                    ],
                  ),
                ),
                if (activeConv?.clientPhone != null) ...[
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366)),
                    tooltip: 'WhatsApp Client',
                    onPressed: () => _whatsAppClient(activeConv!.clientPhone!),
                  ),
                  IconButton(
                    icon: const Icon(Icons.phone_in_talk_outlined, color: AppColors.primary),
                    tooltip: 'Call Client',
                    onPressed: () => _callClient(activeConv!.clientPhone!),
                  ),
                ],
              ],
            ),
          ),

          // Messages
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chatState.currentMessages.length,
                    itemBuilder: (context, index) {
                      final msg = chatState.currentMessages[index];
                      final isStaff = msg.isFromAdmin;
                      final timeStr = DateFormat('hh:mm a').format(msg.createdAt);

                      return Align(
                        alignment: isStaff ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.65,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isStaff ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(14),
                              topRight: const Radius.circular(14),
                              bottomLeft: Radius.circular(isStaff ? 14 : 4),
                              bottomRight: Radius.circular(isStaff ? 4 : 14),
                            ),
                            border: isStaff ? null : Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: isStaff ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (!isStaff) ...[
                                Text(
                                  msg.senderName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                                ),
                                const SizedBox(height: 2),
                              ],
                              Text(
                                msg.message,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: isStaff ? Colors.white : const Color(0xFF1E293B),
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timeStr,
                                style: TextStyle(fontSize: 10, color: isStaff ? Colors.white60 : Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Type your official reply...',
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _handleSendReply(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: chatState.isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                  onPressed: chatState.isSending ? null : _handleSendReply,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
