import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/recording_manager.dart';
import '../widgets/search_transcript_dialog.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<ApiRecording> _searchResults = [];
  bool _isSearching = false;
  String? _errorMessage;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    if (_searchController.text.trim().isEmpty && _fromDate == null && _toDate == null) {
      setState(() {
        _errorMessage = 'Please enter a search query or select a date range';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final apiService = context.read<ApiService>();
      final results = await apiService.searchRecordings(
        query: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        from: _fromDate,
        to: _toDate,
        limit: 50,
      );

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Search failed: $e';
        _isSearching = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
  }

  Future<void> _showTranscript(ApiRecording recording) async {
    if (recording.transcriptText == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transcript available')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => SearchTranscriptDialog(
        recording: recording,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Recordings'),
      ),
      body: Column(
        children: [
          // Search input section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search text field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search transcripts',
                    hintText: 'Enter keywords...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _performSearch(),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),

                // Date range filter
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectDateRange,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          _fromDate != null && _toDate != null
                              ? '${_formatDate(_fromDate!)} - ${_formatDate(_toDate!)}'
                              : 'Date range',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    if (_fromDate != null || _toDate != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearDateRange,
                        tooltip: 'Clear date range',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Search button
                ElevatedButton.icon(
                  onPressed: _isSearching ? null : _performSearch,
                  icon: _isSearching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_isSearching ? 'Searching...' : 'Search'),
                ),

                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),

          const Divider(),

          // Results section
          Expanded(
            child: _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty && _searchController.text.isEmpty && _fromDate == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Search your recordings',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Enter keywords or select a date range to find specific recordings',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final recording = _searchResults[index];
        return _buildResultCard(recording);
      },
    );
  }

  Widget _buildResultCard(ApiRecording recording) {
    final hasTranscript = recording.transcriptText != null;
    final excerpt = hasTranscript
        ? _getExcerpt(recording.transcriptText!, _searchController.text)
        : 'No transcript available';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(_getStatusIcon(recording.status)),
        ),
        title: Text(
          _formatDateTime(recording.createdAt),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              excerpt,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _getStatusText(recording.status),
              style: TextStyle(
                fontSize: 12,
                color: _getStatusColor(recording.status),
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: hasTranscript
            ? const Icon(Icons.chevron_right)
            : null,
        onTap: hasTranscript ? () => _showTranscript(recording) : null,
      ),
    );
  }

  String _getExcerpt(String text, String query) {
    if (query.isEmpty) {
      return text.length > 150 ? '${text.substring(0, 150)}...' : text;
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index == -1) {
      return text.length > 150 ? '${text.substring(0, 150)}...' : text;
    }

    final start = (index - 50).clamp(0, text.length);
    final end = (index + query.length + 100).clamp(0, text.length);
    final excerpt = text.substring(start, end);

    return '${start > 0 ? '...' : ''}$excerpt${end < text.length ? '...' : ''}';
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'transcribed':
        return Icons.check_circle;
      case 'transcribing':
        return Icons.hourglass_empty;
      case 'failed':
        return Icons.error;
      default:
        return Icons.upload;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'transcribed':
        return 'Transcribed';
      case 'transcribing':
        return 'Transcribing...';
      case 'failed':
        return 'Failed';
      default:
        return 'Uploaded';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'transcribed':
        return Colors.green;
      case 'transcribing':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
