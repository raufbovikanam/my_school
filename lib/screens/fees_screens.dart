import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/constants.dart';
import '../services/school_db_service.dart';

class FeesManagerScreen extends StatefulWidget {
  final String schoolId;
  final String className;
  const FeesManagerScreen({super.key, required this.schoolId, required this.className});

  @override
  State<FeesManagerScreen> createState() => _FeesManagerScreenState();
}

class _FeesManagerScreenState extends State<FeesManagerScreen> {
  final _feeNameController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    SchoolDbService.instance.refreshFees(
      schoolId: widget.schoolId,
      className: widget.className,
    );
  }

  void _addFeeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Fee for ${widget.className}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _feeNameController, decoration: const InputDecoration(labelText: 'Fee Name (e.g. Exam Fee)')),
            TextField(controller: _amountController, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await SchoolDbService.instance.addFee(
                schoolId: widget.schoolId,
                className: widget.className,
                name: _feeNameController.text,
                amount: _amountController.text,
              );
              _feeNameController.clear();
              _amountController.clear();
              if (mounted) navigator.pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Fee Management - ${widget.className}')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SchoolDbService.instance.watchFees(
          schoolId: widget.schoolId,
          className: widget.className,
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.isEmpty) {
            return const Center(child: Text('No fees added yet for this class.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final fee = snapshot.data![index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(fee['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Amount: ₹${fee['amount']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.payment, color: Colors.green),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FeeStatusScreen(
                              feeId: fee['id'] as String,
                              feeName: fee['name'],
                              schoolId: widget.schoolId,
                              className: widget.className,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => SchoolDbService.instance.deleteFee(
                          fee['id'] as String,
                          schoolId: widget.schoolId,
                          className: widget.className,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFeeDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class FeeStatusScreen extends StatefulWidget {
  final String feeId;
  final String feeName;
  final String schoolId;
  final String className;
  const FeeStatusScreen({
    super.key,
    required this.feeId,
    required this.feeName,
    required this.schoolId,
    required this.className,
  });

  @override
  State<FeeStatusScreen> createState() => _FeeStatusScreenState();
}

class _FeeStatusScreenState extends State<FeeStatusScreen> {
  String _filterStatus = 'All';
  Map<String, dynamic> _paidStatus = {};

  @override
  void initState() {
    super.initState();
    _loadStatus();
    SchoolDbService.instance.refreshStudents(
      schoolId: widget.schoolId,
      className: widget.className,
    );
  }

  Future<void> _loadStatus() async {
    final status = await SchoolDbService.instance.getFeeStatus(widget.feeId);
    if (mounted) setState(() => _paidStatus = status);
  }

  Future<void> _shareFeeList(List<Map<String, dynamic>> students, bool isPaidReport) async {
    final filteredStudents = students.where((s) => (_paidStatus[s['id']] == true) == isPaidReport).toList();
    if (filteredStudents.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isPaidReport ? 'No paid students!' : 'No unpaid students!')),
        );
      }
      return;
    }

    final sb = StringBuffer();
    sb.writeln(isPaidReport ? '✅ *PAID LIST: ${widget.feeName}*' : '📋 *UNPAID LIST: ${widget.feeName}*');
    sb.writeln('Class: ${widget.className}');
    sb.writeln('-----------------------------------');
    for (var i = 0; i < filteredStudents.length; i++) {
      sb.writeln('${i + 1}. ${filteredStudents[i]['name']}');
    }
    sb.writeln('-----------------------------------');
    sb.writeln('Generated by My School App');

    await Share.share(sb.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.feeName)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'All', label: Text('All'), icon: Icon(Icons.people)),
                ButtonSegment(value: 'Paid', label: Text('Paid'), icon: Icon(Icons.check_circle, color: Colors.green)),
                ButtonSegment(value: 'Unpaid', label: Text('Unpaid'), icon: Icon(Icons.cancel, color: Colors.red)),
              ],
              selected: {_filterStatus},
              onSelectionChanged: (newSelection) {
                setState(() => _filterStatus = newSelection.first);
              },
            ),
          ),
          const SizedBox(height: 12),
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

                final displayStudents = students.where((s) {
                  if (_filterStatus == 'Paid') return _paidStatus[s['id']] == true;
                  if (_filterStatus == 'Unpaid') return _paidStatus[s['id']] != true;
                  return true;
                }).toList();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total: ${displayStudents.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.share, color: Colors.red),
                                onPressed: () => _shareFeeList(students, false),
                                tooltip: 'Share Unpaid',
                              ),
                              IconButton(
                                icon: const Icon(Icons.share, color: Colors.green),
                                onPressed: () => _shareFeeList(students, true),
                                tooltip: 'Share Paid',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: displayStudents.length,
                        itemBuilder: (context, index) {
                          final student = displayStudents[index];
                          final studentId = student['id'] as String;
                          final gender = student['gender'] ?? 'Boy';
                          final isPaid = _paidStatus[studentId] == true;

                          return CheckboxListTile(
                            title: Text(
                              student['name'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: gender == 'Girl' ? AppColors.girlColor : Colors.black87,
                              ),
                            ),
                            secondary: Icon(
                              isPaid ? Icons.check_circle : Icons.pending,
                              color: isPaid ? Colors.green : Colors.orange,
                            ),
                            value: isPaid,
                            onChanged: (val) async {
                              setState(() => _paidStatus[studentId] = val);
                              await SchoolDbService.instance.saveFeeStatus(widget.feeId, _paidStatus);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
