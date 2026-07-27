import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// [FutureBuilder] with the three states every async screen needs: a spinner
/// while pending, a readable message plus Retry on failure, and the content.
class AsyncContent<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback onRetry;
  final String errorMessage;
  final double height;

  const AsyncContent({
    super.key,
    required this.future,
    required this.builder,
    required this.onRetry,
    required this.errorMessage,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) return _error(context);
      if (!snapshot.hasData) return _pending();
      return builder(context, snapshot.data as T);
    },
  );

  Widget _pending() => SizedBox(
    height: height,
    child: const Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );

  Widget _error(BuildContext context) => SizedBox(
    height: height,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: context.theme.typography.sm.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 12),
          FButton(
            variant: FButtonVariant.outline,
            size: FButtonSizeVariant.sm,
            mainAxisSize: MainAxisSize.min,
            onPress: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
