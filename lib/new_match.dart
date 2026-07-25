import 'package:flutter/material.dart';
import 'table_tennis/tt_setup.dart';

class NewMatch extends StatelessWidget {
  const NewMatch({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Sport'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSportCard(
            context,
            'Table Tennis',
            Icons.sports_tennis,
            Colors.blue,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TableTennisSetup()),
              );
            },
          ),
          _buildSportCard(
            context,
            'Tennis (Coming Soon)',
            Icons.sports_tennis_outlined,
            Colors.grey,
            null,
          ),
          _buildSportCard(
            context,
            'Badminton (Coming Soon)',
            Icons.sports,
            Colors.grey,
            null,
          ),
        ],
      ),
    );
  }

  Widget _buildSportCard(BuildContext context, String title, IconData icon, Color color, VoidCallback? onTap) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Icon(icon, size: 40, color: color),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
        enabled: onTap != null,
      ),
    );
  }
}
