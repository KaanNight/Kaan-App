import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const TaskReminderApp());
}

class TaskReminderApp extends StatelessWidget {
  const TaskReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Görev Hatırlatıcı',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: const TaskHomePage(),
    );
  }
}

class TaskItem {
  TaskItem({
    required this.id,
    required this.title,
    this.note,
    this.remindAt,
    this.isDone = false,
  });

  final int id;
  final String title;
  final String? note;
  final DateTime? remindAt;
  final bool isDone;

  int get notificationId => id.remainder(2147483647);

  TaskItem copyWith({
    String? title,
    String? note,
    DateTime? remindAt,
    bool? isDone,
    bool clearReminder = false,
  }) {
    return TaskItem(
      id: id,
      title: title ?? this.title,
      note: note ?? this.note,
      remindAt: clearReminder ? null : (remindAt ?? this.remindAt),
      isDone: isDone ?? this.isDone,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'remindAt': remindAt?.toIso8601String(),
      'isDone': isDone,
    };
  }

  static TaskItem fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] as int,
      title: json['title'] as String,
      note: json['note'] as String?,
      remindAt: json['remindAt'] == null
          ? null
          : DateTime.parse(json['remindAt'] as String),
      isDone: json['isDone'] as bool? ?? false,
    );
  }
}

class TaskRepository {
  static const _storageKey = 'daily_tasks_v1';

  Future<List<TaskItem>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => TaskItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveTasks(List<TaskItem> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(tasks.map((task) => task.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'daily_tasks_channel',
    'Gündelik Görevler',
    channelDescription: 'Saatli görev hatırlatmaları',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const DarwinNotificationDetails _iosDetails =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  static const NotificationDetails _details = NotificationDetails(
    android: _androidDetails,
    iOS: _iosDetails,
  );

  Future<void> init() async {
    tz_data.initializeTimeZones();

    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleForTask(TaskItem task) async {
    if (task.remindAt == null || task.isDone) return;

    final now = DateTime.now();
    if (!task.remindAt!.isAfter(now)) return;

    await _plugin.cancel(task.notificationId);

    await _plugin.zonedSchedule(
      task.notificationId,
      'Görev zamanı',
      task.title,
      tz.TZDateTime.from(task.remindAt!, tz.local),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: task.id.toString(),
    );
  }

  Future<void> cancelForTask(TaskItem task) async {
    await _plugin.cancel(task.notificationId);
  }
}

class TaskHomePage extends StatefulWidget {
  const TaskHomePage({super.key});

  @override
  State<TaskHomePage> createState() => _TaskHomePageState();
}

class _TaskHomePageState extends State<TaskHomePage> {
  final TaskRepository _repository = TaskRepository();
  List<TaskItem> _tasks = [];
  bool _isLoading = true;

  List<TaskItem> get _activeTasks =>
      _tasks.where((task) => !task.isDone).toList()..sort(_taskSort);

  List<TaskItem> get _doneTasks =>
      _tasks.where((task) => task.isDone).toList()..sort(_taskSort);

  bool get _hasCompletedTasks => _tasks.any((task) => task.isDone);

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  int _taskSort(TaskItem a, TaskItem b) {
    final aDate = a.remindAt;
    final bDate = b.remindAt;

    if (aDate == null && bDate == null) return b.id.compareTo(a.id);
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return aDate.compareTo(bDate);
  }

  Future<void> _loadTasks() async {
    final tasks = await _repository.loadTasks();

    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });

    for (final task in tasks) {
      await NotificationService.instance.scheduleForTask(task);
    }
  }

  Future<void> _saveAndRefresh(List<TaskItem> updatedTasks) async {
    await _repository.saveTasks(updatedTasks);
    setState(() => _tasks = updatedTasks);
  }

  Future<void> _addTask(TaskDraft draft) async {
    final task = TaskItem(
      id: DateTime.now().microsecondsSinceEpoch,
      title: draft.title,
      note: draft.note,
      remindAt: draft.remindAt,
    );

    final updated = [..._tasks, task];
    await _saveAndRefresh(updated);
    await NotificationService.instance.scheduleForTask(task);
  }

  Future<void> _toggleDone(TaskItem task, bool? value) async {
    final isDone = value ?? false;
    final updatedTask = task.copyWith(isDone: isDone);

    final updated = _tasks
        .map((item) => item.id == task.id ? updatedTask : item)
        .toList();

    await _saveAndRefresh(updated);

    if (isDone) {
      await NotificationService.instance.cancelForTask(task);
    } else {
      await NotificationService.instance.scheduleForTask(updatedTask);
    }
  }

  Future<void> _deleteTask(TaskItem task) async {
    final updated = _tasks.where((item) => item.id != task.id).toList();
    await _saveAndRefresh(updated);
    await NotificationService.instance.cancelForTask(task);
  }

  Future<void> _deleteCompletedTasks() async {
    final completed = _tasks.where((task) => task.isDone).toList();
    final updated = _tasks.where((task) => !task.isDone).toList();

    await _saveAndRefresh(updated);

    for (final task in completed) {
      await NotificationService.instance.cancelForTask(task);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${completed.length} tamamlanan görev silindi.')),
    );
  }

  Future<void> _openAddTaskSheet() async {
    final draft = await showModalBottomSheet<TaskDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const TaskEditorSheet(),
    );

    if (draft != null) {
      await _addTask(draft);
    }
  }

  Future<void> _confirmDeleteCompleted() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tamamlananları sil?'),
        content: const Text(
          'Bütün tamamlanan görevler kalıcı olarak silinecek. '
          'Thanos snap gibi ama görev listesi için.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _deleteCompletedTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTasks = _activeTasks;
    final doneTasks = _doneTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Görev Hatırlatıcı'),
        actions: [
          IconButton(
            tooltip: 'Tamamlananları sil',
            onPressed: _hasCompletedTasks ? _confirmDeleteCompleted : null,
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTaskSheet,
        icon: const Icon(Icons.add),
        label: const Text('Görev ekle'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? const EmptyState()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    TaskSection(
                      title: 'Aktif görevler',
                      count: activeTasks.length,
                      tasks: activeTasks,
                      onToggle: _toggleDone,
                      onDelete: _deleteTask,
                    ),
                    const SizedBox(height: 24),
                    TaskSection(
                      title: 'Tamamlananlar',
                      count: doneTasks.length,
                      tasks: doneTasks,
                      onToggle: _toggleDone,
                      onDelete: _deleteTask,
                    ),
                  ],
                ),
    );
  }
}

class TaskSection extends StatelessWidget {
  const TaskSection({
    super.key,
    required this.title,
    required this.count,
    required this.tasks,
    required this.onToggle,
    required this.onDelete,
  });

  final String title;
  final int count;
  final List<TaskItem> tasks;
  final Future<void> Function(TaskItem task, bool? value) onToggle;
  final Future<void> Function(TaskItem task) onDelete;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('$title boş. Şimdilik boss yok.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title  •  $count',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...tasks.map(
          (task) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TaskCard(
              task: task,
              onToggle: (value) => onToggle(task, value),
              onDelete: () => onDelete(task),
            ),
          ),
        ),
      ],
    );
  }
}

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  final TaskItem task;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isExpired = task.remindAt != null &&
        task.remindAt!.isBefore(DateTime.now()) &&
        !task.isDone;

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline),
      ),
      child: Card(
        child: CheckboxListTile(
          value: task.isDone,
          onChanged: onToggle,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            task.title,
            style: textTheme.titleMedium?.copyWith(
              decoration: task.isDone ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((task.note ?? '').isNotEmpty) Text(task.note!),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    size: 16,
                    color: isExpired
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    task.remindAt == null
                        ? 'Saat yok'
                        : formatDateTime(task.remindAt!),
                    style: TextStyle(
                      color: isExpired
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
          secondary: IconButton(
            tooltip: 'Sil',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.task_alt,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Görev yok.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Yeni görev ekle, saat seç, telefon sana hatırlatsın. '
              'İnsan hafızası RAM değil sonuçta.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class TaskDraft {
  TaskDraft({
    required this.title,
    this.note,
    this.remindAt,
  });

  final String title;
  final String? note;
  final DateTime? remindAt;
}

class TaskEditorSheet extends StatefulWidget {
  const TaskEditorSheet({super.key});

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  DateTime? get _remindAt {
    final date = _selectedDate;
    final time = _selectedTime;
    if (date == null || time == null) return null;

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      initialDate: _selectedDate ?? now,
    );

    if (selected != null) {
      setState(() => _selectedDate = selected);
    }
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (selected != null) {
      setState(() => _selectedTime = selected);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final remindAt = _remindAt;
    if (remindAt != null && !remindAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Geçmiş zamana hatırlatma kurulmaz, zaman makinesi DLC yok.',
          ),
        ),
      );
      return;
    }

    final note = _noteController.text.trim();

    Navigator.pop(
      context,
      TaskDraft(
        title: _titleController.text.trim(),
        note: note.isEmpty ? null : note,
        remindAt: remindAt,
      ),
    );
  }

  void _clearReminder() {
    setState(() {
      _selectedDate = null;
      _selectedTime = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding + 16),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Yeni görev',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Görev adı',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Görev adı boş olmasın.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Not',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      _selectedDate == null
                          ? 'Tarih seç'
                          : formatDate(_selectedDate!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text(
                      _selectedTime == null
                          ? 'Saat seç'
                          : _selectedTime!.format(context),
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedDate != null || _selectedTime != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _clearReminder,
                  icon: const Icon(Icons.notifications_off_outlined),
                  label: const Text('Hatırlatmayı kaldır'),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}

String twoDigits(int value) => value.toString().padLeft(2, '0');

String formatDate(DateTime value) {
  return '${twoDigits(value.day)}.${twoDigits(value.month)}.${value.year}';
}

String formatDateTime(DateTime value) {
  return '${formatDate(value)} ${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}
