import 'package:flutter/material.dart';

class ContactFormLayout extends StatelessWidget {
  const ContactFormLayout({
    super.key,
    required this.fourColumns,
    required this.fields,
    required this.closeButton,
    required this.submitButton,
    this.compact = false,
    this.submitInLastColumn = false,
    this.showCloseButton = true,
    this.message,
  }) : assert(fields.length == 8);

  final bool fourColumns;
  final List<Widget> fields;
  final Widget closeButton;
  final Widget submitButton;
  final bool compact;
  final bool submitInLastColumn;
  final bool showCloseButton;
  final Widget? message;

  double get _rowSpacing => compact && fourColumns ? 8 : 12;

  Widget _row(List<Widget> children) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(child: children[i]),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (fourColumns) ...[
        _row(fields.sublist(0, 4)),
        SizedBox(height: _rowSpacing),
        _row([...fields.sublist(4, 8), if (submitInLastColumn) submitButton]),
      ] else ...[
        _row(fields.sublist(0, 2)),
        SizedBox(height: compact ? 8 : 12),
        fields[2],
        SizedBox(height: compact ? 8 : 12),
        fields[3],
        SizedBox(height: compact ? 8 : 12),
        _row(fields.sublist(4, 6)),
        SizedBox(height: compact ? 8 : 12),
        _row(fields.sublist(6, 8)),
      ],
      if (message != null) ...[SizedBox(height: compact ? 8 : 12), message!],
      if (showCloseButton) ...[
        SizedBox(height: compact ? 8 : 18),
        if (fourColumns && !submitInLastColumn)
          _row([
            closeButton,
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            submitButton,
          ])
        else if (!fourColumns) ...[
          submitButton,
          SizedBox(height: compact ? 8 : 12),
          closeButton,
        ],
      ],
    ],
  );
}
