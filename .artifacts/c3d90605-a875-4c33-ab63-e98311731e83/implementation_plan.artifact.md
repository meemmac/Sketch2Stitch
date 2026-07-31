# Implementation Plan - Browse & Search Service

Implement a comprehensive `BrowseService` to handle complex filtering and searching for products, tailors, retailers, and orders.

## Proposed Changes

### [NEW] [browse_service.dart](file:///D:/SDP2/Sketch2Stitch/lib/services/browse_service.dart)

Create a new service class `BrowseService` with the following methods:

- `getProductsByFilter({String? category, String? materialType, double? minPrice, double? maxPrice, List<String>? colors, String? sortBy, String? search})`:
  - Returns a `Stream<List<Product>>`.
  - Filters products by category, material, price range, and colors.
  - Supports sorting by price (low to high, high to low).

- `searchProductsByQuery(String query)`:
  - Returns a `Future<List<Product>>`.
  - Performs a prefix search on the `productName`.

- `getTailorsByFilter({double? minRating, String? location, String? sortBy, String? search})`:
  - Returns a `Stream<List<Tailor>>`.
  - Filters tailors by minimum rating and general location.

- `getRetailersByFilter({double? minRating, String? location, String? sortBy, String? search})`:
  - Returns a `Stream<List<Retailer>>`.
  - Filters retailers by rating and location.

- `searchOrders(String customerId, String query)`:
  - Returns a `Stream<List<Order>>`.
  - Searches through the customer's orders based on ID or status.

## Implementation Details

### Firestore Limitations
Since Firestore has limited support for full-text search and multiple inequality filters, the implementation will:
1. Use compound queries for basic filters (e.g., `category`, `minRating`).
2. Implement client-side filtering for complex multi-field searches to ensure responsiveness.
3. For text search, use prefix matching (startAt/endAt) on searchable fields.

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure code quality.

### Manual Verification
- Test each filter in the `BrowseFabricsScreen`, `BrowseTailorsScreen`, and `BrowseRetailersScreen` once wired up.
- Verify that search results update as the user types or applies filters.
