@RestResource(urlMapping='/order/create')
global without sharing class OrderController {

    // ================================
    // Request Wrapper
    // ================================
    global class OrderCreateRequest {
        public String idToken; // 🔥 REQUIRED
        public String restaurantId;
        public Decimal orderTotal;
        public Decimal creditsUsed;
    }

    // ================================
    // Response Wrapper
    // ================================
    global class OrderCreateResponse {
        public Boolean success;
        public String orderId;
        public String orderNumber;
        public String message;
    }

    @HttpPost
    global static OrderCreateResponse createOrder() {

        OrderCreateResponse res = new OrderCreateResponse();

        try {

            RestRequest req = RestContext.request;

            if (req.requestBody == null) {
                return buildError(res, 'Request body missing.', 400);
            }

            OrderCreateRequest input =
                (OrderCreateRequest) JSON.deserialize(
                    req.requestBody.toString(),
                    OrderCreateRequest.class
                );

            // ================================
            // 🔥 VALIDATE INPUT
            // ================================
            if (String.isBlank(input.idToken) ||
                String.isBlank(input.restaurantId) ||
                input.orderTotal == null ||
                input.orderTotal <= 0) {

                return buildError(res, 'Invalid request data.', 400);
            }

            // ================================
            // 🔐 VERIFY FIREBASE TOKEN
            // ================================
            String firebaseUid = FirebaseAuthUtil.verifyToken(input.idToken);

            if (String.isBlank(firebaseUid)) {
                return buildError(res, 'Invalid authentication.', 401);
            }

            // ================================
            // ✅ GET CUSTOMER FROM UID
            // ================================
            List<Customer__c> customers = [
                SELECT Id
                FROM Customer__c
                WHERE Firebase_UID__c = :firebaseUid
                LIMIT 1
            ];

            if (customers.isEmpty()) {
                return buildError(res, 'Customer not found.', 404);
            }

            Customer__c customer = customers[0];

            // ================================
            // ✅ RESTAURANT VALIDATION
            // ================================
            List<Restaurant__c> restaurants = [
                SELECT Id,
                       Is_Active__c,
                       Is_Temporarily_Closed__c
                FROM Restaurant__c
                WHERE Id = :input.restaurantId
                LIMIT 1
            ];

            if (restaurants.isEmpty()) {
                return buildError(res, 'Invalid restaurant.', 400);
            }

            Restaurant__c restaurant = restaurants[0];

            if (!restaurant.Is_Active__c ||
                restaurant.Is_Temporarily_Closed__c) {
                return buildError(res, 'Restaurant not available.', 400);
            }

            // ================================
            // 💰 CREDITS
            // ================================
            Decimal creditsUsed =
                (input.creditsUsed != null && input.creditsUsed > 0)
                ? input.creditsUsed
                : 0;

            // ================================
            // 🚀 CREATE ORDER
            // ================================
            Order__c order = new Order__c(
                OwnerId = UserInfo.getUserId(),
                Customer__c = customer.Id,
                Restaurant__c = restaurant.Id,
                Order_Status__c = 'PAYMENT_PENDING',
                Payment_Status__c = 'UNPAID',
                Order_Total__c = input.orderTotal,
                Credits_Used__c = creditsUsed,
                Order_Created_At__c = System.now()
            );

            insert order;

            // ================================
            // ✅ RESPONSE
            // ================================
            res.success = true;
            res.orderId = order.Id;
            res.orderNumber = order.Order_Number__c;

            RestContext.response.statusCode = 200;
            return res;

        } catch (Exception e) {

            System.debug('Order Creation Error: ' + e.getMessage());

            return buildError(
                res,
                'Order creation failed.',
                500
            );
        }
    }

    // ================================
    private static OrderCreateResponse buildError(
        OrderCreateResponse res,
        String message,
        Integer statusCode
    ) {
        res.success = false;
        res.message = message;
        RestContext.response.statusCode = statusCode;
        return res;
    }
}