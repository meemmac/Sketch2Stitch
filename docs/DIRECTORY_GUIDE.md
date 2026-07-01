# Directory Guide — What Goes Where

Use this as a map before writing code. Each entry says what the file/folder is responsible for, so nobody duplicates logic or puts it in the wrong layer.

---

## `lib/models/`
**Purpose:** Plain Dart classes that mirror your Firestore documents. No UI, no Firebase calls — just data shape + `fromJson()` / `toJson()` (or `fromFirestore()`).

Example — `order.dart` should contain:
```dart
class Order {
  final String id;
  final String customerId;
  final String status;
  final double totalPrice;
  // ...
  factory Order.fromMap(String id, Map<String, dynamic> data) { ... }
  Map<String, dynamic> toMap() { ... }
}
```
Every model file (`customer.dart`, `tailor_job.dart`, etc.) follows this same pattern — one class matching one Firestore collection/document from `docs/ERD.png`.

---

## `lib/screens/`
**Purpose:** Full-page UI, organized by role (`shared/`, `customer/`, `retailer/`, `tailor/`). Each file is one screen = one page the user sees.

- Screens should **not** call Firebase directly. They call functions from `lib/services/` and display the result.
- Keep UI layout, form fields, and navigation logic here — no business logic (e.g. don't calculate order totals inside a screen file, do it in a service).

Example — `lib/screens/customer/orders/order_detail_screen.dart`:
- Displays order data passed in
- Has buttons like "Select Tailor", "Approve Quote"
- On button tap → calls `OrderService.assignTailor(...)` from services, doesn't write to Firestore itself

**Subfolders:**
- `customer/cart/` — the 4-step cart flow (items → design inputs → tailor → payment), one file per step
- `customer/orders/` — order list + order detail
- `*/messaging/` — conversations list + chat screen, same pattern for all three roles

---

## `lib/widgets/`
**Purpose:** Small, reusable UI pieces used across multiple screens.

- `persistent_nav_bar.dart` — the sidebar/bottom nav shown on every logged-in page
- `countdown_banner.dart` — the "Pay within X hours" style banner, reusable wherever a timer needs displaying
- `sketch_canvas_painter.dart` — the actual `CustomPainter` class for the drawing board (pencil/eraser/undo logic lives here)
- `sketch_toolbar.dart` — buttons for pencil, eraser, width slider, undo/redo, sits above the canvas
- `common/` — generic widgets like buttons, input fields, loading spinners, dialogs used everywhere

---

## `lib/services/`
**Purpose:** All Firebase communication happens here. This is the only layer allowed to call Firestore, Storage, Auth, or Cloud Functions.

- `auth_service.dart` — signup, login, logout, password reset (wraps Firebase Auth)
- `firestore_service.dart` — generic read/write helpers, or split further per-collection if it grows too large (e.g. `order_service.dart`, `product_service.dart` — feel free to split this file by domain as the app grows)
- `storage_service.dart` — image/file uploads (product images, sketch board output, licenses, portfolio images) to Firebase Storage
- `functions_service.dart` — calls to Cloud Functions (e.g. `generateVirtualTrial()`, `mockCheckout()`)
- `notification_service.dart` — FCM token registration, listening for push notifications

**Rule of thumb:** if a screen needs data, it calls a service method, never `FirebaseFirestore.instance...` directly.

---

## `lib/providers/`
**Purpose:** App state management (whichever you choose — Provider, Riverpod, or Bloc). Holds current user session, cart state, and any data shared across multiple screens.

Suggested files to add as you build:
- `auth_provider.dart` — current logged-in user + role
- `cart_provider.dart` — items currently in cart across the 4-step flow
- `order_provider.dart` — currently viewed order state, if needed for live updates

---

## `lib/utils/`
**Purpose:** Constants and pure helper functions — nothing Firebase-related, nothing UI-related.

- `constants.dart` — status enums (`AWAITING_PAYMENT`, `HOLDING`, etc.), timer durations (24h, 72h, 48h), color options, route names
- `validators.dart` — form validation functions (email format, phone format, password rules)

---

## `functions/src/`
**Purpose:** Server-side Cloud Functions — the only place with "trusted" logic (timers, status transitions, Gemini API calls, mock payment logic).

- `orders/createOrder.ts` — validates and creates an order + sub-orders
- `orders/autoCancelUnpaid.ts` — **scheduled function**, runs every X minutes, cancels orders unpaid after 24h
- `orders/autoShipToHome.ts` — **scheduled function**, ships to home if no tailor picked within 72h
- `orders/assignTailor.ts` — callable function, customer assigns/replaces tailor
- `subOrders/acceptReject.ts` — retailer accept/reject a sub-order
- `subOrders/autoRejectExpired.ts` — **scheduled**, auto-rejects sub-orders with no retailer response in 24h
- `tailorJobs/acceptRejectQuote.ts` — tailor accept/reject job, submit quote
- `tailorJobs/autoRejectExpired.ts` — **scheduled**, auto-rejects tailor jobs with no response in 24h
- `payments/mockCheckout.ts` — simulates payment, marks order Paid
- `payments/autoRelease.ts` — **scheduled**, releases mock payment 48h after delivery if not confirmed
- `virtualTrial/generatePreview.ts` — calls Gemini API server-side (keeps API key out of the Flutter app)
- `notifications/sendNotification.ts` — sends FCM push notifications on status changes

**Rule:** anything involving a deadline/timer or an external API key (Gemini) must live here, not in Flutter.

---

## `docs/`
- `ERD.png` — entity relationship diagram (add this when ready)
- `ORDER_LIFECYCLE.md` — the full status flow (already discussed in planning) — paste the finalized order/tailor-job state machine here so everyone references the same source of truth
- `DIRECTORY_GUIDE.md` — this file

---

## Quick Decision Rule

Ask yourself before writing any code:
1. **Is this what the user sees/taps?** → `lib/screens/` or `lib/widgets/`
2. **Is this reading/writing data?** → `lib/services/`
3. **Is this shared state across screens?** → `lib/providers/`
4. **Is this a constant or a pure function with no Firebase?** → `lib/utils/`
5. **Does this need to run automatically on a timer, or use a secret API key?** → `functions/src/`
6. **Is this just describing data shape?** → `lib/models/`
