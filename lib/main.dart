import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SubTrackerApp());
}

class SubscriptionItem {
  final String id;
  final String name;
  final double amount;
  final DateTime dueDate;
  final String category; // e.g. Mobile, OTT, Utility

  SubscriptionItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    required this.category,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'amount': amount,
        'dueDate': dueDate.toIso8601String(),
        'category': category,
      };

  factory SubscriptionItem.fromMap(Map<String, dynamic> map) => SubscriptionItem(
        id: map['id'],
        name: map['name'],
        amount: (map['amount'] as num).toDouble(),
        dueDate: DateTime.parse(map['dueDate']),
        category: map['category'] ?? 'General',
      );
}

class SubTrackerApp extends StatelessWidget {
  const SubTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SubTracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SubscriptionItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final rawData = prefs.getString('subscriptions_list');
    if (rawData != null && rawData.isNotEmpty) {
      final List decoded = jsonDecode(rawData);
      setState(() {
        _items = decoded.map((m) => SubscriptionItem.fromMap(m)).toList();
        _items.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        _isLoading = false;
      });
    } else {
      // Default sample items
      setState(() {
        _items = [
          SubscriptionItem(
            id: const Uuid().v4(),
            name: 'Jio Mobile Recharge',
            amount: 749.0,
            dueDate: DateTime.now().add(const Duration(days: 4)),
            category: 'Mobile',
          ),
          SubscriptionItem(
            id: const Uuid().v4(),
            name: 'Netflix Premium',
            amount: 649.0,
            dueDate: DateTime.now().add(const Duration(days: 12)),
            category: 'Streaming',
          ),
        ];
        _isLoading = false;
      });
      _persistAndSync();
    }
  }

  Future<void> _persistAndSync() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_items.map((i) => i.toMap()).toList());
    await prefs.setString('subscriptions_list', encoded);
    await _updateAndroidWidget();
  }

  Future<void> _updateAndroidWidget() async {
    if (_items.isEmpty) {
      await HomeWidget.saveWidgetData<String>('service_name', 'No upcoming bills');
      await HomeWidget.saveWidgetData<String>('due_info', 'All clear!');
      await HomeWidget.saveWidgetData<String>('total_monthly', '₹0');
    } else {
      // Pick the earliest due
      final next = _items.first;
      final daysLeft = next.dueDate.difference(DateTime.now()).inDays;
      String dueStr;
      if (daysLeft < 0) {
        dueStr = 'Overdue by \${daysLeft.abs()}d';
      } else if (daysLeft == 0) {
        dueStr = 'Due today!';
      } else {
        dueStr = 'Due in \${daysLeft}d';
      }

      final total = _items.fold<double>(0, (sum, item) => sum + item.amount);

      await HomeWidget.saveWidgetData<String>('service_name', next.name);
      await HomeWidget.saveWidgetData<String>(
          'due_info', '$dueStr • ₹\${next.amount.toStringAsFixed(0)}');
      await HomeWidget.saveWidgetData<String>(
          'total_monthly', '₹\${total.toStringAsFixed(0)}');
    }

    await HomeWidget.updateWidget(
      name: 'SubscriptionWidgetProvider',
      androidName: 'SubscriptionWidgetProvider',
    );
  }

  void _addOrEditSubscription([SubscriptionItem? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final amountCtrl =
        TextEditingController(text: existing != null ? existing.amount.toString() : '');
    DateTime selectedDate = existing?.dueDate ?? DateTime.now().add(const Duration(days: 30));
    String category = existing?.category ?? 'Mobile';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null ? 'Add Subscription' : 'Edit Subscription',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Service Name (e.g. Jio, Airtel, Netflix)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF334155),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF334155),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Due Date: \${DateFormat('dd MMM yyyy').format(selectedDate)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: const Text('Pick Date'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                  )
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                    if (name.isEmpty || amount <= 0) return;

                    setState(() {
                      if (existing == null) {
                        _items.add(SubscriptionItem(
                          id: const Uuid().v4(),
                          name: name,
                          amount: amount,
                          dueDate: selectedDate,
                          category: category,
                        ));
                      } else {
                        final idx = _items.indexWhere((i) => i.id == existing.id);
                        if (idx != -1) {
                          _items[idx] = SubscriptionItem(
                            id: existing.id,
                            name: name,
                            amount: amount,
                            dueDate: selectedDate,
                            category: category,
                          );
                        }
                      }
                      _items.sort((a, b) => a.dueDate.compareTo(b.dueDate));
                    });
                    _persistAndSync();
                    Navigator.pop(ctx);
                  },
                  child: Text(existing == null ? 'Save Subscription' : 'Update Subscription'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _markPaid(SubscriptionItem item) {
    setState(() {
      final idx = _items.indexWhere((i) => i.id == item.id);
      if (idx != -1) {
        // Roll forward by 30 days
        _items[idx] = SubscriptionItem(
          id: item.id,
          name: item.name,
          amount: item.amount,
          dueDate: item.dueDate.add(const Duration(days: 30)),
          category: item.category,
        );
        _items.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      }
    });
    _persistAndSync();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rolled \${item.name} forward 30 days!')),
    );
  }

  void _deleteItem(String id) {
    setState(() {
      _items.removeWhere((i) => i.id == id);
    });
    _persistAndSync();
  }

  @override
  Widget build(BuildContext context) {
    final totalMonthly = _items.fold<double>(0, (sum, i) => sum + i.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SubTracker & Recharges', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigoAccent,
        onPressed: () => _addOrEditSubscription(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Monthly Spend',
                              style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('₹\${totalMonthly.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Active Subscriptions',
                              style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('\${_items.length}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: const [
                      Text('Upcoming Bills & Recharges',
                          style: TextStyle(
                              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(
                          child: Text('No subscriptions added yet.',
                              style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final item = _items[idx];
                            final daysLeft = item.dueDate.difference(DateTime.now()).inDays;
                            final isDueSoon = daysLeft <= 3;

                            return Dismissible(
                              key: Key(item.id),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (_) => _deleteItem(item.id),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDueSoon
                                        ? Colors.amber.withOpacity(0.5)
                                        : Colors.white10,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: isDueSoon
                                          ? Colors.amber.withOpacity(0.2)
                                          : Colors.indigo.withOpacity(0.2),
                                      child: Icon(
                                        Icons.receipt_long,
                                        color: isDueSoon ? Colors.amberAccent : Colors.indigoAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Due \${DateFormat('dd MMM').format(item.dueDate)} (\${daysLeft < 0 ? "Overdue" : "$daysLeft days left"})',
                                            style: TextStyle(
                                              color: isDueSoon ? Colors.amber : Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('₹\${item.amount.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                        const SizedBox(height: 4),
                                        InkWell(
                                          onTap: () => _markPaid(item),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('Mark Paid',
                                                style: TextStyle(
                                                    color: Colors.greenAccent, fontSize: 11)),
                                          ),
                                        )
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
