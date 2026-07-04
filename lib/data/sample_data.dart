import '../models/customer.dart';
import '../models/measurement.dart';
import '../models/tailor.dart';
import '../models/retailer.dart';
import '../models/product.dart';
import '../models/design.dart';
import '../models/order.dart';
import '../models/sub_order.dart';
import '../models/order_item.dart';
import '../models/tailor_job.dart';
import '../models/payment.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/review.dart';
import '../models/notification.dart';
import '../models/portfolio.dart';
import '../models/favorite.dart';

final sampleCustomer = Customer(
  id: 'c1',
  name: 'Sarah Ahmed',
  email: 'sarah@email.com',
  phone: '+8801712345678',
  address: 'House 12, Road 5, Gulshan, Dhaka',
  profileImage: 'https://picsum.photos/seed/sarah/200/200',
);

final sampleMeasurement = Measurement(
  id: 'm1',
  customerId: 'c1',
  upperBustCircumference: 34.5,
  roundShoulderCircumference: 40.0,
  hipsCircumference: 38.0,
  underBustCircumference: 32.0,
  bustCircumference: 36.0,
  bustSpan: 18.0,
  shoulderToHips: 45.0,
  shoulderToKnee: 65.0,
  shoulderToUnderBust: 30.0,
  shoulderToBust: 25.0,
  thigh: 22.0,
  knee: 16.0,
  ankle: 12.0,
  createdAt: DateTime.now().subtract(const Duration(days: 30)),
);

final sampleTailors = [
  Tailor(
    id: 't1',
    name: 'Elegant Stitches',
    email: 'elegant@tailor.com',
    phone: '+8801712345679',
    address: 'House 5, Road 12, Dhanmondi, Dhaka',
    licenses: ['License #12345', 'License #67890'],
    rating: 4.9,
    reviewCount: 567,
    profileImage: 'https://picsum.photos/seed/elegantstitches/200/200',
    description: 'Expert tailor specializing in bridal wear and formal attire. 10 years of experience.',
    portfolio: [
      Portfolio(
        id: 'pf1',
        tailorId: 't1',
        image: 'https://picsum.photos/seed/portfolio1/400/500',
        description: 'Bridal gown with intricate embroidery',
      ),
      Portfolio(
        id: 'pf2',
        tailorId: 't1',
        image: 'https://picsum.photos/seed/portfolio2/400/500',
        description: 'Traditional wedding dress',
      ),
      Portfolio(
        id: 'pf3',
        tailorId: 't1',
        image: 'https://picsum.photos/seed/portfolio3/400/500',
        description: 'Modern evening gown',
      ),
      Portfolio(
        id: 'pf4',
        tailorId: 't1',
        image: 'https://picsum.photos/seed/portfolio4/400/500',
        description: 'Custom design suit',
      ),
    ],
    reviews: [
      Review(
        id: 't1r1',
        customerId: 'c1',
        targetId: 't1',
        targetRole: ReviewTargetRole.tailor,
        orderId: 'o1',
        rating: 5,
        comment: 'Incredible work! My wedding dress was perfect.',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      Review(
        id: 't1r2',
        customerId: 'c2',
        targetId: 't1',
        targetRole: ReviewTargetRole.tailor,
        orderId: 'o2',
        rating: 5,
        comment: 'Very professional and talented. Highly recommended!',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ],
  ),
  Tailor(
    id: 't2',
    name: 'Classic Tailoring',
    email: 'classic@tailor.com',
    phone: '+8801712345680',
    address: 'House 8, Road 3, Gulshan, Dhaka',
    licenses: ['License #11111'],
    rating: 4.7,
    reviewCount: 432,
    profileImage: 'https://picsum.photos/seed/classictailoring/200/200',
    description: 'Traditional tailoring with modern designs. Specializing in mens and womens formal wear.',
    portfolio: [
      Portfolio(
        id: 'pf5',
        tailorId: 't2',
        image: 'https://picsum.photos/seed/classic1/400/500',
        description: 'Classic mens suit',
      ),
      Portfolio(
        id: 'pf6',
        tailorId: 't2',
        image: 'https://picsum.photos/seed/classic2/400/500',
        description: 'Traditional panjabi',
      ),
      Portfolio(
        id: 'pf7',
        tailorId: 't2',
        image: 'https://picsum.photos/seed/classic3/400/500',
        description: 'Modern formal wear',
      ),
    ],
    reviews: [
      Review(
        id: 't2r1',
        customerId: 'c3',
        targetId: 't2',
        targetRole: ReviewTargetRole.tailor,
        orderId: 'o3',
        rating: 5,
        comment: 'Best tailor in town! Great attention to detail.',
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
    ],
  ),
];

final sampleRetailers = [
  Retailer(
    id: 'r1',
    shopName: 'Fabric World',
    email: 'fabricworld@shop.com',
    phone: '+8801712345681',
    address: 'Shop 45, Gulshan Shopping Center, Dhaka',
    licenses: ['License #F12345'],
    rating: 4.5,
    reviewCount: 342,
    logoUrl: 'https://picsum.photos/seed/fabricworld/200/200',
    description: 'Premium quality fabrics from around the world. Specializing in cotton, silk, and linen.',
    products: [
      Product(
        id: 'p1',
        retailerId: 'r1',
        productName: 'Premium Cotton Fabric',
        category: 'Cotton',
        materialType: '100% Cotton',
        colorOptions: ['White', 'Pink', 'Blue', 'Green'],
        description: 'High quality cotton fabric perfect for everyday wear.',
        price: 230,
        rating: 4.5,
        reviewCount: 234,
        imageUrl: 'https://picsum.photos/seed/cotton1/300/400',
      ),
      Product(
        id: 'p2',
        retailerId: 'r1',
        productName: 'Silk Blend Fabric',
        category: 'Silk',
        materialType: 'Silk Blend',
        colorOptions: ['White', 'Pink', 'Gold'],
        description: 'Luxurious silk blend for special occasions.',
        price: 330,
        rating: 4.7,
        reviewCount: 334,
        imageUrl: 'https://picsum.photos/seed/silk1/300/400',
      ),
      Product(
        id: 'p3',
        retailerId: 'r1',
        productName: 'Linen Casual Fabric',
        category: 'Linen',
        materialType: '100% Linen',
        colorOptions: ['White', 'Beige', 'Blue'],
        description: 'Breathable linen perfect for summer wear.',
        price: 130,
        rating: 3.5,
        reviewCount: 200,
        imageUrl: 'https://picsum.photos/seed/linen1/300/400',
      ),
    ],
    reviews: [
      Review(
        id: 'r1r1',
        customerId: 'c1',
        targetId: 'r1',
        targetRole: ReviewTargetRole.retailer,
        orderId: 'o1',
        rating: 5,
        comment: 'Excellent quality fabrics! Highly recommend.',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Review(
        id: 'r1r2',
        customerId: 'c4',
        targetId: 'r1',
        targetRole: ReviewTargetRole.retailer,
        orderId: 'o4',
        rating: 4,
        comment: 'Good selection but delivery was a bit slow.',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ],
  ),
  Retailer(
    id: 'r2',
    shopName: 'Silk Emporium',
    email: 'silk@emporium.com',
    phone: '+8801712345682',
    address: 'Shop 12, Banani Market, Dhaka',
    licenses: ['License #S67890'],
    rating: 4.8,
    reviewCount: 521,
    logoUrl: 'https://picsum.photos/seed/silkemporium/200/200',
    description: 'Luxury silk fabrics for special occasions. Premium quality at competitive prices.',
    products: [
      Product(
        id: 'p4',
        retailerId: 'r2',
        productName: 'Satin Silk Fabric',
        category: 'Silk',
        materialType: 'Satin Silk',
        colorOptions: ['White', 'Pink', 'Gold', 'Silver'],
        description: 'Beautiful satin silk perfect for wedding dresses.',
        price: 330,
        rating: 4.7,
        reviewCount: 334,
        imageUrl: 'https://picsum.photos/seed/satinsilk/300/400',
      ),
      Product(
        id: 'p5',
        retailerId: 'r2',
        productName: 'Premium Silk Organza',
        category: 'Silk',
        materialType: 'Silk Organza',
        colorOptions: ['White', 'Gold', 'Ivory'],
        description: 'Sheer and elegant silk organza for overlay designs.',
        price: 450,
        rating: 4.9,
        reviewCount: 456,
        imageUrl: 'https://picsum.photos/seed/organza/300/400',
      ),
    ],
    reviews: [
      Review(
        id: 'r2r1',
        customerId: 'c5',
        targetId: 'r2',
        targetRole: ReviewTargetRole.retailer,
        orderId: 'o5',
        rating: 5,
        comment: 'Absolutely stunning silk! Made my wedding dress perfect.',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ],
  ),
];

final sampleOrders = [
  Order(
    id: 'o1',
    customerId: 'c1',
    orderDate: DateTime.now().subtract(const Duration(days: 2)),
    totalPrice: 560.0,
    status: OrderStatus.confirmed,
    paymentStatus: PaymentStatus.paid,
    paymentDeadline: DateTime.now().add(const Duration(days: 5)),
    tailorSelectionDeadline: DateTime.now().add(const Duration(days: 2)),
  ),
];

final sampleSubOrders = [
  SubOrder(
    id: 'so1',
    orderId: 'o1',
    retailerId: 'r1',
    status: SubOrderStatus.confirmed,
    confirmedAt: DateTime.now().subtract(const Duration(days: 1)),
    paymentStatus: PaymentStatus.paid,
    paymentReleaseDeadline: DateTime.now().add(const Duration(days: 7)),
    autoReleaseAt: DateTime.now().add(const Duration(days: 7)),
  ),
];

final sampleOrderItems = [
  OrderItem(
    id: 'oi1',
    subOrderId: 'so1',
    productId: 'p1',
    optionId: 'White',
    quantity: 2,
    price: 230,
    instruction: 'Please fold properly',
  ),
  OrderItem(
    id: 'oi2',
    subOrderId: 'so1',
    productId: 'p2',
    optionId: 'Pink',
    quantity: 1,
    price: 330,
  ),
];

final sampleTailorJobs = [
  TailorJob(
    id: 'tj1',
    orderId: 'o1',
    tailorId: 't1',
    measurementId: 'm1',
    designIds: ['d1'],
    status: TailorJobStatus.accepted,
    confirmedAt: DateTime.now().subtract(const Duration(days: 1)),
    quoteAmount: 2000,
    quoteNote: 'Includes stitching and fitting',
    quoteStatus: QuoteStatus.approved,
    tailorPaymentStatus: PaymentStatus.pending,
    tailorSelectionDeadline: DateTime.now().add(const Duration(days: 2)),
    quoteResponseDeadline: DateTime.now().add(const Duration(days: 3)),
    quoteApprovalDeadline: DateTime.now().add(const Duration(days: 4)),
    paymentReleaseDeadline: DateTime.now().add(const Duration(days: 10)),
    autoReleaseAt: DateTime.now().add(const Duration(days: 10)),
  ),
];

final sampleNotifications = [
  Notification(
    id: 'n1',
    userId: 'c1',
    userRole: 'customer',
    message: 'Your order #o1 has been confirmed',
    isRead: false,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
];

final sampleFavorites = [
  Favorite(
    id: 'f1',
    customerId: 'c1',
    targetId: 't1',
    targetRole: FavoriteTargetRole.tailor,
  ),
];

final sampleConversations = [
  Conversation(
    id: 'conv1',
    customerId: 'c1',
    otherId: 't1',
    otherRole: 'tailor',
    orderId: 'o1',
    lastMessage: 'When will my dress be ready?',
    lastMessageAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
];

final sampleMessages = [
  Message(
    id: 'msg1',
    conversationId: 'conv1',
    senderId: 'c1',
    senderRole: SenderRole.customer,
    msgText: 'When will my dress be ready?',
    sentAt: DateTime.now().subtract(const Duration(hours: 1)),
    isRead: false,
  ),
];

final categories = [
  'All',
  'Cotton',
  'Silk',
  'Wool',
  'Linen',
  'Lace',
  'Embroidery',
];

final materialTypes = [
  'All',
  '100% Cotton',
  'Silk Blend',
  '100% Linen',
  'Wool Blend',
  'Satin Silk',
  'Silk Organza',
  'Pure Cotton Khadi',
];