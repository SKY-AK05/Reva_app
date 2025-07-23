import 'package:flutter/material.dart';

/// Loading indicator with customizable message and size
class LoadingIndicator extends StatelessWidget {
  final String? message;
  final double? size;
  final Color? color;
  final bool showMessage;

  const LoadingIndicator({
    super.key,
    this.message,
    this.size,
    this.color,
    this.showMessage = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size ?? 24,
          height: size ?? 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? theme.colorScheme.primary,
            ),
          ),
        ),
        if (showMessage && message != null) ...[
          const SizedBox(height: 12),
          Text(
            message!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Full-screen loading overlay
class LoadingScreen extends StatelessWidget {
  final String? message;
  final bool canPop;

  const LoadingScreen({
    super.key,
    this.message,
    this.canPop = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: canPop,
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.3),
        body: Center(
          child: Card(
            margin: const EdgeInsets.all(32),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: LoadingIndicator(
                message: message ?? 'Loading...',
                size: 32,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading button that shows spinner when loading
class LoadingButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final ButtonStyle? style;
  final bool isElevated;

  const LoadingButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.style,
    this.isElevated = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = isElevated
        ? ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: style,
            child: _buildChild(context),
          )
        : TextButton(
            onPressed: isLoading ? null : onPressed,
            style: style,
            child: _buildChild(context),
          );

    return button;
  }

  Widget _buildChild(BuildContext context) {
    if (isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          child,
        ],
      );
    }
    return child;
  }
}

/// Loading list item placeholder
class LoadingListItem extends StatelessWidget {
  final double height;
  final EdgeInsets? margin;

  const LoadingListItem({
    super.key,
    this.height = 72,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: height,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildShimmer(context, 40, 40, isCircle: true),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildShimmer(context, double.infinity, 16),
                    const SizedBox(height: 8),
                    _buildShimmer(context, 120, 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer(BuildContext context, double width, double height, {bool isCircle = false}) {
    final theme = Theme.of(context);
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: isCircle 
            ? BorderRadius.circular(height / 2)
            : BorderRadius.circular(4),
      ),
    );
  }
}

/// Loading grid for displaying multiple loading items
class LoadingGrid extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final int crossAxisCount;

  const LoadingGrid({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 120,
    this.crossAxisCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => _buildLoadingCard(context),
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 16,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 80,
              height: 12,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Spacer(),
            Container(
              width: 60,
              height: 12,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline loading indicator for forms
class InlineLoading extends StatelessWidget {
  final String? message;
  final double size;

  const InlineLoading({
    super.key,
    this.message,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(width: 8),
          Text(
            message!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Pull-to-refresh loading indicator
class PullToRefreshLoading extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final String? refreshMessage;

  const PullToRefreshLoading({
    super.key,
    required this.child,
    required this.onRefresh,
    this.refreshMessage,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: child,
    );
  }
}

/// Loading state wrapper for async operations
class AsyncLoadingWrapper<T> extends StatelessWidget {
  final AsyncValue<T> asyncValue;
  final Widget Function(T data) dataBuilder;
  final Widget Function()? loadingBuilder;
  final Widget Function(Object error, StackTrace stackTrace)? errorBuilder;
  final String? loadingMessage;

  const AsyncLoadingWrapper({
    super.key,
    required this.asyncValue,
    required this.dataBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.loadingMessage,
  });

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      data: dataBuilder,
      loading: () => loadingBuilder?.call() ?? 
          Center(
            child: LoadingIndicator(
              message: loadingMessage,
            ),
          ),
      error: (error, stackTrace) => errorBuilder?.call(error, stackTrace) ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text('Something went wrong'),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
    );
  }
}

/// Loading state for lists with empty state
class ListLoadingState extends StatelessWidget {
  final bool isLoading;
  final bool isEmpty;
  final bool hasError;
  final String? emptyMessage;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final Widget Function() itemBuilder;
  final int loadingItemCount;

  const ListLoadingState({
    super.key,
    required this.isLoading,
    required this.isEmpty,
    required this.hasError,
    required this.itemBuilder,
    this.emptyMessage,
    this.errorMessage,
    this.onRetry,
    this.loadingItemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return ListView.builder(
        itemCount: loadingItemCount,
        itemBuilder: (context, index) => const LoadingListItem(),
      );
    }

    if (hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(errorMessage ?? 'Something went wrong'),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Try Again'),
              ),
            ],
          ],
        ),
      );
    }

    if (isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, size: 48),
            const SizedBox(height: 16),
            Text(emptyMessage ?? 'No items found'),
          ],
        ),
      );
    }

    return itemBuilder();
  }
}