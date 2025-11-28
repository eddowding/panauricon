import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/recording.dart';
import '../../services/recording_manager.dart';
import '../widgets/transcript_dialog.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recording Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime.now();
                _selectedDate = DateTime.now();
              });
            },
            tooltip: 'Go to today',
          ),
        ],
      ),
      body: Consumer<RecordingManager>(
        builder: (context, manager, child) {
          final recordings = manager.recordings;
          return Column(
            children: [
              _buildMonthSelector(),
              const Divider(),
              _buildCalendar(recordings),
              const Divider(),
              Expanded(
                child: _buildRecordingsList(recordings),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month - 1,
                );
              });
            },
          ),
          Text(
            DateFormat('MMMM yyyy').format(_selectedMonth),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month + 1,
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(List<Recording> recordings) {
    final daysInMonth = DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final firstWeekday = firstDayOfMonth.weekday % 7; // Convert to 0-6 (Sun-Sat)

    // Group recordings by date
    final recordingsByDate = <DateTime, List<Recording>>{};
    for (final recording in recordings) {
      final date = DateTime(
        recording.createdAt.year,
        recording.createdAt.month,
        recording.createdAt.day,
      );
      recordingsByDate.putIfAbsent(date, () => []).add(recording);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          // Weekday headers
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: firstWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < firstWeekday) {
                return const SizedBox();
              }

              final day = index - firstWeekday + 1;
              final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
              final hasRecordings = recordingsByDate.containsKey(date);
              final isSelected = _selectedDate != null &&
                  _selectedDate!.year == date.year &&
                  _selectedDate!.month == date.month &&
                  _selectedDate!.day == date.day;
              final isToday = DateTime.now().year == date.year &&
                  DateTime.now().month == date.month &&
                  DateTime.now().day == date.day;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedDate = date;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : isToday
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                    borderRadius: BorderRadius.circular(8),
                    border: hasRecordings
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          )
                        : null,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : isToday
                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                    : null,
                            fontWeight: hasRecordings ? FontWeight.bold : null,
                          ),
                        ),
                        if (hasRecordings)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingsList(List<Recording> recordings) {
    if (_selectedDate == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Select a date to view recordings',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Filter recordings for selected date
    final selectedRecordings = recordings.where((r) {
      return r.createdAt.year == _selectedDate!.year &&
          r.createdAt.month == _selectedDate!.month &&
          r.createdAt.day == _selectedDate!.day;
    }).toList();

    if (selectedRecordings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mic_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No recordings on ${DateFormat('MMM d, yyyy').format(_selectedDate!)}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate!)} (${selectedRecordings.length} recording${selectedRecordings.length != 1 ? 's' : ''})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: selectedRecordings.length,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemBuilder: (context, index) {
              final recording = selectedRecordings[index];
              return _buildRecordingCard(recording);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingCard(Recording recording) {
    final hasTranscript = recording.transcriptText != null;
    final timeStr = DateFormat('HH:mm').format(recording.createdAt);
    final durationStr = _formatDuration(recording.durationSeconds);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(_getStatusIcon(recording.status)),
        ),
        title: Text(
          '$timeStr - $durationStr',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (hasTranscript)
              Text(
                recording.transcriptText!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            else
              Text(
                _getStatusText(recording.status),
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: _getStatusColor(recording.status),
                ),
              ),
          ],
        ),
        isThreeLine: hasTranscript,
        trailing: hasTranscript ? const Icon(Icons.chevron_right) : null,
        onTap: hasTranscript
            ? () => _showTranscript(recording)
            : null,
      ),
    );
  }

  Future<void> _showTranscript(Recording recording) async {
    if (recording.transcriptText == null) return;

    await showDialog(
      context: context,
      builder: (context) => TranscriptDialog(
        recording: recording,
      ),
    );
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  IconData _getStatusIcon(RecordingStatus status) {
    switch (status) {
      case RecordingStatus.recording:
        return Icons.mic;
      case RecordingStatus.pending:
        return Icons.schedule;
      case RecordingStatus.uploading:
        return Icons.cloud_upload;
      case RecordingStatus.uploaded:
      case RecordingStatus.transcribing:
        return Icons.hourglass_empty;
      case RecordingStatus.transcribed:
        return Icons.check_circle;
      case RecordingStatus.failed:
        return Icons.error;
    }
  }

  String _getStatusText(RecordingStatus status) {
    switch (status) {
      case RecordingStatus.recording:
        return 'Recording...';
      case RecordingStatus.pending:
        return 'Pending upload';
      case RecordingStatus.uploading:
        return 'Uploading...';
      case RecordingStatus.uploaded:
        return 'Uploaded';
      case RecordingStatus.transcribing:
        return 'Transcribing...';
      case RecordingStatus.transcribed:
        return 'Transcribed';
      case RecordingStatus.failed:
        return 'Failed';
    }
  }

  Color _getStatusColor(RecordingStatus status) {
    switch (status) {
      case RecordingStatus.recording:
        return Colors.red;
      case RecordingStatus.pending:
        return Colors.orange;
      case RecordingStatus.uploading:
        return Colors.blue;
      case RecordingStatus.uploaded:
      case RecordingStatus.transcribing:
        return Colors.orange;
      case RecordingStatus.transcribed:
        return Colors.green;
      case RecordingStatus.failed:
        return Colors.red;
    }
  }
}
