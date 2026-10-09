import 'dart:async';

import 'package:favor_ledger/application/providers.dart';
import 'package:favor_ledger/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 居中轻提示：仅文字，无横幅。
///
/// 必须叠在 [MaterialApp.builder] 的 child 上用 Stack 绘制，
/// 不能往 Overlay 里插——builder 上下文在 Navigator Overlay 之上，拿不到 Overlay。
class SoftToastScope extends ConsumerStatefulWidget {
  const SoftToastScope({super.key, required this.child});

  final Widget child;

  static SoftToastScopeState of(BuildContext context) {
    final state = context.findAncestorStateOfType<SoftToastScopeState>();
    assert(state != null, 'SoftToastScope not found');
    return state!;
  }

  static void show(
    BuildContext context,
    String message, {
    bool error = false,
  }) {
    of(context).show(message, error: error);
  }

  @override
  ConsumerState<SoftToastScope> createState() => SoftToastScopeState();
}

class SoftToastScopeState extends ConsumerState<SoftToastScope> {
  Timer? _hideTimer;
  String? _message;
  var _error = false;
  var _seq = 0;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void show(String message, {bool error = false}) {
    final text = message.trim();
    if (text.isEmpty) return;

    _hideTimer?.cancel();
    final token = ++_seq;
    setState(() {
      _message = text;
      _error = error;
    });

    _hideTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted || token != _seq) return;
      setState(() => _message = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(syncHubProvider, (prev, next) {
      final toast = next.pendingToast;
      if (toast == null || toast.isEmpty) return;
      if (prev?.toastSeq == next.toastSeq) return;
      show(toast, error: next.pendingToastError);
      ref.read(syncHubProvider.notifier).clearToast();
    });

    final toast = _message;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (toast != null)
          IgnorePointer(
            child: _SoftToastPane(
              key: ValueKey(_seq),
              message: toast,
              error: _error,
            ),
          ),
      ],
    );
  }
}

class _SoftToastPane extends StatefulWidget {
  const _SoftToastPane({
    super.key,
    required this.message,
    required this.error,
  });

  final String message;
  final bool error;

  @override
  State<_SoftToastPane> createState() => _SoftToastPaneState();
}

class _SoftToastPaneState extends State<_SoftToastPane>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..forward();

  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  late final Animation<double> _slide = Tween<double>(begin: 8, end: 0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.error ? const Color(0xFFB3261E) : AppColors.ink;

    return SafeArea(
      child: Align(
        // 左右居中，垂直落在中下部
        alignment: const Alignment(0, 0.55),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacity.value,
              child: Transform.translate(
                offset: Offset(0, _slide.value),
                child: child,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              widget.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                height: 1.35,
                letterSpacing: 0.2,
                shadows: const [
                  Shadow(
                    color: Color(0xF2F2F6F4),
                    blurRadius: 12,
                    offset: Offset(0, 0),
                  ),
                  Shadow(
                    color: Color(0xE6FFFFFF),
                    blurRadius: 18,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
