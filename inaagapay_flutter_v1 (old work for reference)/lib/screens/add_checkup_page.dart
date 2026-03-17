import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../services/auth_storage.dart';

class AddCheckupPage extends StatefulWidget {
  final int motherId;

  const AddCheckupPage({super.key, required this.motherId});

  @override
  State<AddCheckupPage> createState() => _AddCheckupPageState();
}

class _AddCheckupPageState extends State<AddCheckupPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  final TextEditingController _notesCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    if (_selectedDate == null) return;

    setState(() => _loading = true);

    final token = await AuthStorage.getToken();

    final res = await http.post(
      Uri.parse(
        'https://inaagapay.alwaysdata.net/api/midwife/add_checkup_schedule.php',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      body: {
        'mother_id': widget.motherId.toString(),
        'scheduled_date':
            DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'notes': _notesCtrl.text,
      },
    );

    final decoded = jsonDecode(res.body);

    setState(() => _loading = false);

    if (decoded['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(decoded['message'] ?? 'Failed'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Checkup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              ListTile(
                title: Text(
                  _selectedDate == null
                      ? 'Select Checkup Date'
                      : DateFormat('MMMM d, yyyy')
                          .format(_selectedDate!),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2035),
                    initialDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
              ),

              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: Colors.pink,
                ),
                child: _loading
                    ? const CircularProgressIndicator(
                        color: Colors.white)
                    : const Text('Save Checkup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
