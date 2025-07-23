import 'package:flutter/material.dart';
import '../../services/storage/database_initialization_service.dart';
import '../../services/cache/database_helper.dart';

class DatabaseHealthWidget extends StatefulWidget {
  const DatabaseHealthWidget({super.key});

  @override
  State<DatabaseHealthWidget> createState() => _DatabaseHealthWidgetState();
}

class _DatabaseHealthWidgetState extends State<DatabaseHealthWidget> {
  Map<String, dynamic>? _dbInfo;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDatabaseInfo();
  }

  Future<void> _loadDatabaseInfo() async {
    setState(() => _isLoading = true);
    
    try {
      final info = await DatabaseInitializationService.getDatabaseInfo();
      setState(() => _dbInfo = info);
    } catch (e) {
      setState(() => _dbInfo = {'error': e.toString()});
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetDatabase() async {
    setState(() => _isLoading = true);
    
    try {
      final success = await DatabaseInitializationService.forceReset();
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database reset successfully')),
        );
        await _loadDatabaseInfo();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database reset failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Database Health',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _isLoading ? null : _loadDatabaseInfo,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: _isLoading ? null : _showResetDialog,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_dbInfo != null)
              _buildDatabaseInfo()
            else
              const Text('No database information available'),
          ],
        ),
      ),
    );
  }

  Widget _buildDatabaseInfo() {
    final info = _dbInfo!;
    
    if (info.containsKey('error')) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Database Error', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(info['error'].toString()),
          ],
        ),
      );
    }

    final isInitialized = info['initialized'] ?? false;
    final stats = info['stats'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isInitialized ? Colors.green.shade50 : Colors.orange.shade50,
            border: Border.all(
              color: isInitialized ? Colors.green.shade200 : Colors.orange.shade200,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isInitialized ? Icons.check_circle : Icons.warning,
                color: isInitialized ? Colors.green : Colors.orange,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                isInitialized ? 'Initialized' : 'Not Initialized',
                style: TextStyle(
                  color: isInitialized ? Colors.green.shade700 : Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        if (stats != null) ...[
          const SizedBox(height: 16),
          const Text('Database Statistics:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          
          // Journal mode
          _buildStatRow('Journal Mode', stats['journalMode']?.toString() ?? 'Unknown'),
          
          // Database size
          _buildStatRow(
            'Database Size',
            ((stats['databaseSizeBytes'] as int? ?? 0) / 1024).toStringAsFixed(1) + ' KB',
          ),
          
          // Table counts
          if (stats['tableCounts'] != null) ...[
            const SizedBox(height: 8),
            const Text('Table Counts:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            ...((stats['tableCounts'] as Map<String, dynamic>).entries.map(
              (entry) => _buildStatRow(entry.key, entry.value.toString()),
            )),
          ],
        ],
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Database'),
        content: const Text(
          'This will delete all cached data and reset the database. '
          'Your data on the server will not be affected. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetDatabase();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}