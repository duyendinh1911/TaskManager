import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/Task.dart';
import '../models/User.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({Key? key}) : super(key: key);

  @override
  _TaskDetailScreenState createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  String? _createdByName;
  String? _assignedToName;
  bool _isLoadingCreator = true;
  late User _currentUser;
  Task? _task;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  Future<void> _loadUserData() async {
    try {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
      if (args == null || !args.containsKey('task')) {
        setState(() {
          _createdByName = 'Không xác định';
          _assignedToName = 'Chưa Được Giao';
          _isLoadingCreator = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy thông tin công việc')),
        );
        return;
      }

      _task = args['task'] as Task;
      _currentUser = args['currentUser'] as User? ??
          User(
            id: '',
            username: 'Không xác định',
            password: '',
            email: '',
            createdAt: DateTime.now(),
            lastActive: DateTime.now(),
          );

      print('Task: $_task');
      print('Current User: $_currentUser');

      final dbHelper = DatabaseHelper.instance;
      final users = await dbHelper.getAllUsers();
      print('Users from DB: $users');

      final creator = users.firstWhere(
            (user) => user.id == _task!.createdBy || user.username == _task!.createdBy,
        orElse: () => User(
          id: '',
          username: 'Không xác định',
          password: '',
          email: '',
          createdAt: DateTime.now(),
          lastActive: DateTime.now(),
        ),
      );

      String? assignedToName;
      if (_task!.assignedTo != null && _task!.assignedTo!.isNotEmpty) {
        final assignee = users.firstWhere(
              (user) => user.id == _task!.assignedTo,
          orElse: () => User(
            id: '',
            username: 'Không xác định',
            password: '',
            email: '',
            createdAt: DateTime.now(),
            lastActive: DateTime.now(),
          ),
        );
        assignedToName = assignee.fullname ?? assignee.username;
      } else {
        assignedToName = 'Chưa Được Giao';
      }

      setState(() {
        _createdByName = creator.fullname ?? creator.username;
        _assignedToName = assignedToName;
        _isLoadingCreator = false;
      });
      print('Creator Name: $_createdByName');
      print('Assigned To Name: $_assignedToName');
    } catch (e) {
      setState(() {
        _createdByName = 'Không xác định';
        _assignedToName = 'Chưa Được Giao';
        _isLoadingCreator = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải thông tin người dùng: $e')),
      );
      print('Error loading user data: $e');
    }
  }

  Map<String, dynamic> _hienThiTrangThai(String status) {
    switch (status) {
      case 'To do':
        return {'text': 'Chưa Làm', 'color': Colors.red};
      case 'In progress':
        return {'text': 'Đang Làm', 'color': Colors.orange};
      case 'Done':
        return {'text': 'Hoàn Thành', 'color': Colors.green};
      case 'Cancelled':
        return {'text': 'Hủy Bỏ', 'color': Colors.grey};
      default:
        return {'text': status, 'color': Colors.black};
    }
  }

  Map<String, dynamic> _hienThiDoUuTien(int priority) {
    switch (priority) {
      case 1:
        return {'text': 'Thấp', 'color': Colors.blue};
      case 2:
        return {'text': 'Trung Bình', 'color': Colors.orange};
      case 3:
        return {'text': 'Cao', 'color': Colors.red};
      default:
        return {'text': 'Không xác định', 'color': Colors.black};
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Chưa Đặt';
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  Future<void> _toggleComplete(Task task) async {
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.updateTask(
      task.copyWith(
        completed: !task.completed,
        status: !task.completed ? 'Done' : task.status,
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_task == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chi Tiết Công Việc'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final task = _task!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi Tiết Công Việc'),
        actions: [
          if (_currentUser.id == task.createdBy) // Chỉ hiển thị nút chỉnh sửa nếu người dùng là người tạo
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/task_form',
                  arguments: {'task': task, 'currentUser': _currentUser},
                );
                if (result == true) {
                  Navigator.pop(context, true);
                }
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            task.completed ? Icons.check_circle : Icons.circle_outlined,
                            color: task.completed ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            task.completed ? 'Đã Hoàn Thành' : 'Chưa Hoàn Thành',
                            style: TextStyle(
                              color: task.completed ? Colors.green : Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.description, color: Colors.blueAccent),
                        title: const Text('Mô Tả'),
                        subtitle: Text(task.description),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.info, color: Colors.blueAccent),
                        title: const Text('Trạng Thái'),
                        subtitle: Text(
                          _hienThiTrangThai(task.status)['text'],
                          style: TextStyle(
                            color: _hienThiTrangThai(task.status)['color'],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.priority_high, color: Colors.blueAccent),
                        title: const Text('Độ Ưu Tiên'),
                        subtitle: Text(
                          _hienThiDoUuTien(task.priority)['text'],
                          style: TextStyle(
                            color: _hienThiDoUuTien(task.priority)['color'],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                        title: const Text('Hạn Chót'),
                        subtitle: Text(_formatDate(task.dueDate)),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.event, color: Colors.blueAccent),
                        title: const Text('Ngày Tạo'),
                        subtitle: Text(_formatDate(task.createdAt)),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.update, color: Colors.blueAccent),
                        title: const Text('Ngày Cập Nhật'),
                        subtitle: Text(_formatDate(task.updatedAt)),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.person, color: Colors.blueAccent),
                        title: const Text('Giao Cho'),
                        subtitle: Text(_assignedToName ?? 'Đang tải...'),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.person_add, color: Colors.blueAccent),
                        title: const Text('Người Tạo'),
                        subtitle: _isLoadingCreator
                            ? const Text('Đang tải...')
                            : Text(_createdByName ?? 'Không xác định'),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.category, color: Colors.blueAccent),
                        title: const Text('Danh Mục'),
                        subtitle: Text(task.category ?? 'Không Có'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (task.attachments != null && task.attachments!.isNotEmpty) ...[
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tệp Đính Kèm:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...task.attachments!.map((attachment) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: InkWell(
                            onTap: () {
                              // Thêm logic mở tệp đính kèm nếu cần
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.attachment, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    attachment,
                                    style: const TextStyle(color: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () => _toggleComplete(task),
                  icon: Icon(task.completed ? Icons.undo : Icons.check),
                  label: Text(task.completed ? 'Hủy Hoàn Thành' : 'Đánh Dấu Hoàn Thành'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: task.completed ? Colors.orange : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}