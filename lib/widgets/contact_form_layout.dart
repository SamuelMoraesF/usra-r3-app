import 'package:flutter/material.dart';

class ContactFormLayout extends StatelessWidget {
  const ContactFormLayout({
    super.key,
    required this.fourColumns,
    required this.fields,
    required this.closeButton,
    required this.submitButton,
    this.message,
  }) : assert(fields.length == 8);

  final bool fourColumns;
  final List<Widget> fields;
  final Widget closeButton;
  final Widget submitButton;
  final Widget? message;

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
        const SizedBox(height: 12),
        _row(fields.sublist(4, 8)),
      ] else ...[
        _row(fields.sublist(0, 2)),
        const SizedBox(height: 12),
        fields[2],
        const SizedBox(height: 12),
        fields[3],
        const SizedBox(height: 12),
        _row(fields.sublist(4, 6)),
        const SizedBox(height: 12),
        _row(fields.sublist(6, 8)),
      ],
      if (message != null) ...[const SizedBox(height: 12), message!],
      const SizedBox(height: 18),
      if (fourColumns)
        _row([
          closeButton,
          const SizedBox.shrink(),
          const SizedBox.shrink(),
          submitButton,
        ])
      else ...[
        submitButton,
        const SizedBox(height: 12),
        closeButton,
      ],
    ],
  );
}
