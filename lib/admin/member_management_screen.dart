import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../auth_service.dart';

class MemberManagementScreen extends StatefulWidget {
  const MemberManagementScreen({super.key});

  @override
  State<MemberManagementScreen> createState() =>
      _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  final _search = TextEditingController();
  String _roleFilter = 'all';
  String _statusFilter = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _createMember() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    String role = 'member';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Member name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email / Login ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'member',
                      child: Text('Member'),
                    ),
                    DropdownMenuItem(
                      value: 'administrator',
                      child: Text('Administrator'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => role = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    nameController.dispose();
    emailController.dispose();
    if (name.isEmpty || !email.contains('@')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and a valid email are required.')),
      );
      return;
    }
    try {
      final created = await AuthService.instance.createMember(
        name: name,
        email: email,
        role: role,
      );
      if (!mounted) return;
      final temporaryPassword = created['temporaryPassword'] as String;
      final message =
          'Welcome to Voter list CDM.\n\n'
          'Your account has been created.\n'
          'Login ID: $email\n'
          'Temporary Password: $temporaryPassword\n\n'
          'Please install the application using a secure APK download link '
          'provided by the administrator.\n'
          'On first login, change your temporary password.';
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Member Created'),
          content: const Text(
            'Share the login instructions securely with the new member.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () async {
                await SharePlus.instance.share(
                  ShareParams(text: message),
                );
              },
              child: const Text('Share'),
            ),
          ],
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      final message = error.code == 'not-found'
          ? 'Member creation requires deployed Cloud Functions, unavailable on the Spark plan.'
          : 'Could not create member: ${error.message ?? error.code}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create member: $error')),
      );
    }
  }

  Future<void> _editMember(AppMember member) async {
    final nameController = TextEditingController(text: member.name);
    String role = member.role;
    String accountStatus = member.accountStatus;
    String approvalStatus = member.approvalStatus;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'member',
                      child: Text('Member'),
                    ),
                    DropdownMenuItem(
                      value: 'administrator',
                      child: Text('Administrator'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => role = value ?? role),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: accountStatus,
                  decoration: const InputDecoration(
                    labelText: 'Account status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'pending',
                      child: Text('Pending'),
                    ),
                    DropdownMenuItem(
                      value: 'suspended',
                      child: Text('Suspended'),
                    ),
                    DropdownMenuItem(
                      value: 'rejected',
                      child: Text('Rejected'),
                    ),
                  ],
                  onChanged: (value) => setDialogState(
                    () => accountStatus = value ?? accountStatus,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: approvalStatus,
                  decoration: const InputDecoration(
                    labelText: 'Approval status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'pending',
                      child: Text('Pending'),
                    ),
                    DropdownMenuItem(
                      value: 'approved',
                      child: Text('Approved'),
                    ),
                    DropdownMenuItem(
                      value: 'rejected',
                      child: Text('Rejected'),
                    ),
                  ],
                  onChanged: (value) => setDialogState(
                    () => approvalStatus = value ?? approvalStatus,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await AuthService.instance.updateMember(
        uid: member.uid,
        updates: {
          'name': nameController.text.trim(),
          'role': role,
          'accountStatus': accountStatus,
          'approvalStatus': approvalStatus,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member updated successfully.')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'permission-denied' =>
          'Permission denied: only an administrator can edit this member.',
        'not-found' =>
          'The member profile was not found.',
        'unavailable' ||
        'network-request-failed' =>
          'Network unavailable. Check the connection and try again.',
        _ => 'Could not update member: ${error.message ?? error.code}',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update member: $error')),
      );
    } finally {
      nameController.dispose();
    }
  }

  Future<void> _confirmDelete(AppMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete member?'),
        content: Text(
          'This deactivates ${member.email} and preserves the profile for '
          'audit purposes. It does not delete voter or SQLite records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AuthService.instance.deleteMember(member.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member account deactivated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete member: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Management'),
        actions: [
          IconButton(
            tooltip: 'Create member',
            onPressed: _createMember,
            icon: const Icon(Icons.person_add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Search name or email',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _roleFilter,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(
                        value: 'member',
                        child: Text('Member'),
                      ),
                      DropdownMenuItem(
                        value: 'administrator',
                        child: Text('Administrator'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _roleFilter = value ?? 'all'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('Active'),
                      ),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pending'),
                      ),
                      DropdownMenuItem(
                        value: 'rejected',
                        child: Text('Rejected'),
                      ),
                      DropdownMenuItem(
                        value: 'suspended',
                        child: Text('Suspended'),
                      ),
                      DropdownMenuItem(value: 'locked', child: Text('Locked')),
                    ],
                    onChanged: (value) =>
                        setState(() => _statusFilter = value ?? 'all'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('registeredAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Could not load members: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final query = _search.text.toLowerCase();
                final members = snapshot.data!.docs
                    .map(AppMember.fromSnapshot)
                    .where((member) {
                  final matchesQuery = query.isEmpty ||
                      member.name.toLowerCase().contains(query) ||
                      member.email.toLowerCase().contains(query);
                  final matchesRole =
                      _roleFilter == 'all' || member.role == _roleFilter;
                  final matchesStatus = switch (_statusFilter) {
                    'locked' => member.locked,
                    'all' => true,
                    _ => member.accountStatus == _statusFilter,
                  };
                  return matchesQuery && matchesRole && matchesStatus;
                }).toList();
                if (members.isEmpty) {
                  return const Center(child: Text('No members found.'));
                }
                return ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            member.name.isEmpty
                                ? '?'
                                : member.name.substring(0, 1).toUpperCase(),
                          ),
                        ),
                        title: Text(member.name),
                        subtitle: Text(
                          '${member.email}\n'
                          '${member.role} • ${member.accountStatus} • '
                          '${member.approvalStatus}'
                          '${member.locked ? ' • LOCKED' : ''}',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) async {
                            switch (action) {
                              case 'edit':
                                await _editMember(member);
                                break;
                              case 'reset_lockout':
                                await AuthService.instance
                                    .resetMemberLockout(member.uid);
                                break;
                              case 'reset_password':
                                await AuthService.instance
                                    .resetMemberPassword(member.uid);
                                break;
                              case 'delete':
                                await _confirmDelete(member);
                                break;
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'reset_lockout',
                              child: Text('Reset lockout'),
                            ),
                            const PopupMenuItem(
                              value: 'reset_password',
                              child: Text('Reset password'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createMember,
        tooltip: 'Create member',
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
