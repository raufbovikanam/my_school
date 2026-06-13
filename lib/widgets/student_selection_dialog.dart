import 'package:flutter/material.dart';

class StudentSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  const StudentSelectionDialog({super.key, required this.students});

  @override
  State<StudentSelectionDialog> createState() => _StudentSelectionDialogState();
}

class _StudentSelectionDialogState extends State<StudentSelectionDialog> {
  late List<bool> selected;
  bool allSelected = false;

  @override
  void initState() {
    super.initState();
    selected = List.generate(widget.students.length, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Students to Share'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: const Text('Select All', style: TextStyle(fontWeight: FontWeight.bold)),
              value: allSelected,
              onChanged: (val) {
                setState(() {
                  allSelected = val!;
                  selected = List.generate(widget.students.length, (_) => allSelected);
                });
              },
            ),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.students.length,
                itemBuilder: (context, i) {
                  return CheckboxListTile(
                    title: Text(widget.students[i]['name']),
                    value: selected[i],
                    onChanged: (val) {
                      setState(() {
                        selected[i] = val!;
                        allSelected = selected.every((e) => e);
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final phones = <String>[];
            for (int i = 0; i < selected.length; i++) {
              if (selected[i]) phones.add(widget.students[i]['phone'] ?? '');
            }
            Navigator.pop(context, phones);
          },
          child: const Text('Share'),
        ),
      ],
    );
  }
}
