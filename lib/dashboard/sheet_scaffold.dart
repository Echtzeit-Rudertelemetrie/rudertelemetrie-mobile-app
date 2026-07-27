import 'package:flutter/material.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

/// Bottom-sheet scaffold that can be resized by dragging and scrolled to reveal
/// all of its content. [children] fill a scrollable body; [footer] stays pinned
/// at the bottom (e.g. an Apply / Add button) and may be omitted when the body
/// itself carries the actions.
///
/// [onBack] turns the header into one step of a multi-step sheet: it returns to
/// the previous step rather than closing the sheet.
///
/// Show the host sheet with `isScrollControlled: true` and a transparent
/// background — this widget paints its own surface.
class SheetScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? footer;
  final VoidCallback? onBack;
  final double initialSize;

  const SheetScaffold({
    super.key,
    required this.title,
    required this.children,
    this.footer,
    this.onBack,
    this.initialSize = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initialSize,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: const BoxDecoration(
            color: AppPalette.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              const _Grabber(),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  onBack == null ? 16 : 8,
                  0,
                  16,
                  12,
                ),
                child: Row(
                  children: [
                    if (onBack != null) _BackButton(onTap: onBack!),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  children: children,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      footer == null ? 0 : 8,
                      16,
                      12,
                    ),
                    child: footer ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: const SizedBox(
      width: kMinTapTarget,
      height: kMinTapTarget,
      child: Icon(Icons.arrow_back, size: 20, color: AppPalette.mutedLabel),
    ),
  );
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 4,
    margin: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white24,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}
