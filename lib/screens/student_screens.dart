import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../utils/constants.dart';
import '../utils/image_helper.dart';
import '../services/school_db_service.dart';
import '../services/image_storage_service.dart';

class StudentListScreen extends StatefulWidget {
  final String schoolId;
  final String className;
  const StudentListScreen({
    super.key,
    required this.schoolId,
    required this.className,
  });

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  @override
  void initState() {
    super.initState();
    SchoolDbService.instance.refreshStudents(
      schoolId: widget.schoolId,
      className: widget.className,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Students - ${widget.className}')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SchoolDbService.instance.watchStudents(
          schoolId: widget.schoolId,
          className: widget.className,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No students found in this class.'),
            );
          }

          final docs = snapshot.data!;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index];
              final id = data['id'] as String;
              final phone = data['phone'] ?? '';
              final photoPath = data['photoPath'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
                child: ListTile(
                  onTap: () => _viewStudentDetails(context, data, id),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: data['gender'] == 'Girl'
                        ? AppColors.girlColorLight
                        : AppColors.primaryColor,
                    backgroundImage: imageFromPath(
                      photoPath.isNotEmpty ? photoPath : null,
                    ),
                    child: photoPath.isEmpty
                        ? Text(
                            data['name'].isNotEmpty
                                ? data['name'][0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    data['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: data['gender'] == 'Girl'
                          ? AppColors.girlColor
                          : Colors.black87,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Roll No: ${data['rollNo']}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      if (data['dob'] != null &&
                          data['dob'].toString().isNotEmpty)
                        Text(
                          'DOB: ${data['dob']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (phone.isNotEmpty) ...[
                        _contactButton(
                          icon: Icons.call,
                          color: Colors.green,
                          onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                        ),
                        const SizedBox(width: 4),
                        _contactButton(
                          icon: Icons.message,
                          color: Colors.blue,
                          onPressed: () =>
                              launchUrl(Uri.parse('https://wa.me/91$phone')),
                        ),
                      ],
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.blue,
                          size: 20,
                        ),
                        onPressed: () => _editStudentDialog(context, data, id),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () => _deleteStudent(context, id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addStudentDialog(context),
        backgroundColor: const Color(0xFF004D40),
        label: const Text('Add Student', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _viewStudentDetails(
    BuildContext context,
    Map<String, dynamic> data,
    String docId,
  ) {
    final photoPath = data['photoPath']?.toString() ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: data['gender'] == 'Girl'
                      ? AppColors.girlColorLight
                      : AppColors.primaryColor,
                  backgroundImage: imageFromPath(
                    photoPath.isNotEmpty ? photoPath : null,
                  ),
                  child: photoPath.isEmpty
                      ? Text(
                          data['name'][0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 40,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  data['name'],
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: data['gender'] == 'Girl'
                        ? AppColors.girlColor
                        : AppColors.primaryColor,
                  ),
                ),
              ),
              const Divider(height: 40),
              _detailRow(Icons.class_, 'Class', data['className']),
              _detailRow(
                Icons.person_outline,
                'Father\'s Name',
                data['fatherName'] ?? 'Not set',
              ),
              _detailRow(Icons.numbers, 'Roll Number', data['rollNo']),
              _detailRow(
                Icons.assignment_ind,
                'Admission Number',
                data['admNo'] ?? 'Not set',
              ),
              _detailRow(
                Icons.calendar_today,
                'Date of Birth',
                data['dob'] ?? 'Not set',
              ),
              _detailRow(
                Icons.credit_card,
                'Aadhaar Number',
                data['aadhaar'] ?? 'Not set',
              ),
              _detailRow(
                Icons.phone,
                'Phone Number',
                data['phone'] ?? 'Not set',
              ),
              _detailRow(
                Icons.location_on,
                'Address',
                data['address'] ?? 'Not set',
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  void _deleteStudent(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Student?'),
        content: const Text('This will remove the student from all records.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await SchoolDbService.instance.deleteStudent(
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

  void _addStudentDialog(BuildContext context) {
    final nameController = TextEditingController();
    final fatherNameController = TextEditingController();
    final rollNoController = TextEditingController();
    final admNoController = TextEditingController();
    final phoneController = TextEditingController();
    final dobController = TextEditingController();
    final aadhaarController = TextEditingController();
    final addressController = TextEditingController();
    String selectedGender = 'Boy';
    File? imageFile;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add Student to ${widget.className}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 50,
                      maxWidth: 800,
                      maxHeight: 800,
                    );
                    if (pickedFile != null) {
                      setDialogState(() => imageFile = File(pickedFile.path));
                    }
                  },
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: imageFile != null
                        ? FileImage(imageFile!)
                        : null,
                    child: imageFile == null
                        ? const Icon(Icons.add_a_photo, size: 30)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Student Name'),
                ),
                TextField(
                  controller: fatherNameController,
                  decoration: const InputDecoration(
                    labelText: 'Father\'s Name',
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: rollNoController,
                        decoration: const InputDecoration(labelText: 'Roll No'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: admNoController,
                        decoration: const InputDecoration(labelText: 'Adm No'),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: dobController,
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().subtract(
                        const Duration(days: 365 * 5),
                      ),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      dobController.text = DateFormat(
                        'dd-MM-yyyy',
                      ).format(date);
                    }
                  },
                ),
                TextField(
                  controller: aadhaarController,
                  decoration: const InputDecoration(
                    labelText: 'Aadhaar Number',
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Gender:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'Boy',
                        label: Text('Boy'),
                        icon: Icon(Icons.male),
                      ),
                      ButtonSegment(
                        value: 'Girl',
                        label: Text('Girl'),
                        icon: Icon(Icons.female),
                      ),
                    ],
                    selected: {selectedGender},
                    onSelectionChanged: (newSelection) {
                      setDialogState(() => selectedGender = newSelection.first);
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context),
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

                      try {
                        String? photoPath;
                        if (imageFile != null) {
                          photoPath = await ImageStorageService.instance
                              .saveImage(imageFile!, 'student_photos');
                        }

                        await SchoolDbService.instance.addStudent(
                          schoolId: widget.schoolId,
                          className: widget.className,
                          name: nameController.text,
                          fatherName: fatherNameController.text,
                          rollNo: rollNoController.text,
                          admNo: admNoController.text,
                          phone: phoneController.text,
                          dob: dobController.text,
                          aadhaar: aadhaarController.text,
                          address: addressController.text,
                          photoPath: photoPath,
                          gender: selectedGender,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        debugPrint('Error adding student: $e');
                        setDialogState(() => isUploading = false);
                      }
                    },
              child: isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _editStudentDialog(
    BuildContext context,
    Map<String, dynamic> data,
    String id,
  ) {
    final nameController = TextEditingController(text: data['name'] ?? '');
    final fatherNameController = TextEditingController(
      text: data['fatherName'] ?? '',
    );
    final rollNoController = TextEditingController(text: data['rollNo'] ?? '');
    final admNoController = TextEditingController(text: data['admNo'] ?? '');
    final phoneController = TextEditingController(text: data['phone'] ?? '');
    final dobController = TextEditingController(text: data['dob'] ?? '');
    final aadhaarController = TextEditingController(
      text: data['aadhaar'] ?? '',
    );
    final addressController = TextEditingController(
      text: data['address'] ?? '',
    );
    String selectedGender = data['gender'] ?? 'Boy';
    File? imageFile;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Student - ${data['name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 50,
                      maxWidth: 800,
                      maxHeight: 800,
                    );
                    if (pickedFile != null) {
                      setDialogState(() => imageFile = File(pickedFile.path));
                    }
                  },
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: imageFile != null
                        ? FileImage(imageFile!)
                        : imageFromPath(data['photoPath'] ?? ''),
                    child:
                        imageFile == null &&
                            (data['photoPath'] == null ||
                                (data['photoPath'] as String).isEmpty)
                        ? const Icon(Icons.add_a_photo, size: 30)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Student Name'),
                ),
                TextField(
                  controller: fatherNameController,
                  decoration: const InputDecoration(
                    labelText: 'Father\'s Name',
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: rollNoController,
                        decoration: const InputDecoration(labelText: 'Roll No'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: admNoController,
                        decoration: const InputDecoration(labelText: 'Adm No'),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: dobController,
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().subtract(
                        const Duration(days: 365 * 5),
                      ),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setDialogState(
                        () => dobController.text = DateFormat(
                          'dd-MM-yyyy',
                        ).format(date),
                      );
                    }
                  },
                ),
                TextField(
                  controller: aadhaarController,
                  decoration: const InputDecoration(
                    labelText: 'Aadhaar Number',
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Gender:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'Boy',
                        label: Text('Boy'),
                        icon: Icon(Icons.male),
                      ),
                      ButtonSegment(
                        value: 'Girl',
                        label: Text('Girl'),
                        icon: Icon(Icons.female),
                      ),
                    ],
                    selected: {selectedGender},
                    onSelectionChanged: (newSelection) => setDialogState(
                      () => selectedGender = newSelection.first,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context),
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
                      try {
                        String? photoPath = data['photoPath'] as String?;
                        if (imageFile != null) {
                          photoPath = await ImageStorageService.instance
                              .saveImage(imageFile!, 'student_photos');
                        }

                        await SchoolDbService.instance.updateStudent(
                          id,
                          name: nameController.text,
                          fatherName: fatherNameController.text,
                          rollNo: rollNoController.text,
                          admNo: admNoController.text,
                          phone: phoneController.text,
                          dob: dobController.text,
                          aadhaar: aadhaarController.text,
                          address: addressController.text,
                          photoPath: photoPath,
                          gender: selectedGender,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        debugPrint('Error updating student: $e');
                        setDialogState(() => isUploading = false);
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
}
