import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Icon sizes
enum UIIconSize {
  xs,
  sm,
  md,
  lg,
  xl,
}

/// A reusable icon component with consistent sizing and styling
class UIIcon extends StatelessWidget {
  final IconData icon;
  final UIIconSize size;
  final Color? color;
  final String? semanticLabel;

  const UIIcon({
    super.key,
    required this.icon,
    this.size = UIIconSize.md,
    this.color,
    this.semanticLabel,
  });

  const UIIcon.xs({
    super.key,
    required this.icon,
    this.color,
    this.semanticLabel,
  }) : size = UIIconSize.xs;

  const UIIcon.sm({
    super.key,
    required this.icon,
    this.color,
    this.semanticLabel,
  }) : size = UIIconSize.sm;

  const UIIcon.md({
    super.key,
    required this.icon,
    this.color,
    this.semanticLabel,
  }) : size = UIIconSize.md;

  const UIIcon.lg({
    super.key,
    required this.icon,
    this.color,
    this.semanticLabel,
  }) : size = UIIconSize.lg;

  const UIIcon.xl({
    super.key,
    required this.icon,
    this.color,
    this.semanticLabel,
  }) : size = UIIconSize.xl;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: _getIconSize(),
      color: color ?? AppTheme.getColor(context, 'foreground'),
      semanticLabel: semanticLabel,
    );
  }

  double _getIconSize() {
    switch (size) {
      case UIIconSize.xs:
        return 12;
      case UIIconSize.sm:
        return 16;
      case UIIconSize.md:
        return 20;
      case UIIconSize.lg:
        return 24;
      case UIIconSize.xl:
        return 32;
    }
  }
}

/// Common app icons with consistent styling
class AppIcons {
  // Navigation icons
  static const IconData chat = Icons.chat_bubble_outline;
  static const IconData tasks = Icons.check_circle_outline;
  static const IconData expenses = Icons.receipt_long_outlined;
  static const IconData reminders = Icons.notifications_outlined;
  static const IconData settings = Icons.settings_outlined;
  
  // Action icons
  static const IconData add = Icons.add;
  static const IconData edit = Icons.edit_outlined;
  static const IconData delete = Icons.delete_outline;
  static const IconData save = Icons.save_outlined;
  static const IconData cancel = Icons.close;
  static const IconData search = Icons.search;
  static const IconData filter = Icons.filter_list_outlined;
  static const IconData sort = Icons.sort;
  
  // Status icons
  static const IconData completed = Icons.check_circle;
  static const IconData pending = Icons.schedule;
  static const IconData overdue = Icons.warning_outlined;
  static const IconData priority = Icons.flag_outlined;
  
  // UI icons
  static const IconData back = Icons.arrow_back;
  static const IconData forward = Icons.arrow_forward;
  static const IconData up = Icons.keyboard_arrow_up;
  static const IconData down = Icons.keyboard_arrow_down;
  static const IconData left = Icons.keyboard_arrow_left;
  static const IconData right = Icons.keyboard_arrow_right;
  static const IconData menu = Icons.menu;
  static const IconData more = Icons.more_vert;
  
  // Content icons
  static const IconData calendar = Icons.calendar_today_outlined;
  static const IconData time = Icons.access_time_outlined;
  static const IconData location = Icons.location_on_outlined;
  static const IconData attachment = Icons.attach_file_outlined;
  static const IconData image = Icons.image_outlined;
  static const IconData link = Icons.link_outlined;
  
  // Communication icons
  static const IconData send = Icons.send_outlined;
  static const IconData reply = Icons.reply_outlined;
  static const IconData share = Icons.share_outlined;
  static const IconData copy = Icons.copy_outlined;
  
  // System icons
  static const IconData refresh = Icons.refresh;
  static const IconData sync = Icons.sync;
  static const IconData offline = Icons.cloud_off_outlined;
  static const IconData online = Icons.cloud_done_outlined;
  static const IconData loading = Icons.hourglass_empty;
  static const IconData error = Icons.error_outline;
  static const IconData success = Icons.check_circle_outline;
  static const IconData warning = Icons.warning_outlined;
  static const IconData info = Icons.info_outline;
  
  // User icons
  static const IconData user = Icons.person_outline;
  static const IconData logout = Icons.logout;
  static const IconData login = Icons.login;
  
  // Theme icons
  static const IconData lightMode = Icons.light_mode_outlined;
  static const IconData darkMode = Icons.dark_mode_outlined;
  static const IconData autoMode = Icons.brightness_auto_outlined;
}

/// Icon button component with consistent styling
class UIIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final UIIconSize size;
  final Color? color;
  final Color? backgroundColor;
  final String? tooltip;
  final bool isSelected;

  const UIIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = UIIconSize.md,
    this.color,
    this.backgroundColor,
    this.tooltip,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isSelected 
      ? AppTheme.getColor(context, 'primary')
      : (color ?? AppTheme.getColor(context, 'foreground'));
    
    final bgColor = backgroundColor ?? 
      (isSelected ? AppTheme.getColor(context, 'accent') : Colors.transparent);

    Widget button = IconButton(
      onPressed: onPressed,
      icon: UIIcon(
        icon: icon,
        size: size,
        color: iconColor,
      ),
      style: IconButton.styleFrom(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.getBorderRadius('md'),
        ),
        padding: EdgeInsets.all(AppTheme.spacing2),
      ),
      tooltip: tooltip,
    );

    return button;
  }
}