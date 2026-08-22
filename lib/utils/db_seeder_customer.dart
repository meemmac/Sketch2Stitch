import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CustomerDatabaseSeeder {
  /// Seeds a demo order history.
  ///
  /// [customerUid] is the account the orders belong to, and [targetUid] the
  /// account that plays both the shop and the tailor on those orders — the
  /// tailor's own Orders screen only ever shows jobs whose `tailorId` is the
  /// signed-in uid, so seeding against a hardcoded id left whoever was
  /// actually logged in staring at an empty list. Pass the uids you intend
  /// to sign in as; the old hardcoded pair remain the defaults.
  static Future<void> seedData({
    String? customerUid,
    String? targetUid,
  }) async {
    final FirebaseFirestore db = FirebaseFirestore.instance;
    final String customerId = customerUid ?? "tEG3xhaGa2QgMQELVfsHlGXGbBA2";
    final String targetId = targetUid ?? "9y8tqwjSGFcBdjj7LAy87bb2foH3";

    debugPrint("Starting Customer Database Seeding for $customerId...");

    try {
      final batch = db.batch();

      // --- 0. Clear existing orders for this customer ---
      final existingOrders = await db.collection('Orders').where('customerId', isEqualTo: customerId).get();
      for (var doc in existingOrders.docs) {
        batch.delete(doc.reference);
      }
      debugPrint("Clearing ${existingOrders.docs.length} existing orders...");

      // --- 1. Seed Measurement for Customer ---
      String measurementId = "MEAS-CUST-$customerId";
      batch.set(db.collection('Measurement').doc(measurementId), {
        // `customerId`, not `userId` — MeasurementService queries this
        // collection with `where('customerId', ...)`, so a record keyed the
        // other way is invisible to the customer's own measurement screen
        // even though the tailor (who loads it by document id) can see it.
        'customerId': customerId,
        'upperBustCircumference': 34.5,
        'bustCircumference': 36.0,
        'underBustCircumference': 32.0,
        'roundShoulderCircumference': 40.0,
        'waist': 28.0,
        'hipsCircumference': 38.0,
        'shoulderToBust': 10.0,
        'shoulderToUnderBust': 13.0,
        'shoulderToKnee': 38.0,
        'shoulderToAnkle': 54.0,
        'waistToAnkle': 40.0,
        'thigh': 22.0,
        'knee': 15.0,
        'ankle': 10.0,
        'updatedAt': Timestamp.now(),
      });

      // --- 1b. Seed the Customer profile itself ---
      // Every screen that shows a delivery address reads it off the
      // `Customer` document (the tailor's job sheet, the retailer's packing
      // slip, the customer's own order summary). Seeding orders without
      // seeding this left all three showing "N/A".
      batch.set(db.collection('Customer').doc(customerId), {
        'name': 'Maria Doe',
        'email': 'maria.doe@example.com',
        'phone': '+8801712345678',
        'address': 'Plot 4, Road 7, Mirpur 12, Dhaka 1216',
        'location': const GeoPoint(23.8223, 90.3654),
      }, SetOptions(merge: true));

      // --- 2. Create Mock Retailers & Tailors (if they don't exist) ---
      // Each entry seeds one shop and one tailoring house. They are separate
      // businesses that happen to share an account id here, so they get
      // separate names — "Target Retailer/Tailor" was a placeholder that
      // ended up on screen as if it were a real shop.
      final retailers = [
        {
          'id': targetId,
          'shopName': 'Meem Fabrics',
          'tailorName': 'Meem Tailoring House',
          'address': 'Shop 12, Level 3, Bashundhara City, Panthapath, Dhaka',
        },
        {
          'id': 'mock_ret_1',
          'shopName': 'Silk & Satin',
          'tailorName': 'Silk & Satin Stitching',
          'address': 'House 21, Road 5, Dhanmondi, Dhaka',
        },
        {
          'id': 'mock_ret_2',
          'shopName': 'Cotton King',
          'tailorName': 'Cotton King Tailors',
          'address': 'Plot 9, Sector 4, Uttara, Dhaka',
        },
      ];

      for (var r in retailers) {
        batch.set(db.collection('Retailer').doc(r['id']), {
          'shopName': r['shopName'],
          'email': '${r['id']}@example.com',
          'phone': '+8801811223344',
          // The retailer's own screen ships to this address when a sub-order
          // is routed to a tailor, so it cannot be left unset.
          'address': r['address'],
          'location': const GeoPoint(23.7, 90.4),
          'rating': 4.8,
        }, SetOptions(merge: true));

        batch.set(db.collection('Tailor').doc(r['id']), {
          'name': r['tailorName'],
          'email': '${r['id']}.tailor@example.com',
          'phone': '+8801911223344',
          'address': r['address'],
          'location': const GeoPoint(23.7, 90.4),
          'rating': 4.5,
        }, SetOptions(merge: true));
      }

      // --- 3. Create Products ---
      final productImages = [
        'https://res.cloudinary.com/eh11vsnw/image/upload/v1787063116/Elegant_Off-White_Floral_Printed_Cotton_Kurti_Set___Chic_Everyday_Ethnic_Wear_hbmkro.jpg',
        'https://res.cloudinary.com/eh11vsnw/image/upload/v1787063035/Elegant_white_kurti_with_matching_white_pajama_set_designed_for_comfort_and_style__Ma_n6ynbp.jpg',
        'https://res.cloudinary.com/eh11vsnw/image/upload/v1786979915/pexels-izafi-18730848_d3ikuq.jpg',
        'https://res.cloudinary.com/eh11vsnw/image/upload/v1786977023/pexels-gabby-k-7794264_aaihmm.jpg',
        'https://res.cloudinary.com/eh11vsnw/image/upload/v1786703403/Cherry_Blossom_Jeans_wcfvtz.jpg',
        'https://res.cloudinary.com/eh11vsnw/image/upload/v1786703403/Tie_dye_fqwmm1.jpg',
        'https://res.cloudinary.com/eh11vsnw/image/upload/v1786703404/download_5_rjkuyf.jpg',
        'https://res.cloudinary.com/eh11vsnw/image/upload/v1786700003/lace2_r01cdm.jpg',
      ];

      List<String> productIds = [];
      for (int i = 0; i < productImages.length; i++) {
        String pId = 'prod_cust_seed_$i';
        productIds.add(pId);
        batch.set(db.collection('Products').doc(pId), {
          'retailerId': i < 3 ? targetId : 'mock_ret_${(i % 2) + 1}',
          'productName': 'Premium Fabric $i',
          'description': 'Beautiful fabric material.',
          // The exact labels the retailer's inventory form writes, so all
          // five care tags render on every screen that shows them.
          'careSymbol': const [
            'Washable',
            'Bleach Allowed',
            'Dry Clean Only',
            'Tumble Dry',
            'Iron: Medium',
          ],
          'colorOptions': [
            {
              'optionId': 1,
              'color': 'Standard Color',
              'price': 1500.0 + (i * 200),
              'stock': 100,
              'image': [productImages[i]],
            }
          ]
        }, SetOptions(merge: true));
      }

      final designImages = [
        'https://res.cloudinary.com/eh11vsnw/image/upload/v1787063288/23_Small_Craft_Room_Ideas_Aesthetic_sssnox.jpg',
        'https://res.cloudinary.com/eh11vsnw/image/upload/v1787062731/Not_just_a_dress_but_a_story_stitched_with_love____I_still_remember_when_this_tiny_outfit_was_just_a_sketch_on_paper_and_a_few_strands_of_thread_on_fabric._Every_flower_every_vine_was_han_yzbqvc.jpg',
        'https://res.cloudinary.com/eh11vsnw/image/upload/v1787062128/download_jhouce.jpg',
        'https://res.cloudinary.com/eh11vsnw/image/upload/v1787062558/download_3_ucwyrf.jpg',
      ];

      // `Tailor-jobs.designIds` holds Design document ids, not image URLs —
      // both the tailor's job sheet and the customer's order detail resolve
      // them through the `Design` collection. Seeding raw URLs there meant
      // every lookup missed and no reference image ever rendered.
      final List<String> designIds = [];
      for (int i = 0; i < designImages.length; i++) {
        final dId = 'design_cust_seed_$i';
        designIds.add(dId);
        batch.set(db.collection('Design').doc(dId), {
          'customerId': customerId,
          'designFile': designImages[i],
          'description': 'Reference sketch ${i + 1}',
        }, SetOptions(merge: true));
      }

      // --- 4. Define Test Cases (Total 22) ---
      for (int i = 0; i < 22; i++) {
        String orderId = "ORD-CUST-SEED-${i.toString().padLeft(2, '0')}";
        String subOrderId = "SUB-$orderId";
        String tailorJobId = "TJ-$orderId";
        
        bool isTarget = i < 3;
        String retailerId = isTarget ? targetId : 'mock_ret_${(i % 2) + 1}';
        String tailorId = isTarget ? targetId : 'mock_ret_${(i % 2) + 1}';
        
        String tailorStatusValue = 'pending';
        String orderStatusText = 'Order Preparing';
        String orderStatusValue = 'processing';
        bool hasTailor = true;
        bool hasRetailerReview = false;
        bool hasTailorReview = false;

        String subOrderStatus = 'preparing';

        if (i == 0) { // Target 1: Quoted (Need Confirmation)
          tailorStatusValue = 'quoted';
          orderStatusText = 'Quote Received from Tailor';
        } else if (i == 1) { // Target 2: Confirmed, in progress
          tailorStatusValue = 'in_progress';
          orderStatusText = 'Tailor Confirmed — Stitching Started';
        } else if (i == 2) { // Target 3: Delivered with Reviews
          tailorStatusValue = 'completed';
          orderStatusText = 'Delivered';
          orderStatusValue = 'completed';
          subOrderStatus = 'delivered';
          hasRetailerReview = true;
          hasTailorReview = true;
        } else {
          int stateMod = i % 8;
          switch (stateMod) {
            case 0: // No Tailor, Retailer only, processing -> Order Packed
              hasTailor = false;
              orderStatusText = 'Order Packed';
              subOrderStatus = 'packed';
              break;
            case 1: // No Tailor, Delivered
              hasTailor = false;
              orderStatusValue = 'completed';
              orderStatusText = 'Delivered';
              subOrderStatus = 'delivered';
              hasRetailerReview = (i % 2 == 0);
              break;
            case 2: // Tailor Pending
              tailorStatusValue = 'pending';
              orderStatusText = 'Requested Tailor';
              break;
            case 3: // Tailor Quoted
              tailorStatusValue = 'quoted';
              orderStatusText = 'Quote Received from Tailor';
              break;
            case 4: // Tailor Confirmed
              tailorStatusValue = 'confirmed';
              orderStatusText = 'Tailor Confirmed — Stitching Started';
              break;
            case 5: // Tailor Declined
              tailorStatusValue = 'tailor_declined';
              orderStatusText = 'Cancelled';
              break;
            case 6: // Tailor Completed, Order Delivery
              tailorStatusValue = 'completed';
              orderStatusText = 'Stitching Completed';
              break;
            case 7: // Fully Delivered
              tailorStatusValue = 'completed';
              orderStatusValue = 'completed';
              orderStatusText = 'Delivered';
              subOrderStatus = 'delivered';
              hasRetailerReview = true;
              hasTailorReview = true;
              break;
          }
        }

        DateTime orderDate = DateTime.now().subtract(Duration(days: i + 1));

        // A tailor can only be stitching if the fabric actually reached them,
        // and the tailor's screen gates "Start Stitching" on exactly that. A
        // job seeded as in-progress on top of a still-preparing sub-order was
        // a state the app itself will never produce.
        if (hasTailor &&
            (tailorStatusValue == 'in_progress' ||
                tailorStatusValue == 'completed')) {
          subOrderStatus = 'delivered';
        }

        // Create Order
        batch.set(db.collection('Orders').doc(orderId), {
          'customerId': customerId,
          'status': orderStatusValue,
          'statusText': orderStatusText,
          'orderDate': Timestamp.fromDate(orderDate),
          'deliveryAddress': 'Plot 4, Mirpur 12, Dhaka',
        });

        // Every sub-order used to carry exactly one line, so nothing in the
        // app ever exercised a multi-item sub-order. Alternate between one
        // and three lines (with quantities above 1) so the item lists, the
        // "N units" counts and the subtotal arithmetic are all visible.
        final int lineCount = (i % 3 == 0) ? 3 : 1;
        final List<Map<String, dynamic>> lines = [];
        for (int line = 0; line < lineCount; line++) {
          final productIndex = (i + line) % productImages.length;
          lines.add({
            'productId': productIds[productIndex],
            'quantity': line + 1,
            'optionId': 1,
            // Mirrors the option price the product was seeded with, so the
            // subtotal below is the one the screens re-derive from Products.
            'price': 1500.0 + (productIndex * 200),
          });
        }

        // itemsSubtotal has to be price × quantity summed over every line —
        // it was the unit price of a single item, so any order with more
        // than one garment under-reported its own total.
        final double itemsSubtotal = lines.fold(
          0.0,
          (runningTotal, l) => runningTotal + (l['price'] as double) * (l['quantity'] as int),
        );

        // Create Sub-order
        batch.set(db.collection('Sub-orders').doc(subOrderId), {
          'orderId': orderId,
          'retailerId': retailerId,
          'status': subOrderStatus,
          'deliveryDestination': hasTailor ? 'tailor' : 'customer',
          'itemsSubtotal': itemsSubtotal,
          'deliveryCharge': 60.0,
          'deliveryDistanceKm': 5.0,
          'deliveryPoint': const GeoPoint(23.7, 90.3),
          'deliveryDate': orderStatusValue == 'completed' ? Timestamp.now() : null,
        });

        // Create Order Items
        for (int line = 0; line < lines.length; line++) {
          batch.set(db.collection('Order-Items').doc("ITEM-$orderId-$line"), {
            'subOrderId': subOrderId,
            'productId': lines[line]['productId'],
            'quantity': lines[line]['quantity'],
            'optionId': lines[line]['optionId'],
          });
        }

        // Create Tailor Job (if applicable)
        if (hasTailor) {
          final bool quoteSent = tailorStatusValue != 'pending' &&
              tailorStatusValue != 'tailor_declined';
          batch.set(db.collection('Tailor-jobs').doc(tailorJobId), {
            'orderId': orderId,
            'tailorId': tailorId,
            'customerId': customerId,
            'status': tailorStatusValue,
            'measurementId': measurementId,
            'designIds': [designIds[i % designIds.length]],
            'specialInstructions': 'Please make it slightly loose on the waist.',
            'quoteAmount': quoteSent ? 2500.0 : null,
            'estimatedDeliveryDate': quoteSent
                ? Timestamp.fromDate(orderDate.add(const Duration(days: 7)))
                : null,
            'deliveryCharge': 50.0,
            'deliveryDistanceKm': 5.0,
            // Both the customer's order list and the tailor's job list sort
            // jobs newest-first on these and read the 12h response window off
            // `quoteResponseDeadline`. Without them a re-hired order picked an
            // arbitrary job as "current", and the countdown never appeared.
            'requestedAt': Timestamp.fromDate(orderDate),
            'createdAt': Timestamp.fromDate(orderDate),
            'quoteResponseDeadline':
                Timestamp.fromDate(orderDate.add(const Duration(hours: 12))),
            'quoteStatus': quoteSent ? 'sent' : 'not_sent',
            'tailorPaymentStatus': tailorStatusValue == 'pending' ||
                    tailorStatusValue == 'quoted' ||
                    tailorStatusValue == 'tailor_declined'
                ? 'unpaid'
                : 'paid',
            'confirmedAt': (tailorStatusValue == 'confirmed' ||
                    tailorStatusValue == 'in_progress' ||
                    tailorStatusValue == 'completed')
                ? Timestamp.fromDate(orderDate.add(const Duration(days: 1)))
                : null,
            'completedAt': tailorStatusValue == 'completed'
                ? Timestamp.fromDate(orderDate.add(const Duration(days: 6)))
                : null,
            'rejectionReason': tailorStatusValue == 'tailor_declined' ? 'Fully booked this week' : null,
          });
        }

        // Create Reviews (if applicable)
        if (hasRetailerReview) {
          batch.set(db.collection('Reviews').doc("REV-RET-$orderId"), {
            'orderId': orderId,
            'customerId': customerId,
            'targetId': retailerId,
            'targetRole': 'retailer',
            'rating': 4.0 + (i % 2),
            'comment': 'Great fabric quality!',
            'createdAt': Timestamp.now(),
          });
        }

        if (hasTailorReview && hasTailor) {
          batch.set(db.collection('Reviews').doc("REV-TAI-$orderId"), {
            'orderId': orderId,
            'customerId': customerId,
            'targetId': tailorId,
            'targetRole': 'tailor',
            'rating': 5.0,
            'comment': 'Perfect fit and stitching.',
            'createdAt': Timestamp.now(),
          });
        }
      }

      await batch.commit();
      debugPrint("Customer Database Seeding Completed Successfully! Seeded 20 orders.");
    } catch (e) {
      debugPrint("Error during customer seeding: $e");
    }
  }
}
