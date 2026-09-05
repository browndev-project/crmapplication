import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../widgets/common_shimmer_skeleton.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:paytm_allinonesdk/paytm_allinonesdk.dart';
import '../../../core/services/promo_campaign_service.dart';
import '../../../core/services/auth_service.dart';
import 'package:intl/intl.dart';
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

class _PromoCampaignScreenState extends State<PromoCampaignScreen> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchCitiesFromApi();
    _checkSavedSession();
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
      if (_currentStep == PromoStep.paytmCheckout) {
        debugPrint('🔄 [PromoCampaignScreen] Resumed from Paytm app. Fetching latest orders status...');
        _refreshUserData();
      }
    }
  }
  PromoStep _currentStep = PromoStep.phoneEntry;
  final List<PromoStep> _stepStack = [PromoStep.phoneEntry];

  void _navigateToStep(PromoStep nextStep) {
    if (mounted) {
      setState(() {
        _isLoading = false;
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
        _isLoading = false;
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
        _isLoading = false;
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

  // Dynamic promo amount helper getters
  Map<String, dynamic>? get _promoData {
    return widget.initialPromoData ?? PromoCampaignService.getCachedPromoData();
  }

  dynamic get _rawPromoAmount {
    final data = _promoData;
    return data?['amount'];
  }

  String get _promoAmount {
    final raw = _rawPromoAmount;
    if (raw != null) {
      final numVal = num.tryParse(raw.toString());
      if (numVal != null) {
        if (numVal % 1 == 0) {
          return '₹${numVal.toInt()}';
        }
        return '₹${numVal.toStringAsFixed(2)}';
      }
      final strVal = raw.toString().trim();
      if (strVal.isNotEmpty) {
        return strVal.startsWith('₹') ? strVal : '₹$strVal';
      }
    }
    return '₹99';
  }

  String get _promoAmountFormatted {
    final amt = _promoAmount;
    if (!amt.contains('.')) {
      return '$amt.00';
    }
    return amt;
  }

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

          debugPrint('📦 [PromoCampaignScreen] Fresh user data fetched. Total orders: ${freshPurchased.length}');
          for (int i = 0; i < freshPurchased.length; i++) {
            debugPrint('📦 [PromoCampaignScreen] Order #$i: ${freshPurchased[i]}');
          }

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

      debugPrint('📦 [PromoCampaignScreen] _refreshUserData succeeded. Total orders: ${purchased.length}');
      for (int i = 0; i < purchased.length; i++) {
        debugPrint('📦 [PromoCampaignScreen] Order #$i: ${purchased[i]}');
      }

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

    try {
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
        amount: _rawPromoAmount,
      );

      debugPrint('💳 [PromoCampaignScreen] initiatePaytmPayment returned payRes: $payRes');

      final bool isPaySuccess = payRes['success'] == true;
      final payData = payRes['data'] is Map
          ? Map<String, dynamic>.from(payRes['data'])
          : <String, dynamic>{};

      final String orderId = (payData['orderId'] ?? payData['ORDER_ID'] ?? 'TRV${DateTime.now().millisecondsSinceEpoch}').toString();
      String rawCheckoutUrl = (payData['checkoutUrl'] ?? payData['url'] ?? '').toString();
      final String txnToken = (payData['txnToken'] ?? payData['token'] ?? (payData['body'] is Map ? payData['body']['txnToken'] : null) ?? '').toString();
      final String mid = (payData['paytm_mid'] ?? payData['mid'] ?? payData['merchantId'] ?? '').toString();
      final String amountStr = (_rawPromoAmount ?? payData['amount'] ?? payData['txnAmount'] ?? '99').toString();

      debugPrint('💳 [PromoCampaignScreen] Extracted Params -> MID: "$mid" | TxnToken: "$txnToken" | OrderId: "$orderId" | CheckoutUrl: "$rawCheckoutUrl"');

      // Check if initiation failed or parameters are missing
      if (!isPaySuccess || (rawCheckoutUrl.isEmpty && txnToken.isEmpty)) {
        final String errMsg = (payRes['message'] ?? 'Payment initiation failed. Please try again.').toString();
        debugPrint('❌ [PromoCampaignScreen] Payment initiation failed: $errMsg');
        if (mounted) {
          String displayMsg = errMsg;
          if (errMsg.toLowerCase().contains('system error')) {
            displayMsg = 'Paytm Gateway System Error (502). If testing mode is enabled, please verify Paytm Staging credentials on your backend server.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(displayMsg),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Direct Web Gateway Fallback if initiate API returned txnToken but empty checkoutUrl
      if (rawCheckoutUrl.isEmpty && txnToken.isNotEmpty && mid.isNotEmpty) {
        rawCheckoutUrl = '${AuthService.baseUrl}/api/v1/otp/paytm/checkout?orderId=$orderId&txnToken=$txnToken&mid=$mid&amount=$amountStr';
      }

      // PREVIOUS FALLBACK (Preserved in comments per user rule):
      // if (rawCheckoutUrl.isEmpty) {
      //   rawCheckoutUrl = '${AuthService.baseUrl}/api/v1/otp/paytm/checkout?leadId=$_leadId&phoneNo=$_verifiedPhoneNo&targetCity=${Uri.encodeComponent(_selectedCity)}&name=${Uri.encodeComponent(name)}&email=${Uri.encodeComponent(email)}';
      // }

      // PREVIOUS _lastSuccessOrder (Preserved in comments per user rule):
      // _lastSuccessOrder = {
      //   'orderId': orderId,
      //   'city': _selectedCity,
      //   'leads': '5,000 Leads',
      //   'amount': _promoAmountFormatted,
      //   'date': DateTime.now().toLocal().toString().substring(0, 16),
      // };

      _lastSuccessOrder = {
        'orderId': orderId,
        'city': _selectedCity,
        'leads': '5,000 Leads',
        'amount': _promoAmountFormatted,
        'companyName': _companyController.text.trim(),
        'phoneNo': _verifiedPhoneNo,
        'email': _emailController.text.trim(),
        'type': _selectedType,
        'status': 'Completed',
        'purchasedAt': DateTime.now().toIso8601String(),
        'date': DateTime.now().toLocal().toString().substring(0, 16),
      };

      // =======================================================================
      // OPTION 1: PAYTM ALL-IN-ONE NATIVE SDK FLOW (APP INVOKE & REDIRECTION)
      // To disable/remove SDK flow and revert to 100% old Webview flow, 
      // set `const bool enablePaytmNativeSdk = false;` or comment out this block.
      // =======================================================================
      // Check whether Paytm native app is installed on the device
      bool isPaytmAppInstalled = false;
      try {
        isPaytmAppInstalled = await canLaunchUrl(Uri.parse('paytmmp://pay')) ||
            await canLaunchUrl(Uri.parse('paytm://'));
      } catch (_) {
        isPaytmAppInstalled = false;
      }

      debugPrint('💳 [PromoCampaignScreen] Is Paytm App Installed? $isPaytmAppInstalled');

      // =======================================================================
      // 100% IN-APP WEBVIEW FLOW (Bypasses AllInOneSdk PaytmPGActivity "Lost in Space")
      // Preserved AllInOneSdk code below in comments per user rule.
      // =======================================================================
      /*
      bool enablePaytmNativeSdk = false;
      if (enablePaytmNativeSdk && isPaytmAppInstalled && txnToken.isNotEmpty && mid.isNotEmpty) {
          try {
            debugPrint('🚀 [PaytmSDK] Attempting Paytm All-in-One SDK Payment...');
            final bool isStaging = payData['isStaging'] == true || payData['isTesting'] == true;
            final String paytmHost = isStaging ? 'https://securegw-stage.paytm.in/' : 'https://securegw.paytm.in/';
            final String callbackUrl = '${paytmHost}theia/paytmCallback?ORDER_ID=$orderId';

            final paytmResponse = await AllInOneSdk.startTransaction(
              mid,
              orderId,
              amountStr,
              txnToken,
              callbackUrl,
              isStaging,
              false,
              false,
            );

            Map<String, dynamic> respMap = {};
            if (paytmResponse != null) {
              if (paytmResponse['response'] is Map) {
                respMap = Map<String, dynamic>.from(paytmResponse['response']);
              } else if (paytmResponse['response'] is String) {
                try {
                  final decoded = jsonDecode(paytmResponse['response'] as String);
                  if (decoded is Map) {
                    respMap = Map<String, dynamic>.from(decoded);
                  }
                } catch (_) {}
              }
              if (respMap.isEmpty) {
                respMap = Map<String, dynamic>.from(paytmResponse);
              }
            }

            final String status = (respMap['STATUS'] ?? respMap['status'] ?? '').toString().toUpperCase();
            final String respCode = (respMap['RESPCODE'] ?? respMap['respCode'] ?? '').toString();

            if (status == 'TXN_SUCCESS' || respCode == '01' || status.contains('SUCCESS')) {
              _onPaymentSuccessful();
              return;
            } else {
              final String msg = (respMap['RESPMSG'] ?? respMap['errorMessage'] ?? respMap['errorMsg'] ?? 'Payment was cancelled.').toString();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(msg), backgroundColor: Colors.red),
                );
              }
              return;
            }
          } catch (e) {
            debugPrint('⚠️ [PaytmSDK] Paytm SDK exception: $e');
            final errStr = e.toString().toLowerCase();
            if (errStr.contains('cancel') || errStr.contains('back') || errStr.contains('declined') || errStr.contains('user')) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment was cancelled.'), backgroundColor: Colors.red),
                );
              }
              return;
            }
          }
      }
      */

      // =======================================================================
      // OPTION 2: ORIGINAL / PREVIOUS IN-APP WEBVIEW REDIRECTION FLOW
      // (Executes if Native SDK is disabled or if checkoutUrl fallback is used)
      // =======================================================================
      if (rawCheckoutUrl.isNotEmpty) {
        String rawUrl = rawCheckoutUrl;
        if (rawUrl.startsWith('http://')) {
          rawUrl = rawUrl.replaceFirst('http://', 'https://');
        }
        _checkoutUrl = rawUrl;
        _navigateToStep(PromoStep.paytmCheckout);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment checkout URL could not be generated. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [PromoCampaignScreen] Exception during submit & pay: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment initiation error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
                        ? const AppShimmerButtonLoading(size: 20)
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
                        ? const AppShimmerButtonLoading(size: 20)
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
                        ? const AppShimmerButtonLoading(size: 20)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Submit & Pay $_promoAmount',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded,
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

                    // PREVIOUS IMPLEMENTATION (Preserved in comments per user rule):
                    // final date = item['purchasedAt'] != null
                    //     ? item['purchasedAt'].toString().substring(0, 10)
                    //     : '24 Aug 2026';
                    //
                    // final rawItemAmount = item['amount'] ?? item['price'] ?? item['paidAmount'] ?? item['amountPaid'];
                    // final String cardAmountDisplay;
                    // if (rawItemAmount != null && rawItemAmount.toString().trim().isNotEmpty) {
                    //   final str = rawItemAmount.toString().trim();
                    //   cardAmountDisplay = str.startsWith('₹') ? str : '₹$str';
                    // } else {
                    //   cardAmountDisplay = '₹11';
                    // }

                    // Extract Order ID
                    final String orderId = (item['orderId'] ??
                            item['ORDER_ID'] ??
                            item['order_id'] ??
                            item['id'] ??
                            item['_id'] ??
                            item['txnId'] ??
                            'N/A')
                        .toString();

                    // Extract Company Name
                    final String companyName = (item['companyName'] ??
                            item['company'] ??
                            item['company_name'] ??
                            (_companyController.text.trim().isNotEmpty
                                ? _companyController.text.trim()
                                : null) ??
                            'N/A')
                        .toString();

                    // Extract Phone Number
                    final String phone = (item['phoneNo'] ??
                            item['phone'] ??
                            item['phoneNumber'] ??
                            (_verifiedPhoneNo.isNotEmpty ? _verifiedPhoneNo : null) ??
                            (_phoneController.text.trim().isNotEmpty
                                ? _phoneController.text.trim()
                                : null) ??
                            'N/A')
                        .toString();

                    // Extract Email
                    final String email = (item['email'] ??
                            item['userEmail'] ??
                            (_emailController.text.trim().isNotEmpty
                                ? _emailController.text.trim()
                                : null) ??
                            'N/A')
                        .toString();

                    // Extract Business Type
                    final String businessType = (item['type'] ??
                            item['businessType'] ??
                            item['business_type'] ??
                            (_selectedType.isNotEmpty ? _selectedType : null) ??
                            'Real Estate')
                        .toString();

                    // Extract and Format Status
                    final String rawStatus = (item['status'] ??
                            item['orderStatus'] ??
                            item['paymentStatus'] ??
                            'Completed')
                        .toString();
                    final String status = rawStatus.isNotEmpty
                        ? '${rawStatus[0].toUpperCase()}${rawStatus.substring(1)}'
                        : 'Completed';

                    // Extract and Format Purchased At (e.g., "27 July 2026, 8:39 pm")
                    final dynamic rawPurchasedAt = item['purchasedAt'] ??
                        item['createdAt'] ??
                        item['date'] ??
                        item['timestamp'] ??
                        item['orderDate'];
                    final String formattedPurchasedAt = _formatPurchasedAt(rawPurchasedAt);

                    // Extract Leads and Amount
                    final String leadsDisplay = (item['leads'] ?? '5,000 $businessType Leads').toString();
                    final rawItemAmount = item['amount'] ?? item['price'] ?? item['paidAmount'] ?? item['amountPaid'];
                    final String cardAmountDisplay;
                    if (rawItemAmount != null && rawItemAmount.toString().trim().isNotEmpty) {
                      final str = rawItemAmount.toString().trim();
                      cardAmountDisplay = str.startsWith('₹') ? str : '₹$str';
                    } else {
                      cardAmountDisplay = '₹11';
                    }

                    final isSuccess = status.toLowerCase().contains('success') || status.toLowerCase().contains('complete');
                    final isPending = status.toLowerCase().contains('pend');

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
                              // PREVIOUS STATUS BADGE (Preserved in comments per user rule):
                              // Container(
                              //   padding: const EdgeInsets.symmetric(
                              //       horizontal: 10, vertical: 4),
                              //   decoration: BoxDecoration(
                              //     color: const Color(0xFFDCFCE7),
                              //     borderRadius: BorderRadius.circular(8),
                              //   ),
                              //   child: const Text(
                              //     'Completed',
                              //     style: TextStyle(
                              //       fontSize: 11,
                              //       fontWeight: FontWeight.bold,
                              //       color: Color(0xFF16A34A),
                              //     ),
                              //   ),
                              // ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSuccess
                                      ? const Color(0xFFDCFCE7)
                                      : isPending
                                          ? const Color(0xFFFEF3C7)
                                          : const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSuccess
                                        ? const Color(0xFF16A34A)
                                        : isPending
                                            ? const Color(0xFFD97706)
                                            : const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          // PREVIOUS ORDER CARD ROWS (Preserved in comments per user rule):
                          // _buildOrderRow('Order Date', date, isDark),
                          // const SizedBox(height: 6),
                          // _buildOrderRow('Leads', '5,000 Real Estate Leads', isDark),
                          // const SizedBox(height: 6),
                          // _buildOrderRow('Amount', cardAmountDisplay, isDark),

                          _buildOrderRow('Order ID', orderId, isDark),
                          const SizedBox(height: 8),
                          _buildOrderRow('Company Name', companyName, isDark),
                          const SizedBox(height: 8),
                          _buildOrderRow('Phone', phone, isDark),
                          const SizedBox(height: 8),
                          _buildOrderRow('Email', email, isDark),
                          const SizedBox(height: 8),
                          _buildOrderRow('Business Type', businessType, isDark),
                          const SizedBox(height: 8),
                          _buildOrderRow('Status', status, isDark),
                          const SizedBox(height: 8),
                          _buildOrderRow('Purchased At', formattedPurchasedAt, isDark),
                          const SizedBox(height: 8),
                          _buildOrderRow('Leads', leadsDisplay, isDark),
                          const SizedBox(height: 8),
                          _buildOrderRow('Amount', cardAmountDisplay, isDark),
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

  /// Formats raw date/timestamp string into format: e.g. "27 July 2026, 8:39 pm"
  String _formatPurchasedAt(dynamic rawDate) {
    if (rawDate == null) return 'N/A';
    final str = rawDate.toString().trim();
    if (str.isEmpty || str == 'null') return 'N/A';

    try {
      DateTime? dt;
      final maybeNum = int.tryParse(str);
      if (maybeNum != null) {
        if (str.length == 10) {
          dt = DateTime.fromMillisecondsSinceEpoch(maybeNum * 1000).toLocal();
        } else if (str.length >= 13) {
          dt = DateTime.fromMillisecondsSinceEpoch(maybeNum).toLocal();
        }
      }
      dt ??= DateTime.tryParse(str)?.toLocal();

      if (dt != null) {
        // e.g. "27 July 2026, 8:39 pm"
        final formatted = DateFormat('d MMMM yyyy, h:mm a').format(dt);
        return formatted.replaceAll('AM', 'am').replaceAll('PM', 'pm');
      }
    } catch (_) {}

    return str;
  }

  // PREVIOUS _buildOrderRow IMPLEMENTATION (Preserved in comments per user rule):
  // Widget _buildOrderRow(String label, String value, bool isDark) {
  //   return Row(
  //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //     children: [
  //       Text(
  //         label,
  //         style: TextStyle(
  //           fontSize: 13,
  //           color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
  //         ),
  //       ),
  //       Text(
  //         value,
  //         style: TextStyle(
  //           fontSize: 13.5,
  //           fontWeight: FontWeight.bold,
  //           color: isDark ? Colors.white : const Color(0xFF0F172A),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildOrderRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
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
  // IOS PAYTM UPI INTENT INTEGRATION HELPERS
  // ==========================================
  /// Converts an Android Intent URI (used by Paytm web checkout) into an iOS compatible UPI URI
  Uri? _convertIntentToIosUri(String urlStr) {
    try {
      if (!urlStr.startsWith('intent:')) {
        return Uri.tryParse(urlStr);
      }

      String queryPart = '';
      String packagePart = '';

      final intentIndex = urlStr.indexOf('#Intent;');
      if (intentIndex != -1) {
        final beforeIntent = urlStr.substring(0, intentIndex);
        final afterIntent = urlStr.substring(intentIndex);

        final packageMatch = RegExp(r'package=([^;]+)').firstMatch(afterIntent);
        if (packageMatch != null) {
          packagePart = packageMatch.group(1)?.toLowerCase() ?? '';
        }

        final dataMatch = RegExp(r'data=([^;]+)').firstMatch(afterIntent);
        if (dataMatch != null) {
          final rawData = Uri.decodeFull(dataMatch.group(1)!);
          if (!rawData.startsWith('intent:')) {
            return _convertIntentToIosUri(rawData);
          }
        }

        final qIndex = beforeIntent.indexOf('?');
        if (qIndex != -1) {
          queryPart = beforeIntent.substring(qIndex + 1);
        }
      } else {
        final qIndex = urlStr.indexOf('?');
        if (qIndex != -1) {
          queryPart = urlStr.substring(qIndex + 1);
        }
      }

      // Map Android UPI app package to iOS URI scheme
      String targetScheme = 'upi';
      if (packagePart.contains('google') ||
          packagePart.contains('paisa') ||
          packagePart.contains('gpay') ||
          packagePart.contains('tez')) {
        targetScheme = 'tez'; // Google Pay India iOS primary scheme
      } else if (packagePart.contains('phonepe')) {
        targetScheme = 'phonepe'; // PhonePe iOS scheme
      } else if (packagePart.contains('paytm')) {
        targetScheme = 'paytmmp'; // Paytm iOS scheme
      } else if (packagePart.contains('bhim') || packagePart.contains('npci')) {
        targetScheme = 'bhim'; // BHIM iOS scheme
      } else if (packagePart.contains('cred') || packagePart.contains('dreamplug')) {
        targetScheme = 'credpay'; // CRED iOS scheme
      }

      final iosUriStr = '$targetScheme://upi/pay?$queryPart';
      debugPrint('🔄 [PaytmIntent] Converted Android intent to iOS URI: $iosUriStr (package: "$packagePart")');
      return Uri.tryParse(iosUriStr);
    } catch (e) {
      debugPrint('❌ [PaytmIntent] Error converting intent URI: $e');
      return null;
    }
  }

  /// Robustly launches a UPI URI on iOS with multi-scheme fallbacks
  Future<bool> _launchIosUpiUri(Uri targetUri) async {
    final uriStr = targetUri.toString();
    debugPrint('🚀 [PaytmLaunch] Attempting to launch UPI URI on iOS: $uriStr');

    // Try 1: Direct external application launch
    try {
      final ok = await launchUrl(targetUri, mode: LaunchMode.externalApplication);
      if (ok) {
        debugPrint('✅ [PaytmLaunch] Successfully launched: $targetUri');
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ [PaytmLaunch] Direct externalApplication failed for $targetUri: $e');
    }

    // Try 2: If tez:// failed, try gpay:// fallback
    if (targetUri.scheme == 'tez') {
      try {
        final gpayUri = targetUri.replace(scheme: 'gpay');
        debugPrint('🔄 [PaytmLaunch] Trying gpay:// fallback: $gpayUri');
        final ok = await launchUrl(gpayUri, mode: LaunchMode.externalApplication);
        if (ok) return true;
      } catch (_) {}
    }

    // Try 3: If paytmmp:// failed, try paytm:// fallback
    if (targetUri.scheme == 'paytmmp') {
      try {
        final paytmUri = targetUri.replace(scheme: 'paytm');
        debugPrint('🔄 [PaytmLaunch] Trying paytm:// fallback: $paytmUri');
        final ok = await launchUrl(paytmUri, mode: LaunchMode.externalApplication);
        if (ok) return true;
      } catch (_) {}
    }

    // Try 4: Try generic upi:// fallback
    if (targetUri.scheme != 'upi') {
      try {
        final genericUpiUri = targetUri.replace(scheme: 'upi');
        debugPrint('🔄 [PaytmLaunch] Trying generic upi:// fallback: $genericUpiUri');
        final ok = await launchUrl(genericUpiUri, mode: LaunchMode.externalApplication);
        if (ok) return true;
      } catch (_) {}
    }

    // Try 5: Fallback to externalNonBrowserApplication
    try {
      final ok = await launchUrl(targetUri, mode: LaunchMode.externalNonBrowserApplication);
      if (ok) return true;
    } catch (e) {
      debugPrint('❌ [PaytmLaunch] All launch attempts failed for $targetUri: $e');
    }

    return false;
  }

  /// Retrieves installed UPI apps on iOS for Paytm JS Checkout UPI Intent
  Future<List<Map<String, dynamic>>> _getInstalledUpiAppsForIos() async {
    final apps = <Map<String, dynamic>>[];

    // 1. Google Pay (iOS uses tez:// as primary scheme in India, also check gpay://)
    bool hasGPay = false;
    try {
      hasGPay = await canLaunchUrl(Uri.parse('tez://')) || await canLaunchUrl(Uri.parse('gpay://'));
    } catch (_) {}
    if (hasGPay) {
      apps.add({
        'name': 'GOOGLE_PAY',
        'displayName': 'Google Pay',
        'icon': 'https://staticpg.paytmpayments.com/pg-widgets/v1/upi/gpay.svg',
        'scheme': 'tez',
      });
    }

    // 2. PhonePe (scheme: phonepe://)
    bool hasPhonePe = false;
    try {
      hasPhonePe = await canLaunchUrl(Uri.parse('phonepe://'));
    } catch (_) {}
    if (hasPhonePe) {
      apps.add({
        'name': 'PHONEPE',
        'displayName': 'PhonePe',
        'icon': 'https://staticpg.paytmpayments.com/pg-widgets/v1/upi/phonepe.svg',
        'scheme': 'phonepe',
      });
    }

    // 3. Paytm (scheme: paytmmp:// or paytm://)
    bool hasPaytm = false;
    try {
      hasPaytm = await canLaunchUrl(Uri.parse('paytmmp://')) || await canLaunchUrl(Uri.parse('paytm://'));
    } catch (_) {}
    if (hasPaytm) {
      apps.add({
        'name': 'PAYTM',
        'displayName': 'Paytm',
        'icon': 'https://staticpg.paytmpayments.com/pg-widgets/v1/upi/paytm.svg',
        'scheme': 'paytmmp',
      });
    }

    // 4. BHIM (scheme: bhim://)
    bool hasBhim = false;
    try {
      hasBhim = await canLaunchUrl(Uri.parse('bhim://'));
    } catch (_) {}
    if (hasBhim) {
      apps.add({
        'name': 'BHIM',
        'displayName': 'BHIM',
        'icon': 'https://staticpg.paytmpayments.com/pg-widgets/v1/upi/bhim.svg',
        'scheme': 'bhim',
      });
    }

    // 5. CRED (scheme: credpay:// or cred://)
    bool hasCred = false;
    try {
      hasCred = await canLaunchUrl(Uri.parse('credpay://')) || await canLaunchUrl(Uri.parse('cred://'));
    } catch (_) {}
    if (hasCred) {
      apps.add({
        'name': 'CRED',
        'displayName': 'CRED',
        'icon': 'https://staticpg.paytmpayments.com/pg-widgets/v1/upi/cred.svg',
        'scheme': 'credpay',
      });
    }

    // Fallback: If canLaunchUrl returns empty (e.g. simulator or sandbox query restriction),
    // provide default popular apps so UPI buttons render and tapping invokes deep link.
    if (apps.isEmpty) {
      debugPrint('ℹ️ [PaytmUPI] No apps returned by canLaunchUrl. Using default UPI apps list for iOS.');
      apps.addAll([
        {
          'name': 'GOOGLE_PAY',
          'displayName': 'Google Pay',
          'icon': 'https://staticpg.paytmpayments.com/pg-widgets/v1/upi/gpay.svg',
          'scheme': 'tez',
        },
        {
          'name': 'PHONEPE',
          'displayName': 'PhonePe',
          'icon': 'https://staticpg.paytmpayments.com/pg-widgets/v1/upi/phonepe.svg',
          'scheme': 'phonepe',
        },
        {
          'name': 'PAYTM',
          'displayName': 'Paytm',
          'icon': 'https://staticpg.paytmpayments.com/pg-widgets/v1/upi/paytm.svg',
          'scheme': 'paytmmp',
        },
      ]);
    }

    return apps;
  }

  /// Sends installed UPI apps list to the Paytm JS Checkout webview
  Future<void> _sendInstalledUpiAppsToWebview(InAppWebViewController controller) async {
    try {
      final apps = await _getInstalledUpiAppsForIos();
      final jsonStr = jsonEncode(apps);
      debugPrint('📱 [PaytmUPI] Sending installed UPI apps to webview: $jsonStr');

      final js = '''
        (function() {
          var apps = $jsonStr;
          console.log('[NativeBridge] Invoking setUpiIntentApps with:', JSON.stringify(apps));
          if (window.upiIntent && typeof window.upiIntent.setUpiIntentApps === 'function') {
            try { window.upiIntent.setUpiIntentApps(apps); } catch(e) { window.upiIntent.setUpiIntentApps(JSON.stringify(apps)); }
          }
          if (typeof window.setUpiIntentApps === 'function') {
            try { window.setUpiIntentApps(apps); } catch(e) { window.setUpiIntentApps(JSON.stringify(apps)); }
          }
          if (window.Paytm && typeof window.Paytm.setUpiIntentApps === 'function') {
            try { window.Paytm.setUpiIntentApps(apps); } catch(e) { window.Paytm.setUpiIntentApps(JSON.stringify(apps)); }
          }
          window.upiIntentApps = apps;
          try {
            var ev = new CustomEvent('upiIntentAppsReady', { detail: apps });
            window.dispatchEvent(ev);
            document.dispatchEvent(ev);
          } catch(e) {}
        })();
      ''';
      await controller.evaluateJavascript(source: js);
    } catch (e) {
      debugPrint('❌ [PaytmUPI] Error sending apps to webview: $e');
    }
  }

  // ==========================================
  // SCREEN 4: PAYTM CHECKOUT IN-APP WEBVIEW
  // ==========================================
  Widget _buildPaytmCheckoutScreen(BuildContext context, bool isDark) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Paytm Checkout ($_promoAmount)'),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _handleBackNavigation();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            tooltip: 'Open in Browser',
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
        ],
      ),
      body: Platform.isIOS
          ? Stack(
              children: [
                InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(_checkoutUrl)),
                  initialUserScripts: UnmodifiableListView<UserScript>([
                    UserScript(
                      source: '''
                        (function() {
                          console.log('[NativeBridge] Initializing Android User-Agent & UPI bridge on iOS AT_DOCUMENT_START');
                          
                          // 1. Override navigator properties to simulate Android Chrome so Paytm serves UPI intent options
                          try {
                            Object.defineProperty(navigator, 'userAgent', {
                              get: function() { return 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36'; }
                            });
                            Object.defineProperty(navigator, 'appVersion', {
                              get: function() { return '5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36'; }
                            });
                            Object.defineProperty(navigator, 'platform', {
                              get: function() { return 'Linux armv8l'; }
                            });
                          } catch (e) {}

                          // 2. Intercept direct clicks on links with intent:, upi:, or tez: schemes
                          document.addEventListener('click', function(e) {
                            var el = e.target;
                            while (el && el.tagName !== 'A') {
                              el = el.parentElement;
                            }
                            if (el && el.href) {
                              var h = el.href;
                              if (h.startsWith('intent:') || h.startsWith('upi:') || h.startsWith('tez:')) {
                                e.preventDefault();
                                e.stopPropagation();
                                console.log('[NativeBridge] Intercepted link click: ' + h);
                                if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                                  window.flutter_inappwebview.callHandler('onExternalIntentClick', h);
                                }
                              }
                            }
                          }, true);

                          // 3. Inject sendSignalToNative bridge
                          var handler = {
                            postMessage: function(data) {
                              console.log('[NativeBridge] sendSignalToNative called with:', JSON.stringify(data));
                              try {
                                if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                                  window.flutter_inappwebview.callHandler('sendSignalToNative', data);
                                } else {
                                  window.addEventListener('flutterInAppWebViewPlatformReady', function() {
                                    window.flutter_inappwebview.callHandler('sendSignalToNative', data);
                                  });
                                }
                              } catch (err) {
                                console.error('[NativeBridge] Error sending signal:', err);
                              }
                            }
                          };

                          if (!window.webkit) window.webkit = {};
                          if (!window.webkit.messageHandlers) window.webkit.messageHandlers = {};

                          try {
                            window.webkit.messageHandlers.sendSignalToNative = handler;
                          } catch (e) {
                            try {
                              Object.defineProperty(window.webkit.messageHandlers, 'sendSignalToNative', {
                                value: handler,
                                writable: true,
                                configurable: true,
                                enumerable: true
                              });
                            } catch (e2) {}
                          }

                          window.sendSignalToNative = handler;
                          if (!window.upiIntent) window.upiIntent = {};
                        })();
                      ''',
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                      forMainFrameOnly: false,
                    ),
                  ]),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    useShouldOverrideUrlLoading: true,
                    mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                    allowContentAccess: true,
                    allowFileAccess: true,
                    allowsInlineMediaPlayback: true,
                    isFraudulentWebsiteWarningEnabled: false,
                    allowsBackForwardNavigationGestures: true,
                    sharedCookiesEnabled: true,
                    thirdPartyCookiesEnabled: true,
                    javaScriptCanOpenWindowsAutomatically: true,
                    supportMultipleWindows: true,
                    cacheEnabled: false,
                    clearCache: true,
                    userAgent:
                        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
                  ),
                  onConsoleMessage: (controller, consoleMessage) {
                    debugPrint('🌐 [PaytmWebView-iOS] Console: ${consoleMessage.messageLevel} | ${consoleMessage.message}');
                  },
                  onReceivedError: (controller, request, error) {
                    debugPrint('⚠️ [PaytmWebView-iOS] Error: ${error.type} | ${error.description} on ${request.url}');
                  },
                  onCreateWindow: (controller, createWindowAction) async {
                    final reqUrl = createWindowAction.request.url;
                    if (reqUrl != null) {
                      final scheme = reqUrl.scheme.toLowerCase();
                      final urlStr = reqUrl.toString();
                      if (scheme != 'http' && scheme != 'https' && scheme != 'about' && scheme != 'javascript') {
                        debugPrint('🚀 [PaytmWebView-iOS] onCreateWindow intercepted external scheme: $urlStr');
                        Uri? targetUri = reqUrl;
                        if (scheme == 'intent') {
                          targetUri = _convertIntentToIosUri(urlStr);
                        }
                        if (targetUri != null) {
                          await _launchIosUpiUri(targetUri);
                        }
                        return true;
                      } else {
                        controller.loadUrl(urlRequest: URLRequest(url: reqUrl));
                        return true;
                      }
                    }
                    return false;
                  },
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

                    // Handle link clicks intercepted in JS
                    controller.addJavaScriptHandler(
                      handlerName: 'onExternalIntentClick',
                      callback: (args) async {
                        if (args.isNotEmpty) {
                          final urlStr = args[0].toString();
                          debugPrint('🚀 [PaytmClick] Handled external click: $urlStr');
                          Uri? targetUri = Uri.tryParse(urlStr);
                          if (urlStr.startsWith('intent:')) {
                            targetUri = _convertIntentToIosUri(urlStr);
                          }
                          if (targetUri != null) {
                            await _launchIosUpiUri(targetUri);
                          }
                        }
                      },
                    );

                    // Handle sendSignalToNative from Paytm JS Checkout on iOS
                    controller.addJavaScriptHandler(
                      handlerName: 'sendSignalToNative',
                      callback: (args) async {
                        debugPrint('🔔 [PaytmSignal] Received sendSignalToNative: $args');
                        if (args.isEmpty) return;

                        try {
                          final firstArg = args[0];
                          Map<String, dynamic> data = {};
                          String signalText = '';

                          if (firstArg is Map) {
                            data = Map<String, dynamic>.from(firstArg);
                            signalText = (data['message'] ?? data['signal'] ?? data['action'] ?? '').toString();
                          } else if (firstArg is String) {
                            signalText = firstArg;
                            try {
                              final decoded = jsonDecode(firstArg);
                              if (decoded is Map) {
                                data = Map<String, dynamic>.from(decoded);
                                signalText = (data['message'] ?? data['signal'] ?? data['action'] ?? signalText).toString();
                              }
                            } catch (_) {}
                          }

                          debugPrint('🔔 [PaytmSignal] Parsed signalText="$signalText", data=$data');

                          // Signal 1: Request installed UPI apps list
                          if (signalText.contains('setUpiIntentApps') ||
                              signalText.contains('callPSPApp') ||
                              data.containsKey('pspApps') ||
                              data.containsKey('schemas')) {
                            debugPrint('🔔 [PaytmSignal] Handling Execute setUpiIntentApps signal');
                            await _sendInstalledUpiAppsToWebview(controller);
                            return;
                          }

                          // Signal 2: Request invocation of selected UPI PSP app
                          final deeplink = data['deeplink'] ?? data['deepLink'] ?? data['url'] ?? data['uri'];
                          if (signalText.contains('Invoke PSP app') ||
                              signalText.contains('invokePSPApp') ||
                              deeplink != null) {
                            String? targetLink = deeplink?.toString();
                            if (targetLink == null || targetLink.isEmpty) {
                              if (signalText.startsWith('intent://') ||
                                  signalText.startsWith('tez://') ||
                                  signalText.startsWith('phonepe://') ||
                                  signalText.startsWith('paytmmp://') ||
                                  signalText.startsWith('paytm://') ||
                                  signalText.startsWith('upi://') ||
                                  signalText.startsWith('bhim://') ||
                                  signalText.startsWith('credpay://') ||
                                  signalText.startsWith('gpay://')) {
                                targetLink = signalText;
                              }
                            }

                            if (targetLink != null && targetLink.isNotEmpty) {
                              debugPrint('🚀 [PaytmSignal] Launching PSP deeplink: $targetLink');
                              Uri? targetUri = Uri.tryParse(targetLink);
                              if (targetLink.startsWith('intent:')) {
                                targetUri = _convertIntentToIosUri(targetLink);
                              }
                              if (targetUri != null) {
                                await _launchIosUpiUri(targetUri);
                              }
                              return;
                            }
                          }
                        } catch (e) {
                          debugPrint('❌ [PaytmSignal] Error processing sendSignalToNative: $e');
                        }
                      },
                    );
                  },
                  shouldOverrideUrlLoading: (controller, navigationAction) async {
                    final uri = navigationAction.request.url;
                    if (uri == null) return NavigationActionPolicy.ALLOW;

                    final urlStr = uri.toString();

                    // Check if Paytm callback URL reached
                    if (urlStr.contains('/paytm/callback') || urlStr.contains('/callback')) {
                      final upper = urlStr.toUpperCase();
                      if (upper.contains('TXN_FAILURE') ||
                          upper.contains('STATUS=FAILURE') ||
                          upper.contains('STATUS=FAILED') ||
                          upper.contains('RESPCODE=227') ||
                          upper.contains('RESPCODE=295') ||
                          upper.contains('CANCEL')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment was cancelled or failed.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        _handleBackNavigation();
                        return NavigationActionPolicy.CANCEL;
                      }
                      return NavigationActionPolicy.ALLOW;
                    }

                    // Handle external app schemes (intent://, tez://, gpay://, phonepe://, paytmmp://, paytm://, upi://, bhim://, credpay://, etc.)
                    final scheme = uri.scheme.toLowerCase();
                    if (scheme != 'http' && scheme != 'https' && scheme != 'about' && scheme != 'javascript') {
                      debugPrint('🚀 [PaytmWebView-iOS] shouldOverrideUrlLoading external scheme: $urlStr');
                      Uri? targetUri = uri;
                      if (scheme == 'intent') {
                        targetUri = _convertIntentToIosUri(urlStr);
                      }
                      if (targetUri != null) {
                        await _launchIosUpiUri(targetUri);
                      }
                      return NavigationActionPolicy.CANCEL;
                    }

                    return NavigationActionPolicy.ALLOW;
                  },
                  onLoadStart: (controller, url) {
                    if (mounted) setState(() => _isWebViewLoading = true);
                    // Inject bridges into window
                    controller.evaluateJavascript(source: '''
                      (function() {
                        if (!window.TrevionPaymentChannel) {
                          window.TrevionPaymentChannel = {
                            postMessage: function(msg) {
                              window.flutter_inappwebview.callHandler('TrevionPaymentChannel', msg);
                            }
                          };
                        }
                        var handler = {
                          postMessage: function(data) {
                            try {
                              if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                                window.flutter_inappwebview.callHandler('sendSignalToNative', data);
                              }
                            } catch (e) {}
                          }
                        };
                        if (!window.webkit) window.webkit = {};
                        if (!window.webkit.messageHandlers) window.webkit.messageHandlers = {};
                        try {
                          window.webkit.messageHandlers.sendSignalToNative = handler;
                        } catch(e) {
                          try {
                            Object.defineProperty(window.webkit.messageHandlers, 'sendSignalToNative', {
                              value: handler,
                              writable: true,
                              configurable: true,
                              enumerable: true
                            });
                          } catch(e2) {}
                        }
                        window.sendSignalToNative = handler;
                        if (!window.upiIntent) window.upiIntent = {};
                      })();
                    ''');
                  },
                  onLoadStop: (controller, url) async {
                    if (mounted) setState(() => _isWebViewLoading = false);
                    if (url != null) {
                      final urlStr = url.toString();
                      final upper = urlStr.toUpperCase();

                      // Re-ensure bridges
                      controller.evaluateJavascript(source: '''
                        (function() {
                          if (!window.TrevionPaymentChannel) {
                            window.TrevionPaymentChannel = {
                              postMessage: function(msg) {
                                window.flutter_inappwebview.callHandler('TrevionPaymentChannel', msg);
                              }
                            };
                          }
                          var handler = {
                            postMessage: function(data) {
                              try {
                                if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                                  window.flutter_inappwebview.callHandler('sendSignalToNative', data);
                                }
                              } catch(e) {}
                            }
                          };
                          if (!window.webkit) window.webkit = {};
                          if (!window.webkit.messageHandlers) window.webkit.messageHandlers = {};
                          try {
                            window.webkit.messageHandlers.sendSignalToNative = handler;
                          } catch(e) {
                            try {
                              Object.defineProperty(window.webkit.messageHandlers, 'sendSignalToNative', {
                                value: handler,
                                writable: true,
                                configurable: true,
                                enumerable: true
                              });
                            } catch(e2) {}
                          }
                          window.sendSignalToNative = handler;
                          if (!window.upiIntent) window.upiIntent = {};
                        })();
                      ''');

                      // Proactively send installed UPI apps to page so buttons appear immediately
                      _sendInstalledUpiAppsToWebview(controller);
                      Future.delayed(const Duration(milliseconds: 600), () {
                        if (mounted) _sendInstalledUpiAppsToWebview(controller);
                      });
                      Future.delayed(const Duration(milliseconds: 1500), () {
                        if (mounted) _sendInstalledUpiAppsToWebview(controller);
                      });

                      if (urlStr.contains('/paytm/callback') || urlStr.contains('/callback')) {
                        try {
                          final html = await controller.getHtml() ?? '';
                          final upperHtml = html.toUpperCase();
                          if (upperHtml.contains('PAYMENT FAILED') ||
                              upperHtml.contains('ORDER NOT FOUND') ||
                              upperHtml.contains('STATUS-PILL">FAILED')) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Payment Failed. Please try again.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            _handleBackNavigation();
                            return;
                          }
                        } catch (_) {}
                        _onPaymentSuccessful();
                        return;
                      }

                      if (upper.contains('TXN_SUCCESS') ||
                          upper.contains('STATUS=SUCCESS') ||
                          upper.contains('STATUS=TXN_SUCCESS') ||
                          upper.contains('RESPCODE=01')) {
                        _onPaymentSuccessful();
                      } else if (upper.contains('TXN_FAILURE') ||
                          upper.contains('STATUS=FAILURE') ||
                          upper.contains('STATUS=FAILED') ||
                          upper.contains('RESPCODE=227') ||
                          upper.contains('CANCEL')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment was cancelled or failed.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        _handleBackNavigation();
                      }
                    }
                  },
                  onUpdateVisitedHistory: (controller, url, isReload) {
                    if (url != null) {
                      final upper = url.toString().toUpperCase();
                      if (upper.contains('TXN_FAILURE') ||
                          upper.contains('STATUS=FAILURE') ||
                          upper.contains('STATUS=FAILED') ||
                          upper.contains('RESPCODE=227') ||
                          upper.contains('CANCEL')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment was cancelled or failed.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        _handleBackNavigation();
                      } else if (upper.contains('TXN_SUCCESS') ||
                          upper.contains('STATUS=SUCCESS') ||
                          upper.contains('STATUS=TXN_SUCCESS') ||
                          upper.contains('RESPCODE=01')) {
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
                  const AppShimmerDetailSkeleton(),
              ],
            )
          : InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_checkoutUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                useShouldOverrideUrlLoading: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                allowContentAccess: true,
                allowFileAccess: true,
                thirdPartyCookiesEnabled: true,
                sharedCookiesEnabled: true,
                javaScriptCanOpenWindowsAutomatically: true,
                cacheEnabled: false,
                clearCache: true,
                userAgent:
                    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
              ),
              onConsoleMessage: (controller, consoleMessage) {
                debugPrint('🌐 [PaytmWebView] Console: ${consoleMessage.messageLevel} | ${consoleMessage.message}');
              },
              onReceivedError: (controller, request, error) {
                debugPrint('⚠️ [PaytmWebView] Error: ${error.type} | ${error.description} on ${request.url}');
              },
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
                if (urlStr.contains('/paytm/callback') || urlStr.contains('/callback')) {
                  final upper = urlStr.toUpperCase();
                  if (upper.contains('TXN_FAILURE') ||
                      upper.contains('STATUS=FAILURE') ||
                      upper.contains('STATUS=FAILED') ||
                      upper.contains('RESPCODE=227') ||
                      upper.contains('RESPCODE=295') ||
                      upper.contains('CANCEL')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Payment was cancelled or failed.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    _handleBackNavigation();
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
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
                // Inject bridge into window
                controller.evaluateJavascript(source: '''
                  if (!window.TrevionPaymentChannel) {
                    window.TrevionPaymentChannel = {
                      postMessage: function(msg) {
                        window.flutter_inappwebview.callHandler('TrevionPaymentChannel', msg);
                      }
                    };
                  }
                ''');
              },
              onUpdateVisitedHistory: (controller, url, isReload) {
                if (url != null) {
                  final upper = url.toString().toUpperCase();
                  if (upper.contains('TXN_FAILURE') ||
                      upper.contains('STATUS=FAILURE') ||
                      upper.contains('STATUS=FAILED') ||
                      upper.contains('RESPCODE=227') ||
                      upper.contains('CANCEL')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Payment was cancelled or failed.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    _handleBackNavigation();
                  } else if (upper.contains('TXN_SUCCESS') ||
                      upper.contains('STATUS=SUCCESS') ||
                      upper.contains('STATUS=TXN_SUCCESS') ||
                      upper.contains('RESPCODE=01')) {
                    _onPaymentSuccessful();
                  }
                }
              },
              onReceivedHttpError: (controller, request, errorResponse) {
                if (_currentStep == PromoStep.orderSuccess) return;
                debugPrint('⚠️ [InAppWebView] HTTP Error: ${errorResponse.statusCode}');
                if ((errorResponse.statusCode ?? 0) >= 500) {
                  if (mounted && _currentStep != PromoStep.orderSuccess) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Server Error during Paytm callback. Please check your connection.'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }
                }
              },
              onLoadStop: (controller, url) async {
                if (url != null) {
                  final urlStr = url.toString();
                  final upper = urlStr.toUpperCase();

                  // Inject bridge
                  controller.evaluateJavascript(source: '''
                    if (!window.TrevionPaymentChannel) {
                      window.TrevionPaymentChannel = {
                        postMessage: function(msg) {
                          window.flutter_inappwebview.callHandler('TrevionPaymentChannel', msg);
                        }
                      };
                    }
                  ''');

                  if (urlStr.contains('/paytm/callback') || urlStr.contains('/callback')) {
                    try {
                      final html = await controller.getHtml() ?? '';
                      final upperHtml = html.toUpperCase();
                      if (upperHtml.contains('PAYMENT FAILED') ||
                          upperHtml.contains('ORDER NOT FOUND') ||
                          upperHtml.contains('STATUS-PILL">FAILED')) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Payment Failed. Please try again.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        _handleBackNavigation();
                        return;
                      }
                    } catch (_) {}
                    // Navigates directly to Flutter's dedicated Success Screen!
                    _onPaymentSuccessful();
                    return;
                  }

                  if (upper.contains('TXN_SUCCESS') ||
                      upper.contains('STATUS=SUCCESS') ||
                      upper.contains('STATUS=TXN_SUCCESS') ||
                      upper.contains('RESPCODE=01')) {
                    _onPaymentSuccessful();
                  } else if (upper.contains('TXN_FAILURE') ||
                      upper.contains('STATUS=FAILURE') ||
                      upper.contains('STATUS=FAILED') ||
                      upper.contains('RESPCODE=227') ||
                      upper.contains('CANCEL')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Payment was cancelled or failed.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    _handleBackNavigation();
                  }
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
                      _buildOrderRow('Amount Paid', _lastSuccessOrder['amount'] ?? _promoAmountFormatted, isDark),
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
