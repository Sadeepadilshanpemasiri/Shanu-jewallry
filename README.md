# Jewellery Business Manager

Phase 1 provides a responsive owner sign-in, protected workspace, persistent Firebase Auth session that signs out after 15 minutes of inactivity, and a saved light/dark/system appearance choice.

## Run on Windows

Install Flutter with Dart 3.8 or later, Chrome, Node.js, Java 21, and the Firebase CLI. Open this folder in VS Code. From its PowerShell terminal:

~~~powershell
flutter pub get
.\run-local.ps1
~~~

Chrome opens at http://localhost:5050/. Sign in as **owner@jewellery.test** with **JewelleryDemo123**. This owner exists in the local Auth emulator only. Keep the launcher running while using the app. It discards local emulator data on exit.

## Connect your Firebase project

1. Register a Web app in the Firebase console. Enable Email/Password Authentication and create one owner account in the console. Copy that user's UID.
2. Create the default Firestore database. Add the document **access/owner**, with a **uid** string containing the exact UID from Authentication. Set it via the Firebase console or a trusted Admin SDK session. Firestore rules deny changes to this document from the app.
3. Enable Cloud Storage before deploying its rules. If prompted, grant the Firebase Storage service agent access to evaluate rules that read Firestore. Inventory uses this bucket for product photos.
4. Create an ignored file named **.firebase-config.json** in the project root using the public Web app identifiers. Replace each value with the corresponding value from the Firebase console.

~~~json
{
  "FIREBASE_API_KEY": "web apiKey",
  "FIREBASE_APP_ID": "web appId",
  "FIREBASE_MESSAGING_SENDER_ID": "web messagingSenderId",
  "FIREBASE_PROJECT_ID": "web projectId",
  "FIREBASE_AUTH_DOMAIN": "web authDomain",
  "FIREBASE_STORAGE_BUCKET": "web storageBucket"
}
~~~

Add your development and hosting domains to Firebase Authentication's authorized domains where needed. See [Firebase setup for Flutter](https://firebase.google.com/docs/flutter/setup) and [Firebase email/password sign-in](https://firebase.google.com/docs/auth/flutter/password-auth).

~~~powershell
firebase deploy --project YOUR_PROJECT_ID --only firestore:rules,firestore:indexes,storage
flutter run -d chrome --dart-define-from-file=.firebase-config.json
~~~

## Checks and Hosting

~~~powershell
dart run build_runner build --delete-conflicting-outputs
dart format lib test
flutter analyze
flutter test
firebase emulators:exec --project demo-jewellery-manager --only auth,firestore,storage "node scripts/seed-local.mjs --verify"
.\build-web.ps1
firebase deploy --project YOUR_PROJECT_ID --only hosting
~~~

Open the deployed HTTPS URL and sign in as the owner. On a phone, use the browser's **Install app** or **Add to Home Screen** action where available. The Web manifest, icons, and Hosting rewrites are included. Offline app-shell caching and web push are included in the production build.

## Phase 2 — Inventory

From the owner workspace, open **Inventory**.

- Add a product with a unique SKU or leave it blank for an automatic code. Add up to six JPEG, PNG, or WebP photos. The picker requests 1600 px resizing and JPEG quality 82 where the browser supports it.
- Use category, metal, and stock filters or search by product name or SKU. Valuation totals use all active products, regardless of filters.
- Open a product to see its Code 128 barcode and stock history. **Scan SKU** uses the camera on HTTPS or localhost and includes manual SKU entry.
- Use **Adjust stock** to receive units, remove units, set a counted balance, or return units to stock. Add a reason. Every stock change and audit entry commit in the same Firestore transaction. Changes that would make stock negative are rejected.
- Variant labels such as size, colour, and length are stored on the product. Stock is counted per product.

For an existing Firebase deployment, redeploy Firestore rules, indexes, and Storage rules before using Inventory. Stock adjustments require a connection to Firestore.

## Phase 3 — Customers and orders

Open **Customers** to add or edit a profile. A normalized +94 phone number identifies each customer. The customer profile includes order history, cancellation and return counts, failed delivery history, and private watchlist and blacklist reasons.

Open **Orders → New order**:

1. Enter a phone number and select the matching customer or enter the new delivery details.
2. Review any flagged history. You can proceed, require an advance, or go back. A blacklisted customer also requires an explicit override for the new order.
3. Add products by searching or scanning a SKU, then enter delivery, discount, payment, and order source. Choose whether stock is deducted on confirmation or packing.
4. Check totals and save pending or confirm immediately.

Open a pending order to edit items and charges using current catalogue prices. Open any order to edit notes and payment, print an invoice or a basic courier label, or record a status change. Courier name and tracking ID are required when shipping. On cancellation or return, confirm that the items are sellable before returning them to inventory. A pending order does not reserve units. Confirming or packing rechecks availability in a Firestore transaction. A single order supports six distinct products so stock movements fit the atomic write rules.

For an existing Firebase deployment, redeploy the Firestore rules and indexes, including the customer-order history index. Browser print/share and camera availability depend on the device. Run the direct Firestore authorization and atomicity checks with:

~~~powershell
firebase emulators:exec --project demo-jewellery-manager --only auth,firestore,storage "node scripts/seed-local.mjs --verify && node scripts/verify-order-rules.mjs"
~~~

The Chrome repository integration test is separate from the regular Flutter test suite:

~~~powershell
firebase emulators:exec --project demo-jewellery-manager --only auth,firestore,storage "node scripts/seed-local.mjs --verify && flutter test --platform chrome --dart-define=LOCAL_FIREBASE=true test/order_emulator_test.dart"
~~~

## Phase 4 — Shipping and Quick Ship

Open **Quick Ship → Manage couriers** to add a courier. Optionally enter an HTTPS URL template such as https://courier.example/track?number={tracking}, replacing the example host with the courier's actual tracking site. Courier names are fixed after creation because waybill uniqueness uses the normalized courier name. Disable old couriers to remove them from new batches. Existing order tracking links still work when a courier is inactive.

- **Single parcel**. Open a packed order, select **Shipped**, then choose a saved courier or type its name. Scan the courier waybill to fill the tracking ID, or type it and confirm. The order details open the courier's tracking page when a template is available.
- **Quick Ship batch**. Select an active courier and start the camera or enter codes manually. Scan a Jewellery Business Manager order label and then its waybill. The screen identifies which order will receive the next unrecognized waybill. An unmatched waybill can also be scanned first and linked to a packed or failed-delivery order by search. Review the queue and ship a single parcel or all ready parcels. Each parcel saves independently and the summary shows errors that can be corrected and retried.
- **Order labels**. Print a courier label from Order Details. The QR encodes the internal order ID. Use **Scan order label** in Orders to reopen that order.

Camera scanning needs HTTPS or localhost and browser camera permission. Flashlight controls appear only on supported devices. A Quick Ship batch exists in the current page session. Orders remain saved after shipping even after clearing or leaving a batch.

Redeploy Firestore rules before using Shipping against an existing Firebase project. New shipments atomically reserve a normalized waybill per courier. Existing shipments retain their recorded tracking IDs.

~~~powershell
firebase emulators:exec --project demo-jewellery-manager --only auth,firestore,storage "node scripts/seed-local.mjs --verify && node scripts/verify-order-rules.mjs && node scripts/verify-shipping-rules.mjs"
~~~


## Phase 5 — Dashboard and reports

The owner workspace shows today's orders and delivered revenue, work waiting to ship, parcels in transit, low or empty stock, and this week's cancellations. **Needs attention** links to delayed orders and highlights active orders with recorded customer risk. **Attention thresholds** saves the shop's waiting and transit limits in Firestore. Choose 7, 30, or 90 days for the sales trend, order status, and top-product panels.

Open **Reports** for a custom date range or a 7, 30, or 90 day preset. Download CSV or PDF, or use **Share CSV**. Browsers without supported file sharing use a download fallback.

Reports use the Sri Lanka calendar. Revenue is the billed total of orders currently delivered, grouped by delivery date. Gross merchandise profit is subtotal minus the order discount and the recorded product cost, before courier and operating expenses. Status, cancellation, and return rates use orders placed in the selected period. Courier metrics use the latest dispatch date. Best product and category sales are before discounts. Older order lines without a category snapshot use the current inventory category when available.

Phase 5 uses existing Firebase collections and access rules. The dashboard adds the owner-only settings/dashboard_attention document when the owner saves thresholds.

## Phase 6 — Reminders and notifications

Open the bell on the owner dashboard. **Inbox**, **Snoozed**, and **Completed** show the latest entries in each folder. Open a notice for its related order or stock screen. Use **Reminder actions** to mark it read, snooze for an hour or a day, or mark it done.

The scheduled **shopReminders** function runs every 15 minutes. It checks the time spent in Pending, Confirmed, and Packed, follows up on parcels in transit, flags delivered COD orders with an unpaid balance, and uses each product's inventory threshold. Daily and weekly digests use the Sri Lanka calendar. Open **Notifications → Reminder rules** to change the thresholds, digest hour, or enabled reminder types. Dashboard attention thresholds control the dashboard panel separately.

### Local check

~~~powershell
.\run-local.ps1 -SeedReminders
~~~

Open the bell after signing in. This generates daily and weekly digest examples through the real scheduler logic in the local emulator. Background browser push requires a deployed Firebase project.

To verify the scheduler and Firestore permissions:

~~~powershell
Push-Location functions
npm ci
npm test
Pop-Location
firebase emulators:exec --project demo-jewellery-manager --only auth,firestore,storage "node scripts/seed-local.mjs && node functions/test/emulator.cjs"
~~~

### Deploy scheduled reminders and optional web push

1. Use a billing-enabled Firebase project with the owner UID configured in access/owner. Confirm Node.js 22 and an up-to-date Firebase CLI.
2. For browser push, generate or import a **Web Push certificate** under **Firebase console → Project settings → Cloud Messaging**. Set **FIREBASE_VAPID_KEY** in .firebase-config.json to the public Web Push key. Leave that key absent for in-app reminders only. [Firebase Flutter messaging setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)
3. Run from the project root:

   ~~~powershell
   Push-Location functions
   npm ci
   npm run build
   Pop-Location
   firebase deploy --project YOUR_PROJECT_ID --only firestore:rules,firestore:indexes,storage,functions:shopReminders
   .\build-web.ps1
   firebase deploy --project YOUR_PROJECT_ID --only hosting
   ~~~

4. Wait for new composite indexes to finish building. In the deployed HTTPS app, open **Notifications → Enable push here** and allow the browser prompt. Enable each browser separately. **Disable push here** removes that browser's server registration. Browser push can continue after signing out. Lock-screen messages contain only a reminder count. Clicking a push opens the protected notification center. [Scheduled Firebase Functions](https://firebase.google.com/docs/functions/schedule-functions) · [Firebase web message delivery](https://firebase.google.com/docs/cloud-messaging/web/receive-messages)

The build script writes the public Firebase Web identifiers into the worker configuration in build/web/. Use that build command for Hosting deployments with push. It does not read service account credentials.

## Phase 7 — Language, search, backups, and PWA

- Choose **Language** at sign-in or under **Settings**. Sinhala covers primary navigation, headings, common form labels and actions. Untranslated help and diagnostic text, PDFs, CSVs, and data entered by the shop use their original language.
- Use the dashboard search icon to find an order by number, tracking ID or contact details, or find a customer or product by name, phone or SKU. Search shows up to eight matches per record type.
- **Settings → Download data backup** exports the owner’s business collections and timestamps as JSON from the server. Store the export privately. It omits Firebase Auth records, push tokens, and image file bytes. Report CSVs are available under **Reports**.
- Order details show estimated gross merchandise profit and offer WhatsApp drafts for confirmation, shipment, and delivery follow-up. The owner sends each message from WhatsApp.

### Try sample records locally

~~~powershell
.\run-local.ps1 -DemoData -SeedReminders
~~~

The switches generate a sample product, customer, orders, and reminders in the emulator. Test the search, reports, cancellation warning, stock history, and bell. Use the normal launcher for an empty workspace.

### Install and verify on the deployed site

1. Build and deploy the full web bundle with the **build-web.ps1** and **firebase deploy** commands in Phase 6. The build script compiles local CanvasKit assets and generates the versioned app-shell manifest. Deploy from the site root on HTTPS. [Flutter web initialization](https://docs.flutter.dev/platform-integration/web/initialization)
2. Sign in online and visit the record screens you plan to use. With Chrome or Edge, select **Settings → Install app** or use the browser’s install action. On iPhone, use **Safari → Share → Add to Home Screen**.
3. Reopen the installed app. Disable your connection and confirm the offline banner appears and previously loaded records are available where Firestore has cached them. Try a stock or order transaction again after reconnecting. New sign-in, uncached records, uploads, and Firebase transactions need a connection.
4. For push, enable the browser registration in **Notifications** on the deployed HTTPS site. Lock-screen messages contain only a summary count. On a phone, test a reminder with the app closed and tap it to confirm the protected inbox opens.

The shell worker serves app files from its release cache. Firebase request data stays in Firebase’s SDK cache rather than the shell cache. After a deployment, fully close all tabs or installed windows for the old release and reopen to switch workers. [How service-worker updates activate](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API/Using_Service_Workers)

~~~powershell
flutter analyze
flutter test
node --test scripts/pwa.test.mjs
# After building the PWA bundle, with Chrome installed
node scripts/pwa-browser-smoke.mjs
~~~

## Inventory archive and activity

Open a product and choose **Archive product**. The confirmation explains the effect on pending orders. Use **Undo** from the success message or **Settings → Product recycle bin → Restore**. The product keeps its SKU, quantity, photos, and history while archived. Archived products are excluded from stock available for new orders.

**Settings → Activity** combines order status history, the latest 100 stock movements, and the latest 100 archive and restore events. Filter by event type and use **Show more** to expand the visible results.

Deploy the updated Firestore rules before using archive and restore on a live project.

~~~powershell
firebase emulators:exec --project demo-jewellery-manager --only auth,firestore "node scripts/seed-local.mjs && node scripts/verify-archive-rules.mjs"
~~~

## Large lists

Inventory, Orders, and Customers show pages of 25 records. Paged browsing falls back to records Firestore has cached on the device. Cached results can be incomplete. Select **Check for updates** on a cached list after reconnecting to return to server results. Use **Load more** at the end of a list or pull down to reload from the first page and pick up changes made on other devices. Inventory browse uses Firestore's alphabetical ordering, which distinguishes uppercase and lowercase. Search and filters still check the entire collection. Open **Valuation and filters** in Inventory for totals and stock counts across all active products.

Deploy the updated Firestore indexes and wait for the products index to finish building before using Inventory against a hosted Firebase project.

## Project structure

Source files and deployment inputs for the seven phases.

~~~text
.gitignore
analysis_options.yaml
build-web.ps1
firebase.json
firestore.indexes.json
firestore.rules
functions/package.json
functions/package-lock.json
functions/src/demo.ts
functions/src/index.ts
functions/src/local.ts
functions/src/reminder_plan.ts
functions/src/reminders.ts
functions/test/emulator.cjs
functions/test/reminders.test.cjs
functions/tsconfig.json
lib/core/constants/app_copy.dart
lib/core/localization/copy.dart
lib/core/localization/language_button.dart
lib/core/localization/language_provider.dart
lib/core/localization/language_provider.g.dart
lib/core/router/app_router.dart
lib/core/services/browser_capabilities.dart
lib/core/services/browser_capabilities_stub.dart
lib/core/services/browser_capabilities_web.dart
lib/core/services/firebase_config.dart
lib/core/services/report_download.dart
lib/core/services/report_download_stub.dart
lib/core/services/report_download_web.dart
lib/core/theme/app_theme.dart
lib/core/theme/theme_provider.dart
lib/core/theme/theme_provider.g.dart
lib/core/widgets/barcode_camera.dart
lib/core/widgets/connectivity_banner.dart
lib/core/widgets/global_search.dart
lib/core/widgets/premium_card.dart
lib/core/widgets/scan_code_page.dart
lib/features/auth/data/repositories/firebase_auth_repository.dart
lib/features/auth/domain/entities/owner.dart
lib/features/auth/domain/repositories/auth_repository.dart
lib/features/auth/presentation/pages/login_page.dart
lib/features/auth/presentation/pages/splash_page.dart
lib/features/auth/presentation/providers/auth_providers.dart
lib/features/auth/presentation/providers/auth_providers.g.dart
lib/features/auth/presentation/widgets/owner_idle_guard.dart
lib/features/customers/data/firestore_customer_repository.dart
lib/features/customers/domain/customer.dart
lib/features/customers/domain/customer_repository.dart
lib/features/customers/presentation/customer_form.dart
lib/features/customers/presentation/customer_providers.dart
lib/features/customers/presentation/customer_providers.g.dart
lib/features/customers/presentation/customers_page.dart
lib/features/dashboard/data/dashboard_settings.dart
lib/features/dashboard/domain/dashboard_data.dart
lib/features/dashboard/presentation/dashboard_providers.dart
lib/features/dashboard/presentation/dashboard_providers.g.dart
lib/features/dashboard/presentation/pages/dashboard_page.dart
lib/features/dashboard/presentation/widgets/attention_panel.dart
lib/features/inventory/data/firestore_inventory_repository.dart
lib/features/inventory/domain/inventory_product.dart
lib/features/inventory/domain/inventory_repository.dart
lib/features/inventory/presentation/inventory_format.dart
lib/features/inventory/presentation/inventory_page.dart
lib/features/inventory/presentation/inventory_providers.dart
lib/features/inventory/presentation/inventory_providers.g.dart
lib/features/inventory/presentation/product_details_sheet.dart
lib/features/inventory/presentation/product_editor.dart
lib/features/inventory/presentation/product_scanner.dart
lib/features/inventory/presentation/stock_adjustment.dart
lib/features/notifications/data/browser_push.dart
lib/features/notifications/data/firestore_notification_repository.dart
lib/features/notifications/domain/notice.dart
lib/features/notifications/domain/notification_repository.dart
lib/features/notifications/presentation/browser_push_panel.dart
lib/features/notifications/presentation/notification_bell.dart
lib/features/notifications/presentation/notification_providers.dart
lib/features/notifications/presentation/notification_providers.g.dart
lib/features/notifications/presentation/notifications_page.dart
lib/features/notifications/presentation/reminder_settings_sheet.dart
lib/features/orders/data/firestore_order_repository.dart
lib/features/orders/domain/order_repository.dart
lib/features/orders/domain/shop_order.dart
lib/features/orders/presentation/order_customer_review.dart
lib/features/orders/presentation/order_details_page.dart
lib/features/orders/presentation/order_editor_page.dart
lib/features/orders/presentation/order_format.dart
lib/features/orders/presentation/order_printing.dart
lib/features/orders/presentation/order_providers.dart
lib/features/orders/presentation/order_providers.g.dart
lib/features/orders/presentation/orders_page.dart
lib/features/reports/domain/business_report.dart
lib/features/reports/presentation/report_charts.dart
lib/features/reports/presentation/report_export.dart
lib/features/reports/presentation/report_tables.dart
lib/features/reports/presentation/reports_page.dart
lib/features/settings/data/shop_backup.dart
lib/features/settings/presentation/settings_page.dart
lib/features/shipping/data/firestore_courier_repository.dart
lib/features/shipping/domain/courier.dart
lib/features/shipping/domain/courier_repository.dart
lib/features/shipping/domain/parcel_lookup.dart
lib/features/shipping/presentation/couriers_page.dart
lib/features/shipping/presentation/parcel_link_sheet.dart
lib/features/shipping/presentation/quick_ship_page.dart
lib/features/shipping/presentation/shipping_providers.dart
lib/features/shipping/presentation/shipping_providers.g.dart
lib/main.dart
pubspec.lock
pubspec.yaml
README.md
run-local.ps1
scripts/build-pwa.mjs
scripts/pwa-browser-smoke.mjs
scripts/pwa.test.mjs
scripts/seed-local.mjs
scripts/verify-order-rules.mjs
scripts/verify-shipping-rules.mjs
storage.rules
test/auth_routing_test.dart
test/business_report_test.dart
test/inventory_domain_test.dart
test/login_page_test.dart
test/notifications_page_test.dart
test/order_emulator_test.dart
test/orders_domain_test.dart
test/phase7_polish_test.dart
test/quick_ship_page_test.dart
test/reports_page_test.dart
test/shipping_domain_test.dart
web/firebase-messaging-sw.js
web/icons/icon-192.png
web/icons/icon-512.png
web/index.html
web/manifest.json
web/shop-pwa.js
web/shop-sw.js
~~~
