import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/settings_service.dart';
import '../../services/activation_service.dart';
import '../../services/backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _keyController = TextEditingController();
  final _settingsService = SettingsService();
  bool _isLoading = true;
  Map<String, dynamic>? _activationStatus;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadActivationStatus();
  }

  Future<void> _loadActivationStatus() async {
    final status = await ActivationService.instance.getActivationStatus();
    if (mounted) {
      setState(() {
        _activationStatus = status;
      });
    }
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.getStoreInfo();
    if (mounted) {
      setState(() {
        _nameController.text = settings['name'] ?? '';
        _phoneController.text = settings['phone'] ?? '';
        _addressController.text = settings['address'] ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      await _settingsService.updateStoreInfo(
        _nameController.text,
        _phoneController.text,
        _addressController.text,
      );
      
      try {
        await BackupService.instance.uploadBackup();
        if (mounted) _showSnackBar('Settings saved and Drive backup updated!');
      } catch (e) {
        if (mounted) _showSnackBar('Settings saved locally, but Drive backup failed: $e');
      }
      
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUpload() async {
    _showLoading();
    try {
      await BackupService.instance.uploadBackup();
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar('Drive backup updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _launchWhatsApp() async {
    final regId = _activationStatus?['registrationId'] ?? 'N/A';
    final message = "Hello, I want to activate My School app.\nRegistration ID: $regId";
    final url = "https://wa.me/918281308603?text=${Uri.encodeComponent(message)}";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('Could not launch WhatsApp');
    }
  }

  Future<void> _verifyKey() async {
    if (_keyController.text.isEmpty) return;
    final success = await ActivationService.instance.activate(_keyController.text);
    if (success) {
      if (mounted) {
        Navigator.pop(context);
        _loadActivationStatus();
        _showSnackBar('App activated successfully!');
      }
    } else {
      _showSnackBar('Invalid Activation Key');
    }
  }

  void _showActivationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("App Activation", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("1. Get your Activation Key:"),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton.icon(
                onPressed: _launchWhatsApp,
                icon: const Icon(Icons.message, color: Colors.white, size: 18),
                label: const Text("CONTACT WHATSAPP"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ),
            const SizedBox(height: 15),
            Text(
                "Registration ID: ${_activationStatus?['registrationId'] ?? 'N/A'}",
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(height: 30),
            const Text("2. Enter Activation Key:"),
            const SizedBox(height: 10),
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(
                hintText: "Enter Key",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: _verifyKey,
            child: const Text("ACTIVATE"),
          ),
        ],
      ),
    );
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("About My School", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Version: 1.0.0", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Text("About the App", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                SizedBox(height: 8),
                Text(
                  "My School is a school management app for inventory, "
                  "quick sales, expenses, reports, and Google Drive backup.",
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                Divider(height: 24),
                Text("Developer", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                SizedBox(height: 6),
                Text("Rauf Bovikanam", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                SizedBox(height: 16),
                Text("Company", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                SizedBox(height: 6),
                Text("Bytecode Company", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Divider(height: 24),
                Text("License", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                SizedBox(height: 8),
                Text(
                  "• 15-day free trial per device\n"
                  "• After trial, activation key is required\n"
                  "• Data is stored locally and on Google Drive",
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CLOSE")),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), backgroundColor: Colors.blueGrey),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('School Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      'School Name appears on Home screen. '
                      'School Name, Phone Number, and Address appear on WhatsApp.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.3),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                          labelText: 'School Name',
                          hintText: 'e.g. Best Bicycle School',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.store)),
                      validator: (value) => value == null || value.isEmpty ? 'Enter school name' : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone)),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on)),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 25),
                    ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size(double.infinity, 50)),
                      child: const Text('Save School Details', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(height: 30),
                    const Divider(),
                    const Text('Cloud Backup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Card(
                      elevation: 2,
                      child: ListTile(
                        leading: const Icon(Icons.cloud_upload, color: Colors.blue),
                        title: const Text('Update Drive Backup'),
                        onTap: _handleUpload,
                      ),
                    ),
                    const Divider(),
                    const Text('App Activation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ListTile(
                      leading: Icon(
                        _activationStatus?['isActivated'] == true ? Icons.verified : Icons.lock_open,
                        color: _activationStatus?['isActivated'] == true ? Colors.green : Colors.orange,
                      ),
                      title: Text(_activationStatus?['isActivated'] == true ? 'Activated' : 'Trial Version'),
                      subtitle: Text(_activationStatus?['isActivated'] == true
                          ? 'Full version active'
                          : 'Expires in ${_activationStatus?['remainingDays'] ?? 0} days'),
                      trailing: _activationStatus?['isActivated'] == true
                          ? null
                          : const Text('Register', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                      onTap: _activationStatus?['isActivated'] == true ? null : _showActivationDialog,
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: Colors.blueGrey),
                      title: const Text('About My School'),
                      onTap: () => _showAboutDialog(context),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _keyController.dispose();
    super.dispose();
  }
}