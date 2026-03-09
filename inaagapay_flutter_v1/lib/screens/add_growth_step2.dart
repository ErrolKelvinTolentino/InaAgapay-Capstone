import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AddGrowthStep2 extends StatelessWidget {
  final int childId;
  final String height;
  final String weight;

  const AddGrowthStep2({
    super.key,
    required this.childId,
    required this.height,
    required this.weight,
  });

  Future<void> save(BuildContext context) async {
    final res = await http.post(
      Uri.parse(
        'https://inaagapay.alwaysdata.net/api/midwife/add_child_growth.php',
      ),
      body: {
        'child_id': childId.toString(),
        'height': height,
        'weight': weight,
      },
    );

    final json = jsonDecode(res.body);

    if (json['success'] == true) {
      Navigator.popUntil(context, (r) => r.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(json['message'] ?? 'Failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Growth Record')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(title: const Text('Height'), trailing: Text('$height cm')),
            ListTile(title: const Text('Weight'), trailing: Text('$weight kg')),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => save(context),
                child: const Text('Save Growth Record'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
