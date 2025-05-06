import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/User.dart';
import '../models/Task.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._instance();
  static Database? _database;

  DatabaseHelper._instance();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'task_manager.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        email TEXT NOT NULL,
        avatar TEXT,
        createdAt TEXT NOT NULL,
        lastActive TEXT NOT NULL,
        birthDate TEXT,
        phoneNumber TEXT,
        fullname TEXT,
        isAdmin INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        status TEXT NOT NULL,
        priority INTEGER NOT NULL,
        dueDate TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        assignedTo TEXT,
        createdBy TEXT NOT NULL,
        category TEXT,
        attachments TEXT,
        completed INTEGER NOT NULL,
        FOREIGN KEY (createdBy) REFERENCES users(id)
      )
    ''');
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users');
    return List.generate(maps.length, (i) => User.fromMap(maps[i]));
  }

  Future<List<User>> getNonAdminUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'isAdmin = ?',
      whereArgs: [0],
    );
    final users = List.generate(maps.length, (i) => User.fromMap(maps[i]));
    print('Non-admin users fetched: ${users.map((u) => u.username).toList()}'); // Debug print
    return users;
  }

  Future<void> createUser(User user) async {
    final db = await database;
    await db.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateUser(User user) async {
    final db = await database;
    await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<void> toggleAdminStatus(String userId, bool isAdmin) async {
    final db = await database;
    await db.update(
      'users',
      {'isAdmin': isAdmin ? 1 : 0},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> createTask(Task task) async {
    final db = await database;
    await db.insert('tasks', task.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateTask(Task task) async {
    final db = await database;
    await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Task>> searchTasks({
    String? query,
    String? status,
    String? category,
    String? userId,
    bool isAdmin = true,
  }) async {
    final db = await database;
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (query != null && query.isNotEmpty) {
      whereClauses.add('title LIKE ? OR description LIKE ?');
      whereArgs.addAll(['%$query%', '%$query%']);
    }
    if (status != null) {
      whereClauses.add('status = ?');
      whereArgs.add(status);
    }
    if (category != null) {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }
    if (!isAdmin && userId != null) {
      whereClauses.add('(assignedTo = ? OR createdBy = ?)');
      whereArgs.addAll([userId, userId]);
    }

    final whereClause = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
    );

    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  Future<List<Task>> getAllTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('tasks');
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  Future<void> debugTasks() async {
    final tasks = await getAllTasks();
    print('Tasks table: ${tasks.map((t) => {'id': t.id, 'title': t.title, 'createdBy': t.createdBy}).toList()}');
  }

  Future<bool> updatePassword(String email, String newPassword) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (result.isEmpty) {
      return false;
    }
    await db.update(
      'users',
      {'password': newPassword},
      where: 'email = ?',
      whereArgs: [email],
    );
    return true;
  }

  Future<int> getTaskCountByUser(String userId) async {
    final db = await database;
    final result = await db.query(
      'tasks',
      where: 'createdBy = ?',
      whereArgs: [userId],
    );
    return result.length;
  }
}