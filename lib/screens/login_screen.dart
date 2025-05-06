import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/User.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _fullnameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  bool _isLogin = true;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  DateTime? _birthDate;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    print('Loading GoogleFonts.poppins...');
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final initialDate = _birthDate ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.cyanAccent,
              onPrimary: Colors.black,
              surface: Color(0xFF212121), // Thay Colors.grey[900] bằng mã màu tương đương
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Color(0xFF212121),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      final dbHelper = DatabaseHelper.instance;
      try {
        if (_isLogin) {
          final users = await dbHelper.getAllUsers();
          final user = users.firstWhere(
                (u) =>
            u.username == _usernameController.text &&
                u.password == _passwordController.text,
            orElse: () => User(
              id: '',
              username: '',
              password: '',
              email: '',
              createdAt: DateTime.now(),
              lastActive: DateTime.now(),
            ),
          );
          if (user.id.isNotEmpty) {
            await dbHelper.updateUser(user.copyWith(
              lastActive: DateTime.now(),
            ));
            Navigator.pushReplacementNamed(context, '/tasks', arguments: user);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Tên đăng nhập hoặc mật khẩu không đúng'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        } else {
          final existingUsers = await dbHelper.getAllUsers();
          if (existingUsers.any((u) => u.username == _usernameController.text)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Tên đăng nhập đã tồn tại'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
            return;
          }
          if (existingUsers.any((u) => u.email == _emailController.text)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Email đã được sử dụng'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
            return;
          }
          if (_birthDate == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Vui lòng chọn ngày sinh'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
            return;
          }
          final user = User(
            id: const Uuid().v4(),
            username: _usernameController.text,
            password: _passwordController.text,
            email: _emailController.text,
            createdAt: DateTime.now(),
            lastActive: DateTime.now(),
            birthDate: _birthDate,
            phoneNumber: _phoneNumberController.text.isEmpty ? null : _phoneNumberController.text,
            fullname: _fullnameController.text.isEmpty ? null : _fullnameController.text,
            isAdmin: _isAdmin,
          );
          await dbHelper.createUser(user);
          Navigator.pushReplacementNamed(context, '/tasks', arguments: user);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullnameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blueAccent, Colors.purpleAccent],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeIn(
                    duration: Duration(milliseconds: 1000),
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.task_alt,
                        size: 80,
                        color: Colors.cyanAccent,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  FadeInDown(
                    duration: Duration(milliseconds: 900),
                    child: Text(
                      _isLogin ? 'Đăng Nhập' : 'Đăng Ký',
                      style: GoogleFonts.poppins(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                  FadeInUp(
                    duration: Duration(milliseconds: 1000),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20.0),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                        child: Container(
                          padding: const EdgeInsets.all(24.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20.0),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                FadeInUp(
                                  duration: Duration(milliseconds: 1100),
                                  child: _buildTextField(
                                    controller: _usernameController,
                                    label: 'Tên đăng nhập',
                                    icon: Icons.person,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Vui lòng nhập tên đăng nhập';
                                      }
                                      if (value.length < 3) {
                                        return 'Tên đăng nhập phải có ít nhất 3 ký tự';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                if (!_isLogin) ...[
                                  SizedBox(height: 16),
                                  FadeInUp(
                                    duration: Duration(milliseconds: 1200),
                                    child: _buildTextField(
                                      controller: _fullnameController,
                                      label: 'Tên người dùng',
                                      icon: Icons.person_outline,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Vui lòng nhập tên người dùng';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                                SizedBox(height: 16),
                                FadeInUp(
                                  duration: Duration(milliseconds: 1300),
                                  child: _buildTextField(
                                    controller: _passwordController,
                                    label: 'Mật khẩu',
                                    icon: Icons.lock,
                                    isPassword: true,
                                    obscureText: !_isPasswordVisible,
                                    toggleVisibility: () {
                                      setState(() {
                                        _isPasswordVisible = !_isPasswordVisible;
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Vui lòng nhập mật khẩu';
                                      }
                                      if (value.length < 6) {
                                        return 'Mật khẩu phải có ít nhất 6 ký tự';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                if (!_isLogin) ...[
                                  SizedBox(height: 16),
                                  FadeInUp(
                                    duration: Duration(milliseconds: 1400),
                                    child: _buildTextField(
                                      controller: _confirmPasswordController,
                                      label: 'Nhập lại mật khẩu',
                                      icon: Icons.lock,
                                      isPassword: true,
                                      obscureText: !_isConfirmPasswordVisible,
                                      toggleVisibility: () {
                                        setState(() {
                                          _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                        });
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Vui lòng nhập lại mật khẩu';
                                        }
                                        if (value != _passwordController.text) {
                                          return 'Mật khẩu không khớp';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  FadeInUp(
                                    duration: Duration(milliseconds: 1500),
                                    child: _buildTextField(
                                      controller: _emailController,
                                      label: 'Email',
                                      icon: Icons.email,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Vui lòng nhập email';
                                        }
                                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                          return 'Email không hợp lệ';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  FadeInUp(
                                    duration: Duration(milliseconds: 1600),
                                    child: ListTile(
                                      title: Text(
                                        'Ngày sinh: ${_birthDate != null ? DateFormat.yMd().format(_birthDate!) : 'Chưa chọn'}',
                                        style: GoogleFonts.poppins(color: Colors.white),
                                      ),
                                      trailing: Icon(Icons.calendar_today, color: Colors.cyanAccent),
                                      onTap: _selectBirthDate,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12.0),
                                        side: BorderSide(color: Colors.white.withOpacity(0.3)),
                                      ),
                                      tileColor: Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  FadeInUp(
                                    duration: Duration(milliseconds: 1700),
                                    child: _buildTextField(
                                      controller: _phoneNumberController,
                                      label: 'Số điện thoại (tùy chọn)',
                                      icon: Icons.phone,
                                      keyboardType: TextInputType.phone,
                                      validator: (value) {
                                        if (value != null && value.isNotEmpty) {
                                          if (!RegExp(r'^[0-9]{10,11}$').hasMatch(value)) {
                                            return 'Số điện thoại không hợp lệ';
                                          }
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  FadeInUp(
                                    duration: Duration(milliseconds: 1800),
                                    child: CheckboxListTile(
                                      title: Text(
                                        'Đăng ký tài khoản Admin',
                                        style: GoogleFonts.poppins(color: Colors.white),
                                      ),
                                      value: _isAdmin,
                                      onChanged: (value) {
                                        setState(() {
                                          _isAdmin = value ?? false;
                                        });
                                      },
                                      activeColor: Colors.cyanAccent,
                                      checkColor: Colors.black,
                                      tileColor: Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                ],
                                SizedBox(height: 24),
                                FadeInUp(
                                  duration: Duration(milliseconds: 1900),
                                  child: _isLoading
                                      ? SpinKitCircle(
                                    color: Colors.cyanAccent,
                                    size: 50.0,
                                  )
                                      : ElevatedButton(
                                    onPressed: _submit,
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12.0),
                                      ),
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.black.withOpacity(0.3),
                                      elevation: 10,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.cyanAccent, Colors.pinkAccent],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12.0),
                                      ),
                                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(_isLogin ? Icons.login : Icons.person_add, color: Colors.black),
                                          SizedBox(width: 10),
                                          Text(
                                            _isLogin ? 'Đăng nhập' : 'Đăng ký',
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (_isLogin)
                                  FadeInUp(
                                    duration: Duration(milliseconds: 2000),
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/forgot_password');
                                      },
                                      child: Text(
                                        'Quên mật khẩu?',
                                        style: GoogleFonts.poppins(
                                          color: Colors.cyanAccent,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                SizedBox(height: 16),
                                FadeInUp(
                                  duration: Duration(milliseconds: 2100),
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _isLogin = !_isLogin;
                                        _formKey.currentState?.reset();
                                        _usernameController.clear();
                                        _fullnameController.clear();
                                        _passwordController.clear();
                                        _confirmPasswordController.clear();
                                        _emailController.clear();
                                        _phoneNumberController.clear();
                                        _birthDate = null;
                                        _isPasswordVisible = false;
                                        _isConfirmPasswordVisible = false;
                                        _isAdmin = false;
                                      });
                                    },
                                    child: Text(
                                      _isLogin ? 'Tạo tài khoản mới' : 'Đã có tài khoản? Đăng nhập',
                                      style: GoogleFonts.poppins(
                                        color: Colors.cyanAccent,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? toggleVisibility,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.cyanAccent),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.cyanAccent,
          ),
          onPressed: toggleVisibility,
        )
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.cyanAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.redAccent, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
      validator: validator,
    );
  }
}