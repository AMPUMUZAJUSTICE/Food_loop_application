import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/chat_message.dart';
import '../bloc/chat_bloc.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatBloc _chatBloc;
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late String _currentUserId;
  late String _recipientId;

  @override
  void initState() {
    super.initState();
    _chatBloc = sl<ChatBloc>();
    
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _currentUserId = authState.user.uid;
      // Derived from deterministic chatId (buyerId_sellerId_listingId)
      // Extract recipientId from chatId string logic
      List<String> parts = widget.chatId.split('_');
      if (parts.length >= 2) {
        if (parts[0] == _currentUserId) {
          _recipientId = parts[1];
        } else {
          _recipientId = parts[0];
        }
      } else {
        _recipientId = 'unknown';
      }

      _chatBloc.add(LoadChatMessages(widget.chatId, _currentUserId));
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _chatBloc.close();
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final msg = ChatMessage(
      id: const Uuid().v4(),
      senderId: _currentUserId,
      recipientId: _recipientId,
      text: text,
      timestamp: DateTime.now(),
      isRead: false,
      messageType: MessageType.text,
    );

    _chatBloc.add(SendMessage(widget.chatId, msg, _recipientId));
    _msgController.clear();
    
    // Scroll to bottom manually on optimistic send
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _chatBloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.primaryGreen,
          elevation: 1,
        ),
        body: Column(
          children: [
            Expanded(
              child: BlocConsumer<ChatBloc, ChatState>(
                listener: (context, state) {
                  // Auto scroll when new messages come in
                  if (state is ChatLoaded && _scrollController.hasClients) {
                    Future.delayed(const Duration(milliseconds: 100), () {
                     if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                     }
                    });
                  }
                },
                builder: (context, state) {
                  if (state is ChatLoading || state is ChatInitial) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
                  } else if (state is ChatError) {
                    return Center(child: Text(state.message));
                  } else if (state is ChatLoaded) {
                    if (state.messages.isEmpty) {
                      return const Center(child: Text('Be the first to say something!', style: TextStyle(color: AppColors.textGrey)));
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      itemCount: state.messages.length,
                      itemBuilder: (context, index) {
                        final msg = state.messages[index];
                        final isMe = msg.senderId == _currentUserId;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe ? AppColors.primaryGreen : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                                bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                              ),
                              border: isMe ? null : Border.all(color: Colors.grey[200]!),
                            ),
                            child: Text(
                              msg.text,
                              style: TextStyle(
                                color: isMe ? Colors.white : AppColors.textDark,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            
            // Input Area
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
