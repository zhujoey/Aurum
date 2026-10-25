import 'dart:async';
import 'package:flutter/material.dart';
import '../../auth_service.dart';
import '../../language_service.dart';

class InvitationWaitingDialog extends StatefulWidget {
  final List<Map<String, dynamic>> invitations;
  final AuthService authService;

  const InvitationWaitingDialog({
    super.key,
    required this.invitations,
    required this.authService,
  });

  @override
  State<InvitationWaitingDialog> createState() => _InvitationWaitingDialogState();
}

class _InvitationWaitingDialogState extends State<InvitationWaitingDialog> {
  final Map<String, String> _statuses = {};
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    for (var invite in widget.invitations) {
      String id = invite['id'];
      _statuses[id] = 'pending';
      _subscriptions.add(widget.authService.listenToRequest(id).listen((doc) {
        if (doc.exists) {
          String status = doc.get('status') ?? 'pending';
          if (mounted) {
            setState(() {
              _statuses[id] = status;
            });
            _checkAllAccepted();
          }
        }
      }));
    }
  }

  void _checkAllAccepted() {
    bool allAccepted = _statuses.values.every((s) => s == 'accepted');
    if (allAccepted) {
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool anyRejected = _statuses.values.any((s) => s == 'rejected');

    return AlertDialog(
      title: Text('Waiting for Players'.tr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(anyRejected 
            ? 'Invitation declined. Correct the username and try again.'.tr 
            : 'Match will start once everyone accepts.'.tr),
          const SizedBox(height: 20),
          ...widget.invitations.map((invite) {
            String name = invite['name'];
            String status = _statuses[invite['id']] ?? 'pending';
            Color color = status == 'accepted' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange);
            String statusText = status == 'accepted' ? 'Accepted'.tr : (status == 'rejected' ? 'Declined'.tr : 'Pending'.tr);
            return ListTile(
              leading: Icon(
                status == 'accepted' ? Icons.check_circle : (status == 'rejected' ? Icons.cancel : Icons.hourglass_empty), 
                color: color
              ),
              title: Text(name),
              trailing: Text(statusText.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false), 
          child: Text('Cancel'.tr)
        ),
      ],
    );
  }
}
