import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/promo_campaign_service.dart';
import '../whatsapp/widgets/whatsapp_icon.dart';

enum PromoStep {
  phoneEntry,
  otpVerification,
  detailsEntry,
  myOrders,
  paytmCheckout,
  orderSuccess,
}

class PromoCampaignScreen extends StatefulWidget {
  final Map<String, dynamic>? initialPromoData;
  const PromoCampaignScreen({super.key, this.initialPromoData});

  @override
  State<PromoCampaignScreen> createState() => _PromoCampaignScreenState();
}

class _PromoCampaignScreenState extends State<PromoCampaignScreen> {
  PromoStep _currentStep = PromoStep.phoneEntry;
  final List<PromoStep> _stepStack = [PromoStep.phoneEntry];

  void _navigateToStep(PromoStep nextStep) {
    if (mounted) {
      setState(() {
        if (_stepStack.isEmpty || _stepStack.last != nextStep) {
          _stepStack.add(nextStep);
        }
        _currentStep = nextStep;
      });
    }
  }

  void _resetToStep(PromoStep step) {
    if (mounted) {
      setState(() {
        _stepStack.clear();
        _stepStack.add(step);
        _currentStep = step;
      });
    }
  }

  void _handleBackNavigation() {
    HapticFeedback.lightImpact();
    if (_stepStack.length > 1) {
      setState(() {
        _stepStack.removeLast();
        _currentStep = _stepStack.last;
      });
    } else {
      Navigator.pop(context);
    }
  }

  // Controllers
  final _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();

  String _selectedType = 'Channel Partner';
  String _selectedCity = 'Noida';

  // State flags
  bool _isLoading = false;
  bool _isWebViewLoading = true;
  int _timerSeconds = 45;
  Timer? _resendTimer;

  // Verified Data
  String _verifiedPhoneNo = '';
  String _leadId = '';
  List<dynamic> _alreadyPurchasedSheets = [];
  Map<String, dynamic> _lastSuccessOrder = {};

  // Paytm Checkout URL
  String _checkoutUrl = '';

  // Banner image URL fallback
  final String _defaultBigBannerUrl =
      'https://treviondocs.browndevs.com/campaign/sale_big.png';

  final List<String> _businessTypes = [
    'Channel Partner',
    'Broker',
    'Builder/Developer',
  ];

  List<String> _citiesList = [
    'Ahmedabad',
    'Bengaluru',
    'Chandigarh',
    'Chennai',
    'Delhi',
    'Greater Noida',
    'Gurugram',
    'Hyderabad',
    'Mumbai',
    'Navi Mumbai',
    'Noida',
    'Pune',
  ];

  @override
  void initState() {
    super.initState();
    _fetchCitiesFromApi();
    _checkSavedSession();
  }

  Future<void> _fetchCitiesFromApi() async {
    final apiCities = await PromoCampaignService.fetchCities();
    if (apiCities.isNotEmpty && mounted) {
      setState(() {
        _citiesList = apiCities;
        if (!_citiesList.contains(_selectedCity)) {
          _selectedCity = _citiesList.first;
        }
      });
    }
  }

  Future<void> _checkSavedSession() async {
    final savedAuth = await PromoCampaignService.getPromoAuth();
    if (savedAuth != null && savedAuth['isAuthenticated'] == true) {
      final phone = savedAuth['phoneNo'] ?? '';
      final cachedLead = savedAuth['lead'] ?? {};
      final cachedPurchased = savedAuth['alreadyPurchased'] as List? ?? [];

      if (mounted) {
        setState(() {
          _verifiedPhoneNo = phone;
          _alreadyPurchasedSheets = cachedPurchased;
          _leadId = cachedLead['leadId'] ?? '';
          _nameController.text = cachedLead['name'] ?? '';
          _emailController.text = cachedLead['email'] ?? '';
          _companyController.text = cachedLead['companyName'] ?? '';
          if (cachedLead['type'] != null && _businessTypes.contains(cachedLead['type'])) {
            _selectedType = cachedLead['type'];
          }

          if (cachedPurchased.isNotEmpty) {
            _resetToStep(PromoStep.myOrders);
          } else {
            _resetToStep(PromoStep.phoneEntry);
          }
        });
      }

      // Asynchronously fetch fresh data from server
      if (phone.isNotEmpty) {
        final res = await PromoCampaignService.fetchUserData(phone);
        if (res['success'] == true && mounted) {
          final data = res['data'] ?? {};
          final freshLead = data['lead'] ?? {};
          final freshPurchased = data['alreadyPurchased'] as List? ?? [];

          setState(() {
            _alreadyPurchasedSheets = freshPurchased;
            _leadId = freshLead['leadId'] ?? _leadId;
            if (freshLead['name'] != null && freshLead['name'].toString().isNotEmpty) {
              _nameController.text = freshLead['name'];
            }
            if (freshLead['email'] != null && freshLead['email'].toString().isNotEmpty) {
              _emailController.text = freshLead['email'];
            }
            if (freshLead['companyName'] != null && freshLead['companyName'].toString().isNotEmpty) {
              _companyController.text = freshLead['companyName'];
            }
            if (freshLead['type'] != null && _businessTypes.contains(freshLead['type'])) {
              _selectedType = freshLead['type'];
            }

            if (freshPurchased.isNotEmpty) {
              _resetToStep(PromoStep.myOrders);
            } else {
              _resetToStep(PromoStep.phoneEntry);
            }
          });
        }
      }
    }
  }

  Future<void> _refreshUserData() async {
    if (_verifiedPhoneNo.isEmpty) return;
    setState(() => _isLoading = true);
    final res = await PromoCampaignService.fetchUserData(_verifiedPhoneNo);
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      final data = res['data'] ?? {};
      final purchased = data['alreadyPurchased'] as List? ?? [];
      final lead = data['lead'] as Map? ?? {};

      if (mounted) {
        setState(() {
          _alreadyPurchasedSheets = purchased;
          _leadId = lead['leadId'] ?? _leadId;
          if (lead['name'] != null && lead['name'].toString().isNotEmpty) {
            _nameController.text = lead['name'];
          }
          if (lead['email'] != null && lead['email'].toString().isNotEmpty) {
            _emailController.text = lead['email'];
          }
          if (lead['companyName'] != null && lead['companyName'].toString().isNotEmpty) {
            _companyController.text = lead['companyName'];
          }
          if (lead['type'] != null && _businessTypes.contains(lead['type'])) {
            _selectedType = lead['type'];
          }
        });
      }
    }
  }

  void _handleViewOrderDetails() async {
    await _refreshUserData();
    if (mounted) {
      _navigateToStep(PromoStep.myOrders);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    _nameController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _timerSeconds = 45);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        if (mounted) setState(() => _timerSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  // Action: Send OTP
  Future<void> _handleSendOtp() async {
    HapticFeedback.lightImpact();
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit phone number')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final res = await PromoCampaignService.sendOtp(rawPhone);
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      _verifiedPhoneNo = rawPhone;
      _navigateToStep(PromoStep.otpVerification);
      _startResendTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'OTP sent via WhatsApp')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Action: Verify OTP
  Future<void> _handleVerifyOtp() async {
    final otpCode = _otpControllers.map((c) => c.text).join();
    if (otpCode.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the complete 4-digit OTP')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final res = await PromoCampaignService.verifyOtp(_verifiedPhoneNo, otpCode);
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      final data = res['data'] ?? {};
      final purchased = data['alreadyPurchased'] as List? ?? [];
      final lead = data['lead'] as Map? ?? {};

      setState(() {
        _alreadyPurchasedSheets = purchased;
        _leadId = lead['leadId'] ?? '';
        if (lead['name'] != null && lead['name'].toString().isNotEmpty) {
          _nameController.text = lead['name'];
        }
        if (lead['email'] != null && lead['email'].toString().isNotEmpty) {
          _emailController.text = lead['email'];
        }
        if (lead['companyName'] != null && lead['companyName'].toString().isNotEmpty) {
          _companyController.text = lead['companyName'];
        }
        if (lead['type'] != null && _businessTypes.contains(lead['type'])) {
          _selectedType = lead['type'];
        }

        if (purchased.isNotEmpty) {
          _resetToStep(PromoStep.myOrders);
        } else {
          _navigateToStep(PromoStep.detailsEntry);
        }
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Action: Submit Details & Initiate Paytm Payment
  Future<void> _handleSubmitDetailsAndPay() async {
    HapticFeedback.lightImpact();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final company = _companyController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both Name and Email')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Step 1: Update Lead Details
    final updateRes = await PromoCampaignService.updateDetails(
      phoneNo: _verifiedPhoneNo,
      name: name,
      email: email,
      companyName: company.isNotEmpty ? company : name,
      type: _selectedType,
      targetCity: _selectedCity,
    );

    if (updateRes['success'] != true) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(updateRes['message']), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final updatedLeadId = updateRes['data']?['leadId'] ?? _leadId;
    _leadId = updatedLeadId;

    // Step 2: Initiate Paytm Payment
    final payRes = await PromoCampaignService.initiatePaytmPayment(
      leadId: _leadId,
      phoneNo: _verifiedPhoneNo,
      name: name,
      email: email,
      companyName: company.isNotEmpty ? company : name,
      type: _selectedType,
      targetCity: _selectedCity,
    );

    setState(() => _isLoading = false);

    if (payRes['success'] == true && payRes['data']?['checkoutUrl'] != null) {
      String rawUrl = payRes['data']['checkoutUrl'].toString();
      if (rawUrl.startsWith('http://')) {
        rawUrl = rawUrl.replaceFirst('http://', 'https://');
      }
      _checkoutUrl = rawUrl;
      _lastSuccessOrder = {
        'orderId': payRes['data']['orderId'] ?? 'TRV2508214567',
        'city': _selectedCity,
        'leads': '5,000 Leads',
        'amount': '₹11.00',
        'date': DateTime.now().toLocal().toString().substring(0, 16),
      };
      _navigateToStep(PromoStep.paytmCheckout);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(payRes['message'] ?? 'Failed to open Paytm gateway'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _stepStack.length <= 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          body: SafeArea(
            top: false,
            child: _buildCurrentStepView(context, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepView(BuildContext context, bool isDark) {
    switch (_currentStep) {
      case PromoStep.phoneEntry:
        return _buildPhoneEntryScreen(context, isDark);
      case PromoStep.otpVerification:
        return _buildOtpVerificationScreen(context, isDark);
      case PromoStep.detailsEntry:
        return _buildDetailsEntryScreen(context, isDark);
      case PromoStep.myOrders:
        return _buildMyOrdersScreen(context, isDark);
      case PromoStep.paytmCheckout:
        return _buildPaytmCheckoutScreen(context, isDark);
      case PromoStep.orderSuccess:
        return _buildOrderSuccessScreen(context, isDark);
    }
  }

  // ==========================================
  // COMMON HEADER BANNER
  // ==========================================
  Widget _buildHeaderBanner(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final bannerHeight = isKeyboardOpen ? 180.0 : 350.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      height: bannerHeight,
      child: Stack(
        children: [
          // Big Banner Graphic
          Container(
            width: double.infinity,
            height: bannerHeight,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF7ED),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              child: Image.network(
                (widget.initialPromoData?['bigImageUrl'] != null &&
                        widget.initialPromoData!['bigImageUrl'].toString().trim().isNotEmpty)
                    ? widget.initialPromoData!['bigImageUrl']
                    : _defaultBigBannerUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0xFFFFF7ED),
                  padding: EdgeInsets.only(top: isKeyboardOpen ? 30 : 60, left: 24, right: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Rakshabandhan',
                            style: TextStyle(
                              fontSize: isKeyboardOpen ? 18 : 26,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF991B1B),
                            ),
                          ),
                          Text(
                            '— SALE IS LIVE —',
                            style: TextStyle(
                              fontSize: isKeyboardOpen ? 10 : 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFEA580C),
                              letterSpacing: 2,
                            ),
                          ),
                          if (!isKeyboardOpen) const SizedBox(height: 12),
                          if (!isKeyboardOpen)
                            const Text(
                              'UP TO 25% OFF',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFEA580C),
                              ),
                            ),
                        ],
                      ),
                      Text('🏵️', style: TextStyle(fontSize: isKeyboardOpen ? 36 : 60)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Back Button (<)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: InkWell(
              onTap: _handleBackNavigation,
              borderRadius: BorderRadius.circular(100),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chevron_left_rounded,
                  color: Color(0xFF0F172A),
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SCREEN 1: PHONE ENTRY
  // ==========================================
  Widget _buildPhoneEntryScreen(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24.0),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        children: [
          _buildHeaderBanner(context),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              children: [
                Text(
                  'Unlock Exclusive Offers',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter your phone number and receive WhatsApp OTP to continue',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),

                // Phone Input Card (+91 Fixed Prefix)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Static Fixed +91 (No dropdown as requested)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+91',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                            hintText: 'Enter phone number',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.phone_outlined,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        size: 20,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Send WhatsApp OTP Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0052FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Send WhatsApp OTP',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  void _handleOtpInput(int index, String val) {
    if (val.length > 1) {
      final digits = val.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 4; i++) {
        if (i < digits.length) {
          _otpControllers[i].text = digits[i];
        }
      }
      if (digits.length >= 4) {
        _otpFocusNodes[3].unfocus();
        _handleVerifyOtp();
      } else {
        _otpFocusNodes[digits.length.clamp(0, 3)].requestFocus();
      }
      return;
    }

    if (val.isNotEmpty && index < 3) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (val.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }

    if (index == 3 && val.isNotEmpty) {
      _handleVerifyOtp();
    }
  }

  // ==========================================
  // SCREEN 2: OTP VERIFICATION
  // ==========================================
  Widget _buildOtpVerificationScreen(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24.0),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        children: [
          _buildHeaderBanner(context),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
            child: Column(
              children: [
                // Real WhatsApp Logo Badge
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: whatsAppIcon(size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  'OTP Sent on WhatsApp',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'We\'ve sent a 4-digit OTP to\n+91 $_verifiedPhoneNo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 28),

                // 4 PIN Boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return Container(
                      width: 56,
                      height: 58,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _otpFocusNodes[index].hasFocus
                              ? const Color(0xFF2563EB)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          width: 1.5,
                        ),
                      ),
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.backspace) {
                            if (_otpControllers[index].text.isEmpty && index > 0) {
                              _otpControllers[index - 1].clear();
                              _otpFocusNodes[index - 1].requestFocus();
                            }
                          }
                        },
                        child: TextField(
                          controller: _otpControllers[index],
                          focusNode: _otpFocusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                          ),
                          onTap: () {
                            _otpControllers[index].selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _otpControllers[index].text.length,
                            );
                          },
                          onChanged: (val) => _handleOtpInput(index, val),
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 24),

                // Primary "Verify OTP" Button (As requested by user)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleVerifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0052FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.verified_outlined,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Verify OTP',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // Countdown Timer
                Text(
                  _timerSeconds > 0
                      ? '⏱ Resend OTP in 00:${_timerSeconds.toString().padLeft(2, '0')}'
                      : 'You can resend OTP now',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 28),

                // Didn't receive OTP?
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined,
                          color: Color(0xFF2563EB), size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Didn\'t receive OTP? ',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                    ),
                    InkWell(
                      onTap: _timerSeconds == 0 ? _handleSendOtp : null,
                      child: Text(
                        'Resend OTP',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _timerSeconds == 0
                              ? const Color(0xFF0052FF)
                              : Colors.grey,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SCREEN 3A: DETAILS ENTRY SCREEN (Submit & Pay ₹11)
  // ==========================================
  Widget _buildDetailsEntryScreen(BuildContext context, bool isDark) {
    if (_phoneController.text.trim().isEmpty && _verifiedPhoneNo.isNotEmpty) {
      _phoneController.text = _verifiedPhoneNo;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24.0),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        children: [
          _buildHeaderBanner(context),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEFF6FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_outline,
                            color: Color(0xFF2563EB), size: 28),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Enter Your Details',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Provide your details to unlock exclusive lead offers',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Name (Pre-filled & Editable)
                _buildFieldLabel('Name', isDark),
                const SizedBox(height: 6),
                _buildInputField(
                  controller: _nameController,
                  hintText: 'Enter your full name',
                  icon: Icons.person_outline,
                  isDark: isDark,
                  readOnly: false,
                ),
                const SizedBox(height: 16),

                // Agency / Company Phone (Pre-filled & Editable)
                _buildFieldLabel('Agency / Company Phone', isDark),
                const SizedBox(height: 6),
                _buildInputField(
                  controller: _phoneController,
                  hintText: 'Enter phone number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  isDark: isDark,
                  readOnly: false,
                ),
                const SizedBox(height: 16),

                // Email (Pre-filled & Editable)
                _buildFieldLabel('Email', isDark),
                const SizedBox(height: 6),
                _buildInputField(
                  controller: _emailController,
                  hintText: 'Enter your email address',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  isDark: isDark,
                  readOnly: false,
                ),
                const SizedBox(height: 16),

                // Type Dropdown (Pre-selected & Editable)
                _buildFieldLabel('Type', isDark),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedType,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18, color: Colors.grey),
                      items: _businessTypes
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Row(
                                  children: [
                                    const Icon(Icons.business_outlined,
                                        size: 18, color: Colors.grey),
                                    const SizedBox(width: 10),
                                    Text(
                                      t,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedType = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Which city leads you want to buy? (ALWAYS ENABLED IN ALL CASES!)
                _buildFieldLabel('Which city leads you want to buy?', isDark),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFF2563EB),
                      width: 1.5,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedCity,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF2563EB)),
                      items: _citiesList
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 18, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 10),
                                    Text(
                                      c,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCity = val);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Action Button: Submit & Pay ₹11 (As requested by user)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmitDetailsAndPay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0052FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Submit & Pay ₹11',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded,
                                  color: Colors.white, size: 20),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SCREEN 3B: MY ORDERS / PURCHASED SHEETS
  // ==========================================
  Widget _buildMyOrdersScreen(BuildContext context, bool isDark) {
    final name = _nameController.text.isNotEmpty ? _nameController.text : 'User';

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeaderBanner(context),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEFF6FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.view_in_ar_rounded,
                            color: Color(0xFF2563EB), size: 28),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Hi, $name! 👋',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Welcome back! Here are your orders',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Your Orders',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),

                // Order Cards List
                if (_alreadyPurchasedSheets.isEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text('No purchased sheets found yet.'),
                    ),
                  ),
                ] else ...[
                  ..._alreadyPurchasedSheets.map((item) {
                    final city = item['city'] ?? 'City';
                    final date = item['purchasedAt'] != null
                        ? item['purchasedAt'].toString().substring(0, 10)
                        : '24 Aug 2026';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEFF6FF),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.apartment_rounded,
                                        color: Color(0xFF2563EB), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    city,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Completed',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _buildOrderRow('Order Date', date, isDark),
                          const SizedBox(height: 6),
                          _buildOrderRow('Leads', '5,000 Real Estate Leads', isDark),
                          const SizedBox(height: 6),
                          _buildOrderRow('Amount', '₹11', isDark),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                HapticFeedback.lightImpact();
                                final String rawSheetUrl = item['sheetUrl']?.toString() ?? '';
                                debugPrint('📄 [PromoOrder] Download Leads button tapped for item: $item');
                                debugPrint('📄 [PromoOrder] Target sheetUrl: "$rawSheetUrl"');

                                if (rawSheetUrl.isNotEmpty) {
                                  try {
                                    final uri = Uri.parse(rawSheetUrl);
                                    debugPrint('📄 [PromoOrder] Parsed URI: $uri');

                                    bool launched = false;
                                    // 1. Try launching in In-App Browser (Chrome Custom Tabs) to bypass Google Drive App account requirements
                                    try {
                                      launched = await launchUrl(
                                        uri,
                                        mode: LaunchMode.inAppBrowserView,
                                      );
                                      debugPrint('📄 [PromoOrder] inAppBrowserView launch result: $launched');
                                    } catch (inAppErr) {
                                      debugPrint('⚠️ [PromoOrder] inAppBrowserView exception: $inAppErr');
                                    }

                                    // 2. Fallback to platform default browser if inAppBrowserView is not supported
                                    if (!launched) {
                                      try {
                                        launched = await launchUrl(
                                          uri,
                                          mode: LaunchMode.platformDefault,
                                        );
                                        debugPrint('📄 [PromoOrder] platformDefault launch result: $launched');
                                      } catch (platformErr) {
                                        debugPrint('⚠️ [PromoOrder] platformDefault exception: $platformErr');
                                      }
                                    }

                                    // 3. Fallback to external application
                                    if (!launched) {
                                      try {
                                        launched = await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                        debugPrint('📄 [PromoOrder] externalApplication launch result: $launched');
                                      } catch (externalErr) {
                                        debugPrint('❌ [PromoOrder] externalApplication exception: $externalErr');
                                      }
                                    }

                                    if (!launched && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Could not open sheet link: $rawSheetUrl'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } catch (e, stackTrace) {
                                    debugPrint('❌ [PromoOrder] GENERAL EXCEPTION: $e\n$stackTrace');
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error launching sheet URL: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                } else {
                                  debugPrint('⚠️ [PromoOrder] sheetUrl is EMPTY for item: $item');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Sheet URL is not available for this order.'),
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: const Text('Download Leads',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF0052FF)),
                                foregroundColor: const Color(0xFF0052FF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 16),

                // Buy More Cities Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      _navigateToStep(PromoStep.detailsEntry);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0052FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Buy More Cities Leads',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Why Buy Leads Feature Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_outlined,
                              color: Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Why Buy Leads from Trevion?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildCheckLine('High quality & verified leads', isDark),
                      const SizedBox(height: 6),
                      _buildCheckLine('Regularly updated database', isDark),
                      const SizedBox(height: 6),
                      _buildCheckLine('Exclusive city-wise lead packs', isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckLine(String text, bool isDark) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF2563EB), size: 16),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? Colors.grey[300] : const Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  void _onPaymentSuccessful() {
    if (_currentStep == PromoStep.orderSuccess) return;
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      _resetToStep(PromoStep.orderSuccess);
    }

    // Call Paytm Webhook Callback API (POST /api/v1/otp/paytm/callback) upon reaching success screen
    final orderId = _lastSuccessOrder['orderId'] ?? '';
    if (_verifiedPhoneNo.isNotEmpty && orderId.isNotEmpty) {
      PromoCampaignService.sendPaytmCallback(
        phoneNo: _verifiedPhoneNo,
        orderId: orderId,
      ).then((_) {
        _refreshUserData();
      });
    }
  }

  // ==========================================
  // SCREEN 4: PAYTM CHECKOUT IN-APP WEBVIEW
  // ==========================================
  Widget _buildPaytmCheckoutScreen(BuildContext context, bool isDark) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paytm Checkout (₹11)'),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _handleBackNavigation();
          },
        ),
        actions: Platform.isIOS
            ? [
                IconButton(
                  icon: const Icon(Icons.open_in_browser_rounded),
                  tooltip: 'Open in Safari/Browser',
                  onPressed: () async {
                    if (_checkoutUrl.isNotEmpty) {
                      final uri = Uri.parse(_checkoutUrl);
                      try {
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      } catch (e) {
                        debugPrint('Failed to launch external checkout URL: $e');
                      }
                    }
                  },
                ),
              ]
            : null,
      ),
      body: Platform.isIOS
          ? Stack(
              children: [
                InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(_checkoutUrl)),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    useShouldOverrideUrlLoading: true,
                    mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                    allowContentAccess: true,
                    allowFileAccess: true,
                    allowsInlineMediaPlayback: true,
                    isFraudulentWebsiteWarningEnabled: false,
                    allowsBackForwardNavigationGestures: true,
                    sharedCookiesEnabled: true,
                  ),
                  onWebViewCreated: (controller) {
                    controller.addJavaScriptHandler(
                      handlerName: 'TrevionPaymentChannel',
                      callback: (args) {
                        if (args.isNotEmpty) {
                          try {
                            final msg = args[0];
                            final Map<String, dynamic> data = msg is Map
                                ? Map<String, dynamic>.from(msg)
                                : jsonDecode(msg.toString());

                            if (data['status'] == 'success') {
                              _onPaymentSuccessful();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(data['message'] ?? 'Payment failed'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              _handleBackNavigation();
                            }
                          } catch (e) {
                            debugPrint('TrevionPaymentChannel error: $e');
                          }
                        }
                      },
                    );
                  },
                  shouldOverrideUrlLoading: (controller, navigationAction) async {
                    final uri = navigationAction.request.url;
                    if (uri == null) return NavigationActionPolicy.ALLOW;

                    final urlStr = uri.toString();

                    // Check if Paytm callback URL reached
                    if (urlStr.contains('/paytm/callback')) {
                      if (urlStr.contains('TXN_FAILURE') ||
                          urlStr.contains('STATUS=FAILURE') ||
                          urlStr.contains('status=failed')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment Failed. Please try again.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        _handleBackNavigation();
                      } else {
                        _onPaymentSuccessful();
                      }
                      return NavigationActionPolicy.CANCEL;
                    }

                    // Handle external app schemes (paytm://, paytmmp://, upi://, phonepe://, gpay://, etc.)
                    final scheme = uri.scheme.toLowerCase();
                    if (scheme != 'http' && scheme != 'https' && scheme != 'about' && scheme != 'javascript') {
                      try {
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
                        }
                      } catch (e) {
                        debugPrint('Failed to launch external app URL ($urlStr): $e');
                      }
                      return NavigationActionPolicy.CANCEL;
                    }

                    return NavigationActionPolicy.ALLOW;
                  },
                  onLoadStart: (controller, url) {
                    if (mounted) setState(() => _isWebViewLoading = true);
                    if (url != null && url.toString().contains('/paytm/callback')) {
                      final urlStr = url.toString();
                      if (urlStr.contains('TXN_FAILURE') ||
                          urlStr.contains('STATUS=FAILURE') ||
                          urlStr.contains('status=failed')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment Failed. Please try again.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        _handleBackNavigation();
                      } else {
                        _onPaymentSuccessful();
                      }
                    }
                  },
                  onLoadStop: (controller, url) async {
                    if (mounted) setState(() => _isWebViewLoading = false);
                    if (url != null && url.toString().contains('/callback')) {
                      _onPaymentSuccessful();
                    }
                  },
                  onUpdateVisitedHistory: (controller, url, isReload) {
                    if (url != null && url.toString().contains('/paytm/callback')) {
                      final urlStr = url.toString();
                      if (urlStr.contains('TXN_FAILURE') ||
                          urlStr.contains('STATUS=FAILURE') ||
                          urlStr.contains('status=failed')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment Failed. Please try again.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        _handleBackNavigation();
                      } else {
                        _onPaymentSuccessful();
                      }
                    }
                  },
                  onReceivedHttpError: (controller, request, errorResponse) {
                    if (_currentStep == PromoStep.orderSuccess) return;
                    if (request.url.toString().contains('/paytm/callback')) {
                      _onPaymentSuccessful();
                      return;
                    }
                  },
                  onWebContentProcessDidTerminate: (controller) {
                    debugPrint('⚠️ [InAppWebView] Web Content Process Terminated. Reloading...');
                    controller.reload();
                  },
                ),
                if (_isWebViewLoading)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF0052FF),
                    ),
                  ),
              ],
            )
          : InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_checkoutUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                useShouldOverrideUrlLoading: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                allowContentAccess: true,
                allowFileAccess: true,
              ),
              onWebViewCreated: (controller) {
                controller.addJavaScriptHandler(
                  handlerName: 'TrevionPaymentChannel',
                  callback: (args) {
                    if (args.isNotEmpty) {
                      try {
                        final msg = args[0];
                        final Map<String, dynamic> data = msg is Map
                            ? Map<String, dynamic>.from(msg)
                            : jsonDecode(msg.toString());

                        if (data['status'] == 'success') {
                          _onPaymentSuccessful();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(data['message'] ?? 'Payment failed'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          _handleBackNavigation();
                        }
                      } catch (e) {
                        debugPrint('TrevionPaymentChannel error: $e');
                      }
                    }
                  },
                );
              },
              onLoadStart: (controller, url) {
                if (url != null && url.toString().contains('/paytm/callback')) {
                  final urlStr = url.toString();
                  if (urlStr.contains('TXN_FAILURE') ||
                      urlStr.contains('STATUS=FAILURE') ||
                      urlStr.contains('status=failed')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Payment Failed. Please try again.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    _handleBackNavigation();
                  } else {
                    _onPaymentSuccessful();
                  }
                }
              },
              onUpdateVisitedHistory: (controller, url, isReload) {
                if (url != null && url.toString().contains('/paytm/callback')) {
                  final urlStr = url.toString();
                  if (urlStr.contains('TXN_FAILURE') ||
                      urlStr.contains('STATUS=FAILURE') ||
                      urlStr.contains('status=failed')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Payment Failed. Please try again.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    _handleBackNavigation();
                  } else {
                    _onPaymentSuccessful();
                  }
                }
              },
              onReceivedHttpError: (controller, request, errorResponse) {
                if (_currentStep == PromoStep.orderSuccess) return;
                if (request.url.toString().contains('/paytm/callback')) {
                  _onPaymentSuccessful();
                  return;
                }
                if ((errorResponse.statusCode ?? 0) >= 500) {
                  if (mounted && _currentStep != PromoStep.orderSuccess) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Server/CORS Error during Paytm callback. Please verify backend CORS configuration.'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }
                }
              },
              onLoadStop: (controller, url) async {
                if (url != null && url.toString().contains('/callback')) {
                  _onPaymentSuccessful();
                }
              },
            ),
    );
  }

  // ==========================================
  // SCREEN 5: ORDER SUCCESS SCREEN
  // ==========================================
  Widget _buildOrderSuccessScreen(BuildContext context, bool isDark) {
    final orderId = _lastSuccessOrder['orderId'] ?? 'TRV2508214567';
    final date = _lastSuccessOrder['date'] ?? '24 Aug 2026';
    final city = _lastSuccessOrder['city'] ?? _selectedCity;

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeaderBanner(context),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Animated Green Circle Checkmark
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF16A34A),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Order Successful!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Thank you! Your lead request has been placed successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 24),

                // Order Details Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.assignment_outlined,
                              color: Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Order Details',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildOrderRow('City', city, isDark),
                      const SizedBox(height: 8),
                      _buildOrderRow('Leads Requested', '5,000 Leads', isDark),
                      const SizedBox(height: 8),
                      _buildOrderRow('Amount Paid', '₹11.00', isDark),
                      const SizedBox(height: 8),
                      _buildOrderRow('Order ID', orderId, isDark),
                      const SizedBox(height: 8),
                      _buildOrderRow('Order Date', date, isDark),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Notification Info Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Color(0xFF2563EB), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your leads will be ready soon. You will receive a WhatsApp notification once your leads are ready to download.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[300] : const Color(0xFF1E40AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // 1. Primary: View Order Details
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _handleViewOrderDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0052FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.list_alt_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'View Order Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Secondary: Back to Login Screen
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0052FF)),
                      foregroundColor: const Color(0xFF0052FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_back_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Back to Login Screen',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper Form Fields
  Widget _buildFieldLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.grey[300] : const Color(0xFF334155),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required bool isDark,
    bool readOnly = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: readOnly
            ? (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF1F5F9))
            : (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: isDark ? Colors.grey[400] : const Color(0xFF64748B), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              keyboardType: keyboardType,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: readOnly ? FontWeight.bold : FontWeight.w500,
                color: readOnly
                    ? (isDark ? Colors.grey[400] : const Color(0xFF475569))
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: const TextStyle(fontSize: 13.5, color: Colors.grey),
              ),
            ),
          ),
          if (readOnly)
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Icon(Icons.lock_outline_rounded, color: Colors.grey, size: 18),
            ),
        ],
      ),
    );
  }
}
