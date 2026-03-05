// lib/screens/child_management_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/child.dart';
import '../services/session_service.dart';

class ChildManagementPage extends StatefulWidget {
  const ChildManagementPage({super.key});

  @override
  State<ChildManagementPage> createState() => _ChildManagementPageState();
}

class _ChildManagementPageState extends State<ChildManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedGender = 'Girl';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Child Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _showClearAllDialog,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            // Add Child Form
            _buildAddChildForm(),
            const Divider(height: 1),
            // Children List
            Expanded(
              child: _buildChildrenList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddChildForm() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_add, color: Colors.blue),
                  SizedBox(width: 10),
                  Text(
                    'Add New Child',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 20),
              
              // Child Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Child Name',
                  prefixIcon: const Icon(Icons.child_care),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter child name';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 15),
              
              // Birth Date Picker
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Birth Date',
                    prefixIcon: const Icon(Icons.cake),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('MMMM dd, yyyy').format(_selectedDate),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 15),
              
              // Gender Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButton<String>(
                  value: _selectedGender,
                  isExpanded: true,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down),
                  items: const [
                    DropdownMenuItem(value: 'Girl', child: Text('Girl')),
                    DropdownMenuItem(value: 'Boy', child: Text('Boy')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value!;
                    });
                  },
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Add Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _addChild,
                  icon: const Icon(Icons.save),
                  label: const Text(
                    'ADD CHILD',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChildrenList() {
    return Consumer<SessionService>(
      builder: (context, sessionService, child) {
        if (sessionService.children.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.child_care,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No children added yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add a child using the form above',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sessionService.children.length,
          itemBuilder: (context, index) {
            final child = sessionService.children[index];
            final ageInWeeks = child.getAgeInWeeks();
            final recordCount = sessionService.getChildRecords(child.id).length;

            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: CircleAvatar(
                  radius: 25,
                  backgroundColor: child.gender == 'Girl' ? Colors.pink : Colors.blue,
                  child: Text(
                    child.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  child.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'Born: ${DateFormat('MMM dd, yyyy').format(child.birthDate)}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    Text(
                      'Age: $ageInWeeks weeks • ${child.gender}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    Text(
                      'Records: $recordCount',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                trailing: PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'select') {
                      sessionService.selectChild(child);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${child.name} selected'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else if (value == 'delete') {
                      _showDeleteDialog(child);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'select',
                      child: ListTile(
                        leading: Icon(Icons.check_circle, color: Colors.blue),
                        title: Text('Select for Assessment'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addChild() async {
    if (_formKey.currentState!.validate()) {
      final sessionService = Provider.of<SessionService>(context, listen: false);
      
      final newChild = Child(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        birthDate: _selectedDate,
        gender: _selectedGender,
        dateAdded: DateTime.now(),
      );

      await sessionService.addChild(newChild);

      // Clear form
      _nameController.clear();
      _selectedDate = DateTime.now();
      _selectedGender = 'Girl';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Child added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showDeleteDialog(Child child) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Child'),
        content: Text('Are you sure you want to delete ${child.name}? All growth records will also be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await Provider.of<SessionService>(context, listen: false).deleteChild(child.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${child.name} deleted'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('Are you sure you want to delete ALL children and growth records? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await Provider.of<SessionService>(context, listen: false).clearAll();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All data cleared'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}