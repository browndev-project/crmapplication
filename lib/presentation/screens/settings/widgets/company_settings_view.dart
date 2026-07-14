import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/r2_service.dart';
import '../../../../data/models/company_settings_model.dart';
import '../../../providers/company_settings_provider.dart';
import '../../../providers/login_provider.dart';
import '../../../providers/company_provider.dart';

class CompanySettingsView extends ConsumerStatefulWidget {
  const CompanySettingsView({super.key});

  @override
  ConsumerState<CompanySettingsView> createState() => _CompanySettingsViewState();
}

class _CompanySettingsViewState extends ConsumerState<CompanySettingsView> {
  bool _isUploadingLogo = false;
  bool _isSavingTerms = false;
  bool _isSubmittingBank = false;
  bool _hasPrefilledTerms = false;

  // Form Controllers for Bank Account
  final _ownerController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _numberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _upiController = TextEditingController();
  bool _isDefaultValue = false;

  // Controller for Invoice Terms
  final _termsController = TextEditingController();

  // Active Bank Account being edited (null for Create Mode)
  BankAccount? _editingBankAccount;

  final _bankFormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _ownerController.dispose();
    _bankNameController.dispose();
    _numberController.dispose();
    _ifscController.dispose();
    _upiController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  void _clearBankForm() {
    setState(() {
      _ownerController.clear();
      _bankNameController.clear();
      _numberController.clear();
      _ifscController.clear();
      _upiController.clear();
      _isDefaultValue = false;
      _editingBankAccount = null;
    });
  }

  void _prefillBankForm(BankAccount bank) {
    setState(() {
      _editingBankAccount = bank;
      _ownerController.text = bank.accountOwner;
      _bankNameController.text = bank.bankName;
      _numberController.text = bank.accountNumber;
      _ifscController.text = bank.bankIfsc;
      _upiController.text = bank.upiId;
      _isDefaultValue = bank.isDefault;
    });
  }

  Future<void> _handleLogoUpload(String companyId) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.single.path == null) return;

      setState(() => _isUploadingLogo = true);

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final bytes = result.files.single.bytes ?? await file.readAsBytes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading company logo...'), backgroundColor: Colors.blue),
        );
      }

      final r2Service = R2Service();
      final extension = fileName.split('.').last.toLowerCase();
      final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';
      
      final r2Key = await r2Service.uploadFile(
        bytes,
        'company-logos/${companyId}_${DateTime.now().millisecondsSinceEpoch}.$extension',
        contentType,
      );

      if (r2Key != null) {
        final logoUrl = '${R2Service.publicBaseUrl}/$r2Key';
        final service = ref.read(settingsServiceProvider);
        
        await service.updateCompany(id: companyId, logo: logoUrl);

        // Force reload global company details and settings provider
        ref.invalidate(companySettingsProvider);
        ref.invalidate(companyProvider);
        await ref.read(companyProvider.notifier).fetchCompanyDetails();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logo uploaded and updated successfully!'), backgroundColor: Colors.green),
          );
        }
      } else {
        throw 'Failed to upload to Cloudflare storage';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  Future<void> _handleSaveInvoiceTerms(String companyId) async {
    setState(() => _isSavingTerms = true);
    try {
      final service = ref.read(settingsServiceProvider);
      await service.updateCompany(id: companyId, invoiceTerms: _termsController.text.trim());

      ref.invalidate(companySettingsProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice terms saved successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving terms: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingTerms = false);
    }
  }

  Future<void> _handleSaveBankAccount() async {
    if (!_bankFormKey.currentState!.validate()) return;

    final owner = _ownerController.text.trim();
    final bankName = _bankNameController.text.trim();
    final number = _numberController.text.trim();
    final ifsc = _ifscController.text.trim();
    final upi = _upiController.text.trim();

    setState(() => _isSubmittingBank = true);

    try {
      final service = ref.read(settingsServiceProvider);
      
      if (_editingBankAccount == null) {
        // Create Mode
        await service.createBankAccount(
          bankName: bankName,
          accountOwner: owner,
          accountNumber: number,
          bankIfsc: ifsc,
          upiId: upi,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bank account added successfully'), backgroundColor: Colors.green),
          );
        }
      } else {
        // Update Mode
        await service.updateBankAccount(
          id: _editingBankAccount!.id,
          bankName: bankName,
          accountOwner: owner,
          accountNumber: number,
          bankIfsc: ifsc,
          upiId: upi,
          isDefault: _isDefaultValue,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bank account updated successfully'), backgroundColor: Colors.green),
          );
        }
      }

      _clearBankForm();
      ref.invalidate(companySettingsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingBank = false);
    }
  }

  Future<void> _handleDeleteBank(BankAccount bank) async {
    final deleteConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: isDark ? const Color(0xFF1E2130) : Colors.white,
          title: Text(
            'Delete Bank Account?',
            style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
          ),
          content: Text(
            'Are you sure you want to delete ${bank.bankName} (${bank.accountNumber})?',
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (deleteConfirmed != true) return;

    try {
      final service = ref.read(settingsServiceProvider);
      await service.deleteBankAccount(bank.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank account deleted successfully'), backgroundColor: Colors.green),
        );
      }
      ref.invalidate(companySettingsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(loginProvider).user;

    // Enforce role-based access control (Admin / Company access only)
    final bool isAuthorized = user?.systemRole == 'company_admin' || user?.systemRole == 'company';
    if (!isAuthorized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: Card(
            elevation: 4,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: isDark ? const Color(0xFF1E2130) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 64, color: Colors.redAccent),
                  const SizedBox(height: 20),
                  Text(
                    'Access Denied',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You do not have permission to view or modify Company Settings. Only administrators can perform these operations.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final companyId = user?.company ?? '';
    final settingsAsync = ref.watch(companySettingsProvider);

    return settingsAsync.when(
      data: (settings) {
        final settingsModel = settings ?? CompanySettingsModel(bankAccounts: [], invoiceDefaultTerms: '', logo: '');
        if (settings != null && !_hasPrefilledTerms) {
          _termsController.text = settingsModel.invoiceDefaultTerms;
          _hasPrefilledTerms = true;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Company Configuration',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Branding, bank accounts presets, and global terms settings',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Card 1: Branding / Logo Card
            Card(
              elevation: 2,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: isDark ? Theme.of(context).cardColor : Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Company Branding',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Customize your business look by setting up your brand identity logo.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        // Logo Thumbnail Display
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.grey[300]!,
                              width: 1.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _isUploadingLogo
                                ? const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2.5),
                                    ),
                                  )
                                : (settingsModel.logo.isNotEmpty)
                                    ? Image.network(
                                        settingsModel.logo,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) => Icon(
                                          Icons.business,
                                          size: 40,
                                          color: isDark ? Colors.grey[700] : Colors.grey[400],
                                        ),
                                      )
                                    : Icon(
                                        Icons.business,
                                        size: 40,
                                        color: isDark ? Colors.grey[700] : Colors.grey[400],
                                      ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Action Info & Button
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'Your Business Logo',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Recommended size: Square (512x512px). Formats: PNG, JPG.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _isUploadingLogo ? null : () => _handleLogoUpload(companyId),
                                icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                                label: const Text(
                                  'UPLOAD LOGO',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? Colors.white : Colors.black,
                                  foregroundColor: isDark ? Colors.black : Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Card 2: Inline Bank Accounts form and List
            Card(
              elevation: 2,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: isDark ? Theme.of(context).cardColor : Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _editingBankAccount == null
                              ? 'Add Preset Bank Account'
                              : 'Edit Bank Account Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (_editingBankAccount != null)
                          TextButton.icon(
                            onPressed: _clearBankForm,
                            icon: const Icon(Icons.close, size: 14),
                            label: const Text('Cancel Edit'),
                            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Register banks to quickly populate financial details in Invoice workflows.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Inline Bank Account Form
                    Form(
                      key: _bankFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildInlineField(
                            'Bank Name',
                            _bankNameController,
                            isDark,
                            validator: (v) => v!.isEmpty ? 'Bank Name is required' : null,
                          ),
                          const SizedBox(height: 16),
                          _buildInlineField(
                            'Account Owner Name',
                            _ownerController,
                            isDark,
                            validator: (v) => v!.isEmpty ? 'Owner is required' : null,
                          ),
                          const SizedBox(height: 16),
                          _buildInlineField(
                            'Account Number',
                            _numberController,
                            isDark,
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'Number is required' : null,
                          ),
                          const SizedBox(height: 16),
                          _buildInlineField(
                            'IFSC Code',
                            _ifscController,
                            isDark,
                            capitalization: TextCapitalization.characters,
                            validator: (v) => v!.isEmpty ? 'IFSC is required' : null,
                          ),
                          const SizedBox(height: 16),
                          _buildInlineField(
                            'UPI ID (Optional)',
                            _upiController,
                            isDark,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Set as default bank account',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                                  ),
                                ),
                                Switch(
                                  value: _isDefaultValue,
                                  onChanged: (val) {
                                    setState(() {
                                      _isDefaultValue = val;
                                    });
                                  },
                                  activeThumbColor: isDark ? Colors.blue : Colors.black,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: _isSubmittingBank ? null : _handleSaveBankAccount,
                              icon: _isSubmittingBank
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Icon(_editingBankAccount == null ? Icons.save : Icons.update, size: 16),
                              label: Text(
                                _editingBankAccount == null ? 'SAVE BANK' : 'UPDATE BANK',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? Colors.blue : Colors.black,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    const Divider(height: 1),
                    const SizedBox(height: 24),

                    Text(
                      'Saved Preset Bank Accounts',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Grid of Saved Preset Bank Accounts
                    if (settingsModel.bankAccounts.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 48,
                                color: isDark ? Colors.grey[700] : Colors.grey[300],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No registered bank accounts yet.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: settingsModel.bankAccounts.length,
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 380,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          mainAxisExtent: 180,
                        ),
                        itemBuilder: (context, index) {
                          final bank = settingsModel.bankAccounts[index];
                          // Securely mask bank account number
                          final String maskedNo = bank.accountNumber.length > 4
                              ? '•••• ${bank.accountNumber.substring(bank.accountNumber.length - 4)}'
                              : bank.accountNumber;

                          return Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.01) : Colors.grey[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: bank.isDefault
                                    ? (isDark ? Colors.blue.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.4))
                                    : (isDark ? Colors.white10 : Colors.grey[300]!),
                                width: bank.isDefault ? 1.5 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.account_balance,
                                            color: isDark ? Colors.blue.shade300 : Colors.black87,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              bank.bankName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (bank.isDefault)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (isDark ? Colors.blue : Colors.black).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'DEFAULT',
                                          style: TextStyle(
                                            color: isDark ? Colors.blue.shade300 : Colors.black,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 8,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildCardItem('Owner', bank.accountOwner, isDark),
                                const SizedBox(height: 6),
                                _buildCardItem('Account No.', maskedNo, isDark),
                                const SizedBox(height: 6),
                                _buildCardItem('IFSC Code', bank.bankIfsc, isDark),
                                if (bank.upiId.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  _buildCardItem('UPI ID', bank.upiId, isDark),
                                ],
                                const Spacer(),
                                const Divider(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 16),
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      tooltip: 'Edit Preset',
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                      onPressed: () => _prefillBankForm(bank),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 16),
                                      color: Colors.redAccent,
                                      tooltip: 'Delete Preset',
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                      onPressed: () => _handleDeleteBank(bank),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Card 3: Invoice default terms Card
            Card(
              elevation: 2,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: isDark ? Theme.of(context).cardColor : Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Global Invoice Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Set standard default terms, conditions, and payment notes embedded on invoices.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Multi-line Text Area for Invoice Default Terms
                    TextFormField(
                      controller: _termsController,
                      maxLines: 6,
                      style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'e.g. 1. Interest will be charged at 18% p.a. after due date.\n2. Goods once sold will not be taken back.',
                        hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: isDark ? Colors.blue : Colors.black, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _isSavingTerms ? null : () => _handleSaveInvoiceTerms(companyId),
                        icon: _isSavingTerms
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.check, size: 16),
                        label: const Text(
                          'SAVE TERMS',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.blue : Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(64.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 54, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Failed to load company settings',
                style: TextStyle(
                  color: Colors.red.shade300,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(companySettingsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineField(
    String label,
    TextEditingController controller,
    bool isDark, {
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      validator: validator,
      style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
        isDense: true,
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: isDark ? Colors.blue : Colors.black, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildCardItem(String label, String value, bool isDark) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

