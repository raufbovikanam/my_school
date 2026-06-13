import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/constants.dart';
import '../utils/image_helper.dart';
import '../services/school_db_service.dart';

class MarkSheetHistoryScreen extends StatefulWidget {
  final String schoolId;
  final String className;
  const MarkSheetHistoryScreen({
    super.key,
    required this.schoolId,
    required this.className,
  });

  @override
  State<MarkSheetHistoryScreen> createState() => _MarkSheetHistoryScreenState();
}

class _MarkSheetHistoryScreenState extends State<MarkSheetHistoryScreen> {
  @override
  void initState() {
    super.initState();
    SchoolDbService.instance.refreshStudents(
      schoolId: widget.schoolId,
      className: widget.className,
    );
    SchoolDbService.instance.refreshMarksheets(
      schoolId: widget.schoolId,
      className: widget.className,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Mark Sheets - ${widget.className}'),
          bottom: TabBar(
            indicatorColor: Colors.amber,
            tabs: [
              const Tab(icon: Icon(Icons.person_add), text: 'New Sheet'),
              const Tab(icon: Icon(Icons.history), text: 'Saved History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildStudentList(), _buildAllMarkSheetsList()],
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SchoolDbService.instance.watchStudents(
        schoolId: widget.schoolId,
        className: widget.className,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No students found in this class.'));
        }

        final students = List<Map<String, dynamic>>.from(snapshot.data!);
        students.sort(
          (a, b) => (a['name'] as String).toLowerCase().compareTo(
            (b['name'] as String).toLowerCase(),
          ),
        );

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final studentData = students[index];
            final gender = studentData['gender'] ?? 'Boy';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: gender == 'Girl'
                      ? AppColors.girlColorLight
                      : AppColors.primaryColor,
                  child: Text(
                    studentData['name'][0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  studentData['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Roll No: ${studentData['rollNo']}'),
                trailing: const Icon(
                  Icons.add_chart,
                  color: AppColors.primaryColor,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MarkSheetInputScreen(
                        schoolId: widget.schoolId,
                        initialClass: widget.className,
                        initialStudent: studentData['name'],
                        initialRoll: studentData['rollNo'],
                        initialFather: studentData['fatherName'],
                        initialAdmNo: studentData['admNo'],
                        initialDob: studentData['dob'],
                        photoUrl: studentData['photoPath'],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAllMarkSheetsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SchoolDbService.instance.watchMarksheets(
        schoolId: widget.schoolId,
        className: widget.className,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No mark sheets found for this class.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final data = snapshot.data![index];
            final gender = data['gender'] ?? 'Boy';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: gender == 'Girl'
                      ? AppColors.girlColorLight
                      : Color(data['themeColor'] ?? 0xFF004D40),
                  child: Text(
                    (data['studentName'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  data['studentName'] ?? 'Unnamed',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: gender == 'Girl'
                        ? AppColors.girlColor
                        : Colors.black87,
                  ),
                ),
                subtitle: Text('${data['examName']} - ${data['schoolName']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () =>
                          _deleteMarkSheet(context, data['id'] as String),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MarkSheetView(
                        docId: data['id'] as String,
                        schoolId: widget.schoolId,
                        schoolName: data['schoolName'],
                        schoolLogo: data['schoolLogo'],
                        examName: data['examName'],
                        examDate: data['examDate'],
                        studentName: data['studentName'],
                        fatherName: data['fatherName'],
                        rollNo: data['rollNo'],
                        admNo: data['admNo'],
                        dob: data['dob'],
                        photoUrl: data['photoUrl'],
                        className: data['className'] ?? '',
                        section: data['section'] ?? '',
                        classTeacherName: data['classTeacherName'],
                        remarks: data['remarks'],
                        position: data['position'],
                        subjects: (data['subjects'] as List)
                            .map((s) => Map<String, String>.from(s as Map))
                            .toList(),
                        themeColor: Color(data['themeColor'] ?? 0xFF004D40),
                        fontFamily: data['fontFamily'] ?? 'Roboto',
                        gender: gender,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  void _deleteMarkSheet(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Mark Sheet?'),
        content: const Text('This will permanently remove this mark sheet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await SchoolDbService.instance.deleteMarksheet(
                id,
                schoolId: widget.schoolId,
                className: widget.className,
              );
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class MarkSheetInputScreen extends StatefulWidget {
  final String? docId;
  final String schoolId; // Added schoolId
  final String? initialSchool;
  final String? initialSchoolAddress; // Added
  final String? initialBoard; // Added
  final String? initialExam;
  final String? examDate;
  final String? initialStudent;
  final String? initialFather; // Added father name
  final String? initialRoll;
  final String? initialAdmNo; // Added admission number
  final String? initialDob;
  final String? photoUrl;
  final String? schoolLogo; // Added school logo
  final String? initialClass;
  final String? initialSection; // Added section
  final String? initialTeacher;
  final String? initialRemarks; // Added remarks
  final String? initialPosition; // Added class position
  final List<Map<String, String>>? initialSubjects;
  final Color? initialColor;
  final String? initialFont;
  final String? initialGender;

  const MarkSheetInputScreen({
    super.key,
    this.docId,
    required this.schoolId, // Added schoolId
    this.initialSchool,
    this.initialSchoolAddress, // Added
    this.initialBoard, // Added
    this.initialExam,
    this.examDate,
    this.initialStudent,
    this.initialFather,
    this.initialRoll,
    this.initialAdmNo,
    this.initialDob,
    this.photoUrl,
    this.schoolLogo,
    this.initialClass,
    this.initialSection,
    this.initialTeacher,
    this.initialRemarks,
    this.initialPosition,
    this.initialSubjects,
    this.initialColor,
    this.initialFont,
    this.initialGender,
  });

  @override
  State<MarkSheetInputScreen> createState() => _MarkSheetInputScreenState();
}

class _MarkSheetInputScreenState extends State<MarkSheetInputScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _schoolNameController;
  late TextEditingController _schoolAddressController; // Added
  late TextEditingController _boardController; // Added
  late TextEditingController _studentNameController;
  late TextEditingController _fatherNameController; // Added
  late TextEditingController _rollNoController;
  late TextEditingController _admNoController; // Added
  late TextEditingController _teacherNameController;
  late TextEditingController _remarksController; // Added
  late TextEditingController _positionController; // Added
  late TextEditingController _dobController;
  late TextEditingController _examDateController;
  String? _selectedPhotoUrl;
  String? _schoolLogoUrl; // Added
  String? _selectedClass;
  String? _selectedDivision;
  String _selectedGender = 'Boy';
  late TextEditingController _examNameController;
  late Color _selectedColor;
  late String _selectedFont;
  List<Map<String, dynamic>> _classStudents = [];

  final List<String> _fonts = [
    'Roboto',
    'Lato',
    'Open Sans',
    'Montserrat',
    'Poppins',
  ];
  final List<String> _classes = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
  ];
  final List<String> _divisions = ['A', 'B', 'C', 'D', 'E'];
  late List<Map<String, TextEditingController>> _subjects;

  @override
  void initState() {
    super.initState();
    _schoolNameController = TextEditingController(
      text: widget.initialSchool ?? '',
    );
    _schoolAddressController = TextEditingController(
      text: widget.initialSchoolAddress,
    ); // Added
    _boardController = TextEditingController(
      text: widget.initialBoard,
    ); // Added
    _studentNameController = TextEditingController(text: widget.initialStudent);
    _fatherNameController = TextEditingController(text: widget.initialFather);
    _rollNoController = TextEditingController(text: widget.initialRoll);
    _admNoController = TextEditingController(text: widget.initialAdmNo);
    _teacherNameController = TextEditingController(text: widget.initialTeacher);
    _remarksController = TextEditingController(text: widget.initialRemarks);
    _positionController = TextEditingController(text: widget.initialPosition);
    _dobController = TextEditingController(text: widget.initialDob);
    _examDateController = TextEditingController(
      text: widget.examDate ?? DateFormat('dd-MM-yyyy').format(DateTime.now()),
    );
    _selectedPhotoUrl = widget.photoUrl;
    _schoolLogoUrl = widget.schoolLogo;
    _selectedGender = widget.initialGender ?? 'Boy';

    if (widget.initialClass != null && widget.initialClass!.contains(' ')) {
      final parts = widget.initialClass!.split(' ');
      _selectedClass = parts[0];
      _selectedDivision = parts[1];
    } else {
      _selectedClass = widget.initialClass;
    }

    _fetchClassStudents();
    _fetchSchoolDetails();
    _fetchClassDetails();
    _fetchLastUsedSettings();

    _examNameController = TextEditingController(text: widget.initialExam);
    _selectedColor = widget.initialColor ?? const Color(0xFF004D40);
    _selectedFont = widget.initialFont ?? 'Roboto';

    if (widget.initialSubjects != null) {
      _subjects = widget.initialSubjects!
          .map(
            (s) => {
              'name': TextEditingController(text: s['name']),
              'max': TextEditingController(text: s['max']),
              'obtained': TextEditingController(text: s['obtained']),
              'remarks': TextEditingController(
                text: s['remarks'] ?? '',
              ), // Added subject remarks
            },
          )
          .toList();
    } else {
      _subjects = [
        {
          'name': TextEditingController(text: 'Quran'),
          'max': TextEditingController(text: '100'),
          'obtained': TextEditingController(),
          'remarks': TextEditingController(),
        },
      ];
    }
  }

  @override
  void dispose() {
    _schoolNameController.dispose();
    _schoolAddressController.dispose(); // Added
    _boardController.dispose(); // Added
    _studentNameController.dispose();
    _fatherNameController.dispose();
    _rollNoController.dispose();
    _admNoController.dispose();
    _teacherNameController.dispose();
    _remarksController.dispose();
    _positionController.dispose();
    _dobController.dispose();
    _examDateController.dispose();
    _examNameController.dispose();
    for (var s in _subjects) {
      s['name']!.dispose();
      s['max']!.dispose();
      s['obtained']!.dispose();
      s['remarks']!.dispose();
    }
    super.dispose();
  }

  void _addSubject() {
    setState(() {
      _subjects.add({
        'name': TextEditingController(),
        'max': TextEditingController(text: '100'),
        'obtained': TextEditingController(),
        'remarks': TextEditingController(),
      });
    });
  }

  void _fetchSchoolDetails() async {
    try {
      final data = await SchoolDbService.instance.getSchool(widget.schoolId);
      if (data != null) {
        setState(() {
          if (_schoolNameController.text.isEmpty) {
            _schoolNameController.text = data['name'] ?? '';
          }
          if (_schoolAddressController.text.isEmpty) {
            _schoolAddressController.text = data['address'] ?? '';
          }
          if (_boardController.text.isEmpty) {
            _boardController.text = data['boardName'] ?? '';
          }
          _schoolLogoUrl ??= data['logoPath'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching school details: $e');
    }
  }

  void _fetchClassDetails() async {
    if (_selectedClass == null || _selectedDivision == null) return;
    try {
      final data = await SchoolDbService.instance.getClassByNameAndDivision(
        schoolId: widget.schoolId,
        name: _selectedClass!,
        division: _selectedDivision!,
      );

      if (data != null) {
        setState(() {
          if (_teacherNameController.text.isEmpty) {
            _teacherNameController.text = data['teacherName'] ?? '';
          }

          if (widget.docId == null && data['subjects'] != null) {
            final List<dynamic> classSubjects = data['subjects'];
            if (classSubjects.isNotEmpty) {
              _subjects = classSubjects
                  .map(
                    (s) => {
                      'name': TextEditingController(text: s.toString()),
                      'max': TextEditingController(text: '100'),
                      'obtained': TextEditingController(),
                      'remarks': TextEditingController(),
                    },
                  )
                  .toList();
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching class details: $e');
    }
  }

  void _fetchLastUsedSettings() async {
    if (widget.docId != null) return;

    try {
      final data = await SchoolDbService.instance.getLastMarksheet();
      if (data != null) {
        setState(() {
          if (_schoolNameController.text.isEmpty) {
            _schoolNameController.text = data['schoolName'] ?? '';
          }
          if (_schoolAddressController.text.isEmpty) {
            _schoolAddressController.text = data['schoolAddress'] ?? '';
          }
          if (_boardController.text.isEmpty) {
            _boardController.text = data['boardName'] ?? '';
          }
          if (_examNameController.text.isEmpty) {
            _examNameController.text = data['examName'] ?? '';
          }
          if (_teacherNameController.text.isEmpty) {
            _teacherNameController.text = data['classTeacherName'] ?? '';
          }
          _schoolLogoUrl ??= data['schoolLogo'];
          _selectedColor = Color(data['themeColor'] ?? 0xFF004D40);
          _selectedFont = data['fontFamily'] ?? 'Roboto';

          if (_subjects.length == 1 &&
              _subjects[0]['name']!.text == 'Quran' &&
              _subjects[0]['obtained']!.text.isEmpty) {
            _subjects = (data['subjects'] as List)
                .map(
                  (s) => {
                    'name': TextEditingController(text: s['name']),
                    'max': TextEditingController(text: s['max']),
                    'obtained': TextEditingController(),
                    'remarks': TextEditingController(),
                  },
                )
                .toList();
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching last settings: $e');
    }
  }

  void _fetchClassStudents() async {
    if (_selectedClass == null || _selectedDivision == null) return;

    try {
      final rows = await SchoolDbService.instance.getStudentsByClassName(
        '$_selectedClass $_selectedDivision',
      );
      final students = rows
          .map(
            (doc) => {
              'name': doc['name'],
              'fatherName': doc['fatherName'] ?? '',
              'rollNo': doc['rollNo'],
              'admNo': doc['admNo'] ?? '',
              'gender': doc['gender'] ?? 'Boy',
              'dob': doc['dob'] ?? '',
              'photoUrl': doc['photoPath'] ?? '',
            },
          )
          .toList();

      students.sort(
        (a, b) => (a['name'] as String).toLowerCase().compareTo(
          (b['name'] as String).toLowerCase(),
        ),
      );

      setState(() {
        _classStudents = students;
      });
    } catch (e) {
      debugPrint('Error fetching students: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Mark Sheet')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('Examination Details'),
              _buildTextField(
                _examNameController,
                'Examination Name (e.g. Annual Exam)',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _examDateController,
                decoration: const InputDecoration(
                  labelText: 'Exam Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    setState(
                      () => _examDateController.text = DateFormat(
                        'dd-MM-yyyy',
                      ).format(date),
                    );
                  }
                },
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Student Selection'),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedClass,
                      decoration: const InputDecoration(
                        labelText: 'Class',
                        border: OutlineInputBorder(),
                      ),
                      items: _classes
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedClass = v;
                          _studentNameController.clear();
                          _rollNoController.clear();
                        });
                        _fetchClassStudents();
                        _fetchClassDetails();
                      },
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedDivision,
                      decoration: const InputDecoration(
                        labelText: 'Div',
                        border: OutlineInputBorder(),
                      ),
                      items: _divisions
                          .map(
                            (d) => DropdownMenuItem(value: d, child: Text(d)),
                          )
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedDivision = v;
                          _studentNameController.clear();
                          _rollNoController.clear();
                        });
                        _fetchClassStudents();
                        _fetchClassDetails();
                      },
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_selectedClass != null &&
                  _selectedDivision != null &&
                  _studentNameController.text.isEmpty) ...[
                const Text(
                  'Select Student:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF004D40),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _classStudents.isEmpty
                      ? const Center(
                          child: Text('No students found in this class'),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _classStudents.length,
                          itemBuilder: (context, index) {
                            final student = _classStudents[index];
                            final isSelected =
                                _studentNameController.text == student['name'];
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: CircleAvatar(
                                radius: 15,
                                backgroundColor: student['gender'] == 'Girl'
                                    ? AppColors.girlColorLight
                                    : AppColors.primaryColor,
                                child: Text(
                                  student['name'][0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              title: Text(
                                student['name'],
                                style: TextStyle(
                                  color: isSelected
                                      ? (student['gender'] == 'Girl'
                                            ? AppColors.girlColor
                                            : AppColors.primaryColor)
                                      : (student['gender'] == 'Girl'
                                            ? AppColors.girlColor
                                            : Colors.black87),
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text('Roll: ${student['rollNo']}'),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                  : null,
                              selected: isSelected,
                              onTap: () {
                                setState(() {
                                  _studentNameController.text = student['name'];
                                  _fatherNameController.text =
                                      student['fatherName'] ??
                                      ''; // Added if exists
                                  _rollNoController.text = student['rollNo'];
                                  _admNoController.text =
                                      student['admNo'] ?? ''; // Added if exists
                                  _selectedGender = student['gender'];
                                  _dobController.text = student['dob'];
                                  _selectedPhotoUrl = student['photoUrl'];
                                });
                              },
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
              ],
              if (_studentNameController.text.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: _selectedGender == 'Girl'
                            ? AppColors.girlColorLight
                            : AppColors.primaryColor,
                        backgroundImage: imageFromPath(_selectedPhotoUrl),
                        child:
                            _selectedPhotoUrl == null ||
                                _selectedPhotoUrl!.isEmpty
                            ? Text(
                                _studentNameController.text[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _studentNameController.text,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Father: ${_fatherNameController.text}',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            Text(
                              'Roll No: ${_rollNoController.text} | Adm: ${_admNoController.text}',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            Text(
                              'DOB: ${_dobController.text} | Gender: $_selectedGender',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_note, color: Colors.blue),
                        onPressed: () {
                          // Allow quick re-selection if needed
                          setState(() {
                            _studentNameController.clear();
                          });
                        },
                        tooltip: 'Change Student',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              _buildSectionTitle('Performance & Grading'),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      _positionController,
                      'Class Position (e.g. 1st)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _remarksController,
                'General Remarks',
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('Subjects & Marks'),
                  TextButton.icon(
                    onPressed: _addSubject,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Subject'),
                  ),
                ],
              ),
              ...List.generate(_subjects.length, (i) => _buildSubjectRow(i)),
              const SizedBox(height: 24),
              _buildSectionTitle('Customization'),
              ListTile(
                title: const Text('Theme Color'),
                trailing: CircleAvatar(backgroundColor: _selectedColor),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Pick Color'),
                      content: SingleChildScrollView(
                        child: ColorPicker(
                          pickerColor: _selectedColor,
                          onColorChanged: (c) =>
                              setState(() => _selectedColor = c),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: _selectedFont,
                items: _fonts
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedFont = v!),
                decoration: const InputDecoration(labelText: 'Font Style'),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MarkSheetView(
                          docId: widget.docId,
                          schoolId: widget.schoolId, // Added schoolId
                          schoolName: _schoolNameController.text,
                          schoolAddress: _schoolAddressController.text, // Added
                          boardName: _boardController.text, // Added
                          schoolLogo: _schoolLogoUrl, // Added
                          examName: _examNameController.text,
                          examDate: _examDateController.text,
                          studentName: _studentNameController.text,
                          fatherName: _fatherNameController.text, // Added
                          rollNo: _rollNoController.text,
                          admNo: _admNoController.text, // Added
                          dob: _dobController.text,
                          photoUrl: _selectedPhotoUrl,
                          className: '$_selectedClass', // Just class
                          section: _selectedDivision ?? '', // Section
                          classTeacherName: _teacherNameController.text,
                          remarks: _remarksController.text, // Added
                          position: _positionController.text, // Added
                          themeColor: _selectedColor,
                          fontFamily: _selectedFont,
                          gender: _selectedGender,
                          subjects: _subjects
                              .map(
                                (s) => {
                                  'name': s['name']!.text,
                                  'max': s['max']!.text,
                                  'obtained': s['obtained']!.text,
                                  'remarks': s['remarks']!.text, // Added
                                },
                              )
                              .toList(),
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004D40),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Preview Mark Sheet',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF004D40),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (v) => v!.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildSubjectRow(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildTextField(_subjects[index]['name']!, 'Subject'),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _buildTextField(_subjects[index]['max']!, 'Max'),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _buildTextField(_subjects[index]['obtained']!, 'Obt'),
              ),
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.red,
                ),
                onPressed: () => setState(() => _subjects.removeAt(index)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MarkSheetView extends StatefulWidget {
  final String? docId;
  final String schoolId; // Added schoolId
  final String schoolName;
  final String? schoolAddress; // Added
  final String? boardName; // Added
  final String? schoolLogo; // Added
  final String examName;
  final String? examDate;
  final String studentName;
  final String? fatherName; // Added
  final String rollNo;
  final String? admNo; // Added
  final String? dob;
  final String? photoUrl;
  final String className;
  final String section; // Added
  final List<Map<String, String>> subjects;
  final String? classTeacherName;
  final String? remarks; // Added
  final String? position; // Added
  final Color themeColor;
  final String fontFamily;
  final String? gender;

  const MarkSheetView({
    super.key,
    this.docId,
    required this.schoolId, // Added schoolId
    required this.schoolName,
    this.schoolAddress, // Added
    this.boardName, // Added
    this.schoolLogo, // Added
    required this.examName,
    this.examDate,
    required this.studentName,
    this.fatherName,
    required this.rollNo,
    this.admNo,
    this.dob,
    this.photoUrl,
    required this.className,
    required this.section,
    required this.subjects,
    this.classTeacherName,
    this.remarks,
    this.position,
    required this.themeColor,
    required this.fontFamily,
    this.gender,
  });

  @override
  State<MarkSheetView> createState() => _MarkSheetViewState();
}

class _MarkSheetViewState extends State<MarkSheetView> {
  final ScreenshotController screenshotController = ScreenshotController();
  bool _isSaving = false;

  String _calculateGrade(double percentage) {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B+';
    if (percentage >= 60) return 'B';
    if (percentage >= 50) return 'C+';
    if (percentage >= 40) return 'C';
    if (percentage >= 33) return 'D';
    return 'E';
  }

  Future<void> _saveToLocal() async {
    setState(() => _isSaving = true);
    try {
      final data = {
        'userId': SchoolDbService.instance.userId,
        'schoolId': widget.schoolId,
        'schoolName': widget.schoolName,
        'schoolAddress': widget.schoolAddress,
        'boardName': widget.boardName,
        'schoolLogo': widget.schoolLogo,
        'examName': widget.examName,
        'examDate': widget.examDate,
        'studentName': widget.studentName,
        'fatherName': widget.fatherName,
        'rollNo': widget.rollNo,
        'admNo': widget.admNo,
        'dob': widget.dob,
        'photoUrl': widget.photoUrl,
        'className': widget.className,
        'section': widget.section,
        'classTeacherName': widget.classTeacherName,
        'remarks': widget.remarks,
        'position': widget.position,
        'gender': widget.gender,
        'subjects': widget.subjects,
        'themeColor': widget.themeColor.toARGB32(),
        'fontFamily': widget.fontFamily,
      };

      await SchoolDbService.instance.saveMarksheet(data, docId: widget.docId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Mark Sheet Saved!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _shareMarkSheet() async {
    final Uint8List? imageBytes = await screenshotController.capture();
    if (imageBytes == null) return;

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${widget.studentName}_marksheet.jpg');
    await file.writeAsBytes(imageBytes);

    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Mark Sheet for ${widget.studentName}');
  }

  Future<void> _printMarkSheet() async {
    final Uint8List? imageBytes = await screenshotController.capture();
    if (imageBytes == null) return;

    final doc = pw.Document();
    final image = pw.MemoryImage(imageBytes);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain));
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Sheet Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Mark Sheet',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MarkSheetInputScreen(
                    docId: widget.docId,
                    schoolId: widget.schoolId, // Added schoolId
                    initialSchool: widget.schoolName,
                    initialSchoolAddress: widget.schoolAddress, // Added
                    initialBoard: widget.boardName, // Added
                    schoolLogo: widget.schoolLogo,
                    initialExam: widget.examName,
                    examDate: widget.examDate,
                    initialStudent: widget.studentName,
                    initialFather: widget.fatherName,
                    initialRoll: widget.rollNo,
                    initialAdmNo: widget.admNo,
                    initialDob: widget.dob,
                    photoUrl: widget.photoUrl,
                    initialClass: widget.className,
                    initialSection: widget.section,
                    initialTeacher: widget.classTeacherName,
                    initialRemarks: widget.remarks,
                    initialPosition: widget.position,
                    initialSubjects: widget.subjects,
                    initialColor: widget.themeColor,
                    initialFont: widget.fontFamily,
                    initialGender: widget.gender,
                  ),
                ),
              );
            },
          ),
          IconButton(
            onPressed: _saveToLocal,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save),
            tooltip: 'Save Mark Sheet',
          ),
          IconButton(
            onPressed: _printMarkSheet,
            icon: const Icon(Icons.print),
            tooltip: 'Print as A4 PDF',
          ),
          IconButton(onPressed: _shareMarkSheet, icon: const Icon(Icons.share)),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey.shade200, Colors.grey.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: Screenshot(
                controller: screenshotController,
                child: Container(
                  width: 850,
                  padding: const EdgeInsets.all(2), // Outer border padding
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFF0D47A1),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    constraints: const BoxConstraints(minHeight: 1150),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.amber.shade700,
                        width: 4,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Modern Professional Header
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Row(
                            children: [
                              // School Emblem
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF0D47A1),
                                    width: 2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor: Colors.white,
                                  backgroundImage: imageFromPath(
                                    widget.schoolLogo,
                                  ),
                                  child: widget.schoolLogo == null
                                      ? const Icon(
                                          Icons.school,
                                          size: 70,
                                          color: Color(0xFF0D47A1),
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 30),
                              // School Name & Address
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      widget.schoolName.toUpperCase(),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.getFont(
                                        widget.fontFamily,
                                        fontSize: 38,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF0D47A1),
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (widget.schoolAddress != null &&
                                        widget.schoolAddress!.isNotEmpty)
                                      Text(
                                        widget.schoolAddress!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey.shade800,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    if (widget.boardName != null &&
                                        widget.boardName!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          widget.boardName!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.blue.shade900,
                                            fontWeight: FontWeight.w600,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 30),
                              // Placeholder for symmetry or QR code
                              const SizedBox(width: 124),
                            ],
                          ),
                        ),

                        const Divider(thickness: 2, color: Color(0xFF0D47A1)),

                        // Report Title
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D47A1),
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: const Text(
                                  'PROGRESS REPORT',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.examName.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                              Text(
                                'Academic Session: ${widget.examDate?.split('-').last ?? ""}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Student Profile Section
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Student Photo
                              Container(
                                width: 140,
                                height: 160,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFF0D47A1),
                                    width: 2,
                                  ),
                                ),
                                child:
                                    (widget.photoUrl != null &&
                                        widget.photoUrl!.isNotEmpty &&
                                        File(widget.photoUrl!).existsSync())
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.zero,
                                        child: Image.file(
                                          File(widget.photoUrl!),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                        ),
                                      )
                                    : const Center(
                                        child: Icon(
                                          Icons.person,
                                          size: 100,
                                          color: Colors.grey,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 30),
                              Expanded(
                                child: Column(
                                  children: [
                                    _profileRowWithIcon(
                                      Icons.person,
                                      'Name',
                                      widget.studentName.toUpperCase(),
                                    ),
                                    _profileRowWithIcon(
                                      Icons.person_outline,
                                      'Father',
                                      widget.fatherName?.toUpperCase() ?? 'N/A',
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _profileRowWithIcon(
                                            Icons.class_,
                                            'Class',
                                            widget.className,
                                          ),
                                        ),
                                        Expanded(
                                          child: _profileRowWithIcon(
                                            Icons.numbers,
                                            'Roll No',
                                            widget.rollNo,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _profileRowWithIcon(
                                            Icons.segment,
                                            'Section',
                                            widget.section,
                                          ),
                                        ),
                                        Expanded(
                                          child: _profileRowWithIcon(
                                            Icons.badge,
                                            'Adm. No',
                                            widget.admNo ?? 'N/A',
                                          ),
                                        ),
                                      ],
                                    ),
                                    _profileRowWithIcon(
                                      Icons.calendar_today,
                                      'Date of Birth',
                                      widget.dob ?? 'N/A',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Marks Table
                        _buildParadiseMarksTable(),

                        const SizedBox(height: 30),

                        // Summary and Remarks Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Results Summary
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'RESULTS SUMMARY',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D47A1),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _summaryBox(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 30),
                            // Overall Remarks
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'REMARKS',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D47A1),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(15),
                                    height: 145,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      widget.remarks ?? "No remarks added.",
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        // Signatures
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _signatureArea(
                                'Class Teacher',
                                widget.classTeacherName,
                              ),
                              _signatureArea('Headmaster', 'Office Seal'),
                              _signatureArea('Parent/Guardian', ''),
                            ],
                          ),
                        ),

                        // Grading Scale Table
                        Column(
                          children: [
                            const Text(
                              'GRADING SCALE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Table(
                              border: TableBorder.all(
                                color: Colors.grey.shade300,
                              ),
                              children: [
                                const TableRow(
                                  decoration: BoxDecoration(
                                    color: Color(0xFFF5F5F5),
                                  ),
                                  children: [
                                    _GradeCell('91-100 (A+)'),
                                    _GradeCell('81-90 (A)'),
                                    _GradeCell('71-80 (B+)'),
                                    _GradeCell('61-70 (B)'),
                                    _GradeCell('51-60 (C+)'),
                                    _GradeCell('41-50 (C)'),
                                    _GradeCell('33-40 (D)'),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileRowWithIcon(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.amber.shade800),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(
              '$label: ',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.black,
              ),
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParadiseMarksTable() {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FixedColumnWidth(50),
        1: FlexColumnWidth(3),
        2: FixedColumnWidth(80),
        3: FixedColumnWidth(90),
        4: FixedColumnWidth(80),
        5: FixedColumnWidth(100),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.blue.shade50),
          children: [
            _th('S.NO.'),
            _th('SUBJECT NAME'),
            _th('TOTAL MARKS'),
            _th('MARKS OBTAINED'),
            _th('GRADE'),
            _th('PERCENTAGE'),
          ],
        ),
        ...widget.subjects.asMap().entries.map((entry) {
          int index = entry.key;
          var s = entry.value;
          double max = double.tryParse(s['max']!) ?? 100;
          double obt = double.tryParse(s['obtained']!) ?? 0;
          double perc = (obt / max) * 100;
          String grade = _calculateGrade(perc);

          return TableRow(
            decoration: BoxDecoration(
              color: index % 2 == 1 ? Colors.grey.shade50 : Colors.white,
            ),
            children: [
              _td((index + 1).toString()),
              _td(s['name']!, align: TextAlign.left, bold: true),
              _td(s['max']!),
              _td(s['obtained']!),
              _buildGradeBadge(grade),
              _td('${perc.toStringAsFixed(0)}%'),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildGradeBadge(String grade) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _getGradeColor(grade),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _getGradeColor(grade).withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            grade,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Color _getGradeColor(String grade) {
    if (grade == 'A+') return Colors.green.shade800;
    if (grade == 'A') return Colors.green;
    if (grade == 'B+') return Colors.blue;
    if (grade == 'B') return Colors.blue.shade300;
    if (grade == 'C+') return Colors.orange;
    if (grade == 'C') return Colors.orange.shade300;
    return Colors.red;
  }

  Widget _th(String text) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 13,
          color: Color(0xFF0D47A1),
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _td(
    String text, {
    TextAlign align = TextAlign.center,
    bool bold = false,
    Color? color,
    double fontSize = 13,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          fontSize: fontSize,
          color: color ?? Colors.black87,
        ),
      ),
    );
  }

  Widget _summaryBox() {
    int totalMax = 0;
    int totalObt = 0;
    for (var s in widget.subjects) {
      totalMax += int.tryParse(s['max']!) ?? 0;
      totalObt += int.tryParse(s['obtained']!) ?? 0;
    }
    double overallPerc = (totalObt / totalMax) * 100;
    String overallGrade = _calculateGrade(overallPerc);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _summaryRow('Grand Total', '$totalObt / $totalMax'),
          _summaryRow('Total Percentage', '${overallPerc.toStringAsFixed(2)}%'),
          _summaryRow('Overall Grade', overallGrade),
          _summaryRow('Class Position', widget.position ?? 'N/A', isLast: true),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF1565C0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _signatureArea(String label, String? name) {
    return Column(
      children: [
        if (name != null)
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        const SizedBox(height: 5),
        Container(width: 150, height: 1, color: Colors.black87),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF1565C0),
          ),
        ),
      ],
    );
  }
}

class _GradeCell extends StatelessWidget {
  final String text;
  const _GradeCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
      ),
    );
  }
}
