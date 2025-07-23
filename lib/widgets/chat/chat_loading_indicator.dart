import 'package:flutter/material.dart';

class ChatLoadingIndicator extends StatefulWidget {
  final String? message;

  const ChatLoadingIndicator({
    super.key,
    this.message,
  });

  @override
  State<ChatLoadingIndicator> createState() => _ChatLoadingIndicatorState();
}

class _ChatLoadingIndicatorState extends State<ChatLoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAvatar(context),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTypingBubble(context),
              if (widget.message != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.message!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Theme.of(context).colorScheme.secondary,
      child: Icon(
        Icons.smart_toy,
        size: 16,
        color: Theme.of(context).colorScheme.onSecondary,
      ),
    );
  }

  Widget _buildTypingBubble(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(18).copyWith(
          bottomLeft: const Radius.circular(4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTypingDot(context, 0),
          const SizedBox(width: 4),
          _buildTypingDot(context, 200),
          const SizedBox(width: 4),
          _buildTypingDot(context, 400),
        ],
      ),
    );
  }

  Widget _buildTypingDot(BuildContext context, int delay) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final delayedAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            delay / 1500.0,
            (delay + 300) / 1500.0,
            curve: Curves.easeInOut,
          ),
        ));

        return Transform.translate(
          offset: Offset(0, -4 * delayedAnimation.value),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(
                0.4 + (0.4 * delayedAnimation.value),
              ),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

/// Typing indicator for when Reva is processing a message
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ChatLoadingIndicator(
        message: 'Reva is typing...',
      ),
    );
  }
}

/// Loading indicator for when loading more messages
class LoadingMoreIndicator extends StatelessWidget {
  const LoadingMoreIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Loading messages...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}