import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/error_provider.dart';

/// Enhanced text field with validation and error display
class ValidatedTextField extends ConsumerWidget {
  final String fieldName;
  final String formId;
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final bool required;
  final TextCapitalization textCapitalization;

  const ValidatedTextField({
    super.key,
    required this.fieldName,
    required this.formId,
    this.label,
    this.hint,
    this.controller,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.required = false,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formErrorState = ref.watch(formErrorProvider(formId));
    final formErrorNotifier = ref.read(formErrorProvider(formId).notifier);
    final fieldError = formErrorState.getFieldError(fieldName);
    final hasError = fieldError != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RichText(
              text: TextSpan(
                text: label!,
                style: Theme.of(context).textTheme.labelMedium,
                children: [
                  if (required)
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          maxLength: maxLength,
          enabled: enabled,
          textCapitalization: textCapitalization,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            errorText: hasError ? fieldError : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError 
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError 
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError 
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.error,
                width: 2,
              ),
            ),
          ),
          onChanged: (value) {
            // Clear field error when user starts typing
            if (hasError) {
              formErrorNotifier.clearFieldError(fieldName);
            }
            
            // Run validation if provided
            if (validator != null) {
              final error = validator!(value);
              if (error != null) {
                formErrorNotifier.setFieldError(fieldName, error);
              }
            }
            
            onChanged?.call(value);
          },
          onFieldSubmitted: onSubmitted,
          validator: (value) {
            // This is used for form validation
            final error = validator?.call(value);
            if (error != null) {
              formErrorNotifier.setFieldError(fieldName, error);
            }
            return error;
          },
        ),
      ],
    );
  }
}

/// Form validation summary widget
class FormValidationSummary extends ConsumerWidget {
  final String formId;
  final bool showFieldErrors;

  const FormValidationSummary({
    super.key,
    required this.formId,
    this.showFieldErrors = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formErrorState = ref.watch(formErrorProvider(formId));
    
    if (!formErrorState.hasErrors) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final errors = formErrorState.allErrors;

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.onErrorContainer,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Please fix the following errors:',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...errors.map((error) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      error,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

/// Dropdown field with validation
class ValidatedDropdownField<T> extends ConsumerWidget {
  final String fieldName;
  final String formId;
  final String? label;
  final String? hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;
  final bool enabled;
  final bool required;

  const ValidatedDropdownField({
    super.key,
    required this.fieldName,
    required this.formId,
    required this.items,
    this.label,
    this.hint,
    this.value,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.required = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formErrorState = ref.watch(formErrorProvider(formId));
    final formErrorNotifier = ref.read(formErrorProvider(formId).notifier);
    final fieldError = formErrorState.getFieldError(fieldName);
    final hasError = fieldError != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RichText(
              text: TextSpan(
                text: label!,
                style: Theme.of(context).textTheme.labelMedium,
                children: [
                  if (required)
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: enabled ? (newValue) {
            // Clear field error when user makes selection
            if (hasError) {
              formErrorNotifier.clearFieldError(fieldName);
            }
            
            // Run validation if provided
            if (validator != null) {
              final error = validator!(newValue);
              if (error != null) {
                formErrorNotifier.setFieldError(fieldName, error);
              }
            }
            
            onChanged?.call(newValue);
          } : null,
          decoration: InputDecoration(
            hintText: hint,
            errorText: hasError ? fieldError : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError 
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError 
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError 
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          ),
          validator: (value) {
            final error = validator?.call(value);
            if (error != null) {
              formErrorNotifier.setFieldError(fieldName, error);
            }
            return error;
          },
        ),
      ],
    );
  }
}

/// Checkbox field with validation
class ValidatedCheckboxField extends ConsumerWidget {
  final String fieldName;
  final String formId;
  final String label;
  final bool value;
  final void Function(bool?)? onChanged;
  final String? Function(bool?)? validator;
  final bool enabled;

  const ValidatedCheckboxField({
    super.key,
    required this.fieldName,
    required this.formId,
    required this.label,
    required this.value,
    this.onChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formErrorState = ref.watch(formErrorProvider(formId));
    final formErrorNotifier = ref.read(formErrorProvider(formId).notifier);
    final fieldError = formErrorState.getFieldError(fieldName);
    final hasError = fieldError != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: Text(label),
          value: value,
          onChanged: enabled ? (newValue) {
            // Clear field error when user makes selection
            if (hasError) {
              formErrorNotifier.clearFieldError(fieldName);
            }
            
            // Run validation if provided
            if (validator != null) {
              final error = validator!(newValue);
              if (error != null) {
                formErrorNotifier.setFieldError(fieldName, error);
              }
            }
            
            onChanged?.call(newValue);
          } : null,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: Text(
              fieldError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

/// Form submission button with loading state
class FormSubmitButton extends ConsumerWidget {
  final String formId;
  final VoidCallback? onPressed;
  final String text;
  final bool isLoading;
  final bool validateBeforeSubmit;

  const FormSubmitButton({
    super.key,
    required this.formId,
    required this.onPressed,
    required this.text,
    this.isLoading = false,
    this.validateBeforeSubmit = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formErrorState = ref.watch(formErrorProvider(formId));
    final hasErrors = validateBeforeSubmit && formErrorState.hasErrors;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (isLoading || hasErrors) ? null : onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: isLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('Processing...'),
                ],
              )
            : Text(text),
      ),
    );
  }
}

/// Helper class for common form validations
class FormValidators {
  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.isEmpty) return null;
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? minLength(String? value, int minLength, {String? fieldName}) {
    if (value == null || value.isEmpty) return null;
    
    if (value.length < minLength) {
      return '${fieldName ?? 'This field'} must be at least $minLength characters';
    }
    return null;
  }

  static String? maxLength(String? value, int maxLength, {String? fieldName}) {
    if (value == null || value.isEmpty) return null;
    
    if (value.length > maxLength) {
      return '${fieldName ?? 'This field'} must be no more than $maxLength characters';
    }
    return null;
  }

  static String? numeric(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) return null;
    
    if (double.tryParse(value) == null) {
      return '${fieldName ?? 'This field'} must be a valid number';
    }
    return null;
  }

  static String? positiveNumber(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) return null;
    
    final number = double.tryParse(value);
    if (number == null) {
      return '${fieldName ?? 'This field'} must be a valid number';
    }
    
    if (number <= 0) {
      return '${fieldName ?? 'This field'} must be greater than 0';
    }
    return null;
  }

  static String? Function(String?) combine(List<String? Function(String?)> validators) {
    return (String? value) {
      for (final validator in validators) {
        final error = validator(value);
        if (error != null) return error;
      }
      return null;
    };
  }
}