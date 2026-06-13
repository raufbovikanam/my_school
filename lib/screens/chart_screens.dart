import 'dart:typed_data';
import 'dart:ui' as ui show TextDirection;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:screenshot/screenshot.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../utils/share_helper.dart';
import '../utils/constants.dart';
import '../services/school_db_service.dart';

class HistoryScreen extends StatefulWidget {
  final String schoolId;
  final String className;
  const HistoryScreen({super.key, required this.schoolId, required this.className});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    SchoolDbService.instance.refreshCharts(
      schoolId: widget.schoolId,
      className: widget.className,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Saved Records - ${widget.className}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: SchoolDbService.instance.watchCharts(
                      schoolId: widget.schoolId,
                      className: widget.className,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text('No records found for this class.'));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final data = snapshot.data![index];
                          final updatedAt = data['updatedAt'] as String?;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              title: Text(
                                data['subject']?.toUpperCase() ?? 'UNNAMED SUBJECT',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF004D40)),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('${data['madrasaName']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                                  Text('Reg: ${data['regNo']} | Date: ${updatedAt != null ? updatedAt.split('T').first : 'N/A'}'),
                                ],
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF004D40)),
                              onTap: () {
                                List<Map<String, String>> studentData = [];
                                List<List<bool>> progressData = [];

                                if (data.containsKey('studentsProgressData')) {
                                  final List list = data['studentsProgressData'] as List;
                                  for (var item in list) {
                                    final map = item as Map<String, dynamic>;
                                    studentData.add({
                                      'name': map['studentName'] ?? '',
                                      'gender': map['gender'] ?? 'Boy',
                                    });
                                    progressData.add(List<bool>.from(map['progressList'] ?? []));
                                  }
                                } else if (data.containsKey('studentNames') && data.containsKey('progress')) {
                                  final List names = data['studentNames'] as List;
                                  for (var name in names) {
                                    studentData.add({
                                      'name': name.toString(),
                                      'gender': 'Boy',
                                    });
                                  }
                                  progressData = (data['progress'] as List)
                                      .map((row) => List<bool>.from(row))
                                      .toList();
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => GridScreen(
                                      docId: data['id'] as String,
                                      schoolId: widget.schoolId,
                                      madrasaName: data['madrasaName'],
                                      address: data['address'] ?? '',
                                      pin: data['pin'] ?? '',
                                      phone: data['phone'] ?? '',
                                      regNo: data['regNo'],
                                      subject: data['subject'],
                                      className: data['className'] ?? widget.className,
                                      rowCount: data['rowCount'],
                                      colCount: data['colCount'],
                                      initialStudentData: studentData,
                                      initialProgress: progressData,
                                      initialMilestones: data['milestones'] != null ? List<String>.from(data['milestones']) : null,
                                      themeColor: Color(data['themeColor'] ?? 0xFF004D40),
                                      fontFamily: data['fontFamily'] ?? 'Roboto',
                                      pageColor: data['pageColor'] != null ? Color(data['pageColor']) : null,
                                      textColor: data['textColor'] != null ? Color(data['textColor']) : null,
                                      headerColors: data['headerColors'] != null 
                                        ? (data['headerColors'] as Map<String, dynamic>).map((k, v) => MapEntry(k, Color(v)))
                                        : null,
                                    ),
                                  ),
                                );
                              },
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

class InputScreen extends StatefulWidget {
  final String schoolId;
  final String className;
  const InputScreen({super.key, required this.schoolId, required this.className});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final _formKey = GlobalKey<FormState>();
  String _madrasaName = 'MANSOOR MADRASA';
  String _address = '';
  final String _pin = '';
  final String _phone = '';
  final _regNoController = TextEditingController();
  final _subjectController = TextEditingController();
  final _colsController = TextEditingController();
  Color _selectedColor = const Color(0xFF004D40);
  String _selectedFont = 'Roboto';

  final List<String> _fonts = ['Roboto', 'Lato', 'Open Sans', 'Montserrat', 'Poppins'];

  @override
  void initState() {
    super.initState();
    _fetchSchoolDetails();
  }

  void _fetchSchoolDetails() async {
    try {
      final data = await SchoolDbService.instance.getSchool(widget.schoolId);
      if (data != null) {
        setState(() {
          _madrasaName = data['name'] ?? 'MANSOOR MADRASA';
          _address = data['address'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error fetching school details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Chart Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Step 1: Progress Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
              const SizedBox(height: 16),
              _buildTextField(_subjectController, 'Surah Name (e.g. Al-Baqarah)', icon: Icons.book),
              const SizedBox(height: 16),
              _buildTextField(_regNoController, 'Register Number/Year', icon: Icons.numbers),
              const SizedBox(height: 16),
              _buildTextField(_colsController, 'Number of Ayats (Columns)', isNumber: true, icon: Icons.view_column),
              const SizedBox(height: 24),
              const Text('Step 2: Customization', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Theme Color', style: TextStyle(fontSize: 16)),
                trailing: CircleAvatar(backgroundColor: _selectedColor),
                onTap: () => _pickColor(),
                shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedFont,
                decoration: InputDecoration(
                  labelText: 'Select Font',
                  labelStyle: const TextStyle(fontSize: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: _fonts.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 16)))).toList(),
                onChanged: (v) => setState(() => _selectedFont = v!),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final navigator = Navigator.of(context);
                    final scaffoldMessenger = ScaffoldMessenger.of(context);

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      final students = await SchoolDbService.instance.getStudents(
                        schoolId: widget.schoolId,
                        className: widget.className,
                      );

                      if (!mounted) return;

                      navigator.pop();

                      List<Map<String, String>> studentData = students
                          .map((data) => {
                                'name': (data['name'] ?? '').toString(),
                                'gender': (data['gender'] ?? 'Boy').toString(),
                              })
                          .toList();
                      
                      // Sort: Boys first, then Girls. Within each group, sort by name.
                      studentData.sort((a, b) {
                        if (a['gender'] == b['gender']) {
                          return a['name']!.compareTo(b['name']!);
                        }
                        return a['gender'] == 'Boy' ? -1 : 1;
                      });

                      if (studentData.isEmpty) {
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(content: Text('No students found in this class! Please add students first in Student Management.'))
                        );
                        return;
                      }

                      navigator.push(
                        MaterialPageRoute(
                          builder: (context) => GridScreen(
                            schoolId: widget.schoolId,
                            madrasaName: _madrasaName,
                            address: _address,
                            pin: _pin,
                            phone: _phone,
                            regNo: _regNoController.text,
                            subject: _subjectController.text,
                            className: widget.className,
                            rowCount: studentData.length,
                            colCount: int.parse(_colsController.text),
                            themeColor: _selectedColor,
                            fontFamily: _selectedFont,
                            initialStudentData: studentData,
                            initialMilestones: null,
                          ),
                        ),
                      );
                    } catch (e) {
                      if (mounted) {
                        navigator.pop();
                        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004D40),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Create Progress Chart', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _selectedColor,
            onColorChanged: (color) => setState(() => _selectedColor = color),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false, IconData? icon, String? hint, int? maxLines = 1}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : ((maxLines == null || maxLines > 1) ? TextInputType.multiline : TextInputType.text),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        prefixIcon: icon != null ? Icon(icon) : null,
      ),
      validator: (v) {
        if (label == 'Address' || label == 'PIN Code' || label == 'Phone Number') return null;
        return v!.isEmpty ? 'Enter $label' : null;
      },
    );
  }
}

class GridScreen extends StatefulWidget {
  final String? docId;
  final String schoolId; // Added schoolId
  final String madrasaName;
  final String address;
  final String pin;
  final String phone;
  final String regNo;
  final String subject;
  final String className; // Added className
  final int rowCount;
  final int colCount;
  final List<Map<String, String>>? initialStudentData;
  final List<List<bool>>? initialProgress;
  final List<String>? initialMilestones;
  final Color themeColor;
  final String fontFamily;
  final Color? pageColor;
  final Color? textColor;
  final Map<String, Color>? headerColors;

  const GridScreen({
    super.key,
    this.docId,
    required this.schoolId, // Added schoolId
    required this.madrasaName,
    this.address = '',
    this.pin = '',
    this.phone = '',
    required this.regNo,
    required this.subject,
    required this.className, // Added className
    required this.rowCount,
    required this.colCount,
    this.initialStudentData,
    this.initialProgress,
    this.initialMilestones,
    required this.themeColor,
    required this.fontFamily,
    this.pageColor,
    this.textColor,
    this.headerColors,
  });

  @override
  State<GridScreen> createState() => _GridScreenState();
}

class _GridScreenState extends State<GridScreen> {
  late List<TextEditingController> studentControllers;
  late List<String> studentGenders;
  late List<TextEditingController> milestoneControllers;
  late List<List<bool>> progress;
  final ScreenshotController screenshotController = ScreenshotController();
  bool _isSaving = false;
  late Color _currentPageColor;
  late Color _currentTextColor;
  late Map<String, Color> _currentHeaderColors;

  @override
  void initState() {
    super.initState();
    _currentPageColor = widget.pageColor ?? Colors.white;
    _currentTextColor = widget.textColor ?? Colors.black87;
    
    _currentHeaderColors = widget.headerColors ?? {
      'name': widget.themeColor,
      'address': Colors.grey.shade700,
      'pin': Colors.grey.shade600,
      'phone': Colors.grey.shade600,
      'regNo': Colors.black87,
      'subject': Colors.black87,
    };

    studentControllers = List.generate(
      widget.rowCount,
      (index) => TextEditingController(
        text: widget.initialStudentData != null ? widget.initialStudentData![index]['name'] : '',
      ),
    );
    studentGenders = List.generate(
      widget.rowCount,
      (index) => widget.initialStudentData != null ? widget.initialStudentData![index]['gender'] ?? 'Boy' : 'Boy',
    );
    milestoneControllers = List.generate(
      widget.colCount,
      (index) => TextEditingController(
        text: widget.initialMilestones != null ? widget.initialMilestones![index] : '',
      ),
    );
    progress = widget.initialProgress ?? List.generate(
      widget.rowCount,
      (_) => List.generate(widget.colCount, (_) => false),
    );
  }

  void _onMilestoneChanged(int index, String value) {}

  Future<void> _saveToLocal() async {
    setState(() => _isSaving = true);
    try {
      List<Map<String, dynamic>> studentsProgressData = [];
      for (int i = 0; i < widget.rowCount; i++) {
        studentsProgressData.add({
          'studentName': studentControllers[i].text,
          'gender': studentGenders[i],
          'progressList': progress[i],
        });
      }

      final data = {
        'userId': SchoolDbService.instance.userId,
        'schoolId': widget.schoolId,
        'madrasaName': widget.madrasaName,
        'address': widget.address,
        'pin': widget.pin,
        'phone': widget.phone,
        'regNo': widget.regNo,
        'subject': widget.subject,
        'className': widget.className,
        'rowCount': widget.rowCount,
        'colCount': widget.colCount,
        'milestones': milestoneControllers.map((c) => c.text).toList(),
        'studentsProgressData': studentsProgressData,
        'themeColor': widget.themeColor.toARGB32(),
        'fontFamily': widget.fontFamily,
        'pageColor': _currentPageColor.toARGB32(),
        'textColor': _currentTextColor.toARGB32(),
        'headerColors': _currentHeaderColors.map((k, v) => MapEntry(k, v.toARGB32())),
      };

      await SchoolDbService.instance.saveChart(data, docId: widget.docId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved locally & Drive backup updated!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildFullChartWidget() {
    return Container(
      color: _currentPageColor,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildProfessionalHeader(isForScreenshot: true, forExport: true),
          const SizedBox(height: 24),
          _buildProfessionalTable(isForScreenshot: true, forExport: true),
          _buildFooter(forExport: true),
        ],
      ),
    );
  }

  Map<int, pw.TableColumnWidth> _pdfTableColumnWidths(double ayatCellWidth) {
    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(28),
      1: const pw.FlexColumnWidth(2.2),
    };
    for (var i = 0; i < widget.colCount; i++) {
      widths[i + 2] = pw.FixedColumnWidth(ayatCellWidth);
    }
    return widths;
  }

  /// Total export width matching [Table] columnWidths (padding + cols).
  double get _exportChartWidth => 48.0 + 50.0 + 220.0 + widget.colCount * 70.0;

  Future<Uint8List> _encodeJpeg(Uint8List pngBytes, {int quality = 92}) async {
    final decoded = img.decodeImage(pngBytes);
    if (decoded == null) {
      throw Exception('Failed to decode chart image');
    }
    return Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
  }

  /// Renders the **entire** chart (all rows) off-screen and returns JPEG bytes.
  ///
  /// Uses [ScreenshotController.captureFromLongWidget] so height is measured from
  /// content — [captureFromWidget] clips to phone screen height.
  Future<Uint8List> _captureChartImage() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return Uint8List(0);

    final exportWidth = _exportChartWidth;
    final estimatedHeight = 200.0 + widget.rowCount * 76.0;
    final pixelRatio = exportWidth * estimatedHeight > 4_000_000 ? 2.0 : 2.5;

    final chartWidget = Material(
      color: _currentPageColor,
      child: SizedBox(
        width: exportWidth,
        child: _buildFullChartWidget(),
      ),
    );

    final pngBytes = await screenshotController.captureFromLongWidget(
      chartWidget,
      context: context,
      constraints: BoxConstraints(
        minWidth: exportWidth,
        maxWidth: exportWidth,
        maxHeight: double.infinity,
      ),
      delay: Duration(milliseconds: 900 + widget.rowCount * 50),
      pixelRatio: pixelRatio,
    );

    if (pngBytes.isEmpty) {
      throw Exception('Failed to generate chart image');
    }

    return _encodeJpeg(pngBytes);
  }

  Future<Uint8List> _buildChartPdfBytes() async {
    final pdf = pw.Document();
    final font = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();
    final pdfThemeColor = PdfColor.fromInt(widget.themeColor.toARGB32());
    final pdfTextColor = PdfColor.fromInt(_currentTextColor.toARGB32());
    final headerFill = pdfThemeColor.luminance > 0.5
        ? pdfThemeColor.shade(0.1)
        : pdfThemeColor.shade(0.9);

    final ayatCellWidth = widget.colCount > 20
        ? 24.0
        : widget.colCount > 12
            ? 30.0
            : 38.0;
    final ayatFontSize = widget.colCount > 20
        ? 7.0
        : widget.colCount > 12
            ? 8.0
            : 10.0;

    final pageWidth = (100 + 140 + widget.colCount * ayatCellWidth).clamp(595.0, 2800.0);
    final pageHeight = (180 + widget.rowCount * 20.0 + 80).clamp(420.0, 3500.0);
    final pageFormat = PdfPageFormat(pageWidth, pageHeight, marginAll: 18);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(18),
        build: (pw.Context context) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              width: double.infinity,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: pdfThemeColor, width: 2),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    widget.madrasaName.toUpperCase(),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 20,
                      color: PdfColor.fromInt(
                        _currentHeaderColors['name']?.toARGB32() ?? widget.themeColor.toARGB32(),
                      ),
                    ),
                  ),
                  if (widget.address.isNotEmpty)
                    pw.Text(
                      widget.address,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 10,
                        color: PdfColor.fromInt(
                          _currentHeaderColors['address']?.toARGB32() ?? _currentTextColor.toARGB32(),
                        ),
                      ),
                    ),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      if (widget.pin.isNotEmpty)
                        pw.Text(
                          'PIN: ${widget.pin} ',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            color: PdfColor.fromInt(
                              _currentHeaderColors['pin']?.toARGB32() ?? _currentTextColor.toARGB32(),
                            ),
                          ),
                        ),
                      if (widget.pin.isNotEmpty && widget.phone.isNotEmpty)
                        pw.Text(' | ', style: pw.TextStyle(color: PdfColors.grey)),
                      if (widget.phone.isNotEmpty)
                        pw.Text(
                          'PH: ${widget.phone}',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            color: PdfColor.fromInt(
                              _currentHeaderColors['phone']?.toARGB32() ?? _currentTextColor.toARGB32(),
                            ),
                          ),
                        ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Column(
                        children: [
                          pw.Text('REG NO', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey)),
                          pw.Text(
                            widget.regNo,
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 12,
                              color: PdfColor.fromInt(
                                _currentHeaderColors['regNo']?.toARGB32() ?? _currentTextColor.toARGB32(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text('SUBJECT', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey)),
                          pw.Text(
                            widget.subject,
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 12,
                              color: PdfColor.fromInt(
                                _currentHeaderColors['subject']?.toARGB32() ?? _currentTextColor.toARGB32(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: _pdfTableColumnWidths(ayatCellWidth),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: headerFill),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('No.', style: pw.TextStyle(font: boldFont, fontSize: 9, color: pdfThemeColor)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Student', style: pw.TextStyle(font: boldFont, fontSize: 9, color: pdfThemeColor)),
                    ),
                    ...List.generate(
                      widget.colCount,
                      (i) => pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Column(
                          children: [
                            pw.Text('Ayat', style: pw.TextStyle(font: font, fontSize: 6, color: pdfThemeColor)),
                            pw.Text(
                              milestoneControllers[i].text.isEmpty ? '${i + 1}' : milestoneControllers[i].text,
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(font: boldFont, fontSize: ayatFontSize, color: pdfThemeColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Table Data Rows - Including ALL students
                ...List.generate(
                  widget.rowCount,
                  (r) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          '${r + 1}',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(font: font, fontSize: 9, color: pdfTextColor),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          studentControllers[r].text,
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            color: studentGenders[r] == 'Girl' ? PdfColors.pink : pdfTextColor,
                          ),
                        ),
                      ),
                      ...List.generate(
                        widget.colCount,
                        (c) => pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Center(
                            child: pw.Container(
                              height: 12,
                              width: 12,
                              decoration: pw.BoxDecoration(
                                color: progress[r][c] ? pdfThemeColor : null,
                                border: pw.Border.all(color: pdfThemeColor, width: 0.5),
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                              ),
                              child: progress[r][c]
                                  ? pw.Center(
                                      // Helvetica only supports Latin-1; use 'X' not '✓'
                                      child: pw.Text(
                                        'X',
                                        style: pw.TextStyle(
                                          color: PdfColors.white,
                                          fontSize: 8,
                                          font: boldFont,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Report Generated on: ${DateTime.now().toString().split(' ')[0]}',
                  style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey),
                ),
                pw.Text(
                  'mansoor usthad',
                  style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  void _dismissShareLoadingDialog() {
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _shareChart(bool asPdf) async {
    if (!mounted) return;

    FocusManager.instance.primaryFocus?.unfocus();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      final baseName = widget.subject.trim().isNotEmpty
          ? widget.subject.trim()
          : widget.madrasaName.trim();
      
      late final List<int> bytes;
      late final String fileName;
      late final String mimeType;

      if (asPdf) {
        bytes = await _buildChartPdfBytes();
        fileName = safeShareFileName(baseName, extension: 'pdf');
        mimeType = 'application/pdf';
      } else {
        final imageBytes = await _captureChartImage();
        if (imageBytes.isEmpty) {
          throw Exception('Could not generate chart image');
        }
        bytes = imageBytes;
        fileName = safeShareFileName(baseName, extension: 'jpg');
        mimeType = 'image/jpeg';
      }

      _dismissShareLoadingDialog();

      // Let keyboard / Vivo insets settle before the system share sheet opens.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      await shareBytes(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        context: context,
      );
    } catch (e) {
      _dismissShareLoadingDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share failed: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showShareOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Share Chart',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.image, color: Color(0xFF25D366)),
              title: const Text('WhatsApp / JPEG (Recommended)'),
              subtitle: const Text('Full chart as a single image — All students'),
              onTap: () {
                Navigator.pop(ctx);
                _shareChart(false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Color(0xFF004D40)),
              title: const Text('PDF File'),
              subtitle: const Text('Send as Print / Document'),
              onTap: () {
                Navigator.pop(ctx);
                _shareChart(true);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _pickPageColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick Page Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _currentPageColor,
            onColorChanged: (color) => setState(() => _currentPageColor = color),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      ),
    );
  }

  void _pickTextColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick Global Text Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _currentTextColor,
            onColorChanged: (color) => setState(() => _currentTextColor = color),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      ),
    );
  }

  void _pickHeaderColor(String part, String label) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pick Color for $label'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _currentHeaderColors[part]!,
            onColorChanged: (color) => setState(() => _currentHeaderColors[part] = color),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Chart'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.palette),
            tooltip: 'Customize Colors',
            onSelected: (value) {
              if (value == 'page') {
                _pickPageColor();
              } else if (value == 'text') {
                _pickTextColor();
              } else if (value == 'h_name') {
                _pickHeaderColor('name', 'Madrasa Name');
              } else if (value == 'h_address') {
                _pickHeaderColor('address', 'Address');
              } else if (value == 'h_pin') {
                _pickHeaderColor('pin', 'PIN Code');
              } else if (value == 'h_phone') {
                _pickHeaderColor('phone', 'Phone Number');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'page', child: Text('Page Color')),
              const PopupMenuItem(value: 'text', child: Text('Global Text Color')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'h_name', child: Text('Madrasa Name Color')),
              const PopupMenuItem(value: 'h_address', child: Text('Address Color')),
              const PopupMenuItem(value: 'h_pin', child: Text('PIN Color')),
              const PopupMenuItem(value: 'h_phone', child: Text('Phone Color')),
            ],
          ),
          IconButton(onPressed: _saveToLocal, icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save)),
          IconButton(
            onPressed: _showShareOptions,
            icon: const Icon(Icons.share),
            tooltip: 'Share chart',
          ),
        ],
      ),
      body: Screenshot(
        controller: screenshotController,
        child: Container(
          color: _currentPageColor,
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildProfessionalHeader(),
                const SizedBox(height: 24),
                _buildProfessionalTable(),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalHeader({bool isForScreenshot = false, bool forExport = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: isForScreenshot ? null : double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: widget.themeColor, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            widget.madrasaName.toUpperCase(),
            textAlign: TextAlign.center,
            style: _getCustomFont(
              size: 32,
              weight: FontWeight.bold,
              color: _currentHeaderColors['name'],
              forExport: forExport,
              shadows: [
                Shadow(offset: const Offset(2, 2), blurRadius: 4, color: Colors.grey.withValues(alpha: 0.5)),
                Shadow(offset: const Offset(-1, -1), blurRadius: 2, color: Colors.white.withValues(alpha: 0.8)),
                Shadow(offset: const Offset(4, 4), blurRadius: 10, color: Colors.black.withValues(alpha: 0.2)),
              ],
            ),
          ),
          if (widget.address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.address,
              textAlign: TextAlign.center,
              style: _getCustomFont(size: 14, color: _currentHeaderColors['address'], forExport: forExport),
            ),
          ],
          if (widget.pin.isNotEmpty || widget.phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.pin.isNotEmpty)
                  Text('PIN: ${widget.pin}', style: _getCustomFont(size: 12, color: _currentHeaderColors['pin'], forExport: forExport)),
                if (widget.pin.isNotEmpty && widget.phone.isNotEmpty)
                  const Text(' | ', style: TextStyle(color: Colors.grey)),
                if (widget.phone.isNotEmpty)
                  Text('PH: ${widget.phone}', style: _getCustomFont(size: 12, color: _currentHeaderColors['phone'], forExport: forExport)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Container(height: 2, width: 100, color: widget.themeColor),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _headerInfo('REG NO', widget.regNo, color: _currentHeaderColors['regNo'], forExport: forExport),
              _headerInfo('SUBJECT', widget.subject, color: _currentHeaderColors['subject'], forExport: forExport),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerInfo(String label, String value, {Color? color, bool forExport = false}) {
    return Column(
      children: [
        Text(label, style: _getCustomFont(size: 12, weight: FontWeight.w300, color: (color ?? _currentTextColor).withValues(alpha: 0.6), forExport: forExport)),
        Text(value, style: _getCustomFont(size: 16, weight: FontWeight.bold, color: color ?? _currentTextColor, forExport: forExport)),
      ],
    );
  }

  Widget _buildProfessionalTable({bool isForScreenshot = false, bool forExport = false}) {
    Widget table = Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(70),
        columnWidths: const {
          0: FixedColumnWidth(50),
          1: FixedColumnWidth(220),
        },
        border: TableBorder.all(color: _currentTextColor.withValues(alpha: 0.3), width: 1.5),
        children: [
          TableRow(
            decoration: BoxDecoration(color: widget.themeColor.withValues(alpha: 0.1)),
            children: [
              _tableHeader('No.', forExport: forExport),
              _tableHeader('Student Name', align: TextAlign.left, forExport: forExport),
              ...List.generate(widget.colCount, (i) => TableCell(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Ayat', style: _getCustomFont(size: 11, color: widget.themeColor, weight: FontWeight.bold, forExport: forExport)),
                      isForScreenshot 
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(milestoneControllers[i].text, style: _getCustomFont(size: 20, weight: FontWeight.bold, color: widget.themeColor, forExport: forExport)),
                          )
                        : TextField(
                            controller: milestoneControllers[i],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            onChanged: (v) => _onMilestoneChanged(i, v),
                            style: _getCustomFont(size: 20, weight: FontWeight.bold, color: widget.themeColor),
                            decoration: const InputDecoration(border: InputBorder.none, hintText: '#'),
                          ),
                    ],
                  ),
                ),
              )),
            ],
          ),
          ...List.generate(widget.rowCount, (r) => TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '${r + 1}',
                  textAlign: TextAlign.center,
                  style: _getCustomFont(size: 20, weight: FontWeight.bold, color: _currentTextColor, forExport: forExport),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: isForScreenshot
                  ? Text(
                      studentControllers[r].text, 
                      textAlign: TextAlign.left, 
                      style: _getCustomFont(
                        size: 20, 
                        weight: FontWeight.w500, 
                        color: studentGenders[r] == 'Girl' ? AppColors.girlColor : _currentTextColor,
                        forExport: forExport,
                      ),
                    )
                  : TextField(
                      controller: studentControllers[r],
                      textAlign: TextAlign.left,
                      style: _getCustomFont(
                        size: 20, 
                        weight: FontWeight.w500, 
                        color: studentGenders[r] == 'Girl' ? AppColors.girlColor : _currentTextColor,
                      ),
                      decoration: const InputDecoration(hintText: 'Name...', border: InputBorder.none),
                    ),
              ),
              ...List.generate(
                widget.colCount,
                (c) => isForScreenshot ? _tableCellExport(r, c) : _tableCell(r, c),
              ),
            ],
          )),
        ],
      ),
    );

    if (isForScreenshot) {
      return table;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      physics: const NeverScrollableScrollPhysics(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: table,
      ),
    );
  }

  Widget _tableHeader(String text, {TextAlign align = TextAlign.center, bool forExport = false}) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Text(text, textAlign: align, style: _getCustomFont(size: 20, weight: FontWeight.bold, color: widget.themeColor, forExport: forExport)),
    );
  }

  Widget _tableCell(int r, int c) {
    return InkWell(
      onTap: () => setState(() => progress[r][c] = !progress[r][c]),
      child: _tableCellContent(r, c),
    );
  }

  Widget _tableCellExport(int r, int c) => _tableCellContent(r, c);

  Widget _tableCellContent(int r, int c) {
    return Container(
      height: 54,
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: progress[r][c] ? widget.themeColor : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: widget.themeColor.withValues(alpha: 0.2)),
      ),
      child: progress[r][c] ? const Icon(Icons.check, color: Colors.white, size: 28) : null,
    );
  }

  Widget _buildFooter({bool forExport = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Report Generated on: ${DateTime.now().toString().split(' ')[0]}', style: _getCustomFont(size: 10, color: _currentTextColor.withValues(alpha: 0.5), forExport: forExport)),
          Text('mansoor usthad', style: _getCustomFont(size: 14, weight: FontWeight.bold, color: _currentTextColor.withValues(alpha: 0.7), forExport: forExport)),
        ],
      ),
    );
  }

  TextStyle _getCustomFont({
    required double size,
    FontWeight weight = FontWeight.normal,
    Color? color,
    List<Shadow>? shadows,
    bool forExport = false,
  }) {
    if (forExport) {
      return TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        shadows: shadows,
      );
    }
    return GoogleFonts.getFont(
      widget.fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      shadows: shadows,
    );
  }
}
