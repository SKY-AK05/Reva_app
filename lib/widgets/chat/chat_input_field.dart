import 'package:flutter/material.dart';

class ChatInputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool isEnabled;
  final bool isSending;
  final bool isOffline;

  const ChatInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    this.isEnabled = true,
    this.isSending = false,
    this.isOffline = false,
  });

  @override
  State<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<ChatInputField> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _handleSend() {
    if (_hasText && widget.isEnabled && !widget.isOffline) {
      widget.onSend();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF000000) : theme.colorScheme.surface;
    final inputColor = isDark ? const Color(0xFF181818) : theme.colorScheme.surfaceVariant;
    final borderColor = isDark ? const Color(0xFF23272F) : theme.colorScheme.outline.withOpacity(0.2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      color: backgroundColor,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: inputColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        enabled: widget.isEnabled && !widget.isOffline,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: widget.isOffline 
                              ? 'You\'re offline'
                              : widget.isSending 
                                  ? 'Sending...'
                                  : 'Ask anything...',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          prefixIcon: widget.isOffline
                              ? Icon(
                                  Icons.cloud_off,
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                )
                              : null,
                        ),
                        onSubmitted: (_) => _handleSend(),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _buildSendButton(theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton(ThemeData theme) {
    final canSend = _hasText && widget.isEnabled && !widget.isOffline;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: canSend ? _handleSend : null,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: widget.isSending
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  )
                : Icon(
                    Icons.send,
                    color: canSend
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.4),
                    size: 24,
                  ),
          ),
        ),
      ),
    );
  }
}