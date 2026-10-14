import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sportspro/auth_service.dart';
import 'package:sportspro/widgets/active_match_banner.dart';
import 'table_tennis/tt_setup.dart';
import 'badminton/badminton_setup.dart';

class NewMatch extends StatelessWidget {
  const NewMatch({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<QuerySnapshot>(
      stream: authService.myActiveMatches,
      builder: (context, snapshot) {
        final bool hasActiveMatch = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Select Sport'),
          ),
          body: Column(
            children: [
              if (hasActiveMatch)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: ActiveMatchBanner(matchDoc: snapshot.data!.docs.first),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildSportCard(
                      context,
                      'Table Tennis',
                      Icons.sports_tennis,
                      Colors.blue,
                      hasActiveMatch 
                        ? null 
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const TableTennisSetup()),
                            );
                          },
                    ),
                    _buildSportCard(
                      context,
                      'Badminton',
                      Icons.sports,
                      Colors.green,
                      hasActiveMatch 
                        ? null 
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const BadmintonSetup()),
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
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSportCard(BuildContext context, String title, IconData icon, Color color, VoidCallback? onTap) {
    final bool isDisabled = onTap == null;
    return Card(
      elevation: isDisabled ? 1 : 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Icon(icon, size: 40, color: isDisabled ? Colors.grey : color),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.bold,
            color: isDisabled ? Colors.grey : null,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: isDisabled ? Colors.grey : null),
        onTap: onTap,
        enabled: !isDisabled,
      ),
    );
  }
}
