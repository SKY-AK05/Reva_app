import 'package:flutter/material.dart';

class AuthLoadingScreen extends StatelessWidget {
  final String message;
  
  const AuthLoadingScreen({
    super.key,
    this.message = 'Loading...',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Icon(
              Icons.psychology_outlined,
              size: 80,
              color: theme.primaryColor,
            ),
            
            const SizedBox(height: 32),
            
            // Loading Indicator
            const CircularProgressIndicator(),
            
            const SizedBox(height: 24),
            
            // Loading Message
            Text(
              message,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Please wait...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}