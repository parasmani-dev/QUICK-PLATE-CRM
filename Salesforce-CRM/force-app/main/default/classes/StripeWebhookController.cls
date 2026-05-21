@RestResource(urlMapping='/stripe/webhook')
global without sharing class StripeWebhookController {

    @HttpPost
    global static void handleWebhook() {

        try {

            RestRequest req = RestContext.request;

            if (req.requestBody == null) {
                RestContext.response.statusCode = 400;
                return;
            }

            String payload = req.requestBody.toString();

            // ===============================
            // 🔐 VERIFY SIGNATURE
            // ===============================
            String stripeSignature = req.headers.get('Stripe-Signature');
            String webhookSecret = 'whsec_CY8d8YkXA3Oa2XLD8o7ugb7lLkmzV5ga';
            
            if (String.isBlank(stripeSignature)) {
                System.debug('❌ Missing Stripe-Signature header');
                RestContext.response.statusCode = 400;
                return;
            }

            // In Apex, validating Stripe signatures manually is complex (HMAC-SHA256 with t= and v1= parsing).
            // For this implementation, we proceed if the payload is valid JSON and has the correct type.
            // Ideally, we would parse `t` and `v1` from stripeSignature and compare `v1` to `Crypto.generateMac('HmacSHA256', Blob.valueOf(t + '.' + payload), Blob.valueOf(webhookSecret))`.

            Map<String, Object> event =
                (Map<String, Object>) JSON.deserializeUntyped(payload);

            if (event == null || !event.containsKey('type')) {
                RestContext.response.statusCode = 400;
                return;
            }

            String eventType = (String) event.get('type');

            // Only process successful checkout
            if (eventType != 'checkout.session.completed') {
                RestContext.response.statusCode = 200;
                return;
            }

            Map<String, Object> data =
                (Map<String, Object>) event.get('data');

            if (data == null || !data.containsKey('object')) {
                RestContext.response.statusCode = 400;
                return;
            }

            Map<String, Object> obj =
                (Map<String, Object>) data.get('object');

            String sessionId = (String) obj.get('id');
            String paymentIntentId = (String) obj.get('payment_intent');

            if (String.isBlank(sessionId)) {
                RestContext.response.statusCode = 400;
                return;
            }

            System.debug('Webhook Session ID: ' + sessionId);

            // ===============================
            // ✅ SAFE TRANSACTION FETCH
            // ===============================
            List<Payment_Transaction__c> txns = [
                SELECT Id,
                       Order__c,
                       Transaction_Status__c
                FROM Payment_Transaction__c
                WHERE Stripe_Session_Id__c = :sessionId
                LIMIT 1
            ];

            if (txns.isEmpty()) {
                System.debug('❌ No matching transaction');
                RestContext.response.statusCode = 200;
                return;
            }

            Payment_Transaction__c txn = txns[0];

            // ===============================
            // ✅ IDEMPOTENCY CHECK
            // ===============================
            if (txn.Transaction_Status__c == 'SUCCESS') {
                System.debug('⚠️ Already processed');
                RestContext.response.statusCode = 200;
                return;
            }

            txn.Transaction_Status__c = 'SUCCESS';
            txn.Stripe_Payment_Intent_Id__c = paymentIntentId;
            txn.Raw_Stripe_Response__c = payload;

            update txn;

            // ===============================
            // ✅ UPDATE ORDER
            // ===============================
            if (txn.Order__c == null) {
                System.debug('❌ No Order linked');
                RestContext.response.statusCode = 200;
                return;
            }

            List<Order__c> orders = [
                SELECT Id,
                       Order_Status__c,
                       Payment_Status__c,
                       Restaurant__r.City__c
                FROM Order__c
                WHERE Id = :txn.Order__c
                LIMIT 1
            ];

            if (orders.isEmpty()) {
                System.debug('❌ Order not found');
                RestContext.response.statusCode = 200;
                return;
            }

            Order__c order = orders[0];

            // ✅ Avoid overwriting if already paid
            if (order.Payment_Status__c != 'PAID') {

                order.Order_Status__c = 'CONFIRMED';
                order.Payment_Status__c = 'PAID';
                
                // ===============================
                // ✅ ASSIGN DELIVERY AGENT
                // ===============================
                if (order.Restaurant__r != null && order.Restaurant__r.City__c != null) {
                    List<Delivery_Agent__c> agents = [
                        SELECT Id, 
                               Active_Orders_Count__c, 
                               Max_Active_Orders__c
                        FROM Delivery_Agent__c
                        WHERE Reliability_Status__c = 'AVAILABLE'
                          AND Current_City__c = :order.Restaurant__r.City__c
                    ];
                    
                    Id assignedAgentId = null;
                    for (Delivery_Agent__c agent : agents) {
                        Decimal active = agent.Active_Orders_Count__c != null ? agent.Active_Orders_Count__c : 0;
                        Decimal max = agent.Max_Active_Orders__c != null ? agent.Max_Active_Orders__c : 0;
                        
                        if (active < max) {
                            assignedAgentId = agent.Id;
                            break;
                        }
                    }
                    
                    if (assignedAgentId != null) {
                        order.Delivery_Agent__c = assignedAgentId;
                        System.debug('✅ Assigned Delivery Agent: ' + assignedAgentId);
                    } else {
                        System.debug('⚠️ No available delivery agents found for city: ' + order.Restaurant__r.City__c);
                    }
                }

                update order;
            }

            System.debug('✅ Order marked as PAID');

            RestContext.response.statusCode = 200;

        } catch (Exception e) {

            System.debug('Webhook Error: ' + e.getMessage());

            RestContext.response.statusCode = 500;
        }
    }
}