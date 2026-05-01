import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

class SubmitClaimScreen extends StatefulWidget {
  const SubmitClaimScreen({super.key});

  @override
  State<SubmitClaimScreen> createState() => _SubmitClaimScreenState();
}

class _SubmitClaimScreenState extends State<SubmitClaimScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _providerController = TextEditingController();
  final _treatmentController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  // File Upload State (Web-Safe Bytes)
  Uint8List? _selectedFileBytes;
  String? _fileName;
  String? _fileSizeStr;
  
  // Submission State
  bool _isSubmitting = false;

  @override
  void dispose() {
    _providerController.dispose();
    _treatmentController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // --- UI INTERACTION METHODS ---

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.black),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showFilePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Colors.blue),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Colors.purple),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined, color: Colors.orange),
                title: const Text('Upload PDF / Document'),
                onTap: () {
                  Navigator.pop(context);
                  _pickDocument();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      }
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedFileBytes = bytes;
        _fileName = pickedFile.name;
        _fileSizeStr = '${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB';
      });
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      withData: true, 
    );

    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      setState(() {
        _selectedFileBytes = bytes;
        _fileName = result.files.single.name;
        _fileSizeStr = '${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB';
      });
    }
  }
  
  void _removeFile() {
    setState(() {
      _selectedFileBytes = null;
      _fileName = null;
      _fileSizeStr = null;
    });
  }

  // --- SUBMISSION LOGIC ---

  Future<void> _submitClaim() async {
    if (!_formKey.currentState!.validate() || _selectedFileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and upload a document.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = _supabase.auth.currentUser!.id;
      final amount = double.parse(_amountController.text.replaceAll(',', ''));
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // Insert Claim into public.claims
      final claimResponse = await _supabase.from('claims').insert({
        'user_id': userId,
        'claim_date': formattedDate,
        'provider_name': _providerController.text.trim(),
        'treatment_description': _treatmentController.text.trim(),
        'amount': amount,
        'status': 'pending',
      }).select('id').single();

      final claimId = claimResponse['id'];

      // 2. Upload Document to Storage (Bucket: docs)
      final fileExtension = _fileName != null ? path.extension(_fileName!) : '.pdf';
      final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      final storagePath = '$userId/$claimId/$uniqueFileName';

      await _supabase.storage.from('docs').uploadBinary(
        storagePath,
        _selectedFileBytes!,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );
      final publicUrl = _supabase.storage.from('docs').getPublicUrl(storagePath);

      // Link Document in public.claim_documents
      await _supabase.from('claim_documents').insert({
        'claim_id': claimId,
        'document_url': publicUrl,
      });
      // Link Document in public.claim_documents
      await _supabase.from('claim_documents').insert({
        'claim_id': claimId,
        'document_url': publicUrl,
      });

      // Create a Notification
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': 'Claim Submitted',
        'message': 'Your claim for \$${amount.toStringAsFixed(2)} at ${_providerController.text.trim()} has been submitted and is pending review.',
      });

      // Success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text('Claim submitted successfully!')]),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); 
      }
    } catch (e) {
      debugPrint('Error submitting claim: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    // Check if the form is fully valid to enable the button visually
    final isFormValid = _providerController.text.isNotEmpty && 
                        _treatmentController.text.isNotEmpty && 
                        _amountController.text.isNotEmpty && 
                        _selectedFileBytes != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Submit New Claim', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      
                      // --- SECTION 1: FINANCIALS (Big & Bold at the top) ---
                      const Text('Claim Amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')), 
                        ],
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black),
                        decoration: InputDecoration(
                          prefixText: '\$ ',
                          prefixStyle: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black),
                          hintText: '0.00',
                          hintStyle: TextStyle(fontSize: 40, color: Colors.grey.shade300),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Amount is required' : null,
                        onChanged: (val) => setState((){}), 
                      ),
                      
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 32),

                      // --- SECTION 2: SERVICE DETAILS ---
                      const Text('Provider Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _providerController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Dr. Sarah Jenkins',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent)),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Provider name is required' : null,
                        onChanged: (val) => setState((){}),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      const Text('Date of Service', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _pickDate(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200)
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('MMMM d, yyyy').format(_selectedDate), style: const TextStyle(fontSize: 16, color: Colors.black87)),
                              Icon(Icons.calendar_today_outlined, color: Colors.grey.shade600, size: 20),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text('Treatment Description', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _treatmentController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'e.g. Routine dental checkup and X-rays',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent)),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Description is required' : null,
                        onChanged: (val) => setState((){}),
                      ),

                      const SizedBox(height: 32),

                      // --- SECTION 3: DOCUMENTS ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Supporting Document', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                          if (_selectedFileBytes == null)
                            const Text('* Required', style: TextStyle(fontSize: 12, color: Colors.red)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_selectedFileBytes == null)
                        InkWell(
                          onTap: _showFilePickerOptions,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.blue.shade200, style: BorderStyle.solid, width: 2),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                                  child: const Icon(Icons.cloud_upload_outlined, color: Colors.blueAccent, size: 32),
                                ),
                                const SizedBox(height: 16),
                                const Text('Tap to upload receipt or invoice', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('JPG, PNG or PDF (Max 10MB)', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300)
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                                child: Icon(
                                  _fileName!.endsWith('.pdf') ? Icons.picture_as_pdf : Icons.image,
                                  color: Colors.blueAccent,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_fileName!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(_fileSizeStr ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: _removeFile,
                              )
                            ],
                          ),
                        ),
                        
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // --- STICKY SUBMIT BUTTON ---
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade100)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFormValid ? Colors.black : Colors.grey.shade300,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      elevation: 0,
                    ),
                    onPressed: (_isSubmitting || !isFormValid) ? null : _submitClaim,
                    child: _isSubmitting
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Submit Claim', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}