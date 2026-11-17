
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'customers_screen.dart';

// =====================================================
// LEAD MODEL
// =====================================================

class LeadRecord {
  final String id;
  final Map<String, dynamic> data;

  const LeadRecord({required this.id, required this.data});

  factory LeadRecord.fromJson(Map<String, dynamic> json) {
    return LeadRecord(
      id: (json['id'] ?? '').toString(),
      data: {
        'name': (json['name'] ?? json['lead_name'] ?? '').toString(),
        'phone': (json['phone'] ?? '').toString(),
        'email': (json['email'] ?? '').toString(),
        'source': (json['source'] ?? '').toString(),
        'category': (json['category'] ?? 'Other').toString(),
        'priority': (json['priority'] ?? 'Medium').toString(),
        'status': (json['status'] ?? 'New').toString(),
        'notes': (json['notes'] ?? '').toString(),
        'customerId': json['customer_id']?.toString(),
        'customerName': (json['customerName'] ?? '').toString(),
        'customerCompany': (json['customerCompany'] ?? '').toString(),
        'organizationId': json['organization_id']?.toString(),
        'createdAt': json['created_at'],
        'updatedAt': json['updated_at'],
      },
    );
  }
}

// =====================================================
// LEADS SCREEN
// =====================================================

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  static const Color emerald = Color(0xFF00C853);

  Color get cardColor => Theme.of(context).colorScheme.surfaceContainerLow;
  Color get mutedColor => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get textColor => Theme.of(context).colorScheme.onSurface;

  Color get emeraldLight => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF69F0AE)
      : const Color(0xFF087A3D);

  static const String webApiBase = 'http://localhost/business_crm_api';
  static const String androidApiBase = 'http://10.0.2.2/business_crm_api';

  String get apiBase {
    if (kIsWeb) return webApiBase;

    if (defaultTargetPlatform == TargetPlatform.android) {
      return androidApiBase;
    }

    return webApiBase;
  }

  String get leadsApiUrl => '$apiBase/api/leads/index.php';
  String get customersApiUrl => '$apiBase/api/customers/index.php';

  // Lead conversion endpoint
  String get convertLeadApiUrl => '$apiBase/api/leads/convert.php';

  final TextEditingController searchController = TextEditingController();

  List<LeadRecord> leads = [];
  List<Customer> customers = [];

  bool isLoading = true;
  String? loadError;

  // Prevent multiple simultaneous conversion requests.
  final Set<String> convertingLeadIds = {};

  String searchText = '';
  String selectedStatus = 'All';
  String selectedPriority = 'All';
  String selectedCategory = 'All';

  final List<String> statuses = [
    'All',
    'New',
    'Contacted',
    'Qualified',
    'Converted',
    'Lost',
  ];

  final List<String> priorities = ['All', 'High', 'Medium', 'Low'];

  final List<String> categories = [
    'All',
    'Business',
    'Individual',
    'Enterprise',
    'Other',
  ];

  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    loadScreenData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // =====================================================
  // API HELPERS
  // =====================================================

  Future<Map<String, String>> getHeaders() async {
    final user = currentUser;

    if (user == null) {
      throw Exception('Please log in to continue.');
    }

    final token = await user.getIdToken(true);

    if (token == null || token.isEmpty) {
      throw Exception('Unable to get Firebase authentication token.');
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> decodeResponse(http.Response response) {
    Map<String, dynamic> result;

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid server response.');
      }

      result = decoded;
    } catch (_) {
      throw Exception(
        'Server returned an invalid response '
        '(HTTP ${response.statusCode}).',
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        result['success'] != true) {
      throw Exception((result['message'] ?? 'Request failed.').toString());
    }

    return result;
  }

  // =====================================================
  // LOAD LEADS AND CUSTOMERS FROM MYSQL
  // =====================================================

  Future<List<LeadRecord>> fetchLeads() async {
    final response = await http
        .get(Uri.parse(leadsApiUrl), headers: await getHeaders())
        .timeout(const Duration(seconds: 20));

    final result = decodeResponse(response);
    final rawData = result['data'];

    if (rawData is! List) {
      throw Exception('Invalid leads data received from server.');
    }

    return rawData
        .whereType<Map<String, dynamic>>()
        .map(LeadRecord.fromJson)
        .toList();
  }

  Future<List<Customer>> fetchCustomers() async {
    final response = await http
        .get(Uri.parse(customersApiUrl), headers: await getHeaders())
        .timeout(const Duration(seconds: 20));

    final result = decodeResponse(response);
    final rawData = result['data'];

    if (rawData is! List) {
      throw Exception('Invalid customers data received from server.');
    }

    return rawData
        .whereType<Map<String, dynamic>>()
        .map((json) {
          return Customer(
            id: (json['id'] ?? '').toString(),
            name: (json['customer_name'] ?? json['name'] ?? '').toString(),
            phone: (json['phone'] ?? '').toString(),
            email: (json['email'] ?? '').toString(),
            company: (json['company'] ?? '').toString(),
          );
        })
        .where((customer) => customer.id.isNotEmpty)
        .toList();
  }

  Future<void> loadScreenData() async {
    if (currentUser == null) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = 'Please log in to view leads.';
      });
      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
        loadError = null;
      });
    }

    try {
      final results = await Future.wait([fetchLeads(), fetchCustomers()]);

      if (!mounted) return;

      setState(() {
        leads = results[0] as List<LeadRecord>;
        customers = results[1] as List<Customer>;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // =====================================================
  // ADD / UPDATE LEAD
  // =====================================================

  Future<void> saveLead({
    required Map<String, dynamic> leadData,
    String? leadId,
  }) async {
    final headers = await getHeaders();

    final payload = <String, dynamic>{
      'name': leadData['name'],
      'phone': leadData['phone'],
      'email': leadData['email'],
      'source': leadData['source'],
      'category': leadData['category'],
      'priority': leadData['priority'],
      'status': leadData['status'],
      'notes': leadData['notes'],
      'customerId': leadData['customerId'],
    };

    if (leadId == null) {
      final response = await http
          .post(
            Uri.parse(leadsApiUrl),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      decodeResponse(response);
    } else {
      payload['id'] = int.tryParse(leadId);

      if (payload['id'] == null) {
        throw Exception('Invalid lead ID.');
      }

      final response = await http
          .put(
            Uri.parse(leadsApiUrl),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      decodeResponse(response);
    }

    await loadScreenData();

    if (loadError != null) {
      throw Exception(
        'Lead was saved, but refreshing the list failed: $loadError',
      );
    }
  }

  // =====================================================
  // CONVERT QUALIFIED LEAD TO CUSTOMER
  // =====================================================

  Future<void> convertLeadToCustomer(LeadRecord lead) async {
    final leadId = lead.id;
    final leadName = (lead.data['name'] ?? 'this lead').toString();
    final leadStatus = (lead.data['status'] ?? '').toString();

    // Only Qualified leads can be converted.
    if (leadStatus.toLowerCase() != 'qualified') {
      showMessage('Only Qualified leads can be converted.');
      return;
    }

    // Do not convert an already linked lead.
    final existingCustomerId = lead.data['customerId'];

    if (existingCustomerId != null &&
        existingCustomerId.toString().isNotEmpty) {
      showMessage('This lead is already linked to a customer.');
      return;
    }

    if (convertingLeadIds.contains(leadId)) {
      return;
    }

    // Ask for confirmation.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cardColor,
          title: Text(
            'Convert Lead to Customer?',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to convert "$leadName" into a customer?\n\n'
            'A new customer record will be created using this lead\'s details.',
            style: TextStyle(color: mutedColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: emerald,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Convert'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      convertingLeadIds.add(leadId);
    });

    try {
      final parsedLeadId = int.tryParse(leadId);

      if (parsedLeadId == null || parsedLeadId <= 0) {
        throw Exception('Invalid lead ID.');
      }

      final response = await http
          .post(
            Uri.parse(convertLeadApiUrl),
            headers: await getHeaders(),
            body: jsonEncode({
              'lead_id': parsedLeadId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final result = decodeResponse(response);
      final responseData = result['data'];

      // Refresh both leads and customers after successful conversion.
      await loadScreenData();

      if (!mounted) return;

      if (loadError != null) {
        showMessage(
          'Lead converted successfully, but refreshing the lists failed: '
          '$loadError',
        );
        return;
      }

      final customerName = responseData is Map
          ? (responseData['customer_name'] ?? leadName).toString()
          : leadName;

      final customerId = responseData is Map
          ? (responseData['customer_id'] ?? '').toString()
          : '';

      showMessage(
        customerId.isNotEmpty
            ? '$customerName converted successfully! Customer ID: $customerId'
            : '$customerName converted successfully!',
      );
    } catch (error) {
      if (!mounted) return;

      showMessage(
        'Conversion failed: ${error.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() {
          convertingLeadIds.remove(leadId);
        });
      }
    }
  }

  // =====================================================
  // SHOW ADD / EDIT DIALOG
  // =====================================================

  Future<void> showLeadDialog({LeadRecord? lead}) async {
    if (currentUser == null) {
      showMessage('Please log in to continue.');
      return;
    }

    if (customers.isEmpty) {
      try {
        final loadedCustomers = await fetchCustomers();

        if (!mounted) return;

        setState(() {
          customers = loadedCustomers;
        });
      } catch (error) {
        showMessage('Unable to load customers: $error');
        return;
      }
    }

    if (!mounted) return;

    String? initialCustomerId = lead?.data['customerId']?.toString();

    if (initialCustomerId != null &&
        !customers.any((customer) => customer.id == initialCustomerId)) {
      initialCustomerId = null;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return _LeadDialog(
          data: lead?.data ?? <String, dynamic>{},
          customers: customers,
          initialCustomerId: initialCustomerId,
          onSave: (data) async {
            await saveLead(leadData: data, leadId: lead?.id);
          },
        );
      },
    );

    if (!mounted || result != true) return;

    showMessage(
      lead == null ? 'Lead added successfully.' : 'Lead updated successfully.',
    );
  }

  // =====================================================
  // DELETE LEAD
  // =====================================================

  Future<void> deleteLead(LeadRecord lead) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          'Delete Lead?',
          style: TextStyle(color: textColor),
        ),
        content: Text(
          'Are you sure you want to delete ${lead.data['name']}?',
          style: TextStyle(color: mutedColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final uri = Uri.parse(leadsApiUrl)
          .replace(queryParameters: {'id': lead.id});

      final response = await http
          .delete(uri, headers: await getHeaders())
          .timeout(const Duration(seconds: 20));

      decodeResponse(response);

      await loadScreenData();

      if (!mounted) return;

      if (loadError != null) {
        showMessage('Lead deleted, but refresh failed: $loadError');
      } else {
        showMessage('Lead deleted successfully.');
      }
    } catch (error) {
      if (!mounted) return;
      showMessage('Delete failed: $error');
    }
  }

  // =====================================================
  // DETAILS DIALOG
  // =====================================================

  void showLeadDetails(LeadRecord lead) {
    final data = lead.data;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          (data['name'] ?? 'Lead Details').toString(),
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailLine('Phone', data['phone']),
                _detailLine('Email', data['email']),
                _detailLine('Source', data['source']),
                _detailLine('Status', data['status']),
                _detailLine('Priority', data['priority']),
                _detailLine('Category', data['category']),
                _detailLine('Linked Customer', data['customerName']),
                _detailLine('Company', data['customerCompany']),
                _detailLine('Notes', data['notes']),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              showLeadDialog(lead: lead);
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit Lead'),
          ),
        ],
      ),
    );
  }

  Widget _detailLine(String label, dynamic value) {
    final text = (value ?? '').toString().trim();

    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: mutedColor, fontSize: 14),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: emeraldLight,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // COLORS AND SMALL UI HELPERS
  // =====================================================

  Color statusColor(String status) {
    switch (status) {
      case 'Contacted':
        return Colors.orange;
      case 'Qualified':
        return Colors.blue;
      case 'Converted':
        return Colors.green;
      case 'Lost':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color priorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      default:
        return emeraldLight;
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _summaryCard(String title, int count, IconData icon, Color color) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: textColor.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 12),
          Text(
            count.toString(),
            style: TextStyle(
              color: textColor,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: mutedColor, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _leadInfo(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 14, color: mutedColor),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: mutedColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // CONVERSION BUTTON
  // =====================================================

  Widget _convertLeadButton(LeadRecord lead) {
    final leadId = lead.id;
    final isConverting = convertingLeadIds.contains(leadId);

    return SizedBox(
      height: 38,
      child: OutlinedButton.icon(
        onPressed: isConverting
            ? null
            : () => convertLeadToCustomer(lead),
        icon: isConverting
            ? const SizedBox(
                height: 15,
                width: 15,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.person_add_alt_1, size: 17),
        label: Text(
          isConverting ? 'Converting...' : 'Convert to Customer',
          style: const TextStyle(fontSize: 12),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: emeraldLight,
          side: BorderSide(color: emeraldLight.withValues(alpha: 0.6)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  // =====================================================
  // LEAD CARD
  // =====================================================

  Widget _leadCard(LeadRecord lead) {
    final data = lead.data;

    final name = (data['name'] ?? 'Unnamed Lead').toString();
    final phone = (data['phone'] ?? '').toString();
    final email = (data['email'] ?? '').toString();
    final source = (data['source'] ?? '').toString();
    final status = (data['status'] ?? 'New').toString();
    final priority = (data['priority'] ?? 'Medium').toString();
    final category = (data['category'] ?? 'Other').toString();
    final customerName = (data['customerName'] ?? '').toString();

    final hasCustomer = data['customerId'] != null &&
        data['customerId'].toString().isNotEmpty;

    final canConvert =
        status.toLowerCase() == 'qualified' && !hasCustomer;

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showLeadDetails(lead),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (phone.isNotEmpty)
                      _leadInfo(Icons.phone_outlined, phone),
                    if (email.isNotEmpty)
                      _leadInfo(Icons.email_outlined, email),
                    if (source.isNotEmpty)
                      _leadInfo(Icons.campaign_outlined, source),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _tag(status, statusColor(status)),
                        _tag('$priority Priority', priorityColor(priority)),
                        _tag(category, Theme.of(context).colorScheme.primary),
                        if (customerName.isNotEmpty)
                          _tag('Customer: $customerName', Colors.teal),
                      ],
                    ),
                    if (canConvert) ...[
                      const SizedBox(height: 12),
                      _convertLeadButton(lead),
                    ],
                    if (status.toLowerCase() == 'converted' || hasCustomer) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: emeraldLight,
                            size: 17,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Customer conversion completed',
                            style: TextStyle(
                              color: emeraldLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                iconColor: mutedColor,
                color: cardColor,
                onSelected: (value) {
                  if (value == 'details') {
                    showLeadDetails(lead);
                  } else if (value == 'edit') {
                    showLeadDialog(lead: lead);
                  } else if (value == 'delete') {
                    deleteLead(lead);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'details',
                    child: Text(
                      'View Details',
                      style: TextStyle(color: textColor),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit', style: TextStyle(color: textColor)),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // SEARCH AND FILTERS
  // =====================================================

  Widget _searchField() {
    return TextField(
      controller: searchController,
      style: TextStyle(color: textColor),
      onChanged: (value) {
        setState(() {
          searchText = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search leads by name, phone or email...',
        hintStyle: TextStyle(color: mutedColor),
        prefixIcon: const Icon(Icons.search, color: emerald),
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: textColor.withValues(alpha: 0.05)),
        ),
      ),
    );
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label-$value'),
        initialValue: value,
        isExpanded: true,
        dropdownColor: cardColor,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: mutedColor),
          filled: true,
          fillColor: cardColor,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(value: item, child: Text(item));
        }).toList(),
        onChanged: (newValue) {
          if (newValue != null) onChanged(newValue);
        },
      ),
    );
  }

  List<LeadRecord> get filteredLeads {
    final query = searchText.toLowerCase().trim();

    return leads.where((lead) {
      final data = lead.data;

      final name = (data['name'] ?? '').toString().toLowerCase();
      final phone = (data['phone'] ?? '').toString();
      final email = (data['email'] ?? '').toString().toLowerCase();

      final matchesSearch =
          name.contains(query) ||
          phone.contains(searchText.trim()) ||
          email.contains(query);

      final matchesStatus =
          selectedStatus == 'All' || data['status'] == selectedStatus;

      final matchesPriority =
          selectedPriority == 'All' || data['priority'] == selectedPriority;

      final matchesCategory =
          selectedCategory == 'All' || data['category'] == selectedCategory;

      return matchesSearch &&
          matchesStatus &&
          matchesPriority &&
          matchesCategory;
    }).toList();
  }

  int countStatus(String status) {
    return leads.where((lead) => lead.data['status'] == status).length;
  }

  // =====================================================
  // MAIN BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Center(
        child: Text(
          'Please log in to view leads.',
          style: TextStyle(color: textColor),
        ),
      );
    }

    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: emerald));
    }

    if (loadError != null && leads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: Colors.orange,
                size: 45,
              ),
              const SizedBox(height: 12),
              Text(
                'Unable to load leads',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: mutedColor),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: loadScreenData,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = filteredLeads;

    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          color: emerald,
          onRefresh: loadScreenData,
          child: Scrollbar(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leads Management',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Track, organize and convert your potential customers.',
                      style: TextStyle(color: mutedColor),
                    ),
                    const SizedBox(height: 22),

                    // SUMMARY CARDS
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _summaryCard(
                          'Total Leads',
                          leads.length,
                          Icons.people_outline,
                          emerald,
                        ),
                        _summaryCard(
                          'New',
                          countStatus('New'),
                          Icons.person_add_alt,
                          Colors.orange,
                        ),
                        _summaryCard(
                          'Contacted',
                          countStatus('Contacted'),
                          Icons.call,
                          Colors.deepOrange,
                        ),
                        _summaryCard(
                          'Qualified',
                          countStatus('Qualified'),
                          Icons.verified,
                          Colors.blue,
                        ),
                        _summaryCard(
                          'Converted',
                          countStatus('Converted'),
                          Icons.check_circle,
                          emeraldLight,
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // SEARCH AND ADD
                    LayoutBuilder(
                      builder: (context, searchConstraints) {
                        if (searchConstraints.maxWidth < 520) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _searchField(),
                              const SizedBox(height: 12),
                              _addLeadButton(),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: _searchField()),
                            const SizedBox(width: 12),
                            _addLeadButton(),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // FILTERS
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _filterDropdown(
                          label: 'Status',
                          value: selectedStatus,
                          items: statuses,
                          onChanged: (value) {
                            setState(() => selectedStatus = value);
                          },
                        ),
                        _filterDropdown(
                          label: 'Priority',
                          value: selectedPriority,
                          items: priorities,
                          onChanged: (value) {
                            setState(() => selectedPriority = value);
                          },
                        ),
                        _filterDropdown(
                          label: 'Category',
                          value: selectedCategory,
                          items: categories,
                          onChanged: (value) {
                            setState(() => selectedCategory = value);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'All Leads',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '${filtered.length} records',
                          style: TextStyle(color: mutedColor),
                        ),
                      ],
                    ),

                    const SizedBox(height: 13),

                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 50),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.person_search_outlined,
                                size: 55,
                                color: mutedColor,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No leads found',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Add a lead or change your filters.',
                                style: TextStyle(color: mutedColor),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...filtered.map(_leadCard),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _addLeadButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: emerald,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      onPressed: () => showLeadDialog(),
      icon: const Icon(Icons.add),
      label: const Text(
        'Add New Lead',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

// =====================================================
// ADD / EDIT LEAD DIALOG
// =====================================================

class _LeadDialog extends StatefulWidget {
  final Map<String, dynamic> data;
  final List<Customer> customers;
  final String? initialCustomerId;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _LeadDialog({
    required this.data,
    required this.customers,
    required this.initialCustomerId,
    required this.onSave,
  });

  @override
  State<_LeadDialog> createState() => _LeadDialogState();
}

class _LeadDialogState extends State<_LeadDialog> {
  static const Color emerald = Color(0xFF00C853);

  Color get cardColor => Theme.of(context).colorScheme.surfaceContainerLow;
  Color get mutedColor => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get textColor => Theme.of(context).colorScheme.onSurface;
  Color get fieldColor =>
      Theme.of(context).colorScheme.surfaceContainerHighest;

  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController emailController;
  late final TextEditingController sourceController;
  late final TextEditingController notesController;

  late String status;
  late String priority;
  late String category;

  String? customerId;
  bool isSaving = false;

  final List<String> statuses = [
    'New',
    'Contacted',
    'Qualified',
    'Converted',
    'Lost',
  ];

  final List<String> priorities = ['High', 'Medium', 'Low'];

  final List<String> categories = [
    'Business',
    'Individual',
    'Enterprise',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    final data = widget.data;

    nameController = TextEditingController(
      text: (data['name'] ?? '').toString(),
    );

    phoneController = TextEditingController(
      text: (data['phone'] ?? '').toString(),
    );

    emailController = TextEditingController(
      text: (data['email'] ?? '').toString(),
    );

    sourceController = TextEditingController(
      text: (data['source'] ?? '').toString(),
    );

    notesController = TextEditingController(
      text: (data['notes'] ?? '').toString(),
    );

    status = (data['status'] ?? 'New').toString();
    priority = (data['priority'] ?? 'Medium').toString();
    category = (data['category'] ?? 'Business').toString();

    if (!statuses.contains(status)) status = 'New';
    if (!priorities.contains(priority)) priority = 'Medium';
    if (!categories.contains(category)) category = 'Business';

    customerId = widget.initialCustomerId;
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    sourceController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> saveLead() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(content: Text('Lead name is required.')),
      );
      return;
    }

    if (phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number is required.')),
      );
      return;
    }

    setState(() => isSaving = true);

    final leadData = <String, dynamic>{
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'email': emailController.text.trim(),
      'source': sourceController.text.trim(),
      'notes': notesController.text.trim(),
      'status': status,
      'priority': priority,
      'category': category,
      'customerId': customerId,
    };

    try {
      await widget.onSave(leadData);

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() => isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: !isSaving,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: mutedColor),
          prefixIcon: Icon(icon, color: emerald),
          filled: true,
          fillColor: fieldColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label-$value'),
        initialValue: value,
        isExpanded: true,
        dropdownColor: cardColor,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: mutedColor),
          filled: true,
          fillColor: fieldColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(value: item, child: Text(item));
        }).toList(),
        onChanged: isSaving ? null : onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: cardColor,
      title: Text(
        widget.data.isEmpty ? 'Add New Lead' : 'Edit Lead',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _textField(nameController, 'Lead Name', Icons.person_outline),
              _textField(
                phoneController,
                'Phone Number',
                Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              _textField(
                emailController,
                'Email Address',
                Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              _textField(
                sourceController,
                'Lead Source',
                Icons.campaign_outlined,
              ),
              _textField(notesController, 'Notes', Icons.notes, maxLines: 3),

              _dropdown(
                label: 'Lead Status',
                value: status,
                items: statuses,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => status = value);
                  }
                },
              ),

              _dropdown(
                label: 'Priority',
                value: priority,
                items: priorities,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => priority = value);
                  }
                },
              ),

              _dropdown(
                label: 'Category',
                value: category,
                items: categories,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => category = value);
                  }
                },
              ),

              DropdownButtonFormField<String?>(
                key: ValueKey('customer-$customerId'),
                initialValue: customerId,
                isExpanded: true,
                dropdownColor: cardColor,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Link Existing Customer (Optional)',
                  labelStyle: TextStyle(color: mutedColor),
                  prefixIcon: const Icon(Icons.link, color: emerald),
                  filled: true,
                  fillColor: fieldColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No customer linked'),
                  ),
                  ...widget.customers.map(
                    (customer) => DropdownMenuItem<String?>(
                      value: customer.id,
                      child: Text(
                        customer.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: isSaving
                    ? null
                    : (value) {
                        setState(() => customerId = value);
                      },
              ),

              if (widget.customers.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'No existing customers found. '
                    'You can still add this lead.',
                    style: TextStyle(color: mutedColor, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: emerald,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          onPressed: isSaving ? null : saveLead,
          icon: isSaving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: Text(isSaving ? 'Saving...' : 'Save Lead'),
        ),
      ],
    );
  }
}
