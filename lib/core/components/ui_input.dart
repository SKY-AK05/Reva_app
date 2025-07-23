import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../animations/app_animations.dart';
import '../accessibility/accessibility_utils.dart';
import '../responsive/responsive_utils.dart';

/// A reusable input field component matching ShadCN UI design with animations and accessibility
class UIInput extends StatefulWidget {
  final String? label;
  final String? placeholder;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final String? semanticLabel;
  final bool enableAnimation;
  final HapticFeedbackType? hapticFeedback;

  const UIInput({
    super.key,
    this.label,
    this.placeholder,
    this.helperText,
    this.errorText,
    this.controller,
    this.onChanged,
    this.onTap,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.validator,
    this.focusNode,
    this.textInputAction,
    this.onEditingComplete,
    this.onSubmitted,
    this.semanticLabel,
    this.enableAnimation = true,
    this.hapticFeedback = HapticFeedbackType.selectionClick,
  });

  @override
  State<UIInput> createState() => _UIInputState();
}

class _UIInputState extends State<UIInput> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
    
    // Provide haptic feedback on focus change
    if (widget.hapticFeedback != null && _isFocused) {
      AccessibilityUtils.provideFeedback(widget.hapticFeedback!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsivePadding = ResponsiveUtils.getResponsivePadding(context);
    final fontSizeMultiplier = ResponsiveUtils.getFontSizeMultiplier(context);
    final effectiveSemanticLabel = widget.semanticLabel ?? widget.label ?? widget.placeholder;

    Widget inputField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          ResponsiveText(
            widget.label!,
            style: AppTheme.getTextStyle(context, 'labelMedium').copyWith(
              color: AppTheme.getColor(context, 'foreground'),
              fontWeight: FontWeight.w500,
              fontSize: (AppTheme.getTextStyle(context, 'labelMedium').fontSize ?? 14) * fontSizeMultiplier,
            ),
          ),
          SizedBox(height: AppTheme.spacing1),
        ],
        AnimatedContainer(
          duration: widget.enableAnimation ? AppAnimations.fast : Duration.zero,
          curve: AppAnimations.defaultCurve,
          decoration: BoxDecoration(
            borderRadius: AppTheme.getBorderRadius('md'),
            boxShadow: _isFocused && widget.enableAnimation
              ? [
                  BoxShadow(
                    color: AppTheme.getColor(context, 'ring').withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            onChanged: widget.onChanged,
            onTap: widget.onTap,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            inputFormatters: widget.inputFormatters,
            validator: widget.validator,
            textInputAction: widget.textInputAction,
            onEditingComplete: widget.onEditingComplete,
            onFieldSubmitted: widget.onSubmitted,
            style: AppTheme.getTextStyle(context, 'body').copyWith(
              color: widget.enabled 
                ? AppTheme.getColor(context, 'foreground')
                : AppTheme.getColor(context, 'mutedForeground'),
              fontSize: (AppTheme.getTextStyle(context, 'body').fontSize ?? 14) * fontSizeMultiplier,
            ),
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: AppTheme.getTextStyle(context, 'body').copyWith(
                color: AppTheme.getColor(context, 'mutedForeground'),
                fontSize: (AppTheme.getTextStyle(context, 'body').fontSize ?? 14) * fontSizeMultiplier,
              ),
              prefixIcon: widget.prefixIcon,
              suffixIcon: widget.suffixIcon,
              filled: true,
              fillColor: widget.enabled 
                ? AppTheme.getColor(context, 'background')
                : AppTheme.getColor(context, 'muted'),
              border: OutlineInputBorder(
                borderRadius: AppTheme.getBorderRadius('md'),
                borderSide: BorderSide(
                  color: AppTheme.getColor(context, 'border'),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppTheme.getBorderRadius('md'),
                borderSide: BorderSide(
                  color: AppTheme.getColor(context, 'border'),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppTheme.getBorderRadius('md'),
                borderSide: BorderSide(
                  color: AppTheme.getColor(context, 'ring'),
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: AppTheme.getBorderRadius('md'),
                borderSide: BorderSide(
                  color: AppTheme.getColor(context, 'destructive'),
                  width: 1,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: AppTheme.getBorderRadius('md'),
                borderSide: BorderSide(
                  color: AppTheme.getColor(context, 'destructive'),
                  width: 2,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.isSmallScreen(context) ? AppTheme.spacing3 : AppTheme.spacing4,
                vertical: ResponsiveUtils.isSmallScreen(context) ? AppTheme.spacing2 : AppTheme.spacing3,
              ),
              errorText: widget.errorText,
              errorStyle: AppTheme.getTextStyle(context, 'bodySmall').copyWith(
                color: AppTheme.getColor(context, 'destructive'),
              ),
              counterStyle: AppTheme.getTextStyle(context, 'bodySmall').copyWith(
                color: AppTheme.getColor(context, 'mutedForeground'),
              ),
            ),
          ),
        ),
        if (widget.helperText != null && widget.errorText == null) ...[
          SizedBox(height: AppTheme.spacing1),
          AnimatedOpacity(
            duration: widget.enableAnimation ? AppAnimations.fast : Duration.zero,
            opacity: 1.0,
            child: ResponsiveText(
              widget.helperText!,
              style: AppTheme.getTextStyle(context, 'bodySmall').copyWith(
                color: AppTheme.getColor(context, 'mutedForeground'),
              ),
            ),
          ),
        ],
        if (widget.errorText != null) ...[
          SizedBox(height: AppTheme.spacing1),
          AnimatedOpacity(
            duration: widget.enableAnimation ? AppAnimations.fast : Duration.zero,
            opacity: 1.0,
            child: ResponsiveText(
              widget.errorText!,
              style: AppTheme.getTextStyle(context, 'bodySmall').copyWith(
                color: AppTheme.getColor(context, 'destructive'),
              ),
            ),
          ),
        ],
      ],
    );

    // Add semantic information for screen readers
    return AccessibleFormField(
      label: widget.label,
      hint: widget.helperText,
      error: widget.errorText,
      isRequired: widget.validator != null,
      child: inputField,
    );
  }
}

/// A specialized textarea component
class UITextArea extends StatelessWidget {
  final String? label;
  final String? placeholder;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final int minLines;
  final int maxLines;
  final bool enabled;
  final String? Function(String?)? validator;

  const UITextArea({
    super.key,
    this.label,
    this.placeholder,
    this.helperText,
    this.errorText,
    this.controller,
    this.onChanged,
    this.minLines = 3,
    this.maxLines = 6,
    this.enabled = true,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return UIInput(
      label: label,
      placeholder: placeholder,
      helperText: helperText,
      errorText: errorText,
      controller: controller,
      onChanged: onChanged,
      maxLines: maxLines,
      enabled: enabled,
      validator: validator,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
    );
  }
}