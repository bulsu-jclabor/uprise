// lib/screens/web/org/org_finance.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../services/activity_logger.dart' as activity_log;
import 'package:fl_chart/fl_chart.dart';
import '../../../widgets/admin_export_button.dart';
import 'export_util.dart';
import 'export_pdf.dart';

// ============ COLOR SCHEME ============
class OrgColors {
  static const Color primaryDark  = Color(0xFFB45309);
  static const Color primaryLight = Color(0xFFD97706);
  static const Color accent       = Color(0xFFF59E0B);
  static const Color white        = Color(0xFFFFFFFF);
  static const Color lightGray    = Color(0xFFF9FAFB);
  static const Color mediumGray   = Color(0xFFE5E7EB);
  static const Color darkGray     = Color(0xFF6B7280);
  static const Color charcoal     = Color(0xFF111827);
  static const Color success      = Color(0xFF10B981);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color error        = Color(0xFFEF4444);
  static const Color info         = Color(0xFF3B82F6);
}

// ============ TRANSACTION MODEL ============
class TransactionModel {
  final String id;
  final String eventId;
  final String eventName;
  final String category;
  final String segment;
  final double amount;
  final String type;
  final Timestamp date;

  TransactionModel({
    required this.id,
    required this.eventId,
    required this.eventName,
    required this.category,
    required this.segment,
    required this.amount,
    required this.type,
    required this.date,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      eventName: data['eventName'] ?? '',
      category: data['category'] ?? '',
      segment: data['segment'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      type: data['type'] ?? 'income',
      date: data['date'] as Timestamp,
    );
  }
}

// ============ MAIN SCREEN ============
class OrgFinanceScreen extends StatefulWidget {
  final String orgId;
  const OrgFinanceScreen({super.key, required this.orgId});

  @override
  State<OrgFinanceScreen> createState() => _OrgFinanceScreenState();
}

class _OrgFinanceScreenState extends State<OrgFinanceScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'income', 'expense'
  String _filterCategory = 'All';

  final List<String> _categories = [
    'All', 'Workshops', 'Competitions', 'Partnerships', 'Socials', 'Retail', 'General'
  ];

  List<TransactionModel> _applyReportFilters(
    List<TransactionModel> list, {
    String eventFilter = 'All Events',
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return list.where((t) {
      final eventMatch = eventFilter == 'All Events' || t.eventName == eventFilter;
      final startMatch = startDate == null || !t.date.toDate().isBefore(startDate);
      final endMatch = endDate == null || !t.date.toDate().isAfter(endDate);
      return eventMatch && startMatch && endMatch;
    }).toList();
  }

  Stream<QuerySnapshot> get _transactionsStream => FirebaseFirestore.instance
      .collection('transactions')
      .where('orgId', isEqualTo: widget.orgId)
      .orderBy('date', descending: true)
      .snapshots();

  Future<Map<String, dynamic>> _getTotals() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('transactions')
        .where('orgId', isEqualTo: widget.orgId)
        .get();
    double income = 0;
    double expense = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final amount = (data['amount'] ?? 0).toDouble();
      if (data['type'] == 'income') {
        income += amount;
      } else {
        expense += amount;
      }
    }
    return {'income': income, 'expense': expense, 'net': income - expense};
  }

  void _openAddModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TransactionModal(orgId: widget.orgId),
    ).then((_) => setState(() {}));
  }

  void _openEditModal(TransactionModel transaction) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TransactionModal(orgId: widget.orgId, existingTransaction: transaction),
    ).then((_) => setState(() {}));
  }

  Future<void> _deleteTransaction(TransactionModel transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete Transaction',
            style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700)),
        content: Text('Delete "${transaction.segment}"? This cannot be undone.',
            style: GoogleFonts.beVietnamPro()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.beVietnamPro()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: OrgColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete', style: GoogleFonts.beVietnamPro(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.collection('transactions').doc(transaction.id).delete();
      await activity_log.ActivityLogger.log(
        action: 'delete_transaction',
        module: 'finance',
        details: {'orgId': widget.orgId, 'transactionId': transaction.id, 'amount': transaction.amount},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction deleted successfully', style: GoogleFonts.beVietnamPro()),
            backgroundColor: OrgColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.beVietnamPro()),
            backgroundColor: OrgColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<TransactionModel> _filterTransactions(List<TransactionModel> list) {
    return list.where((t) {
      final matchSearch = _searchQuery.isEmpty ||
          t.eventName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.segment.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchType = _filterType == 'all' || t.type == _filterType;
      final matchCategory = _filterCategory == 'All' || t.category == _filterCategory;
      return matchSearch && matchType && matchCategory;
    }).toList();
  }

  Future<void> _exportTransactions(String choice, List<TransactionModel> transactions) async {
    final filtered = _filterTransactions(transactions);
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No transactions to export', style: GoogleFonts.beVietnamPro()),
          backgroundColor: OrgColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    final headers = ['Event Name', 'Category', 'Segment', 'Amount', 'Type', 'Date'];
    final rows = filtered.map((t) {
      final date = DateFormat('MM/dd/yyyy').format(t.date.toDate());
      return [
        t.eventName,
        t.category,
        t.segment,
        t.amount.toStringAsFixed(2),
        t.type,
        date,
      ];
    }).toList();

    try {
      if (choice == 'csv') {
        final csv = [headers, ...rows]
            .map((row) => row.map((c) => '"${c.replaceAll('"', '""')}"').join(','))
            .join('\n');
        await OrgExportUtil.saveText(csv, 'transactions_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv', mimeType: 'text/csv');
      } else if (choice == 'pdf') {
        final pdfBytes = await OrgExportPdf.generateTablePdf(
          title: 'Transactions',
          headers: headers,
          rows: rows,
        );
        await OrgExportUtil.saveBytes(pdfBytes, 'transactions_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf', mimeType: 'application/pdf');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${filtered.length} transactions', style: GoogleFonts.beVietnamPro()),
          backgroundColor: OrgColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e', style: GoogleFonts.beVietnamPro()),
          backgroundColor: OrgColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _showGenerateFinancialReportDialog(
      BuildContext context, List<TransactionModel> transactions) async {
    final events = [
      'All Events',
      ...{for (var t in transactions) t.eventName}.toList()..sort(),
    ];
    String selectedEvent = 'All Events';
    DateTime? startDate;
    DateTime? endDate;
    String selectedFormat = 'pdf';

    final dialogContext = context;
    await showDialog<void>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (dialogContext, setState) {
          Future<void> pickDate(bool isStart) async {
            final dialogPickerContext = dialogContext;
            final initial = isStart
                ? startDate ?? DateTime.now().subtract(const Duration(days: 30))
                : endDate ?? DateTime.now();
            final picked = await showDatePicker(
              context: dialogPickerContext,
              initialDate: initial,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked == null) return;
            final pickedDate = picked;
            final currentEndDate = endDate;
            final currentStartDate = startDate;
            setState(() {
              if (isStart) {
                startDate = pickedDate;
                if (currentEndDate != null && currentEndDate.isBefore(pickedDate)) {
                  endDate = pickedDate;
                }
              } else {
                endDate = pickedDate;
                if (currentStartDate != null && currentStartDate.isAfter(pickedDate)) {
                  startDate = pickedDate;
                }
              }
            });
          }

          final filtered = _applyReportFilters(
            transactions,
            eventFilter: selectedEvent,
            startDate: startDate,
            endDate: endDate,
          );

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 520,
              decoration: BoxDecoration(
                color: OrgColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(children: [
                    Expanded(
                      child: Text('Generate Financial Report',
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                      splashRadius: 18,
                    ),
                  ]),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Filter by event',
                        style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: OrgColors.primaryLight),
                        color: OrgColors.lightGray,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedEvent,
                          items: events
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => setState(() => selectedEvent = v ?? 'All Events'),
                          isExpanded: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Filter by date',
                        style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => pickDate(true),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: OrgColors.lightGray,
                            side: BorderSide(color: OrgColors.primaryLight),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            startDate == null
                                ? 'Start date'
                                : DateFormat('MMM d, yyyy').format(startDate!),
                            style: GoogleFonts.beVietnamPro(color: OrgColors.charcoal),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => pickDate(false),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: OrgColors.lightGray,
                            side: BorderSide(color: OrgColors.primaryLight),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            endDate == null
                                ? 'End date'
                                : DateFormat('MMM d, yyyy').format(endDate!),
                            style: GoogleFonts.beVietnamPro(color: OrgColors.charcoal),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 18),
                    Text('Format',
                        style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(children: [
                      ChoiceChip(
                        label: Text('PDF'),
                        selected: selectedFormat == 'pdf',
                        onSelected: (_) => setState(() => selectedFormat = 'pdf'),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: Text('CSV'),
                        selected: selectedFormat == 'csv',
                        onSelected: (_) => setState(() => selectedFormat = 'csv'),
                      ),
                    ]),
                    const SizedBox(height: 18),
                    Text(
                      '${filtered.length} transaction(s) will be included',
                      style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray),
                    ),
                  ]),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: OrgColors.primaryLight),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('Cancel', style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: filtered.isEmpty
                            ? null
                            : () async {
                                Navigator.pop(context);
                                await _generateFinancialReport(
                                  selectedFormat,
                                  transactions,
                                  eventFilter: selectedEvent,
                                  startDate: startDate,
                                  endDate: endDate,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OrgColors.primaryDark,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('Generate Report',
                            style: GoogleFonts.beVietnamPro(color: Colors.white)),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          );
        });
      },
    );
  }

  Future<void> _generateFinancialReport(
      String choice,
      List<TransactionModel> transactions, {
      String eventFilter = 'All Events',
      DateTime? startDate,
      DateTime? endDate,
    }) async {
    final filtered = _applyReportFilters(
      transactions,
      eventFilter: eventFilter,
      startDate: startDate,
      endDate: endDate,
    );

    if (filtered.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No transactions match the selected report filters',
                style: GoogleFonts.beVietnamPro()),
            backgroundColor: OrgColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      return;
    }

    final headers = ['Date', 'Event', 'Category', 'Description', 'Type', 'Amount'];
    final rows = filtered.map((t) {
      return [
        DateFormat('MM/dd/yyyy').format(t.date.toDate()),
        t.eventName,
        t.category,
        t.segment,
        t.type,
        t.amount.toStringAsFixed(2),
      ];
    }).toList();

    final fileName = 'financial_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

    try {
      if (choice == 'csv') {
        final csv = [headers, ...rows]
            .map((row) => row.map((c) => '"${c.replaceAll('"', '""')}"').join(','))
            .join('\n');
        await OrgExportUtil.saveText(csv, '$fileName.csv', mimeType: 'text/csv');
      } else {
        final filters = <String>[];
        if (eventFilter != 'All Events') filters.add('Event: $eventFilter');
        if (startDate != null) filters.add('From: ${DateFormat('MMM d, yyyy').format(startDate)}');
        if (endDate != null) filters.add('To: ${DateFormat('MMM d, yyyy').format(endDate)}');
        final subtitle = filters.isEmpty
            ? 'Organization financial report'
            : filters.join(' • ');

        final pdfBytes = await OrgExportPdf.generateTablePdf(
          title: 'Financial Report',
          headers: headers,
          rows: rows,
          subtitle: subtitle,
        );
        await OrgExportUtil.saveBytes(pdfBytes, '$fileName.pdf', mimeType: 'application/pdf');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Financial report generated successfully',
                style: GoogleFonts.beVietnamPro()),
            backgroundColor: OrgColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report generation failed: $e', style: GoogleFonts.beVietnamPro()),
            backgroundColor: OrgColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Financial Records',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 24, fontWeight: FontWeight.bold, color: OrgColors.charcoal)),
                  const SizedBox(height: 2),
                  Text('Manage and track all organizational transactions',
                      style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray)),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _openAddModal,
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: Text('Add Transaction',
                    style: GoogleFonts.beVietnamPro(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OrgColors.primaryDark,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Stats Row ──
          FutureBuilder<Map<String, dynamic>>(
            future: _getTotals(),
            builder: (context, snapshot) {
              final income = snapshot.data?['income'] ?? 0.0;
              final expense = snapshot.data?['expense'] ?? 0.0;
              final net = snapshot.data?['net'] ?? 0.0;
              return Row(children: [
                _StatCard(
                  label: 'TOTAL INCOME',
                  value: '₱${NumberFormat('#,###').format(income)}',
                  change: '+12.5% vs last month',
                  icon: Icons.trending_up,
                  color: OrgColors.success,
                ),
                const SizedBox(width: 14),
                _StatCard(
                  label: 'TOTAL EXPENSES',
                  value: '₱${NumberFormat('#,###').format(expense)}',
                  change: '+16.2% vs last month',
                  icon: Icons.trending_down,
                  color: OrgColors.error,
                ),
                const SizedBox(width: 14),
                _StatCard(
                  label: 'NET BALANCE',
                  value: net >= 0
                      ? '₱${NumberFormat('#,###').format(net)}'
                      : '-₱${NumberFormat('#,###').format(net.abs())}',
                  change: net >= 0 ? '+16.2% vs last month' : '-16.2% vs last month',
                  icon: Icons.account_balance_wallet_outlined,
                  color: OrgColors.info,
                ),
              ]);
            },
          ),
          const SizedBox(height: 24),

          // ── Main Content: Table + Summary ──
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _transactionsStream,
              builder: (context, snapshot) {
                final transactions = snapshot.hasData
                    ? snapshot.data!.docs
                        .map((doc) => TransactionModel.fromFirestore(doc))
                        .toList()
                    : <TransactionModel>[];
                final filtered = _filterTransactions(transactions);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Transactions Table
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: OrgColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: OrgColors.primaryLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Table toolbar
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                              child: Row(
                                children: [
                                  Text('Transactions',
                                      style: GoogleFonts.beVietnamPro(
                                          fontSize: 15, fontWeight: FontWeight.w600,
                                          color: OrgColors.charcoal)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: OrgColors.mediumGray,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text('${filtered.length}',
                                        style: GoogleFonts.beVietnamPro(
                                            fontSize: 11, fontWeight: FontWeight.w600,
                                            color: OrgColors.darkGray)),
                                  ),
                                  const Spacer(),
                                  // Search
                                  SizedBox(
                                    width: 220,
                                    height: 38,
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: (v) => setState(() => _searchQuery = v),
                                      style: GoogleFonts.beVietnamPro(fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: 'Search event, category...',
                                        hintStyle: GoogleFonts.beVietnamPro(
                                            fontSize: 12, color: OrgColors.darkGray),
                                        prefixIcon: const Icon(Icons.search, size: 18,
                                            color: OrgColors.darkGray),
                                        filled: true,
                                        fillColor: OrgColors.lightGray,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: OrgColors.primaryLight),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: OrgColors.primaryLight),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: OrgColors.primaryLight),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Type Filter
                                  _FilterDropdown<String>(
                                    value: _filterType,
                                    items: const [
                                      DropdownMenuItem(value: 'all', child: Text('All Types')),
                                      DropdownMenuItem(value: 'income', child: Text('Income')),
                                      DropdownMenuItem(value: 'expense', child: Text('Expense')),
                                    ],
                                    onChanged: (v) => setState(() => _filterType = v ?? 'all'),
                                  ),
                                  const SizedBox(width: 8),
                                  // Category Filter
                                  _FilterDropdown<String>(
                                    value: _filterCategory,
                                    items: _categories.map((c) =>
                                        DropdownMenuItem(value: c, child: Text(c))).toList(),
                                    onChanged: (v) =>
                                        setState(() => _filterCategory = v ?? 'All'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => _showGenerateFinancialReportDialog(context, transactions),
                                    icon: const Icon(Icons.insert_drive_file_outlined, size: 18, color: Colors.white),
                                    label: Text('Generate Report',
                                        style: GoogleFonts.beVietnamPro(
                                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: OrgColors.primaryDark,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  AdminExportButton(
                                    label: 'Export',
                                    onSelected: (choice) => _exportTransactions(choice, transactions),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),

                            // Table Content
                            Expanded(
                              child: Builder(builder: (context) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                if (transactions.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.receipt_long_outlined,
                                            size: 48, color: OrgColors.mediumGray),
                                        const SizedBox(height: 12),
                                        Text('No transactions yet',
                                            style: GoogleFonts.beVietnamPro(
                                                color: OrgColors.darkGray, fontSize: 14)),
                                        const SizedBox(height: 6),
                                        Text('Click "Add Transaction" to get started.',
                                            style: GoogleFonts.beVietnamPro(
                                                color: OrgColors.darkGray, fontSize: 12)),
                                      ],
                                    ),
                                  );
                                }
                                if (filtered.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.search_off_outlined,
                                            size: 42, color: OrgColors.mediumGray),
                                        const SizedBox(height: 12),
                                        Text('No matching transactions',
                                            style: GoogleFonts.beVietnamPro(
                                                color: OrgColors.darkGray)),
                                      ],
                                    ),
                                  );
                                }
                                return SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Theme(
                                      data: Theme.of(context).copyWith(
                                        dataTableTheme: DataTableThemeData(
                                          headingTextStyle: GoogleFonts.beVietnamPro(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: OrgColors.darkGray,
                                            letterSpacing: 0.5,
                                          ),
                                          dataTextStyle: GoogleFonts.beVietnamPro(
                                              fontSize: 13, color: OrgColors.charcoal),
                                          headingRowColor: WidgetStateProperty.all(
                                              OrgColors.lightGray),
                                          dataRowColor: WidgetStateProperty.resolveWith(
                                            (states) => states.contains(WidgetState.hovered)
                                                ? OrgColors.lightGray
                                                : OrgColors.white,
                                          ),
                                        ),
                                      ),
                                      child: DataTable(
                                        columnSpacing: 20,
                                        horizontalMargin: 16,
                                        dividerThickness: 1,
                                        columns: [
                                          _col('DATE'),
                                          _col('EVENT'),
                                          _col('CATEGORY'),
                                          _col('DESCRIPTION'),
                                          _col('AMOUNT'),
                                          _col('TYPE'),
                                          _col('ACTIONS'),
                                        ],
                                        rows: filtered.map((t) {
                                          final amountFmt =
                                              NumberFormat('#,###.00').format(t.amount);
                                          final dateFmt = DateFormat('MM/dd/yyyy')
                                              .format(t.date.toDate());
                                          final isIncome = t.type == 'income';
                                          return DataRow(cells: [
                                            DataCell(Text(dateFmt,
                                                style: GoogleFonts.beVietnamPro(
                                                    fontSize: 12, color: OrgColors.darkGray))),
                                            DataCell(Text(t.eventName,
                                                style: GoogleFonts.beVietnamPro(
                                                    fontWeight: FontWeight.w600, fontSize: 13))),
                                            DataCell(Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: OrgColors.lightGray,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(t.category,
                                                  style: GoogleFonts.beVietnamPro(fontSize: 11)),
                                            )),
                                            DataCell(SizedBox(
                                              width: 160,
                                              child: Text(t.segment,
                                                  style: GoogleFonts.beVietnamPro(
                                                      fontSize: 12, color: OrgColors.darkGray),
                                                  overflow: TextOverflow.ellipsis),
                                            )),
                                            DataCell(Text('₱$amountFmt',
                                                style: GoogleFonts.beVietnamPro(
                                                    fontWeight: FontWeight.w700,
                                                    color: isIncome
                                                        ? OrgColors.success
                                                        : OrgColors.error))),
                                            DataCell(Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isIncome
                                                    ? OrgColors.success.withOpacity(0.12)
                                                    : OrgColors.error.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                isIncome ? 'Income' : 'Expense',
                                                style: GoogleFonts.beVietnamPro(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: isIncome
                                                        ? OrgColors.success
                                                        : OrgColors.error),
                                              ),
                                            )),
                                            DataCell(Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _ActionButton(
                                                  icon: Icons.edit_outlined,
                                                  color: OrgColors.info,
                                                  tooltip: 'Edit',
                                                  onTap: () => _openEditModal(t),
                                                ),
                                                const SizedBox(width: 4),
                                                _ActionButton(
                                                  icon: Icons.delete_outline,
                                                  color: OrgColors.error,
                                                  tooltip: 'Delete',
                                                  onTap: () => _deleteTransaction(t),
                                                ),
                                              ],
                                            )),
                                          ]);
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),

                            // Table footer
                            if (filtered.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border(
                                      top: BorderSide(color: OrgColors.primaryLight)),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'Showing ${filtered.length} of ${transactions.length} transactions',
                                      style: GoogleFonts.beVietnamPro(
                                          fontSize: 12, color: OrgColors.darkGray),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Right: Summary Column
                    SizedBox(
                      width: 300,
                      child: _SummaryPanel(orgId: widget.orgId),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  DataColumn _col(String label) => DataColumn(
        label: Text(label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: OrgColors.darkGray, letterSpacing: 0.5)),
      );
}

// ============ ACTION BUTTON ============
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

// ============ FILTER DROPDOWN ============
class _FilterDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: OrgColors.white,
        border: Border.all(color: OrgColors.primaryLight),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item.value,
              child: DefaultTextStyle(
                style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.charcoal),
                child: item.child!,
              ),
            );
          }).toList(),
          onChanged: onChanged,
          style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.charcoal),
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: OrgColors.darkGray),
          isDense: true,
        ),
      ),
    );
  }
}

// ============ STAT CARD ============
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String change;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.change,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: OrgColors.primaryLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 11, color: OrgColors.darkGray,
                          fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 22, fontWeight: FontWeight.bold,
                          color: OrgColors.charcoal)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.arrow_upward, size: 10, color: color),
                      const SizedBox(width: 2),
                      Text(change,
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 10, color: color,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ SUMMARY PANEL ============
class _SummaryPanel extends StatelessWidget {
  final String orgId;
  const _SummaryPanel({required this.orgId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('orgId', isEqualTo: orgId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;

        Map<String, double> incomeByEvent = {};
        Map<String, double> expenseByEvent = {};
        double totalIncome = 0, totalExpense = 0;

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final eventName = data['eventName'] ?? 'Unknown';
          final amount = (data['amount'] ?? 0).toDouble();
          final type = data['type'];
          if (type == 'income') {
            incomeByEvent[eventName] = (incomeByEvent[eventName] ?? 0) + amount;
            totalIncome += amount;
          } else {
            expenseByEvent[eventName] = (expenseByEvent[eventName] ?? 0) + amount;
            totalExpense += amount;
          }
        }

        final allEvents = {...incomeByEvent.keys, ...expenseByEvent.keys}.toList();
        final netPerEvent = <String, double>{};
        for (final event in allEvents) {
          netPerEvent[event] =
              (incomeByEvent[event] ?? 0) - (expenseByEvent[event] ?? 0);
        }
        final sortedEvents = netPerEvent.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topEvents = sortedEvents.take(5).toList();

        return SingleChildScrollView(
          child: Column(
            children: [
              // Bar Chart Card
              _SummaryCard(
                title: 'Income vs Expenses by Event',
                child: SizedBox(
                  height: 190,
                  child: topEvents.isEmpty
                      ? Center(
                          child: Text('No data yet',
                              style: GoogleFonts.beVietnamPro(
                                  color: OrgColors.darkGray, fontSize: 12)))
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: (() {
                              final vals = [
                                ...topEvents.map((e) =>
                                    incomeByEvent[e.key] ?? 0),
                                ...topEvents.map((e) =>
                                    expenseByEvent[e.key] ?? 0),
                              ];
                              return vals.isNotEmpty
                                  ? vals.reduce((a, b) => a > b ? a : b) * 1.2
                                  : 10.0;
                            })(),
                            barGroups: topEvents.asMap().entries.map((entry) {
                              final i = entry.key;
                              final name = entry.value.key;
                              return BarChartGroupData(
                                x: i,
                                barsSpace: 4,
                                barRods: [
                                  BarChartRodData(
                                    toY: incomeByEvent[name] ?? 0,
                                    color: OrgColors.success,
                                    width: 10,
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4)),
                                  ),
                                  BarChartRodData(
                                    toY: expenseByEvent[name] ?? 0,
                                    color: OrgColors.error,
                                    width: 10,
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4)),
                                  ),
                                ],
                              );
                            }).toList(),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 32,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index >= 0 && index < topEvents.length) {
                                      final name = topEvents[index].key;
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(top: 4),
                                        child: Text(
                                          name.length > 6
                                              ? '${name.substring(0, 6)}…'
                                              : name,
                                          style: GoogleFonts.beVietnamPro(
                                              fontSize: 9,
                                              color: OrgColors.darkGray),
                                          textAlign: TextAlign.center,
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      '₱${NumberFormat.compact().format(value)}',
                                      style: GoogleFonts.beVietnamPro(
                                          fontSize: 9, color: OrgColors.darkGray),
                                    );
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) =>
                                  FlLine(color: OrgColors.mediumGray, strokeWidth: 0.8),
                            ),
                            borderData: FlBorderData(show: false),
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendDot(color: OrgColors.success, label: 'Income'),
                  const SizedBox(width: 16),
                  _LegendDot(color: OrgColors.error, label: 'Expenses'),
                ],
              ),
              const SizedBox(height: 14),

              // Per Event Summary
              _SummaryCard(
                title: 'Per Event Summary',
                child: Column(
                  children: topEvents.isEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('No events yet',
                                style: GoogleFonts.beVietnamPro(
                                    color: OrgColors.darkGray, fontSize: 12)),
                          )
                        ]
                      : topEvents.map((entry) {
                          final inc = incomeByEvent[entry.key] ?? 0;
                          final exp = expenseByEvent[entry.key] ?? 0;
                          final net = inc - exp;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry.key,
                                    style: GoogleFonts.beVietnamPro(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: OrgColors.charcoal)),
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        'Income: ₱${NumberFormat('#,###').format(inc)}',
                                        style: GoogleFonts.beVietnamPro(
                                            fontSize: 11,
                                            color: OrgColors.success)),
                                    Text(
                                        'Net: ₱${NumberFormat('#,###').format(net)}',
                                        style: GoogleFonts.beVietnamPro(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: net >= 0
                                                ? OrgColors.success
                                                : OrgColors.error)),
                                  ],
                                ),
                                Text(
                                    'Expense: ₱${NumberFormat('#,###').format(exp)}',
                                    style: GoogleFonts.beVietnamPro(
                                        fontSize: 11,
                                        color: OrgColors.error)),
                              ],
                            ),
                          );
                        }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Semester Summary
              _SummaryCard(
                title: 'Semester Summary (2025–2026)',
                child: Column(
                  children: [
                    _SummaryRow(
                        label: 'Total Income',
                        value: '₱${NumberFormat('#,###').format(totalIncome)}',
                        color: OrgColors.success),
                    const SizedBox(height: 6),
                    _SummaryRow(
                        label: 'Total Expenses',
                        value: '₱${NumberFormat('#,###').format(totalExpense)}',
                        color: OrgColors.error),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(color: OrgColors.mediumGray, height: 1),
                    ),
                    _SummaryRow(
                        label: 'Net Balance',
                        value:
                            '₱${NumberFormat('#,###').format(totalIncome - totalExpense)}',
                        color: (totalIncome - totalExpense) >= 0
                            ? OrgColors.success
                            : OrgColors.error,
                        isBold: true),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style:
                GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SummaryCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: OrgColors.charcoal)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isBold;
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                color: OrgColors.darkGray,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.normal)),
        Text(value,
            style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }
}

// ============ TRANSACTION MODAL (ADD/EDIT) ============
class _TransactionModal extends StatefulWidget {
  final String orgId;
  final TransactionModel? existingTransaction;
  const _TransactionModal({required this.orgId, this.existingTransaction});

  @override
  State<_TransactionModal> createState() => _TransactionModalState();
}

class _TransactionModalState extends State<_TransactionModal> {
  final _segmentCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String? _selectedEventId;
  String _selectedEventName = '';
  String _category = 'Workshops';
  String _type = 'expense';
  DateTime _selectedDate = DateTime.now();
  bool _loadingEvents = true;
  bool _submitting = false;
  List<Map<String, dynamic>> _events = [];

  final List<String> _categories = [
    'Workshops', 'Competitions', 'Partnerships', 'Socials', 'Retail', 'General'
  ];

  bool get _isEdit => widget.existingTransaction != null;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    if (_isEdit) {
      final t = widget.existingTransaction!;
      _segmentCtrl.text = t.segment;
      _amountCtrl.text = t.amount.toStringAsFixed(2);
      _selectedEventName = t.eventName;
      _selectedEventId = t.eventId.isNotEmpty ? t.eventId : null;
      _category = t.category;
      _type = t.type;
      _selectedDate = t.date.toDate();
    }
  }

  Future<void> _loadEvents() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('events')
        .where('orgId', isEqualTo: widget.orgId)
        .orderBy('date', descending: false)
        .get();
    setState(() {
      _events = snapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, 'name': data['title'] ?? 'Untitled'};
      }).toList();
      _loadingEvents = false;
      if (_events.isNotEmpty && !_isEdit) {
        _selectedEventId = _events.first['id'];
        _selectedEventName = _events.first['name'];
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: OrgColors.primaryDark),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (_amountCtrl.text.trim().isEmpty) {
      _showError('Amount is required');
      return;
    }
    if (amount <= 0) {
      _showError('Amount must be greater than 0');
      return;
    }
    if (_selectedEventId == null && _selectedEventName.isEmpty) {
      _showError('Please select an event');
      return;
    }

    setState(() => _submitting = true);
    final user = FirebaseAuth.instance.currentUser;
    final data = {
      'orgId': widget.orgId,
      'eventId': _selectedEventId ?? '',
      'eventName': _selectedEventName,
      'category': _category,
      'segment': _segmentCtrl.text.trim(),
      'amount': amount,
      'type': _type,
      'date': Timestamp.fromDate(_selectedDate),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (_isEdit) {
        await FirebaseFirestore.instance
            .collection('transactions')
            .doc(widget.existingTransaction!.id)
            .update(data);
        await activity_log.ActivityLogger.log(
          action: 'edit_transaction',
          module: 'finance',
          details: {'orgId': widget.orgId, 'transactionId': widget.existingTransaction!.id},
        );
      } else {
        data['createdBy'] = user?.uid ?? '';
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('transactions').add(data);
        await activity_log.ActivityLogger.log(
          action: 'create_transaction',
          module: 'finance',
          details: {'orgId': widget.orgId, 'amount': amount, 'type': _type},
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.beVietnamPro()),
      backgroundColor: OrgColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  void dispose() {
    _segmentCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 460,
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 32,
              offset: const Offset(0, 12),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: const BoxDecoration(
                color: OrgColors.lightGray,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: OrgColors.primaryDark.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long_outlined,
                        color: OrgColors.primaryDark, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isEdit ? 'Edit Transaction' : 'Add Record',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 17, fontWeight: FontWeight.w700,
                        color: OrgColors.charcoal),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 18, color: OrgColors.darkGray),
                    style: IconButton.styleFrom(
                      backgroundColor: OrgColors.mediumGray,
                      padding: const EdgeInsets.all(4),
                      minimumSize: const Size(28, 28),
                    ),
                  ),
                ],
              ),
            ),

            // Divider
            const Divider(height: 1, color: OrgColors.mediumGray),

            // Modal Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Transaction Type Toggle
                    _FieldLabel('TRANSACTION TYPE'),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: OrgColors.lightGray,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: OrgColors.primaryLight),
                      ),
                      child: Row(
                        children: [
                          _TypeToggle(
                            label: 'Expense',
                            isSelected: _type == 'expense',
                            selectedColor: OrgColors.error,
                            onTap: () => setState(() => _type = 'expense'),
                          ),
                          _TypeToggle(
                            label: 'Income',
                            isSelected: _type == 'income',
                            selectedColor: OrgColors.success,
                            onTap: () => setState(() => _type = 'income'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date & Amount Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('DATE'),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: _pickDate,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: OrgColors.primaryLight),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          DateFormat('MM/dd/yyyy').format(_selectedDate),
                                          style: GoogleFonts.beVietnamPro(
                                              fontSize: 13, color: OrgColors.charcoal),
                                        ),
                                      ),
                                      const Icon(Icons.calendar_today_outlined,
                                          size: 15, color: OrgColors.darkGray),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('AMOUNT'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _amountCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: GoogleFonts.beVietnamPro(fontSize: 13),
                                decoration: InputDecoration(
                                  prefixText: '₱ ',
                                  prefixStyle: GoogleFonts.beVietnamPro(
                                      fontSize: 13, color: OrgColors.darkGray),
                                  hintText: '0.00',
                                  hintStyle: GoogleFonts.beVietnamPro(
                                      fontSize: 13, color: OrgColors.mediumGray),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: OrgColors.primaryLight),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: OrgColors.primaryLight),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: OrgColors.primaryLight),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Event Name
                    _FieldLabel('EVENT NAME'),
                    const SizedBox(height: 6),
                    if (_loadingEvents)
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ))
                    else if (_events.isEmpty)
                      TextField(
                        onChanged: (v) => setState(() => _selectedEventName = v),
                        style: GoogleFonts.beVietnamPro(fontSize: 13),
                        decoration: _inputDecoration('e.g. Monthly Rent, Grocery Shopping'),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedEventId,
                        items: _events.map<DropdownMenuItem<String>>((event) {
                          return DropdownMenuItem<String>(
                            value: event['id'],
                            child: Text(event['name'],
                                style: GoogleFonts.beVietnamPro(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedEventId = value;
                            _selectedEventName = _events
                                .firstWhere((e) => e['id'] == value)['name'];
                          });
                        },
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 13, color: OrgColors.charcoal),
                        decoration: _inputDecoration('Select event'),
                      ),
                    const SizedBox(height: 16),

                    // Category
                    _FieldLabel('CATEGORY'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _category,
                      items: _categories.map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c, style: GoogleFonts.beVietnamPro(fontSize: 13)),
                          )).toList(),
                      onChanged: (v) => setState(() => _category = v!),
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 13, color: OrgColors.charcoal),
                      decoration: _inputDecoration('Select category'),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    _FieldLabel('DESCRIPTION (OPTIONAL)'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _segmentCtrl,
                      maxLines: 2,
                      style: GoogleFonts.beVietnamPro(fontSize: 13),
                      decoration: _inputDecoration('Add some notes about this transaction...'),
                    ),
                  ],
                ),
              ),
            ),

            // Divider
            const Divider(height: 1, color: OrgColors.mediumGray),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OrgColors.charcoal,
                      side: const BorderSide(color: OrgColors.primaryLight),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    child: Text('Cancel',
                        style: GoogleFonts.beVietnamPro(
                            fontWeight: FontWeight.w500, fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OrgColors.primaryDark,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      elevation: 0,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            _isEdit ? 'Save Edit' : 'Save Transaction',
                            style: GoogleFonts.beVietnamPro(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.beVietnamPro(
            fontSize: 13, color: OrgColors.mediumGray),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: OrgColors.primaryLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: OrgColors.primaryLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: OrgColors.primaryLight),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      );
}

// ============ HELPERS ============
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.beVietnamPro(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: OrgColors.darkGray,
            letterSpacing: 0.8));
  }
}

class _TypeToggle extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _TypeToggle({
    required this.label,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.beVietnamPro(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : OrgColors.darkGray,
            ),
          ),
        ),
      ),
    );
  }
}



