@RestResource(urlMapping='/order/status/*')
global with sharing class OrderStatusController {

    global class AgentInfo {
        public String name;
        public Decimal rating;
        public String vehicle;
    }

    global class StatusResponse {
        public Boolean success;
        public String message;
        public String orderId;
        public String orderStatus;
        public String paymentStatus;
        public AgentInfo agent;
    }

    @HttpGet
    global static StatusResponse getStatus() {

        StatusResponse res = new StatusResponse();

        try {

            RestRequest req = RestContext.request;

            if (req.requestURI == null) {
                return error(res, 'Invalid request.', 400);
            }

            String orderId = req.requestURI.substring(
                req.requestURI.lastIndexOf('/') + 1
            );

            if (String.isBlank(orderId)) {
                return error(res, 'Missing orderId.', 400);
            }

            // ===============================
            // ✅ SAFE ORDER FETCH
            // ===============================
            List<Order__c> orders = [
                SELECT Id,
                       Order_Status__c,
                       Payment_Status__c,
                       Delivery_Agent__c,
                       Delivery_Agent__r.Name
                FROM Order__c
                WHERE Id = :orderId
                LIMIT 1
            ];

            if (orders.isEmpty()) {
                return error(res, 'Order not found.', 404);
            }

            Order__c order = orders[0];

            // ===============================
            // ✅ RESPONSE
            // ===============================
            res.success = true;
            res.orderId = order.Id;
            res.orderStatus = order.Order_Status__c;
            res.paymentStatus = order.Payment_Status__c;

            // ===============================
            // ✅ AGENT INFO
            // ===============================
            if (order.Delivery_Agent__c != null &&
                order.Delivery_Agent__r != null) {

                AgentInfo agent = new AgentInfo();
                agent.name = order.Delivery_Agent__r.Name;

                // Optional future fields
                agent.rating = null;
                agent.vehicle = null;

                res.agent = agent;
            }

            RestContext.response.statusCode = 200;
            return res;

        } catch (Exception e) {

            System.debug('Order Status Error: ' + e.getMessage());

            return error(res, 'Failed to fetch order status.', 500);
        }
    }

    // ===============================
    // ERROR HANDLER
    // ===============================
    private static StatusResponse error(
        StatusResponse res,
        String msg,
        Integer code
    ) {
        res.success = false;
        res.message = msg;
        RestContext.response.statusCode = code;
        return res;
    }
}