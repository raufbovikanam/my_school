import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import '../services/activation_service.dart';
import '../utils/constants.dart';
import '../utils/image_helper.dart';
import '../services/backup_service.dart';
import '../services/school_db_service.dart';
import '../services/image_storage_service.dart';

class SchoolListScreen extends StatefulWidget {
  const SchoolListScreen({super.key});

  @override
  State<SchoolListScreen> createState() => _SchoolListScreenState();
}

class _SchoolListScreenState extends State<SchoolListScreen> {
  Map<String, dynamic>? _activationStatus;

  @override
  void initState() {
    super.initState();
    _checkInitialBackup();
    _loadActivationStatus();
    SchoolDbService.instance.refreshSchools();
  }

  Future<void> _loadActivationStatus() async {
    final status = await ActivationService.instance.getActivationStatus();
    setState(() {
      _activationStatus = status;
    });
  }

  Future<void> _checkInitialBackup() async {
    await BackupService.instance.checkAndRestoreIfNeeded();
    await SchoolDbService.instance.refreshAll();
  }

  Widget _buildTrialBanner() {
    if (_activationStatus == null ||
        _activationStatus!['isActivated'] == true) {
      return const SizedBox.shrink();
    }

    final int remainingDays = _activationStatus!['remainingDays'];
    final bool isExpired = _activationStatus!['isTrialExpired'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: isExpired ? Colors.red.shade100 : Colors.orange.shade100,
      child: Row(
        children: [
          Icon(
            isExpired ? Icons.error_outline : Icons.timer_outlined,
            color: isExpired ? Colors.red : Colors.orange.shade800,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isExpired
                  ? 'Your trial has expired. Please activate the app to continue.'
                  : 'Trial remaining: $remainingDays days left.',
              style: TextStyle(
                color: isExpired ? Colors.red.shade900 : Colors.orange.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ).then((_) => _loadActivationStatus()),
            child: Text(
              isExpired ? 'ACTIVATE' : 'VIEW',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_activationStatus != null &&
        _activationStatus!['isActivated'] == false &&
        _activationStatus!['isTrialExpired'] == true) {
      return Scaffold(
        appBar: AppBar(title: const Text('App Expired')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_clock_outlined,
                  size: 100,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Trial Period Ended',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your 15-day trial has ended. To continue using the app, please activate it with an activation key.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  ).then((_) => _loadActivationStatus()),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                  ),
                  child: const Text('ACTIVATE NOW'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: const Text('LOGOUT'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schools'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ).then((_) => _loadActivationStatus()),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTrialBanner(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SchoolDbService.instance.watchSchools(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.school_outlined,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No schools added yet.',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _showAddSchoolDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Your First School'),
                        ),
                      ],
                    ),
                  );
                }

                final schools = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: schools.length,
                  itemBuilder: (context, index) {
                    final data = schools[index];
                    final logoPath = data['logoPath'] as String?;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.primaryColor,
                          backgroundImage: imageFromPath(logoPath),
                          child: logoPath == null || logoPath.isEmpty
                              ? const Icon(
                                  Icons.school,
                                  color: Colors.white,
                                  size: 30,
                                )
                              : null,
                        ),
                        title: Text(
                          data['name'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          data['address'] ?? 'No address provided',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () =>
                                  _showEditSchoolDialog(context, data),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                              onPressed: () =>
                                  _deleteSchool(context, data['id'] as String),
                            ),
                            const Icon(Icons.arrow_forward_ios),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ClassListScreen(
                              schoolId: data['id'] as String,
                              schoolName: data['name'],
                            ),
                          ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSchoolDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddSchoolDialog(BuildContext context) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final boardController = TextEditingController();
    File? logoFile;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New School'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 50,
                      maxWidth: 800,
                      maxHeight: 800,
                    );
                    if (picked != null) {
                      setDialogState(() => logoFile = File(picked.path));
                    }
                  },
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: logoFile != null
                        ? FileImage(logoFile!)
                        : null,
                    child: logoFile == null
                        ? const Icon(
                            Icons.add_a_photo,
                            size: 30,
                            color: Colors.grey,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'School Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: boardController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Board/Authority Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      if (nameController.text.isEmpty) return;
                      setDialogState(() => isUploading = true);

                      String? logoPath;

                      if (logoFile != null) {
                        logoPath = await ImageStorageService.instance.saveImage(
                          logoFile!,
                          'school_logos',
                        );
                      }

                      await SchoolDbService.instance.addSchool(
                        name: nameController.text,
                        address: addressController.text,
                        boardName: boardController.text,
                        logoPath: logoPath,
                      );

                      if (context.mounted) Navigator.pop(context);
                    },
              child: isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add School'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSchoolDialog(BuildContext context, Map<String, dynamic> data) {
    final id = data['id'] as String;
    final nameController = TextEditingController(text: data['name'] ?? '');
    final addressController = TextEditingController(
      text: data['address'] ?? '',
    );
    final boardController = TextEditingController(
      text: data['boardName'] ?? '',
    );
    File? logoFile;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit School'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 50,
                      maxWidth: 800,
                      maxHeight: 800,
                    );
                    if (picked != null) {
                      setDialogState(() => logoFile = File(picked.path));
                    }
                  },
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: logoFile != null
                        ? FileImage(logoFile!)
                        : imageFromPath(data['logoPath'] as String?),
                    child:
                        logoFile == null &&
                            (data['logoPath'] == null ||
                                (data['logoPath'] as String).isEmpty)
                        ? const Icon(
                            Icons.add_a_photo,
                            size: 30,
                            color: Colors.grey,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'School Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: boardController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Board/Authority Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      if (nameController.text.isEmpty) {
                        return;
                      }
                      setDialogState(() => isUploading = true);
                      String? logoPath = data['logoPath'] as String?;
                      if (logoFile != null) {
                        logoPath = await ImageStorageService.instance.saveImage(
                          logoFile!,
                          'school_logos',
                        );
                      }
                      await SchoolDbService.instance.updateSchool(
                        id,
                        name: nameController.text,
                        address: addressController.text,
                        boardName: boardController.text,
                        logoPath: logoPath,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
              child: isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteSchool(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete School?'),
        content: const Text(
          'This will remove the school and all its related data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await SchoolDbService.instance.deleteSchool(id);
              if (c.mounted) {
                Navigator.pop(c);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class ClassListScreen extends StatefulWidget {
  final String schoolId;
  final String schoolName;
  const ClassListScreen({
    super.key,
    required this.schoolId,
    required this.schoolName,
  });

  @override
  State<ClassListScreen> createState() => _ClassListScreenState();
}

class _ClassListScreenState extends State<ClassListScreen> {
  @override
  void initState() {
    super.initState();
    SchoolDbService.instance.refreshClasses(widget.schoolId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.schoolName} - Classes')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SchoolDbService.instance.watchClasses(widget.schoolId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.class_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No classes added for this school.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddClassDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Your First Class'),
                  ),
                ],
              ),
            );
          }

          final classes = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: classes.length,
            itemBuilder: (context, index) {
              final data = classes[index];
              final className = '${data['name']} ${data['division']}';
              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomeScreen(
                      schoolId: widget.schoolId,
                      schoolName: widget.schoolName,
                      className: className,
                    ),
                  ),
                ),
                child: Stack(
                  children: [
                    Card(
                      color: AppColors.primaryColor.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          className,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.blue,
                              size: 20,
                            ),
                            onPressed: () =>
                                _showEditClassDialog(context, data),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            onPressed: () =>
                                _deleteClass(context, data['id'] as String),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddClassDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddClassDialog(BuildContext context) {
    final nameController = TextEditingController();
    final divController = TextEditingController();
    final teacherController = TextEditingController();
    final subjectController = TextEditingController();
    List<String> subjects = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Class'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Class (e.g. 5)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: divController,
                  decoration: const InputDecoration(
                    labelText: 'Division (e.g. A)',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: teacherController,
                  decoration: const InputDecoration(
                    labelText: 'Class Teacher Name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Subjects',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: subjects
                      .map(
                        (s) => Chip(
                          label: Text(s, style: const TextStyle(fontSize: 12)),
                          onDeleted: () {
                            setDialogState(() => subjects.remove(s));
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Add Subject',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle,
                        color: AppColors.primaryColor,
                      ),
                      onPressed: () {
                        if (subjectController.text.isNotEmpty) {
                          setDialogState(() {
                            subjects.add(subjectController.text);
                            subjectController.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || divController.text.isEmpty) {
                  return;
                }

                await SchoolDbService.instance.addClass(
                  schoolId: widget.schoolId,
                  name: nameController.text,
                  division: divController.text.toUpperCase(),
                  teacherName: teacherController.text,
                  subjects: subjects,
                );

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Add Class'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditClassDialog(BuildContext context, Map<String, dynamic> data) {
    final id = data['id'] as String;
    final nameController = TextEditingController(text: data['name'] ?? '');
    final divController = TextEditingController(text: data['division'] ?? '');
    final teacherController = TextEditingController(
      text: data['teacherName'] ?? '',
    );
    final subjectController = TextEditingController();
    List<String> subjects = List<String>.from(
      data['subjects'] as List<dynamic>? ?? [],
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Class'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Class (e.g. 5)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: divController,
                  decoration: const InputDecoration(
                    labelText: 'Division (e.g. A)',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: teacherController,
                  decoration: const InputDecoration(
                    labelText: 'Class Teacher Name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Subjects',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: subjects
                      .map(
                        (s) => Chip(
                          label: Text(s, style: const TextStyle(fontSize: 12)),
                          onDeleted: () =>
                              setDialogState(() => subjects.remove(s)),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Add Subject',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle,
                        color: AppColors.primaryColor,
                      ),
                      onPressed: () {
                        if (subjectController.text.isNotEmpty) {
                          setDialogState(() {
                            subjects.add(subjectController.text);
                            subjectController.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || divController.text.isEmpty) {
                  return;
                }
                await SchoolDbService.instance.updateClass(
                  id,
                  name: nameController.text,
                  division: divController.text.toUpperCase(),
                  teacherName: teacherController.text,
                  subjects: subjects,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteClass(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Class?'),
        content: const Text(
          'This will remove the class and all its students and records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await SchoolDbService.instance.deleteClass(id);
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
