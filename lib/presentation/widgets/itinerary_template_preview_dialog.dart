import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/services/itinerary_service.dart';

enum _Screen { mobile, tablet, desktop }

_Screen _screen(double w) {
  if (w < 600) return _Screen.mobile;
  if (w < 1024) return _Screen.tablet;
  return _Screen.desktop;
}

const List<double> zoomSteps = [0.25, 0.5, 0.7, 0.75, 1.0, 1.25, 1.5];
const double _defaultZoom = 0.7;
const double viewportFill = 0.96;
const double templateW = 860.0;
const double templateH = 1100.0;

// ─────────────────────────────────────────────────────────────────────────────
//  MOBILE-FIRST CSS — full width, proportional scale
// ─────────────────────────────────────────────────────────────────────────────
const String _kCSS = r'''
<style>
:root{--ink:#0D0C0A;--ink-soft:#2C2A26;--ink-muted:#6B6860;--ink-faint:#9E9B95;
--paper:#FDFCF9;--paper-warm:#F5F3EE;--card:#FFFFFF;
--rule:rgba(13,12,10,.10);--rule-soft:rgba(13,12,10,.06);
--gold:#B8975A;--gold-lt:#D4B07A;--gold-pale:#F5EDD8;
--navy:#1B3A6B;--navy-pale:#EBF0FA;--green:#1A6B50;--red:#8B2020;
--r-sm:6px;--r-md:12px;--r-lg:18px;--r-xl:24px;
--sh-sm:0 2px 12px rgba(13,12,10,.06);--sh-md:0 8px 32px rgba(13,12,10,.09);
--sp-section:40px;--sp-card:28px;--sp-card-h:28px;--px:16px}
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
html{scroll-behavior:smooth;-webkit-text-size-adjust:100%}
body{font-family:'DM Sans',-apple-system,BlinkMacSystemFont,sans-serif;
font-size:15px;line-height:1.8;color:var(--ink-soft);background:var(--paper);
-webkit-font-smoothing:antialiased;text-rendering:optimizeLegibility;
overflow:visible!important;width:860px!important}
.preview-wrapper{width:860px!important;max-width:860px!important;margin:0;padding:0 var(--px) 60px!important;overflow:visible!important}
h1{font-family:'Cormorant Garamond',Georgia,serif;font-weight:700;
font-size:clamp(26px,7vw,54px);line-height:1.1;letter-spacing:-.025em;color:var(--ink)}
h2{font-family:'Cormorant Garamond',Georgia,serif;font-weight:700;
font-size:clamp(20px,5vw,36px);line-height:1.18;letter-spacing:-.02em;
color:var(--ink);margin-bottom:14px}
h3{font-family:'DM Sans',sans-serif;font-weight:600;font-size:15px;
line-height:1.4;color:var(--ink);margin-bottom:10px;letter-spacing:-.01em}
h4{font-family:'DM Mono','Courier New',monospace;font-weight:500;font-size:8px;
letter-spacing:.2em;text-transform:uppercase;color:var(--gold);margin-bottom:8px}
p{font-size:14px;line-height:1.85;color:var(--ink-soft);margin-bottom:12px}
em{font-family:'Cormorant Garamond',serif;font-style:italic;
font-size:1.05em;color:var(--ink-muted)}
strong{font-weight:600;color:var(--ink)}
a{color:var(--navy);text-decoration:none}
hr{border:none;height:1px;background:var(--rule);margin:28px 0}
.section-label,.eyebrow,[class*="section-label"],[class*="eyebrow"]{
font-family:'DM Mono',monospace!important;font-size:8px!important;font-weight:500!important;
letter-spacing:.22em!important;text-transform:uppercase!important;color:var(--navy)!important;
display:block!important;margin-bottom:10px!important}
.hero-section,.hero,.cover,.cover-section{position:relative!important;
width:100%!important;min-height:240px!important;overflow:hidden!important;
margin-bottom:var(--sp-section)!important;display:flex!important;
flex-direction:column!important;justify-content:flex-end!important}
.hero-section>img,.hero>img,.cover>img,.cover-section>img{position:absolute!important;
inset:0!important;width:100%!important;height:100%!important;
object-fit:cover!important;border-radius:0!important;margin:0!important;box-shadow:none!important}
.hero-section::after,.hero::after,.cover::after,.cover-section::after{content:''!important;
position:absolute!important;inset:0!important;
background:linear-gradient(to top,rgba(6,5,4,.92) 0%,rgba(6,5,4,.55) 40%,rgba(6,5,4,.08) 100%)!important;z-index:1!important}
.hero-content,.cover-content,.hero-body{position:relative!important;z-index:2!important;padding:24px 20px!important}
.hero h1,.hero-title,.cover h1{color:#FFF!important;text-shadow:0 2px 20px rgba(0,0,0,.35)!important;margin-bottom:10px!important}
.hero h2,.hero-subtitle{color:rgba(255,255,255,.72)!important;
font-family:'Cormorant Garamond',serif!important;font-style:italic!important;
font-size:16px!important;font-weight:400!important;margin-bottom:0!important}
.hero-badge,.premium-badge,.cover-badge{display:inline-block!important;
padding:4px 12px!important;border:1px solid rgba(255,255,255,.30)!important;
color:rgba(255,255,255,.90)!important;background:rgba(255,255,255,.10)!important;
backdrop-filter:blur(12px)!important;border-radius:100px!important;
font-family:'DM Mono',monospace!important;font-size:8px!important;
letter-spacing:.18em!important;text-transform:uppercase!important;margin-bottom:16px!important}
.hero-footer,.proposal-footer{position:relative!important;z-index:2!important;
display:flex!important;justify-content:space-between!important;align-items:center!important;
padding:10px 20px!important;background:rgba(0,0,0,.28)!important;
backdrop-filter:blur(8px)!important;font-family:'DM Mono',monospace!important;
font-size:8px!important;color:rgba(255,255,255,.60)!important;
letter-spacing:.12em!important;text-transform:uppercase!important}
.client-section,.dedication-block,.client-card,.client-block{background:var(--card)!important;
border:1px solid var(--rule)!important;border-radius:var(--r-md)!important;
padding:var(--sp-card) var(--sp-card-h)!important;margin-bottom:var(--sp-section)!important;
position:relative!important;overflow:hidden!important;box-shadow:var(--sh-sm)!important}
.client-section::before{content:''!important;position:absolute!important;left:0;top:0;bottom:0!important;
width:3px!important;background:linear-gradient(to bottom,var(--navy),#4A6FA5)!important;
border-radius:4px 0 0 4px!important}
.client-name,.client-section h2,.client-section h1{font-family:'Cormorant Garamond',serif!important;
font-size:clamp(24px,7vw,42px)!important;font-weight:700!important;color:var(--ink)!important;
letter-spacing:-.025em!important;line-height:1.08!important;margin-bottom:6px!important}
.client-company,.company-name,.client-section em{font-family:'Cormorant Garamond',serif!important;
font-style:italic!important;font-size:clamp(14px,4vw,20px)!important;color:var(--ink-muted)!important}
.tour-plan,.journey-outline,.toc-section,.itinerary-toc{background:var(--card)!important;
border:1px solid var(--rule)!important;border-radius:var(--r-md)!important;
padding:var(--sp-card)!important;margin-bottom:var(--sp-section)!important;
box-shadow:var(--sh-sm)!important}
.toc-item,.tour-plan-item,.journey-item{display:flex!important;align-items:center!important;
gap:12px!important;padding:11px 0!important;border-bottom:1px solid var(--rule-soft)!important;
font-size:13.5px!important;font-weight:500!important;color:var(--ink-soft)!important;
list-style:none!important}
.toc-item:last-child{border-bottom:none!important}
.day-num,.toc-day,[class*="day-num"],[class*="day-badge"]{flex-shrink:0!important;
display:inline-flex!important;align-items:center!important;justify-content:center!important;
min-width:54px!important;height:24px!important;padding:0 10px!important;
background:var(--navy)!important;color:#FFF!important;border-radius:100px!important;
font-family:'DM Mono',monospace!important;font-size:7.5px!important;font-weight:500!important;
letter-spacing:.1em!important;text-transform:uppercase!important}
.overview-section,.short-overview,.tour-overview,.overview-block{background:var(--navy)!important;
color:#FFFFFF!important;border-radius:var(--r-md)!important;
padding:var(--sp-card) var(--sp-card-h)!important;margin-bottom:var(--sp-section)!important;
position:relative!important;overflow:hidden!important}
.overview-section::before{content:''!important;position:absolute!important;
top:-80px;right:-80px!important;width:240px;height:240px!important;
border-radius:50%!important;background:rgba(255,255,255,.04)!important;pointer-events:none!important}
.overview-section h2,.overview-section .section-title{color:#FFF!important;margin-bottom:16px!important}
.overview-section p{color:rgba(255,255,255,.80)!important}
.overview-section .section-label,[class*="eyebrow"]{color:var(--gold-lt)!important}
.overview-section .tag,.overview-section .location-tag,.overview-section [class*="tag"]{
display:inline-block!important;padding:4px 10px!important;
background:rgba(255,255,255,.10)!important;border:1px solid rgba(255,255,255,.20)!important;
color:rgba(255,255,255,.90)!important;border-radius:100px!important;
font-family:'DM Mono',monospace!important;font-size:7.5px!important;
letter-spacing:.14em!important;text-transform:uppercase!important;
margin:4px 4px 4px 0!important}
.day-card,.itinerary-day,.day-block,.day-section{background:var(--card)!important;
border:1px solid var(--rule)!important;border-radius:var(--r-md)!important;
padding:var(--sp-card)!important;margin-bottom:20px!important;
box-shadow:var(--sh-sm)!important;position:relative!important;overflow:hidden!important}
.day-card::before{content:''!important;position:absolute!important;
top:0;left:0;right:0!important;height:2px!important;
background:linear-gradient(to right,var(--gold),var(--gold-lt),transparent)!important}
.day-badge,.day-label,.day-number-badge{display:inline-flex!important;align-items:center!important;
padding:4px 14px!important;background:var(--navy)!important;color:#FFF!important;
border-radius:100px!important;font-family:'DM Mono',monospace!important;
font-size:8px!important;font-weight:500!important;letter-spacing:.12em!important;
text-transform:uppercase!important;margin-bottom:16px!important}
.day-title,.day-card h2,.day-block h2,.day-section h2{font-family:'Cormorant Garamond',serif!important;
font-size:clamp(20px,5vw,30px)!important;font-weight:700!important;
color:var(--ink)!important;letter-spacing:-.018em!important;line-height:1.2!important;
margin-bottom:16px!important}
.day-card img,.day-block img,.day-section img{border-radius:var(--r-sm)!important;
margin:16px 0!important;box-shadow:var(--sh-sm)!important}
ul{padding-left:0!important;list-style:none!important}
li{padding:6px 0 6px 20px!important;position:relative!important;font-size:13.5px!important;
color:var(--ink-soft)!important;line-height:1.65!important;
border-bottom:1px solid var(--rule-soft)!important}
li:last-child{border-bottom:none!important}
li::before{content:'◆'!important;position:absolute!important;left:0;top:8px!important;
font-size:6px!important;color:var(--gold)!important}
img{display:block!important;max-width:100%!important;height:auto!important;
border-radius:var(--r-sm)!important;margin:16px 0!important;box-shadow:var(--sh-sm)!important}
.accommodation-section,.hotel-section,.lodging-section{margin-bottom:var(--sp-section)!important}
.hotel-card,.stay-card,.accommodation-card{background:var(--card)!important;
border:1px solid var(--rule)!important;border-radius:var(--r-sm)!important;
overflow:hidden!important;margin-bottom:16px!important;box-shadow:var(--sh-sm)!important}
.hotel-card>img:first-child,.stay-card>img:first-child,.accommodation-card>img:first-child{
width:100%!important;height:160px!important;object-fit:cover!important;
border-radius:0!important;margin:0!important;box-shadow:none!important}
.hotel-body,.stay-body,.hotel-card>div,.stay-card>div,.accommodation-card>div{padding:18px 16px!important}
.hotel-card h3,.stay-card h3,.hotel-name,.stay-name{font-family:'Cormorant Garamond',serif!important;
font-size:18px!important;font-weight:700!important;color:var(--ink)!important;margin-bottom:5px!important}
.hotel-badge,.stay-partner,.partner-label{display:inline-block!important;
padding:3px 8px!important;background:var(--gold-pale)!important;color:var(--gold)!important;
border-radius:100px!important;font-family:'DM Mono',monospace!important;
font-size:7px!important;letter-spacing:.16em!important;text-transform:uppercase!important;
font-weight:500!important;margin-bottom:8px!important}
.transport-section,.flights-section,.transportation{background:var(--card)!important;
border:1px solid var(--rule)!important;border-radius:var(--r-md)!!important;
padding:var(--sp-card)!important;margin-bottom:var(--sp-section)!important;
box-shadow:var(--sh-sm)!important}
.transport-badge,.flight-badge,.train-badge,[class*="transport-type"],[class*="transport-badge"]{
display:inline-flex!important;align-items:center!important;padding:4px 10px!important;
background:var(--navy-pale)!important;color:var(--navy)!important;
border-radius:100px!important;font-family:'DM Mono',monospace!important;
font-size:7.5px!important;font-weight:500!important;letter-spacing:.12em!important;
text-transform:uppercase!important;margin-bottom:8px!important;margin-right:6px!important}
.inclusions-section,.inclusions-exclusions{margin-bottom:var(--sp-section)!important}
.inclusions-grid{display:grid!important;grid-template-columns:1fr 1fr!important;
gap:14px!important;margin-top:20px!important}
.inclusions-card{background:var(--card)!important;border:1px solid var(--rule)!important;
border-top:3px solid var(--green)!important;border-radius:var(--r-sm)!important;
padding:20px!important;box-shadow:var(--sh-sm)!important}
.exclusions-card{background:var(--card)!important;border:1px solid var(--rule)!important;
border-top:3px solid var(--red)!important;border-radius:var(--r-sm)!important;
padding:20px!important;box-shadow:var(--sh-sm)!important}
.inclusions-card h4{color:var(--green)!important;margin-bottom:8px!important}
.exclusions-card h4{color:var(--red)!important;margin-bottom:8px!important}
.inclusions-card li::before{content:'✓'!important;color:var(--green)!important;
font-size:10px!important;top:6px!important}
.exclusions-card li::before{content:'✕'!important;color:var(--red)!important;
font-size:9px!important;top:7px!important}
.pricing-section,.pricing-block,.pricing-summary{background:var(--card)!important;
border:1px solid var(--rule)!important;border-radius:var(--r-md)!important;
padding:var(--sp-card) var(--sp-card-h)!important;margin-bottom:var(--sp-section)!important;
box-shadow:var(--sh-sm)!important}
.pricing-pkg-title,.primary-package-name{font-family:'Cormorant Garamond',serif!important;
font-size:clamp(18px,4vw,26px)!important;font-weight:700!important;
color:var(--ink)!important;margin-bottom:4px!important}
.pricing-meta{display:flex!important;gap:20px!important;flex-wrap:wrap!important;
padding:14px 0!important;border-top:1px solid var(--rule)!important;
border-bottom:1px solid var(--rule)!important;margin:16px 0!important}
.meta-label{font-family:'DM Mono',monospace!important;font-size:7.5px!important;
letter-spacing:.18em!important;text-transform:uppercase!important;color:var(--ink-faint)!important;
margin-bottom:2px!important}
.meta-value{font-family:'Cormorant Garamond',serif!important;
font-size:clamp(16px,3.5vw,22px)!important;font-weight:700!important;color:var(--ink)!important}
.cost-row{display:flex!important;justify-content:space-between!important;align-items:center!important;
padding:9px 0!important;border-bottom:1px solid var(--rule-soft)!important;
font-size:13px!important;color:var(--ink-muted)!important}
.cost-row:last-of-type{border-bottom:none!important}
.cost-amount{font-family:'DM Mono',monospace!important;font-size:12px!important;
font-weight:500!important;color:var(--ink-soft)!important}
.grand-total{display:flex!important;justify-content:space-between!important;
align-items:center!important;background:var(--ink)!important;
padding:16px 20px!important;border-radius:var(--r-sm)!important;margin-top:16px!important}
.gt-label{font-family:'DM Mono',monospace!important;font-size:8px!important;
letter-spacing:.18em!important;text-transform:uppercase!important;
color:rgba(255,255,255,.55)!important;margin-bottom:3px!important}
.gt-sub{font-size:10px!important;color:rgba(255,255,255,.38)!important}
.gt-price{font-family:'Cormorant Garamond',serif!important;
font-size:clamp(28px,7vw,46px)!important;font-weight:700!important;
color:#FFF!important;letter-spacing:-.025em!important;line-height:1!important}
.terms-section,.terms-block,.policy-section,.conditions{background:var(--paper-warm)!important;
border:1px solid var(--rule)!important;border-radius:var(--r-md)!important;
padding:var(--sp-card)!important;margin-bottom:var(--sp-section)!important}
.terms-category h4,.policy-category h4{color:var(--gold)!important;margin-bottom:8px!important}
.terms-category,.policy-category{margin-bottom:20px!important}
.page-footer,.footer-block,.signature-section{text-align:center!important;padding:24px!important;
border-top:1px solid var(--rule)!important;font-family:'DM Mono',monospace!important;
font-size:8px!important;letter-spacing:.14em!important;
text-transform:uppercase!important;color:var(--ink-faint)!important}
@keyframes fadeUp{from{opacity:0;transform:translateY(12px)}to{opacity:1;transform:translateY(0)}}
.day-card,.hotel-card,.pricing-section,.client-section,.overview-section,.terms-section{
animation:fadeUp .35s ease both!important}
@media(max-width:599px){
:root{--sp-section:32px;--sp-card:20px;--sp-card-h:16px;--px:12px}
body{font-size:13.5px}
.preview-wrapper{padding:0 var(--px) 48px!important}
.hero-section,.hero,.cover,.cover-section{min-height:200px!important;width:100%!important}
.hero-content,.cover-content,.hero-body{padding:20px 16px!important}
.hero h2,.hero-subtitle{font-size:14px!important}
.hero-footer,.proposal-footer{padding:8px 16px!important;font-size:7px!important}
.client-section,.dedication-block,.client-card,.client-block{padding:20px 16px!important;
border-radius:var(--r-sm)!important}
.toc-item,.tour-plan-item,.journey-item{gap:8px!important;padding:9px 0!important;font-size:13px!important}
.overview-section,.short-overview,.tour-overview,.overview-block{
border-radius:var(--r-sm)!important;padding:20px 16px!important}
.day-card,.itinerary-day,.day-block,.day-section{padding:18px 16px!important;
border-radius:var(--r-sm)!important;margin-bottom:16px!important}
.day-title,.day-card h2,.day-block h2,.day-section h2{font-size:20px!important;margin-bottom:12px!important}
.inclusions-grid{grid-template-columns:1fr!important;gap:12px!important}
.inclusions-card,.exclusions-card{padding:16px!important}
.pricing-section,.pricing-block,.pricing-summary{padding:20px 16px!important}
.pricing-meta{gap:16px!important}
.grand-total{padding:14px 16px!important;flex-wrap:wrap!important;gap:8px!important}
.gt-price{font-size:28px!important}
.hotel-card>img:first-child,.stay-card>img:first-child,.accommodation-card>img:first-child{
height:140px!important}
.hotel-body,.stay-body,.hotel-card>div,.stay-card>div{padding:14px 14px!important}
.transport-section,.flights-section,.transportation{padding:18px 16px!important}
.terms-section,.terms-block,.policy-section,.conditions{
padding:18px 16px!important;border-radius:var(--r-sm)!important}
li{font-size:13px!important;padding:5px 0 5px 18px!important}
p{font-size:13px!important}
}
@media(min-width:600px) and (max-width:1023px){
:root{--sp-section:36px;--sp-card:24px;--sp-card-h:24px;--px:20px}
.preview-wrapper{max-width:100%}
.hero-section,.hero,.cover,.cover-section{min-height:280px!important}
}
</style>''';

const String _kFonts = '''
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,400;0,600;0,700;1,400;1,600&family=DM+Sans:ital,opsz,wght@0,9..40,300;0,9..40,400;0,9..40,500;0,9..40,600;1,9..40,300&family=DM+Mono:wght@300;400;500&display=swap" rel="stylesheet">
''';

// ─────────────────────────────────────────────────────────────────────────────
//  DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class ItineraryTemplatePreviewDialog extends StatefulWidget {
  final String templateKey;
  final String templateName;

  const ItineraryTemplatePreviewDialog({
    super.key,
    required this.templateKey,
    required this.templateName,
  });

  @override
  State<ItineraryTemplatePreviewDialog> createState() => _DialogState();
}

class _DialogState extends State<ItineraryTemplatePreviewDialog>
    with SingleTickerProviderStateMixin {
  InAppWebViewController? _webCtrl;
  late AnimationController _shimmerCtrl;
  bool _webLoaded = false;
  final double zoomLevel = _defaultZoom;

  final ItineraryService _service = ItineraryService();
  bool _isLoading = false;
  String? _previewHtml;
  String? _error;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _fetchPreview();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPreview() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final html = await _service.getTemplatePreviewHtml(widget.templateKey);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _previewHtml = html;
      });
      _loadContent();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _loadContent() {
    final html = _previewHtml;
    if (html == null || html.isEmpty || _webCtrl == null || !mounted) return;
    final b64 = base64Encode(utf8.encode(_doc(html)));
    _webCtrl!.loadUrl(
      urlRequest: URLRequest(
        url: WebUri('data:text/html;charset=utf-8;base64,$b64'),
      ),
    );
  }

  String _doc(String body) => '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=5,user-scalable=yes">
$_kFonts
$_kCSS
</head>
<body><div class="preview-wrapper">$body</div></body>
</html>''';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screen = _screen(size.width);

    final dw = screen == _Screen.tablet
        ? size.width * 0.96
        : (size.width * 0.94).clamp(320.0, 1200.0);
    final dh = size.height * 0.93;

    return Center(
      child: Container(
        width: dw, height: dh,
        decoration: BoxDecoration(
          color: const Color(0xFFFDFCF9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 64, spreadRadius: -4,
              offset: const Offset(0, 28),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 14, offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Column(
                children: [
                  _MobileTopBar(
                    name: widget.templateName,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _webBody(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── WebView ─────────────────────────────────────────────────────────────────
  Widget _webBody() {
    final showShimmer = _isLoading || (!_webLoaded && _previewHtml == null);
    final hasError = _error != null;
    final hasNoData = !_isLoading && _previewHtml == null && !hasError;

    return Stack(
      children: [
        Positioned.fill(
          child: InAppWebView(
            gestureRecognizers: {
              Factory<VerticalDragGestureRecognizer>(
                  () => VerticalDragGestureRecognizer()),
            },
            initialSettings: InAppWebViewSettings(
              transparentBackground: true,
              supportZoom: true,
              builtInZoomControls: true,
              displayZoomControls: false,
              javaScriptEnabled: true,
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: false,
              verticalScrollBarEnabled: true,
              horizontalScrollBarEnabled: true,
              useWideViewPort: true,
              loadWithOverviewMode: true,
            ),
            onWebViewCreated: (ctrl) {
              _webCtrl = ctrl;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _loadContent();
              });
            },
            onLoadStop: (c, u) {
              if (mounted) setState(() => _webLoaded = true);
            },
            onReceivedError: (c, r, e) {
              if (mounted) setState(() => _webLoaded = true);
            },
          ),
        ),
        if (showShimmer)
          Positioned.fill(child: _Shimmer(ctrl: _shimmerCtrl)),
        if (hasError)
          Positioned.fill(
            child: Container(
              color: const Color(0xFFFDFCF9),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load template',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error ?? 'Unknown error occurred',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _webLoaded = false;
                          });
                          _fetchPreview();
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B3A6B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (hasNoData && !showShimmer)
          Positioned.fill(
            child: Container(
              color: const Color(0xFFFDFCF9),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.preview_rounded, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No preview available',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Template content could not be loaded.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MOBILE TOP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _MobileTopBar extends StatelessWidget {
  final String name;
  final VoidCallback onClose;

  const _MobileTopBar({
    required this.name,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEAE8E3), width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFF1B3A6B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('T',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: .5,
                  )),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Georgia', fontSize: 16,
                  fontWeight: FontWeight.w600, color: Color(0xFF0D0C0A),
                )),
          ),
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 32, height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3EE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE0DDD7)),
              ),
              child: const Icon(Icons.close_rounded,
                  size: 16, color: Color(0xFF2C2A26)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DESKTOP TOP BAR
// ─────────────────────────────────────────────────────────────────────────────
class DesktopTopBar extends StatelessWidget {
  final String name;
  final int zoomPercent;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  const DesktopTopBar({super.key,
    required this.name,
    required this.zoomPercent,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEAE8E3), width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF1B3A6B),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Center(
              child: Text('T',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: .5,
                  )),
            ),
          ),
          const SizedBox(width: 10),
          const Text('TREVION',
              style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w800,
                color: Color(0xFF0D0C0A), letterSpacing: 2.2,
              )),
          Container(width: 1, height: 16, margin: const EdgeInsets.symmetric(horizontal: 14),
              color: const Color(0xFFDDD9D2)),
          Expanded(
            child: Text(name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Georgia', fontSize: 13,
                  fontWeight: FontWeight.w600, color: Color(0xFF0D0C0A),
                )),
          ),
          const SizedBox(width: 12),
          _ZoomPill(
            zoomPercent: zoomPercent,
            onTap: onReset,
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
            size: 'large',
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 16, margin: const EdgeInsets.symmetric(horizontal: 8),
              color: const Color(0xFFDDD9D2)),
          const SizedBox(width: 6),
          Container(
            width: 7, height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF1A6B50), shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text('LIVE PREVIEW',
              style: TextStyle(
                fontFamily: 'Courier', fontSize: 8,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B6860), letterSpacing: 1.4,
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ZOOM PILL
// ─────────────────────────────────────────────────────────────────────────────
class _ZoomPill extends StatelessWidget {
  final int zoomPercent;
  final VoidCallback onTap;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final String size;

  const _ZoomPill({
    required this.zoomPercent,
    required this.onTap,
    required this.onZoomIn,
    required this.onZoomOut,
    this.size = 'small',
  });

  @override
  Widget build(BuildContext context) {
    final isLarge = size == 'large';
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3EE),
        borderRadius: BorderRadius.circular(isLarge ? 10 : 8),
        border: Border.all(color: const Color(0xFFE0DDD7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillBtn(icon: Icons.remove, onTap: onZoomOut),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isLarge ? 10 : 6,
                vertical: 0,
              ),
              child: Text(
                '$zoomPercent%',
                style: TextStyle(
                  fontSize: isLarge ? 11 : 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2C2A26),
                ),
              ),
            ),
          ),
          _PillBtn(icon: Icons.add, onTap: onZoomIn),
        ],
      ),
    );
  }
}

class _PillBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PillBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 28, height: 28,
        child: Center(
          child: Icon(icon, size: 13, color: const Color(0xFF2C2A26)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CLOSE BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class CloseBtn extends StatelessWidget {
  final VoidCallback onTap;
  const CloseBtn({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32, height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3EE),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0DDD7)),
          ),
          child: const Icon(Icons.close_rounded, size: 15, color: Color(0xFF2C2A26)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHIMMER
// ─────────────────────────────────────────────────────────────────────────────
class _Shimmer extends AnimatedWidget {
  const _Shimmer({required AnimationController ctrl}) : super(listenable: ctrl);
  AnimationController get _c => listenable as AnimationController;

  @override
  Widget build(BuildContext context) {
    final t = _c.value;
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 600;

    return Container(
      color: const Color(0xFFFDFCF9),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(isMobile ? 12.0 : 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _b(h: isMobile ? 180 : 280, w: double.infinity, r: 12, t: t),
            SizedBox(height: isMobile ? 16 : 24),
            _b(h: 10, w: 70, t: t),
            const SizedBox(height: 6),
            _b(h: isMobile ? 28 : 36, w: isMobile ? 180 : 260, t: t),
            const SizedBox(height: 4),
            _b(h: 14, w: isMobile ? 120 : 160, t: t),
            SizedBox(height: isMobile ? 16 : 22),
            _b(h: isMobile ? 90 : 130, w: double.infinity, r: 10, t: t),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _b(h: isMobile ? 120 : 150, r: 10, t: t)),
              SizedBox(width: isMobile ? 8 : 12),
              if (!isMobile) Expanded(child: _b(h: 150, r: 10, t: t)),
            ]),
            const SizedBox(height: 12),
            _b(h: isMobile ? 140 : 180, w: double.infinity, r: 10, t: t),
            const SizedBox(height: 12),
            _b(h: isMobile ? 80 : 110, w: double.infinity, r: 10, t: t),
          ],
        ),
      ),
    );
  }

  Widget _b({required double h, double? w, double r = 8, required double t}) =>
      Container(
        height: h, width: w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r),
          gradient: LinearGradient(
            begin: Alignment(-2 + t * 4, 0),
            end: Alignment(-1 + t * 4, 0),
            colors: const [
              Color(0xFFEEECE8),
              Color(0xFFF8F6F2),
              Color(0xFFEEECE8),
            ],
            stops: const [0, .5, 1],
          ),
        ),
      );
}