import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai/ai_chat_service.dart';

class AiPanel extends ConsumerStatefulWidget {
  const AiPanel({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  ConsumerState<AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends ConsumerState<AiPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final aiService = ref.read(aiChatServiceProvider);
    aiService.onMessagesChange.listen((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiService = ref.watch(aiChatServiceProvider);
    final theme = Theme.of(context);
    final messages = aiService.messages;

    return Column(
      children: [
        _buildHeader(context, aiService, theme),
        _buildPromptChips(context, aiService),
        Expanded(
          child: messages.isEmpty ? _buildEmptyState(theme) : _buildMessagesList(messages, theme),
        ),
        _buildInputBar(context, aiService, theme),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, AiChatService aiService, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.smart_toy, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI Ассистент',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => aiService.clearHistory(),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildPromptChips(BuildContext context, AiChatService aiService) {
    final prompts = [
      (AiPromptType.summarizeChapter, 'Суммаризировать главу'),
      (AiPromptType.summarizeBook, 'Суммаризировать книгу'),
      (AiPromptType.mindMap, 'Mind map'),
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ...prompts.map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ActionChip(
                label: Text(p.$2, style: const TextStyle(fontSize: 12)),
                onPressed: () => _sendPrompt(aiService, p.$1),
              ),
            ),
          ),
          ...aiService.settings.customPrompts.map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ActionChip(
                label: Text(p, style: const TextStyle(fontSize: 12)),
                onPressed: () => _sendCustomPrompt(aiService, p),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Свой', style: TextStyle(fontSize: 12)),
              onPressed: () => _showAddPromptDialog(context, aiService),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'Задайте вопрос о книге',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(List<AiMessage> messages, ThemeData theme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final isUser = msg.role == 'user';

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            decoration: BoxDecoration(
              color: isUser
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg.content.isEmpty && msg.isStreaming ? '...' : msg.content,
                  style: theme.textTheme.bodyMedium,
                ),
                if (msg.isStreaming)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputBar(BuildContext context, AiChatService aiService, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Введите вопрос...',
                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(aiService),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: () => _sendMessage(aiService),
            icon: const Icon(Icons.send, size: 20),
          ),
        ],
      ),
    );
  }

  void _sendMessage(AiChatService aiService) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    aiService.sendMessage(text);
  }

  void _sendPrompt(AiChatService aiService, AiPromptType type) {
    final prompt = aiService.buildPrompt(type);
    aiService.sendMessage(prompt);
  }

  void _sendCustomPrompt(AiChatService aiService, String customPrompt) {
    aiService.sendMessage(customPrompt);
  }

  void _showAddPromptDialog(BuildContext context, AiChatService aiService) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавить промпт'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Текст промпта'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                aiService.addCustomPrompt(text);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }
}
