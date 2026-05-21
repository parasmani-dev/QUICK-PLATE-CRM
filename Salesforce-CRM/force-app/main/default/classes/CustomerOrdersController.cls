@RestResource(urlMapping='/customer/orders')
global without sharing class CustomerOrdersController {

    // ================================
    // Response Wrapper
    // ================================
    global class OrderListResponse {
        public Id id;
        public String restaurantName;
        public Datetime createdDate;
        public Decimal totalAmount;
        public String orderStatus;
        public String paymentStatus;
    }

    global class ResponseWrapper {
        public Boolean success;
        public String message;
        public List<OrderListResponse> orders;
    }

    // ================================
    // GET Orders
    // ================================
    @HttpGet
    global static ResponseWrapper getCustomerOrders() {

        ResponseWrapper response = new ResponseWrapper();

        try {

            RestRequest req = RestContext.request;

            // 🔥 Get token instead of customerId
            String idToken = req.params.get('idToken');

            if (String.isBlank(idToken)) {
                return error(response, 'Authentication required.', 401);
            }

            // ===============================
            // 🔐 VERIFY TOKEN
            // ===============================
            String firebaseUid = FirebaseAuthUtil.verifyToken(idToken);

            if (String.isBlank(firebaseUid)) {
                return error(response, 'Invalid authentication.', 401);
            }

            // ===============================
            // ✅ FETCH CUSTOMER FROM UID
            // ===============================
            List<Customer__c> customers = [
                SELECT Id
                FROM Customer__c
                WHERE Firebase_UID__c = :firebaseUid
                LIMIT 1
            ];

            if (customers.isEmpty()) {
                return error(response, 'Customer not found.', 404);
            }

            Id customerId = customers[0].Id;

            // ===============================
            // ✅ FETCH ORDERS (SECURE)
            // ===============================
            List<Order__c> orders = [
                SELECT Id,
                       Restaurant__r.Name,
                       CreatedDate,
                       Order_Total__c,
                       Order_Status__c,
                       Payment_Status__c
                FROM Order__c
                WHERE Customer__c = :customerId
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];

            List<OrderListResponse> responseList = new List<OrderListResponse>();

            for (Order__c o : orders) {

                OrderListResponse res = new OrderListResponse();
                res.id = o.Id;

                res.restaurantName =
                    (o.Restaurant__r != null && o.Restaurant__r.Name != null)
                    ? o.Restaurant__r.Name
                    : 'Quick Plate Order';

                res.createdDate = o.CreatedDate;

                res.totalAmount =
                    o.Order_Total__c == null ? 0 : o.Order_Total__c;

                res.orderStatus = o.Order_Status__c;
                res.paymentStatus = o.Payment_Status__c;

                responseList.add(res);
            }

            response.success = true;
            response.orders = responseList;

            RestContext.response.statusCode = 200;
            return response;

        } catch (Exception e) {

            System.debug('Customer Orders Error: ' + e.getMessage());

            return error(response, 'Failed to fetch orders.', 500);
        }
    }

    // ===============================
    // ERROR HANDLER
    // ===============================
    private static ResponseWrapper error(
        ResponseWrapper res,
        String msg,
        Integer code
    ) {
        res.success = false;
        res.message = msg;
        RestContext.response.statusCode = code;
        return res;
    }
}