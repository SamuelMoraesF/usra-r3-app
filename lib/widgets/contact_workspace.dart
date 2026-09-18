import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Map and contact form on the left; independently scrolling logs on the right.
class ContactWorkspace extends StatefulWidget {
  const ContactWorkspace({
    super.key,
    required this.map,
    required this.form,
    required this.logs,
    required this.formScrollController,
    this.keyboardInset = 0,
    this.mapBottomOverlay,
    this.logsHeader,
    this.logsTitle,
    this.logsTitleInContent = false,
  });

  final Widget map;
  final Widget form;
  final Widget logs;
  final ScrollController formScrollController;
  final double keyboardInset;
  final Widget? mapBottomOverlay;
  final Widget? logsHeader;
  final Widget? logsTitle;
  final bool logsTitleInContent;

  @override
  State<ContactWorkspace> createState() => _ContactWorkspaceState();
}

class _ContactWorkspaceState extends State<ContactWorkspace> {
  double? _contentHeight;
  double _logsWidth = 440;
  final _logsScrollController = ScrollController();

  @override
  void dispose() {
    _logsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const dividerSize = 16.0;
      final formHeight = math.min(
        _contentHeight ?? 390,
        math.max(0.0, constraints.maxHeight - 160),
      );
      final maxLogsWidth = math.max(
        300.0,
        constraints.maxWidth - 360 - dividerSize,
      );
      final logsWidth = _logsWidth.clamp(300.0, maxLogsWidth);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The map must keep its viewport while the IME is visible.
                // Only the form panel moves above the keyboard inset.
                MediaQuery.removeViewInsets(
                  context: context,
                  removeBottom: true,
                  child: widget.map,
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  left: 0,
                  right: 0,
                  bottom: widget.keyboardInset,
                  height: formHeight,
                  child: _buildFormPanel(context),
                ),
                if (widget.mapBottomOverlay != null)
                  Positioned(
                    left: 24,
                    right: 24,
                    // Keep map controls at the map's lower edge while the
                    // form overlays the viewport. As the form grows or moves
                    // above the keyboard, the controls rise with its top.
                    bottom: widget.keyboardInset + formHeight + 12,
                    child: widget.mapBottomOverlay!,
                  ),
              ],
            ),
          ),
          _ResizeHandle(
            key: const ValueKey('logs-resize'),
            vertical: true,
            onDrag: (delta) => setState(() {
              _logsWidth = (logsWidth - delta.dx).clamp(300.0, maxLogsWidth);
            }),
          ),
          SizedBox(
            key: const ValueKey('contact-logs-panel'),
            width: logsWidth,
            child: _buildLogsPanel(constraints),
          ),
        ],
      );
    },
  );

  Widget _buildFormPanel(BuildContext context) => Material(
    color: Theme.of(context).scaffoldBackgroundColor,
    elevation: 0,
    child: SingleChildScrollView(
      key: const ValueKey('contact-form-panel'),
      controller: widget.formScrollController,
      child: _MeasureHeight(
        onHeightChanged: (height) {
          if (mounted && _contentHeight != height) {
            setState(() => _contentHeight = height);
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
          child: Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: Theme.of(context).inputDecorationTheme
                  .copyWith(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
            ),
            child: widget.form,
          ),
        ),
      ),
    ),
  );

  Widget _buildLogsPanel(BoxConstraints constraints) {
    final canFixHeaders =
        widget.logsHeader != null &&
        widget.logsTitle != null &&
        constraints.maxHeight >= 300;
    if (!canFixHeaders) {
      return SingleChildScrollView(
        key: const ValueKey('contact-logs-single-scroll'),
        padding: const EdgeInsets.all(20),
        child: widget.logs,
      );
    }
    return Padding(
      // Keep the existing 20 px visual margin for content while reserving
      // that margin as a side rail for the scrollbar.
      padding: const EdgeInsets.fromLTRB(20, 20, 0, 20),
      child: Column(
        key: const ValueKey('contact-logs-fixed-header'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: widget.logsHeader!,
          ),
          const SizedBox(height: 20),
          if (!widget.logsTitleInContent) ...[
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: widget.logsTitle!,
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: Scrollbar(
              key: const ValueKey('contact-logs-content-scroll'),
              controller: _logsScrollController,
              thumbVisibility: true,
              interactive: true,
              child: SingleChildScrollView(
                controller: _logsScrollController,
                padding: const EdgeInsets.only(right: 20),
                child: widget.logs,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({
    super.key,
    required this.vertical,
    required this.onDrag,
  });
  final bool vertical;
  final ValueChanged<Offset> onDrag;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: vertical
        ? SystemMouseCursors.resizeLeftRight
        : SystemMouseCursors.resizeUpDown,
    child: Tooltip(
      message: vertical ? 'Redimensionar logs' : 'Redimensionar formulário',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: vertical
            ? (details) => onDrag(details.delta)
            : null,
        onVerticalDragUpdate: vertical
            ? null
            : (details) => onDrag(details.delta),
        child: SizedBox(
          width: vertical ? 16 : double.infinity,
          height: vertical ? double.infinity : 16,
          child: Center(
            child: Container(
              width: vertical ? 4 : 40,
              height: vertical ? 40 : 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// Measure after laying out the real form, including validation messages and
// optional fields. A viewport limit must never exceed its content height.
class _MeasureHeight extends SingleChildRenderObjectWidget {
  const _MeasureHeight({required this.onHeightChanged, required super.child});
  final ValueChanged<double> onHeightChanged;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _HeightReporter(onHeightChanged);

  @override
  void updateRenderObject(BuildContext context, _HeightReporter renderObject) {
    renderObject.onHeightChanged = onHeightChanged;
  }
}

class _HeightReporter extends RenderProxyBox {
  _HeightReporter(this.onHeightChanged);
  ValueChanged<double> onHeightChanged;
  double? _lastHeight;

  @override
  void performLayout() {
    super.performLayout();
    if (_lastHeight == size.height) return;
    final height = size.height;
    _lastHeight = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onHeightChanged(height);
    });
  }
}
