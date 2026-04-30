import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart'; // <-- Added Shimmer import

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final supabase = Supabase.instance.client;
  
  // Advanced Date Filter State
  String _activeDateFilter = 'All Time';
  DateTimeRange? _customDateRange;
  
  bool _isLoading = true;
  List<dynamic> _allClaims = [];
  
  // Filtering & Search State
  String _searchQuery = '';
  String _activeFilter = 'All'; // 'All', 'Pending', 'Approved', 'Rejected'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchClaims();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchClaims() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('claims')
          .select()
          .eq('user_id', userId)
          .order('claim_date', ascending: false);

      if (mounted) {
        setState(() {
          _allClaims = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching claims: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FILTERING & GROUPING LOGIC ---
  List<dynamic> get _filteredClaims {
    return _allClaims.where((claim) {
      // 1. Apply Search Query
      final provider = (claim['provider_name'] ?? '').toString().toLowerCase();
      final treatment = (claim['treatment_description'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      final matchesSearch = provider.contains(query) || treatment.contains(query);

      // 2. Apply Status Filter
      final status = (claim['status'] ?? '').toString().toLowerCase();
      final matchesFilter = _activeFilter == 'All' || status == _activeFilter.toLowerCase();

      // 3. Apply Date Filter
      bool matchesDate = true;
      final claimDateStr = claim['claim_date'];
      
      if (claimDateStr != null) {
        final claimDate = DateTime.parse(claimDateStr);
        final now = DateTime.now();
        
        if (_activeDateFilter == 'Last 30 Days') {
          matchesDate = now.difference(claimDate).inDays <= 30;
        } else if (_activeDateFilter == 'Last 6 Months') {
          // approx 180 days
          matchesDate = now.difference(claimDate).inDays <= 180;
        } else if (_activeDateFilter == 'This Year') {
          matchesDate = claimDate.year == now.year;
        } else if (_activeDateFilter == 'Custom' && _customDateRange != null) {
          // Check if date falls within the selected custom range
          matchesDate = claimDate.isAfter(_customDateRange!.start.subtract(const Duration(days: 1))) && 
                        claimDate.isBefore(_customDateRange!.end.add(const Duration(days: 1)));
        }
      }

      return matchesSearch && matchesFilter && matchesDate;
    }).toList();
  }

  Map<String, List<dynamic>> _groupClaimsByMonth(List<dynamic> claims) {
    final Map<String, List<dynamic>> grouped = {};
    
    for (var claim in claims) {
      final dateStr = claim['claim_date'];
      if (dateStr == null) continue;
      
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      
      String groupKey;
      if (date.year == now.year && date.month == now.month) {
        groupKey = 'This Month';
      } else {
        groupKey = DateFormat('MMMM yyyy').format(date);
      }

      if (!grouped.containsKey(groupKey)) grouped[groupKey] = [];
      grouped[groupKey]!.add(claim);
    }
    return grouped;
  }

  // --- BOTTOM SHEET (CLAIM DETAILS) ---
  void _showClaimDetails(Map<String, dynamic> claim) {
    final amount = double.tryParse(claim['amount'].toString()) ?? 0.0;
    final status = (claim['status'] ?? 'pending').toString().toLowerCase();
    
    double covered = 0.0;
    double shortfall = 0.0;
    String rejectionReason = '';

    if (status == 'approved') {
      covered = amount;
    } else if (status == 'rejected') {
      shortfall = amount;
      rejectionReason = "Exceeded annual limit.";
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4, 
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              Text(claim['provider_name'] ?? 'Unknown Provider', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(claim['treatment_description'] ?? 'Medical Service', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              const SizedBox(height: 24),
              
              // Breakdown Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200)
                ),
                child: Column(
                  children: [
                    _buildBreakdownRow('Total Billed', amount, isBold: true),
                    const Divider(height: 24),
                    _buildBreakdownRow('Covered by Aid', covered, color: Colors.green),
                    const SizedBox(height: 12),
                    _buildBreakdownRow('Patient Shortfall', shortfall, color: shortfall > 0 ? Colors.red : Colors.black87),
                  ],
                ),
              ),

              if (status == 'rejected') ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Rejection Reason', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(rejectionReason, style: TextStyle(color: Colors.red.shade900, fontSize: 14)),
                          ],
                        ),
                      )
                    ],
                  ),
                )
              ],
              const SizedBox(height: 40),
            ],
          ),
        );
      }
    );
  }

  // --- BOTTOM SHEET (DATE FILTER) ---
  void _showDateFilterBottomSheet() {
    // Temporary variables for the bottom sheet state before "Apply" is pressed
    String tempDateFilter = _activeDateFilter;
    DateTimeRange? tempCustomRange = _customDateRange;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            
            Widget buildRadioTile(String title) {
              return RadioListTile<String>(
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                value: title,
                groupValue: tempDateFilter,
                activeColor: Colors.blueAccent,
                onChanged: (value) {
                  setModalState(() => tempDateFilter = value!);
                },
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4, 
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Filter by Date', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    
                    buildRadioTile('All Time'),
                    buildRadioTile('Last 30 Days'),
                    buildRadioTile('Last 6 Months'),
                    buildRadioTile('This Year'),
                    
                    // Custom Date Picker option
                    RadioListTile<String>(
                      title: const Text('Custom Range', style: TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: tempDateFilter == 'Custom' && tempCustomRange != null
                          ? Text('${DateFormat('MMM d').format(tempCustomRange!.start)} - ${DateFormat('MMM d, yyyy').format(tempCustomRange!.end)}')
                          : null,
                      value: 'Custom',
                      groupValue: tempDateFilter,
                      activeColor: Colors.blueAccent,
                      onChanged: (value) async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(primary: Colors.blueAccent),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setModalState(() {
                            tempDateFilter = 'Custom';
                            tempCustomRange = picked;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 24),
                    
                    // Apply Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        ),
                        onPressed: () {
                          // Save the choices and rebuild the main screen
                          setState(() {
                            _activeDateFilter = tempDateFilter;
                            _customDateRange = tempCustomRange;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Apply Filter', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildBreakdownRow(String label, double amount, {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 15, color: Colors.grey.shade700, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(
          NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount),
          style: TextStyle(fontSize: 16, color: color ?? Colors.black87, fontWeight: isBold ? FontWeight.bold : FontWeight.w600),
        ),
      ],
    );
  }

  // --- UI WIDGETS ---

  // <-- THE NEW SKELETON LOADER FOR HISTORY -->
  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 40),
        itemCount: 3, // Show 3 fake months/groups
        itemBuilder: (context, index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fake Group Header (Month/Year)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 8),
                child: Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              // 2 Fake Claim Cards per group
              ...List.generate(2, (cardIndex) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Row(
                  children: [
                    // Fake Icon Avatar
                    Container(
                      width: 48, height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Fake Text Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 140,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Fake Amount
                    Container(
                      width: 60,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ))
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildFilterChip(String label, Color color) {
    final isActive = _activeFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive 
            ? (label == 'All' ? Colors.black : color.withOpacity(0.1)) 
            : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive 
              ? (label == 'All' ? Colors.black : color) 
              : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isActive 
              ? (label == 'All' ? Colors.white : color) 
              : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildClaimCard(Map<String, dynamic> claim) {
    final status = (claim['status'] ?? 'pending').toString().toLowerCase();
    final amount = double.tryParse(claim['amount'].toString()) ?? 0.0;
    
    Color statusColor;
    IconData statusIcon;
    String displayAmount;
    Color amountColor;

    if (status == 'approved') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
      displayAmount = '+${NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount)}';
      amountColor = Colors.green;
    } else if (status == 'rejected') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel_outlined;
      displayAmount = '-${NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount)}';
      amountColor = Colors.red;
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.access_time;
      displayAmount = NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount);
      amountColor = Colors.black87;
    }

    final date = DateTime.tryParse(claim['claim_date'] ?? '');
    final dateString = date != null ? DateFormat('MMM dd, yyyy').format(date) : '';

    return InkWell(
      onTap: () => _showClaimDetails(claim),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          children: [
            // Status Icon
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(statusIcon, color: statusColor, size: 24),
            ),
            const SizedBox(width: 16),
            
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(claim['provider_name'] ?? 'Unknown Provider', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('$dateString • ID: ${claim['id'].toString().substring(0, 8).toUpperCase()}', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            ),
            
            // The Money
            Text(
              displayAmount,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: amountColor),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final claimsToDisplay = _filteredClaims;
    final groupedClaims = _groupClaimsByMonth(claimsToDisplay);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Updated to match Notifications
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black), // Added IconTheme
        title: const Text(
          'Activity', 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold), // Matched font style
        ),
      ),
      body: Column(
        children: [
          // --- 1. SEARCH BAR ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search by provider or treatment',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Advanced Filters Icon
                Container(
                  decoration: BoxDecoration(
                    color: _activeDateFilter != 'All Time' 
                        ? Colors.blueAccent.withOpacity(0.1) 
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _activeDateFilter != 'All Time' 
                          ? Colors.blueAccent 
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.tune, 
                      color: _activeDateFilter != 'All Time' ? Colors.blueAccent : Colors.black87,
                    ),
                    onPressed: _showDateFilterBottomSheet, // Hooked up!
                  ),
                ),
              ], // FIXED: Added missing closing bracket for the Row children
            ),
          ),

          // --- 2. QUICK FILTERS (CHIPS) ---
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('All', Colors.black),
                _buildFilterChip('Pending', Colors.orange),
                _buildFilterChip('Approved', Colors.green),
                _buildFilterChip('Rejected', Colors.red),
              ],
            ),
          ),

          // --- 3. TIMELINE & CLAIM CARDS ---
          Expanded(
            child: _isLoading 
              ? _buildSkeletonLoader() // <-- Replaced CircularProgressIndicator here
              : claimsToDisplay.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No claims found.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 40),
                    itemCount: groupedClaims.length,
                    itemBuilder: (context, index) {
                      String monthKey = groupedClaims.keys.elementAt(index);
                      List<dynamic> monthClaims = groupedClaims[monthKey]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Group Header ("This Month", "March 2024")
                          Padding(
                            padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 8),
                            child: Text(
                              monthKey,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                            ),
                          ),
                          // The Cards for this month
                          Container(
                            color: Colors.white,
                            child: Column(
                              children: monthClaims.map((claim) => _buildClaimCard(claim)).toList(),
                            ),
                          )
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}