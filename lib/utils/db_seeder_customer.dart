import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CustomerDatabaseSeeder {
  static Future<void> seedData() async {
    final FirebaseFirestore db = FirebaseFirestore.instance;
    final String customerId = "tEG3xhaGa2QgMQELVfsHlGXGbBA2";
    final String targetId = "9y8tqwjSGFcBdjj7LAy87bb2foH3";

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
        'userId': customerId,
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

      // --- 2. Create Mock Retailers & Tailors (if they don't exist) ---
      final retailers = [
        {'id': targetId, 'name': 'Target Retailer/Tailor'},
        {'id': 'mock_ret_1', 'name': 'Silk & Satin'},
        {'id': 'mock_ret_2', 'name': 'Cotton King'},
      ];

      for (var r in retailers) {
        batch.set(db.collection('Retailer').doc(r['id']), {
          'shopName': r['name'],
          'location': const GeoPoint(23.7, 90.4),
          'rating': 4.8,
        }, SetOptions(merge: true));

        batch.set(db.collection('Tailor').doc(r['id']), {
          'name': r['name']!.replaceAll('Retailer', 'Tailor'),
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
          'careSymbol': ['wash', 'dryClean'],
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
        double productPrice = 1500.0 + ((i % productImages.length) * 200); // Fixed price logic to match product option

        // Create Order
        batch.set(db.collection('Orders').doc(orderId), {
          'customerId': customerId,
          'status': orderStatusValue,
          'statusText': orderStatusText,
          'orderDate': Timestamp.fromDate(orderDate),
          'deliveryAddress': 'Plot 4, Mirpur 12, Dhaka',
        });

        // Create Sub-order
        batch.set(db.collection('Sub-orders').doc(subOrderId), {
          'orderId': orderId,
          'retailerId': retailerId,
          'status': subOrderStatus,
          'deliveryDestination': hasTailor ? 'tailor' : 'customer',
          'itemsSubtotal': productPrice, // Perfectly match item price
          'deliveryCharge': 60.0,
          'deliveryPoint': const GeoPoint(23.7, 90.3),
          'deliveryDate': orderStatusValue == 'completed' ? Timestamp.now() : null,
        });

        // Create Order Item
        String orderItemId = "ITEM-$orderId";
        batch.set(db.collection('Order-Items').doc(orderItemId), {
          'subOrderId': subOrderId,
          'productId': productIds[i % productImages.length],
          'quantity': 1,
          'optionId': 1,
        });

        // Create Tailor Job (if applicable)
        if (hasTailor) {
          batch.set(db.collection('Tailor-jobs').doc(tailorJobId), {
            'orderId': orderId,
            'tailorId': tailorId,
            'status': tailorStatusValue,
            'measurementId': measurementId,
            'designIds': [designImages[i % designImages.length]],
            'specialInstructions': 'Please make it slightly loose on the waist.',
            'quoteAmount': (tailorStatusValue != 'pending' && tailorStatusValue != 'tailor_declined') ? 2500.0 : null,
            'estimatedDeliveryDate': (tailorStatusValue != 'pending' && tailorStatusValue != 'tailor_declined') ? Timestamp.fromDate(orderDate.add(const Duration(days: 7))) : null,
            'deliveryCharge': 50.0,
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
