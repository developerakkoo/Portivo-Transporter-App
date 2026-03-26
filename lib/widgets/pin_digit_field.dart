import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Single digit box for PIN/OTP-style input with correct Backspace behavior:
/// when the field is empty, Backspace clears the previous digit and moves focus.
///
/// Does not wrap [TextFormField] in an extra [Focus] with the same [FocusNode]
/// (that causes "Tried to make a child into a parent of itself").
class PinDigitField extends StatefulWidget {
  const PinDigitField({
    super.key,
    required this.index,
    required this.controller,
    required this.focusNode,
    required this.controllers,
    required this.focusNodes,
    required this.onChanged,
    required this.onStateChanged,
    required this.decoration,
    this.style,
    this.onFieldSubmitted,
    this.onEditingComplete,
    this.width = 70,
    this.height = 70,
  });

  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final ValueChanged<String> onChanged;
  final VoidCallback onStateChanged;
  final InputDecoration decoration;
  final TextStyle? style;
  final void Function(String)? onFieldSubmitted;
  final VoidCallback? onEditingComplete;
  final double width;
  final double height;

  @override
  State<PinDigitField> createState() => _PinDigitFieldState();
}

class _PinDigitFieldState extends State<PinDigitField> {
  bool _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.backspace) return false;
    if (!widget.focusNode.hasFocus) return false;
    if (widget.controller.text.isNotEmpty) return false;
    if (widget.index <= 0) return false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controllers[widget.index - 1].clear();
      widget.focusNodes[widget.index - 1].requestFocus();
      widget.onStateChanged();
    });
    return true;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        style: widget.style,
        decoration: widget.decoration,
        onChanged: widget.onChanged,
        onTap: widget.onStateChanged,
        onEditingComplete: widget.onEditingComplete,
        onFieldSubmitted: widget.onFieldSubmitted,
        buildCounter:
            (context, {required currentLength, required isFocused, maxLength}) =>
                null,
      ),
    );
  }
}
