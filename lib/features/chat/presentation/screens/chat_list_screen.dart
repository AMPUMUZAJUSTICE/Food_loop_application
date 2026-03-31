import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../bloc/chat_list_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late final ChatListBloc _chatListBloc;

  @override
  void initState() {
    super.initState();
    _chatListBloc = sl<ChatListBloc>();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _chatListBloc.add(LoadChatThreads(authState.user.uid));
    }
  }

  @override
  void dispose() {
    _chatListBloc.close();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays == 0) return DateFormat.jm().format(time);
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('MMM d').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      return const Scaffold(body: Center(child: Text('Please login to view chats.')));
    }
    final currentUserId = authState.user.uid;

    return BlocProvider.value(
      value: _chatListBloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.primaryGreen,
          elevation: 0,
        ),
        body: BlocBuilder<ChatListBloc, ChatListState>(
          builder: (context, state) {
            if (state is ChatListLoading || state is ChatListInitial) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
            } else if (state is ChatListError) {
              return Center(child: Text(state.message, style: const TextStyle(color: AppColors.errorRed)));
            } else if (state is ChatListLoaded) {
              if (state.threads.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No messages yet', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Start a conversation by claiming food.', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: state.threads.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final thread = state.threads[index];
                  final unreadCount = thread.unreadCount[currentUserId] ?? 0;
                  final hasUnread = unreadCount > 0;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.lightGreen,
                      backgroundImage: thread.listingImageUrl.isNotEmpty 
                        ? CachedNetworkImageProvider(thread.listingImageUrl) 
                        : null,
                      child: thread.listingImageUrl.isEmpty ? const Icon(Icons.fastfood, color: AppColors.primaryGreen) : null,
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            thread.listingTitle,
                            style: TextStyle(
                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTime(thread.lastMessageTime),
                          style: TextStyle(
                            fontSize: 12,
                            color: hasUnread ? AppColors.primaryGreen : AppColors.textGrey,
                            fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.lastMessage.isEmpty ? 'Say hello!' : thread.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hasUnread ? AppColors.textDark : AppColors.textGrey,
                              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (hasUnread)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(color: AppColors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          )
                      ],
                    ),
                    onTap: () {
                      context.push('/chat/${thread.id}');
                    },
                  );
                },
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }
}
