import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/Task.dart';
import '../models/User.dart';
import 'package:intl/intl.dart';

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({Key? key}) : super(key: key);

  @override
  _TaskFormScreenState createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _status = 'To do';
  int _priority = 1;
  DateTime? _dueDate;
  String? _category;
  String? _assignedTo;
  List<String> _attachments = [];
  bool _completed = false;
  Task? _existingTask;
  List<User> _users = [];
  late User _currentUser;
  String? _createdByName;
  bool _isLoadingCreator = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    final arguments = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    setState(() {
      _currentUser = arguments?['currentUser'] as User? ??
          User(
            id: '',
            username: 'Không xác định',
            password: '',
            email: '',
            createdAt: DateTime.now(),
            lastActive: DateTime.now(),
          );
      print('Current User in TaskFormScreen: $_currentUser');

      final task = arguments?['task'] as Task?;
      if (task != null) {
        _existingTask = task;
        _titleController.text = task.title;
        _descriptionController.text = task.description;
        _status = task.status;
        _priority = task.priority;
        _dueDate = task.dueDate;
        _category = task.category;
        _assignedTo = task.assignedTo;
        _attachments = task.attachments ?? [];
        _completed = task.completed;
        _loadCreatorName(task.createdBy);
      } else {
        _createdByName = _currentUser.fullname ?? _currentUser.username;
        _isLoadingCreator = false;
        // Nếu là tài khoản thường, tự động gán công việc cho chính họ
        if (!_currentUser.isAdmin) {
          _assignedTo = _currentUser.id;
        }
      }
    });
  }

  Future<void> _loadUsers() async {
    final dbHelper = DatabaseHelper.instance;
    try {
      final users = await dbHelper.getAllUsers();
      setState(() {
        _users = users;
      });
      print('Users loaded in TaskFormScreen: $_users');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải danh sách người dùng: $e')),
      );
    }
  }

  Future<void> _loadCreatorName(String createdBy) async {
    if (createdBy.isEmpty) {
      setState(() {
        _createdByName = 'Không xác định';
        _isLoadingCreator = false;
      });
      return;
    }

    final dbHelper = DatabaseHelper.instance;
    try {
      final users = await dbHelper.getAllUsers();
      final creator = users.firstWhere(
            (user) => user.id == createdBy || user.username == createdBy,
        orElse: () => User(
          id: '',
          username: 'Không xác định',
          password: '',
          email: '',
          createdAt: DateTime.now(),
          lastActive: DateTime.now(),
        ),
      );
      setState(() {
        _createdByName = creator.fullname ?? creator.username;
        _isLoadingCreator = false;
      });
    } catch (e) {
      setState(() {
        _createdByName = 'Không xác định';
        _isLoadingCreator = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải thông tin người tạo: $e')),
      );
    }
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_currentUser.id.isEmpty || _currentUser.id == 'currentUserId') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi: Không xác định được người dùng hiện tại')),
        );
        return;
      }

      if (_existingTask != null && _existingTask!.createdBy != _currentUser.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn không có quyền chỉnh sửa công việc này')),
        );
        return;
      }

      // Nếu là tài khoản thường, đảm bảo chỉ gán cho chính họ
      if (!_currentUser.isAdmin && _assignedTo != _currentUser.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn chỉ có thể gán công việc cho chính mình')),
        );
        return;
      }

      final dbHelper = DatabaseHelper.instance;
      final task = Task(
        id: _existingTask?.id ?? const Uuid().v4(),
        title: _titleController.text,
        description: _descriptionController.text,
        status: _status,
        priority: _priority,
        dueDate: _dueDate,
        createdAt: _existingTask?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        assignedTo: _assignedTo,
        createdBy: _existingTask?.createdBy ?? _currentUser.id,
        category: _category,
        attachments: _attachments.isEmpty ? null : _attachments,
        completed: _completed,
      );

      print('Task to update: $task');

      try {
        if (_existingTask == null) {
          await dbHelper.createTask(task);
        } else {
          await dbHelper.updateTask(task);
        }
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
        print('Error updating task: $e');
      }
    }
  }

  Future<void> _deleteTask() async {
    if (_existingTask != null) {
      if (_existingTask!.createdBy != _currentUser.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn không có quyền xóa công việc này')),
        );
        return;
      }

      final dbHelper = DatabaseHelper.instance;
      try {
        await dbHelper.deleteTask(_existingTask!.id);
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Chưa Đặt';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_existingTask == null ? 'Thêm Công Việc' : 'Chỉnh Sửa Công Việc'),
        actions: [
          if (_existingTask != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteTask,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
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
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'Tiêu Đề',
                            prefixIcon: Icon(Icons.title, color: Colors.blueAccent),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng nhập tiêu đề';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'Mô Tả',
                            prefixIcon: Icon(Icons.description, color: Colors.blueAccent),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng nhập mô tả';
                            }
                            return null;
                          },
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
                        DropdownButtonFormField<String>(
                          value: _status,
                          decoration: InputDecoration(
                            labelText: 'Trạng Thái',
                            prefixIcon: Icon(Icons.info, color: Colors.blueAccent),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: [
                            DropdownMenuItem(value: 'To do', child: Text('Chưa Làm')),
                            DropdownMenuItem(value: 'In progress', child: Text('Đang Làm')),
                            DropdownMenuItem(value: 'Done', child: Text('Hoàn Thành')),
                            DropdownMenuItem(value: 'Cancelled', child: Text('Hủy Bỏ')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _status = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: _priority,
                          decoration: InputDecoration(
                            labelText: 'Độ Ưu Tiên',
                            prefixIcon: Icon(Icons.priority_high, color: Colors.blueAccent),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: [
                            DropdownMenuItem(value: 1, child: Text('Thấp')),
                            DropdownMenuItem(value: 2, child: Text('Trung Bình')),
                            DropdownMenuItem(value: 3, child: Text('Cao')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _priority = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: Icon(Icons.calendar_today, color: Colors.blueAccent),
                          title: Text(
                            'Hạn Chót: ${_dueDate != null ? _formatDate(_dueDate!) : 'Chưa Đặt'}',
                          ),
                          trailing: Icon(Icons.arrow_drop_down),
                          onTap: _selectDueDate,
                        ),
                        const Divider(),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Danh Mục',
                            prefixIcon: Icon(Icons.category, color: Colors.blueAccent),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (value) {
                            _category = value.isEmpty ? null : value;
                          },
                          controller: TextEditingController(text: _category),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _assignedTo,
                          decoration: InputDecoration(
                            labelText: 'Giao Cho',
                            prefixIcon: Icon(Icons.person, color: Colors.blueAccent),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: (_currentUser.isAdmin
                              ? _users
                              : _users.where((user) => user.id == _currentUser.id))
                              .map((user) => DropdownMenuItem(
                            value: user.id,
                            child: Text(user.fullname ?? user.username),
                          ))
                              .toList()
                            ..insert(
                              0,
                              DropdownMenuItem(
                                value: null,
                                child: Text('Không Giao'),
                              ),
                            ),
                          onChanged: _currentUser.isAdmin
                              ? (value) {
                            setState(() {
                              _assignedTo = value;
                            });
                          }
                              : null, // Vô hiệu hóa nếu không phải Admin
                        ),
                        const Divider(),
                        ListTile(
                          leading: Icon(Icons.person_add, color: Colors.blueAccent),
                          title: Text('Người Tạo'),
                          subtitle: _isLoadingCreator
                              ? Text('Đang tải...')
                              : Text(_createdByName ?? 'Không xác định'),
                        ),
                        const Divider(),
                        CheckboxListTile(
                          title: Text('Đã Hoàn Thành'),
                          value: _completed,
                          onChanged: (value) {
                            setState(() {
                              _completed = value!;
                            });
                          },
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _submit,
                    icon: Icon(Icons.save),
                    label: Text(_existingTask == null ? 'Thêm' : 'Cập Nhật'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
      ),
    );
  }
}