import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/Task.dart';

class TaskItem extends StatefulWidget {
  final Task task;
  final VoidCallback onTap;
  final Function(bool) onComplete;
  final VoidCallback onDelete;
  final bool isDarkTheme;

  const TaskItem({
    Key? key,
    required this.task,
    required this.onTap,
    required this.onComplete,
    required this.onDelete,
    required this.isDarkTheme,
  }) : super(key: key);

  @override
  _TaskItemState createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem> {
  bool _showSparkle = false;

  void _triggerSparkle() {
    setState(() {
      _showSparkle = true;
    });
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showSparkle = false;
        });
      }
    });
  }

  // Hàm kiểm tra xem công việc có sắp hết hạn không (trong 24 giờ và chưa hoàn thành)
  bool _isDueSoon() {
    if (widget.task.dueDate == null || widget.task.completed) return false;
    final now = DateTime.now();
    final dueDate = widget.task.dueDate!;
    return dueDate.isBefore(now.add(Duration(hours: 24))) && dueDate.isAfter(now);
  }

  // Định dạng ngày hết hạn
  String _formatDueDate() {
    if (widget.task.dueDate == null) return '';
    return DateFormat('dd/MM HH:mm').format(widget.task.dueDate!);
  }

  @override
  Widget build(BuildContext context) {
    final isDueSoon = _isDueSoon();

    return Stack(
      children: [
        // Task Card
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.symmetric(vertical: 8),
          color: widget.isDarkTheme ? Colors.grey[800] : Colors.white,
          child: InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hiển thị đồng hồ và ngày hết hạn nếu sắp đến hạn
                  if (isDueSoon) ...[
                    Column(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        SizedBox(height: 4),
                        Text(
                          _formatDueDate(),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 8),
                  ],
                  Checkbox(
                    value: widget.task.completed,
                    onChanged: _showSparkle
                        ? null // Disable during sparkle animation
                        : (value) {
                      if (value == true) {
                        _triggerSparkle();
                      }
                      widget.onComplete(value!);
                    },
                    activeColor: Colors.green,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task.title,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: widget.isDarkTheme ? Colors.white : Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.task.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: widget.isDarkTheme ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: widget.onDelete,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Sparkle Effect
        if (_showSparkle)
          Positioned.fill(
            child: FadeIn(
              duration: Duration(milliseconds: 300),
              child: Center(
                child: SpinKitFadingCircle(
                  color: Colors.yellow.shade200,
                  size: 80.0,
                  duration: Duration(milliseconds: 600),
                ),
              ),
            ),
          ),
      ],
    );
  }
}