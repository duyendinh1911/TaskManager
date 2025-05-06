import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:ui';
import '../database/database_helper.dart';
import '../models/Task.dart';
import '../models/User.dart';
import '../widgets/task_item.dart';
import 'package:wave/config.dart';
import 'package:wave/wave.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({Key? key}) : super(key: key);

  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  List<Task> _tasks = [];
  String? _selectedStatus;
  String? _selectedCategory;
  bool _showDueTasksOnly = false;
  late User _currentUser;
  User? _originalAdminUser; // Store original admin user
  bool _loggedInAsAdmin = false; // Track admin status at login
  bool _isDarkTheme = true;
  double _completedPercentage = 0.0;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _searchController.addListener(_onSearchChanged);
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = ModalRoute.of(context)!.settings.arguments as User?;
    if (user != null) {
      _currentUser = user;
      _loggedInAsAdmin = user.isAdmin;
      if (_loggedInAsAdmin) {
        _originalAdminUser = user; // Store original admin user
      }
    } else {
      _currentUser = User(
        id: '',
        username: 'Khách',
        password: '',
        email: '',
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
      );
      _loggedInAsAdmin = false;
    }
  }

  Future<void> _loadTasks({bool ignoreFilters = false}) async {
    final dbHelper = DatabaseHelper.instance;
    final tasks = await dbHelper.searchTasks(
      query: _searchController.text,
      status: ignoreFilters ? null : _selectedStatus,
      category: ignoreFilters ? null : _selectedCategory,
      userId: _currentUser.id,
      isAdmin: _currentUser.isAdmin,
    );
    setState(() {
      if (_showDueTasksOnly && !ignoreFilters) {
        _tasks = tasks.where((task) {
          if (task.dueDate == null) return false;
          final now = DateTime.now();
          final dueDate = task.dueDate!;
          return dueDate.isBefore(now.add(Duration(days: 1))) && !task.completed;
        }).toList();
      } else {
        _tasks = tasks;
      }
      _completedPercentage = tasks.isNotEmpty
          ? tasks.where((task) => task.completed).length / tasks.length
          : 0.0;
    });
  }

  void _onSearchChanged() {
    _loadTasks();
  }

  Future<void> _logout() async {
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.updateUser(
      _currentUser.copyWith(lastActive: DateTime.now()),
    );
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
          (Route<dynamic> route) => false,
    );
  }

  Future<void> _toggleAdminStatus() async {
    if (!_loggedInAsAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chỉ tài khoản Admin mới có thể chuyển đổi vai trò',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final dbHelper = DatabaseHelper.instance;
    try {
      if (_currentUser.isAdmin) {
        final nonAdminUsers = await dbHelper.getNonAdminUsers();
        if (nonAdminUsers.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Không có tài khoản người dùng để chuyển đổi',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }

        User? selectedUser = await showDialog<User>(
          context: context,
          builder: (context) => _buildUserSelectionDialog(nonAdminUsers),
        );

        if (selectedUser != null) {
          await dbHelper.toggleAdminStatus(_originalAdminUser!.id, false);
          setState(() {
            _currentUser = selectedUser.copyWith(isAdmin: false);
          });
          await _loadTasks(ignoreFilters: true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã chuyển sang tài khoản Người dùng: ${selectedUser.username}',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              backgroundColor: Colors.greenAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        await dbHelper.toggleAdminStatus(_originalAdminUser!.id, true);
        setState(() {
          _currentUser = _originalAdminUser!.copyWith(isAdmin: true);
        });
        await _loadTasks(ignoreFilters: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã chuyển sang tài khoản Admin',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.greenAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi chuyển đổi vai trò: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildUserSelectionDialog(List<User> users) {
    User? selectedUser;
    return AlertDialog(
      backgroundColor: _isDarkTheme ? Color(0xFF121212) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.all(20),
      title: Text(
        'Chọn Tài Khoản Người Dùng',
        style: GoogleFonts.poppins(
          color: _isDarkTheme ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          if (users.isEmpty) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Không có tài khoản người dùng',
                style: GoogleFonts.poppins(
                  color: _isDarkTheme ? Colors.white70 : Colors.black54,
                  fontSize: 16,
                ),
              ),
            );
          }
          return SizedBox(
            width: double.maxFinite,
            height: 200,
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return RadioListTile<User>(
                  title: Text(
                    user.fullname ?? user.username,
                    style: GoogleFonts.poppins(
                      color: _isDarkTheme ? Colors.white : Colors.black87,
                    ),
                  ),
                  value: user,
                  groupValue: selectedUser,
                  activeColor: Colors.cyanAccent,
                  onChanged: (User? value) {
                    setDialogState(() {
                      selectedUser = value;
                    });
                  },
                );
              },
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Hủy',
            style: GoogleFonts.poppins(
              color: Colors.cyanAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            if (selectedUser != null) {
              Navigator.pop(context, selectedUser);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Vui lòng chọn một tài khoản người dùng',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
          child: Text(
            'Xác Nhận',
            style: GoogleFonts.poppins(
              color: Colors.cyanAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _toggleTheme() {
    setState(() {
      _isDarkTheme = !_isDarkTheme;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  String _hienThiTrangThai(String status) {
    switch (status) {
      case 'To do':
        return 'Chưa Làm';
      case 'In progress':
        return 'Đang Làm';
      case 'Done':
        return 'Hoàn Thành';
      case 'Cancelled':
        return 'Hủy Bỏ';
      default:
        return status;
    }
  }

  // New method to show delete confirmation dialog
  Future<bool> _showDeleteConfirmationDialog(Task task) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkTheme ? Color(0xFF121212) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.all(20),
        title: Text(
          'Xác nhận xóa công việc',
          style: GoogleFonts.poppins(
            color: _isDarkTheme ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Text(
          'Bạn có chắc muốn xóa công việc "${task.title}"?',
          style: GoogleFonts.poppins(
            color: _isDarkTheme ? Colors.white70 : Colors.black54,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Hủy',
              style: GoogleFonts.poppins(
                color: Colors.cyanAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Xóa',
              style: GoogleFonts.poppins(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final backgroundGradient = _isDarkTheme
        ? LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1A237E), Color(0xFF880E4F)],
    )
        : LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFB3E5FC), Color(0xFFFCE4EC)],
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadTasks,
            color: Colors.cyanAccent,
            backgroundColor: Colors.black87,
            child: Column(
              children: [
                // Enhanced Header with Wave Effect
                BounceInDown(
                  duration: Duration(milliseconds: 800),
                  child: Stack(
                    children: [
                      // Wave Background
                      Container(
                        height: 260, // Increased height to accommodate greeting and wrapped icons
                        child: WaveWidget(
                          config: CustomConfig(
                            gradients: [
                              [Colors.cyanAccent, Colors.blueAccent],
                              [Colors.purpleAccent, Colors.pinkAccent],
                            ],
                            durations: [35000, 19440],
                            heightPercentages: [0.20, 0.23],
                            gradientBegin: Alignment.topLeft,
                            gradientEnd: Alignment.bottomRight,
                          ),
                          waveAmplitude: 10,
                          size: Size(double.infinity, double.infinity),
                        ),
                      ),
                      // Header Content with Greeting and Features
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        decoration: BoxDecoration(
                          color: _isDarkTheme
                              ? Colors.black.withOpacity(0.6)
                              : Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Greeting Text
                            Row(
                              children: [
                                // Animated Progress Circle
                                Container(
                                  width: 50,
                                  height: 50,
                                  margin: EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [Colors.greenAccent, Colors.cyan],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.greenAccent.withOpacity(0.5),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        value: _completedPercentage,
                                        backgroundColor: Colors.white.withOpacity(0.3),
                                        color: Colors.white,
                                        strokeWidth: 6,
                                      ),
                                      Text(
                                        '${(_completedPercentage * 100).toInt()}%',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Xin chào, ${_currentUser.fullname ?? _currentUser.username}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: _isDarkTheme ? Colors.white : Colors.black87,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 12,
                                          color: Colors.black54,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            // Feature Icons (Theme, Admin Toggle, Profile, Filter, Logout) with Wrapping
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8.0, // Horizontal spacing between icons
                              runSpacing: 8.0, // Vertical spacing between lines
                              children: [
                                ZoomIn(
                                  duration: Duration(milliseconds: 900),
                                  child: IconButton(
                                    icon: AnimatedSwitcher(
                                      duration: Duration(milliseconds: 300),
                                      child: Icon(
                                        _isDarkTheme ? Icons.wb_sunny : Icons.nightlight_round,
                                        key: ValueKey<bool>(_isDarkTheme),
                                        color: _isDarkTheme ? Colors.yellowAccent : Colors.blueAccent,
                                        size: 28,
                                      ),
                                    ),
                                    tooltip: 'Chuyển đổi chủ đề',
                                    onPressed: _toggleTheme,
                                  ),
                                ),
                                if (_loggedInAsAdmin)
                                  ZoomIn(
                                    duration: Duration(milliseconds: 950),
                                    child: IconButton(
                                      icon: Icon(
                                        _currentUser.isAdmin ? Icons.person : Icons.admin_panel_settings,
                                        color: _isDarkTheme ? Colors.white : Colors.black87,
                                        size: 28,
                                      ),
                                      tooltip: _currentUser.isAdmin ? 'Chuyển sang Người dùng' : 'Chuyển sang Admin',
                                      onPressed: _toggleAdminStatus,
                                    ),
                                  ),
                                ZoomIn(
                                  duration: Duration(milliseconds: 1000),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.person_outline,
                                      color: _isDarkTheme ? Colors.white : Colors.black87,
                                      size: 28,
                                    ),
                                    tooltip: 'Thông tin người dùng',
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/profile',
                                        arguments: _currentUser,
                                      );
                                    },
                                  ),
                                ),
                                ZoomIn(
                                  duration: Duration(milliseconds: 1050),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.filter_list,
                                      color: _isDarkTheme ? Colors.white : Colors.black87,
                                      size: 28,
                                    ),
                                    tooltip: 'Lọc',
                                    onPressed: _showFilterDialog,
                                  ),
                                ),
                                ZoomIn(
                                  duration: Duration(milliseconds: 1100),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.logout,
                                      color: _isDarkTheme ? Colors.white : Colors.black87,
                                      size: 28,
                                    ),
                                    tooltip: 'Đăng xuất',
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => _buildLogoutDialog(),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Glassmorphic Search Bar
                ElasticIn(
                  duration: Duration(milliseconds: 1000),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _isDarkTheme
                                ? Colors.white.withOpacity(0.15)
                                : Colors.black.withOpacity(0.05),
                            border: Border.all(
                              color: _isDarkTheme
                                  ? Colors.white.withOpacity(0.2)
                                  : Colors.black.withOpacity(0.1),
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 15,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: GoogleFonts.poppins(
                              color: _isDarkTheme ? Colors.white : Colors.black87,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Tìm kiếm công việc',
                              labelStyle: GoogleFonts.poppins(
                                color: _isDarkTheme ? Colors.white70 : Colors.black54,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: _isDarkTheme ? Colors.white70 : Colors.black54,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Task List
                Expanded(
                  child: _tasks.isEmpty
                      ? ZoomIn(
                    duration: Duration(milliseconds: 1100),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.task_alt,
                            size: 60,
                            color: _isDarkTheme ? Colors.white70 : Colors.black54,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Không tìm thấy công việc',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              color: _isDarkTheme ? Colors.white70 : Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      return SlideInLeft(
                        duration: Duration(milliseconds: 800 + (index * 100)),
                        child: TaskItem(
                          task: _tasks[index],
                          onTap: () async {
                            final result = await Navigator.pushNamed(
                              context,
                              '/task_detail',
                              arguments: {
                                'task': _tasks[index],
                                'currentUser': _currentUser
                              },
                            );
                            if (result == true) {
                              _loadTasks();
                            }
                          },
                          onComplete: (completed) async {
                            final dbHelper = DatabaseHelper.instance;
                            await dbHelper.updateTask(
                              _tasks[index].copyWith(completed: completed),
                            );
                            _loadTasks();
                          },
                          onDelete: () async {
                            // Show confirmation dialog before deleting
                            final confirmed = await _showDeleteConfirmationDialog(_tasks[index]);
                            if (confirmed) {
                              final dbHelper = DatabaseHelper.instance;
                              await dbHelper.deleteTask(_tasks[index].id);
                              _loadTasks();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Đã xóa công việc "${_tasks[index].title}"',
                                    style: GoogleFonts.poppins(color: Colors.white),
                                  ),
                                  backgroundColor: Colors.redAccent,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          isDarkTheme: _isDarkTheme,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // Enhanced FAB
      floatingActionButton: ZoomIn(
        duration: Duration(milliseconds: 1300),
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(_glowAnimation.value * 0.7),
                    blurRadius: 25,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: () async {
                  final result = await Navigator.pushNamed(
                    context,
                    '/task_form',
                    arguments: {'task': null, 'currentUser': _currentUser},
                  );
                  if (result == true) {
                    await _loadTasks(ignoreFilters: true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Đã thêm công việc mới',
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                        backgroundColor: Colors.greenAccent,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.cyanAccent, Colors.pinkAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(Icons.add, size: 32, color: Colors.black87),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogoutDialog() {
    return AlertDialog(
      backgroundColor: _isDarkTheme ? Color(0xFF121212) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.all(20),
      title: Text(
        'Xác nhận đăng xuất',
        style: GoogleFonts.poppins(
          color: _isDarkTheme ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      content: Text(
        'Bạn có chắc muốn đăng xuất?',
        style: GoogleFonts.poppins(
          color: _isDarkTheme ? Colors.white70 : Colors.black54,
          fontSize: 16,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Hủy',
            style: GoogleFonts.poppins(
              color: Colors.cyanAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _logout();
          },
          child: Text(
            'Đăng xuất',
            style: GoogleFonts.poppins(
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String? tempStatus = _selectedStatus;
        String? tempCategory = _selectedCategory;
        bool tempShowDueTasksOnly = _showDueTasksOnly;
        return AlertDialog(
          backgroundColor: _isDarkTheme
              ? Colors.black.withOpacity(0.85)
              : Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.all(20),
          title: Text(
            'Lọc Công Việc',
            style: GoogleFonts.poppins(
              color: _isDarkTheme ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: tempStatus,
                  hint: Text(
                    'Chọn Trạng Thái',
                    style: GoogleFonts.poppins(
                      color: _isDarkTheme ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tất Cả')),
                    DropdownMenuItem(value: 'To do', child: Text('Chưa Làm')),
                    DropdownMenuItem(value: 'In progress', child: Text('Đang Làm')),
                    DropdownMenuItem(value: 'Done', child: Text('Hoàn Thành')),
                    DropdownMenuItem(value: 'Cancelled', child: Text('Hủy Bỏ')),
                  ],
                  onChanged: (value) {
                    tempStatus = value;
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _isDarkTheme
                        ? Colors.white.withOpacity(0.15)
                        : Colors.black.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: GoogleFonts.poppins(
                    color: _isDarkTheme ? Colors.white : Colors.black87,
                  ),
                  dropdownColor: _isDarkTheme ? Color(0xFF121212) : Colors.white,
                ),
                SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Danh Mục',
                    labelStyle: GoogleFonts.poppins(
                      color: _isDarkTheme ? Colors.white70 : Colors.black54,
                    ),
                    filled: true,
                    fillColor: _isDarkTheme
                        ? Colors.white.withOpacity(0.15)
                        : Colors.black.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: GoogleFonts.poppins(
                    color: _isDarkTheme ? Colors.white : Colors.black87,
                  ),
                  onChanged: (value) {
                    tempCategory = value.isEmpty ? null : value;
                  },
                  controller: TextEditingController(text: tempCategory),
                ),
                SizedBox(height: 16),
                CheckboxListTile(
                  title: Text(
                    'Chỉ hiển thị công việc đến hạn',
                    style: GoogleFonts.poppins(
                      color: _isDarkTheme ? Colors.white : Colors.black87,
                    ),
                  ),
                  value: tempShowDueTasksOnly,
                  onChanged: (value) {
                    tempShowDueTasksOnly = value ?? false;
                    (context as Element).markNeedsBuild();
                  },
                  activeColor: Colors.cyanAccent,
                  checkColor: Colors.black,
                  tileColor: _isDarkTheme
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Hủy',
                style: GoogleFonts.poppins(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedStatus = tempStatus;
                  _selectedCategory = tempCategory;
                  _showDueTasksOnly = tempShowDueTasksOnly;
                });
                _loadTasks();
                Navigator.pop(context);
              },
              child: Text(
                'Áp Dụng',
                style: GoogleFonts.poppins(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}