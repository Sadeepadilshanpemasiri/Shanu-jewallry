import 'package:flutter/material.dart';

class ShopLanguage extends InheritedWidget {
  const ShopLanguage({super.key, required this.locale, required super.child});
  final Locale locale;

  static Locale of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShopLanguage>()?.locale ??
      const Locale('en');

  @override
  bool updateShouldNotify(ShopLanguage oldWidget) => oldWidget.locale != locale;
}

String shopCopy(Locale locale, String value) =>
    locale.languageCode == 'si' ? _sinhala[value] ?? value : value;

extension ShopCopyContext on BuildContext {
  String tr(String value) => shopCopy(ShopLanguage.of(this), value);
}

class Copy extends StatelessWidget {
  const Copy(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) => Text(
    context.tr(data),
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
  );
}

const _sinhala = {
  'Some records could not be loaded.': 'සමහර වාර්තා ලබාගත නොහැකි විය.',
  'No matching records.': 'ගැළපෙන වාර්තා නැත.',
  'The app is open in standalone mode.': 'යෙදුම ස්ථාපිත ආකාරයෙන් විවෘත කර ඇත.',
  'Open the browser menu and choose Install app or Add to Home Screen. On iPhone, use Safari’s Share menu.':
      'බ්‍රවුසර මෙනුවෙන් Install app හෝ Add to Home Screen තෝරන්න. iPhone සඳහා Safari හි Share මෙනුව භාවිත කරන්න.',
  'Includes business records in JSON. Keep the file private.':
      'ව්‍යාපාර වාර්තා JSON ආකෘතියෙන් අඩංගු වේ. ගොනුව පුද්ගලිකව තබා ගන්න.',
  'Could not download the backup. Check your connection.':
      'උපස්ථය බාගත කළ නොහැකි විය. සම්බන්ධතාව පරීක්ෂා කරන්න.',
  "Owner workspace": "හිමිකරුගේ වැඩබිම",
  "Sign in": "පිවිසෙන්න",
  "Sign out": "පිටවන්න",
  "Use the shop owner’s email and password.":
      "වෙළඳසැල් හිමිකරුගේ ඊමේල් ලිපිනය සහ මුරපදය භාවිත කරන්න.",
  "Email": "ඊමේල් ලිපිනය",
  "Password": "මුරපදය",
  "Show password": "මුරපදය පෙන්වන්න",
  "Hide password": "මුරපදය සඟවන්න",
  "Enter a valid email address.": "වලංගු ඊමේල් ලිපිනයක් ඇතුළත් කරන්න.",
  "Enter your password.": "ඔබේ මුරපදය ඇතුළත් කරන්න.",
  "Check your email and password.": "ඊමේල් ලිපිනය සහ මුරපදය පරීක්ෂා කරන්න.",
  "This account does not have owner access.":
      "මෙම ගිණුමට හිමිකරුගේ ප්‍රවේශය නැත.",
  "Check your connection and try again.":
      "සම්බන්ධතාව පරීක්ෂා කර නැවත උත්සාහ කරන්න.",
  "Too many attempts. Try again in a few minutes.":
      "උත්සාහ ගණන වැඩියි. මිනිත්තු කිහිපයකින් නැවත උත්සාහ කරන්න.",
  "Sign-in is currently unavailable.": "දැනට පිවිසිය නොහැක.",
  "Your owner session could not be verified.":
      "හිමිකරුගේ සැසිය තහවුරු කළ නොහැකි විය.",
  "Connect Firebase": "Firebase සම්බන්ධ කරන්න",
  "Retry": "නැවත උත්සාහ කරන්න",
  "Appearance": "පෙනුම",
  "System": "පද්ධතිය අනුව",
  "Dark": "අඳුරු",
  "Light": "ආලෝක",
  "Language": "භාෂාව",
  "Business overview": "ව්‍යාපාර සාරාංශය",
  "New order": "නව ඇණවුම",
  "Scan parcel": "පාර්සලය ස්කෑන් කරන්න",
  "Add product": "නිෂ්පාදනය එක් කරන්න",
  "Open orders": "ඇණවුම් විවෘත කරන්න",
  "Open inventory": "තොගය විවෘත කරන්න",
  "Open customers": "පාරිභෝගිකයින් විවෘත කරන්න",
  "Today’s orders": "අද ඇණවුම්",
  "Today’s delivered revenue": "අද භාරදුන් ඇණවුම් ආදායම",
  "Pending orders": "පොරොත්තු ඇණවුම්",
  "To ship": "යැවීමට තිබෙන",
  "In transit": "ප්‍රවාහනයේ",
  "Low or out of stock": "අඩු හෝ අවසන් තොග",
  "Cancelled this week": "මෙම සතියේ අවලංගු කළ",
  "Needs attention": "අවධානය අවශ්‍යයි",
  "Attention thresholds": "අවධාන සීමා",
  "No orders or stock need attention.": "අවධානය අවශ්‍ය ඇණවුම් හෝ තොග නැත.",
  "Sales trend": "විකුණුම් ප්‍රවණතාව",
  "Order status": "ඇණවුම් තත්ත්වය",
  "Best-selling products": "වැඩිපුරම විකිණෙන නිෂ්පාදන",
  "Orders": "ඇණවුම්",
  "Inventory": "තොගය",
  "Customers": "පාරිභෝගිකයින්",
  "Reports": "වාර්තා",
  "Business performance": "ව්‍යාපාර කාර්යසාධනය",
  "Quick Ship": "ඉක්මන් පාර්සල් යැවීම",
  "Notifications": "දැනුම්දීම්",
  "Settings": "සැකසුම්",
  "Couriers": "ප්‍රවාහන සේවා",
  "Add courier": "ප්‍රවාහන සේවාව එක් කරන්න",
  "Courier settings": "ප්‍රවාහන සේවා සැකසුම්",
  "Save courier": "ප්‍රවාහන සේවාව සුරකින්න",
  "Add customer": "පාරිභෝගිකයෙකු එක් කරන්න",
  "Edit customer": "පාරිභෝගික තොරතුරු සංස්කරණය",
  "Save customer": "පාරිභෝගික තොරතුරු සුරකින්න",
  "Customer": "පාරිභෝගිකයා",
  "Products": "නිෂ්පාදන",
  "Payment": "ගෙවීම",
  "Review": "සමාලෝචනය",
  "Continue": "ඉදිරියට",
  "Back": "ආපසු",
  "Save order": "ඇණවුම සුරකින්න",
  "Edit pending order": "පොරොත්තු ඇණවුම සංස්කරණය",
  "Confirm immediately": "වහාම තහවුරු කරන්න",
  "Review customer history": "පාරිභෝගික ඉතිහාසය බලන්න",
  "Review this customer’s history": "මෙම පාරිභෝගිකයාගේ ඉතිහාසය බලන්න",
  "Require advance payment": "අත්තිකාරමක් අවශ්‍යයි",
  "Proceed": "ඉදිරියට යන්න",
  "Watchlist": "අවධාන ලැයිස්තුව",
  "Blacklist": "අවහිර ලැයිස්තුව",
  "Order history": "ඇණවුම් ඉතිහාසය",
  "No orders yet.": "තවම ඇණවුම් නැත.",
  "Create your first order.": "ඔබේ පළමු ඇණවුම සාදන්න.",
  "No orders match these filters.": "මෙම පෙරහන්වලට ගැළපෙන ඇණවුම් නැත.",
  "Pending": "පොරොත්තුවෙන්",
  "Confirmed": "තහවුරු කර ඇත",
  "Packed": "ඇසුරුම් කර ඇත",
  "Shipped": "යවා ඇත",
  "Delivered": "භාර දී ඇත",
  "Cancelled": "අවලංගු කර ඇත",
  "Returned": "ආපසු ලැබී ඇත",
  "Failed delivery": "භාරදීමට නොහැකි විය",
  "Cash on delivery": "භාරදීමේදී මුදල් ගෙවීම",
  "Bank transfer": "බැංකු මාරුව",
  "Paid": "ගෙවා ඇත",
  "All": "සියල්ල",
  "Any date": "ඕනෑම දිනයක්",
  "Edit product": "නිෂ්පාදනය සංස්කරණය",
  "Save product": "නිෂ්පාදනය සුරකින්න",
  "Product photos": "නිෂ්පාදන ඡායාරූප",
  "Choose photos": "ඡායාරූප තෝරන්න",
  "Adjust stock": "තොගය සකසන්න",
  "Inventory valuation": "තොග වටිනාකම",
  "Stock history": "තොග වෙනස්වීම් ඉතිහාසය",
  "Product barcode": "නිෂ්පාදන බාර්කෝඩ්",
  "Copy SKU": "SKU අංකය පිටපත් කරන්න",
  "In stock": "තොග ඇත",
  "Out of stock": "තොග අවසන්",
  "Save stock movement": "තොග වෙනස සුරකින්න",
  "Start camera": "කැමරාව අරඹන්න",
  "Stop camera": "කැමරාව නවතන්න",
  "Switch camera": "කැමරාව මාරු කරන්න",
  "Use code": "කේතය භාවිත කරන්න",
  "Batch summary": "පාර්සල් කාණ්ඩ සාරාංශය",
  "Link parcel to order": "පාර්සලය ඇණවුමට සම්බන්ධ කරන්න",
  "Choose order": "ඇණවුම තෝරන්න",
  "Link order": "ඇණවුම සම්බන්ධ කරන්න",
  "Enter waybill": "ප්‍රවාහන අංකය ඇතුළත් කරන්න",
  "Order items": "ඇණවුම් අයිතම",
  "Update status": "තත්ත්වය යාවත්කාලීන කරන්න",
  "Status timeline": "තත්ත්ව ඉතිහාසය",
  "Confirm status change": "තත්ත්ව වෙනස තහවුරු කරන්න",
  "Track with courier": "ප්‍රවාහන සේවයෙන් ලුහුබඳින්න",
  "Print invoice": "ඉන්වොයිසිය මුද්‍රණය කරන්න",
  "Share invoice": "ඉන්වොයිසිය බෙදාගන්න",
  "Print courier label": "පාර්සල් ලේබලය මුද්‍රණය කරන්න",
  "Download CSV": "CSV බාගන්න",
  "Download PDF": "PDF බාගන්න",
  "Share CSV": "CSV බෙදාගන්න",
  "Orders placed": "ලැබුණු ඇණවුම්",
  "Orders delivered": "භාරදුන් ඇණවුම්",
  "Delivered revenue": "භාරදුන් ඇණවුම් ආදායම",
  "Gross profit": "දළ ලාභය",
  "Cancellation and returns": "අවලංගු කිරීම් සහ ආපසු ලැබීම්",
  "Category performance": "කාණ්ඩ කාර්යසාධනය",
  "Courier performance": "ප්‍රවාහන සේවා කාර්යසාධනය",
  "Order sources": "ඇණවුම් ලැබුණු මාර්ග",
  "No records for this period.": "මෙම කාල සීමාවට වාර්තා නැත.",
  "Shop reminders": "වෙළඳසැලේ මතක් කිරීම්",
  "Inbox": "ලැබී ඇති",
  "Snoozed": "කල් දැමූ",
  "Completed": "අවසන් කළ",
  "Reminder rules": "මතක් කිරීමේ නීති",
  "Browser push": "බ්‍රවුසර දැනුම්දීම්",
  "Mark as read": "කියවූ බව සලකුණු කරන්න",
  "Snooze for 1 hour": "පැයක් කල් දමන්න",
  "Snooze for 1 day": "දිනයක් කල් දමන්න",
  "Mark done": "අවසන් බව සලකුණු කරන්න",
  "Save rules": "නීති සුරකින්න",
  "No snoozed reminders.": "කල් දැමූ මතක් කිරීම් නැත.",
  "No completed reminders.": "අවසන් කළ මතක් කිරීම් නැත.",
  "Install app": "යෙදුම ස්ථාපනය කරන්න",
  "Offline": "අන්තර්ජාල සම්බන්ධතාව නැත",
  "Cached records may be available. Stock and order transactions need a connection.":
      "කලින් සුරැකුණු වාර්තා පෙන්විය හැක. තොග සහ ඇණවුම් ගනුදෙනු සඳහා සම්බන්ධතාව අවශ්‍යයි.",
  "Global search": "සියලු වාර්තා සොයන්න",
  "Search orders, customers or products":
      "ඇණවුම්, පාරිභෝගිකයින් හෝ නිෂ්පාදන සොයන්න",
  "Download data backup": "දත්ත උපස්ථය බාගන්න",
  "Done": "අවසන්",
  "Close": "වසන්න",
  "Search by name or SKU": "නම හෝ SKU අනුව සොයන්න",
  "Product name": "නිෂ්පාදන නම",
  "Category": "කාණ්ඩය",
  "Metal type": "ලෝහ වර්ගය",
  "Description": "විස්තරය",
  "Cost price (LKR)": "පිරිවැය (LKR)",
  "Selling price (LKR)": "විකුණුම් මිල (LKR)",
  "Opening stock": "ආරම්භක තොගය",
  "Low-stock threshold": "අඩු තොග සීමාව",
  "Customer name": "පාරිභෝගික නම",
  "Delivery address": "භාරදීමේ ලිපිනය",
  "City or district": "නගරය හෝ දිස්ත්‍රික්කය",
  "Sri Lankan phone number": "ශ්‍රී ලංකා දුරකථන අංකය",
  "Customer phone": "පාරිභෝගික දුරකථන අංකය",
  "Search product or SKU": "නිෂ්පාදනය හෝ SKU සොයන්න",
  "Payment method": "ගෙවීමේ ක්‍රමය",
  "Order source": "ඇණවුම ලැබුණු මාර්ගය",
  "Deduct stock": "තොගයෙන් අඩු කරන්න",
  "Courier name": "ප්‍රවාහන සේවාවේ නම",
  "Tracking ID": "ලුහුබැඳීමේ අංකය",
  "Reason": "හේතුව",
  "Required": "අවශ්‍යයි",
};
