import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../grid_locator.dart';

class GridLocatorField extends StatefulWidget {
  const GridLocatorField({
    super.key,
    this.controller,
    this.focusNode,
    this.allowInvalid = false,
    this.labelText = 'Localização ou grid',
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool allowInvalid;
  final String labelText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<GridLocatorField> createState() => _GridLocatorFieldState();
}

class _GridLocatorFieldState extends State<GridLocatorField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  late final FocusNode _focusNode = (widget.focusNode ?? FocusNode())
    ..addListener(_handleFocus);
  GridLocatorInfo _info = const GridLocatorInfo.invalid();

  @override
  void initState() {
    super.initState();
    _update(_controller.text);
    _controller.addListener(_handleText);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocus);
    if (widget.focusNode == null) _focusNode.dispose();
    _controller.removeListener(_handleText);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _handleText() => _update(_controller.text);

  void _update(String value) {
    final info = GridLocator.inspect(value);
    if (mounted) setState(() => _info = info);
    widget.onChanged?.call(value);
  }

  void _handleFocus() {
    if (!_focusNode.hasFocus &&
        _info.isValid &&
        _controller.text != _info.normalized) {
      _controller.value = _controller.value.copyWith(
        text: _info.normalized.toLowerCase(),
        selection: TextSelection.collapsed(offset: _info.normalized.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final showError =
        !widget.allowInvalid &&
        _controller.text.trim().isNotEmpty &&
        !_info.isValid;
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      textCapitalization: TextCapitalization.none,
      inputFormatters: [LowerCaseFormatter()],
      textInputAction: TextInputAction.next,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: 'Ex.: GG30CH90NH',
        errorText: showError ? 'Informe um grid Maidenhead válido' : null,
        helperText: _info.isValid
            ? _info.accuracy?.label
            : (widget.allowInvalid ? 'Texto livre' : null),
        helperStyle: _info.isValid
            ? null
            : const TextStyle(color: Color(0xFF71717A)),
        suffixIcon: _info.isValid
            ? const Icon(Icons.check_circle_outline)
            : null,
      ),
    );
  }
}

class LowerCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(
    text: newValue.text.toLowerCase(),
    selection: newValue.selection,
  );
}
