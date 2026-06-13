import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'settings_screen.dart';
import 'student_screens.dart';
import 'attendance_screens.dart';
import 'chart_screens.dart';
import 'daily_lesson_screen.dart';
import 'fees_screens.dart';
import 'marksheet_screens.dart';

class HomeScreen extends StatelessWidget {
  final String schoolId;
  final String schoolName;
  final String className;

  const HomeScreen({
    super.key,
    required this.schoolId,
    required this.schoolName,
    required this.className,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(schoolName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Class: $className', style: const TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(24),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildHomeCard(
            context,
            'Students',
            Icons.people,
            const Color(0xFF004D40),
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => StudentListScreen(schoolId: schoolId, className: className))),
          ),
          _buildHomeCard(
            context,
            'Attendance',
            Icons.calendar_month,
            Colors.blue,
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceScreen(schoolId: schoolId, className: className))),
          ),
          _buildHomeCard(
            context,
            'Progress Chart',
            Icons.grid_on,
            Colors.green,
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => InputScreen(schoolId: schoolId, className: className))),
          ),
          _buildHomeCard(
            context,
            'Saved Charts',
            Icons.history,
            Colors.teal,
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => HistoryScreen(schoolId: schoolId, className: className))),
          ),
          _buildHomeCard(
            context,
            'Daily Lessons',
            Icons.book,
            Colors.purple,
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => DailyLessonScreen(schoolId: schoolId, className: className))),
          ),
          _buildHomeCard(
            context,
            'Fee Management',
            Icons.money,
            Colors.amber,
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => FeesManagerScreen(schoolId: schoolId, className: className))),
          ),
          _buildHomeCard(
            context,
            'Mark Sheets',
            Icons.assignment,
            Colors.orange,
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => MarkSheetHistoryScreen(schoolId: schoolId, className: className))),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
