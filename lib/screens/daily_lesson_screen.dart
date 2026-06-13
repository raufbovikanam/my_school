import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../services/school_db_service.dart';

class DailyLessonScreen extends StatefulWidget {
  final String schoolId;
  final String className;
  const DailyLessonScreen({super.key, required this.schoolId, required this.className});

  @override
  State<DailyLessonScreen> createState() => _DailyLessonScreenState();
}

class _DailyLessonScreenState extends State<DailyLessonScreen> {
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic> _currentLessons = {};
  bool _lessonsLoaded = false;

  @override
  void initState() {
    super.initState();
    SchoolDbService.instance.refreshStudents(
      schoolId: widget.schoolId,
      className: widget.className,
    );
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    final records = await SchoolDbService.instance.getLessons(
      schoolId: widget.schoolId,
      className: widget.className,
      date: _selectedDate,
    );
    if (mounted) {
      setState(() {
        _currentLessons = Map<String, dynamic>.from(records);
        _lessonsLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lessons - ${widget.className}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = picked;
                  _lessonsLoaded = false;
                });
                await _loadLessons();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Date: ${DateFormat('dd-MM-yyyy').format(_selectedDate)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SchoolDbService.instance.watchStudents(
                schoolId: widget.schoolId,
                className: widget.className,
              ),
              builder: (context, studentSnapshot) {
                if (!studentSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                final students = studentSnapshot.data!;
                if (students.isEmpty) return const Center(child: Text('No students found in this class.'));
                if (!_lessonsLoaded) return const Center(child: CircularProgressIndicator());

                return ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final studentId = student['id'] as String;
                    final studentName = student['name'] as String;
                    final gender = student['gender'] ?? 'Boy';
                    final lesson = _currentLessons[studentId]?.toString() ?? '';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(
                          studentName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: gender == 'Girl' ? AppColors.girlColor : Colors.black87,
                          ),
                        ),
                        subtitle: TextField(
                          controller: TextEditingController(text: lesson)
                            ..selection = TextSelection.collapsed(offset: lesson.length),
                          decoration: const InputDecoration(hintText: 'Enter lesson details...', border: InputBorder.none),
                          onSubmitted: (val) async {
                            _currentLessons[studentId] = val;
                            await SchoolDbService.instance.saveLessons(
                              schoolId: widget.schoolId,
                              className: widget.className,
                              date: _selectedDate,
                              records: _currentLessons,
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
