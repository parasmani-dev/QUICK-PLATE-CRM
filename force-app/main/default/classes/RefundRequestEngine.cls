public with sharing class RefundRequestEngine {

    @InvocableMethod(label='Handle Refund Request')
    public static void processRefundRequest(List<Id> orderIds) {

        if(orderIds == null || orderIds.isEmpty()) return;

        // 🔹 Fetch Orders
        List<Order__c> orders = [
            SELECT Id,
                   Customer__c,
                   Restaurant__c,
                   Delivery_Agent__c,
                   Order_Status__c
            FROM Order__c
            WHERE Id IN :orderIds
        ];

        if(orders.isEmpty()) return;

        // 🔹 Prevent duplicate tickets
        Set<Id> existingTicketOrderIds = new Set<Id>();

        for(Support_Ticket__c st : [
            SELECT Order__c
            FROM Support_Ticket__c
            WHERE Order__c IN :orderIds
        ]) {
            existingTicketOrderIds.add(st.Order__c);
        }

        // 🔹 Fetch Queue once
        Id serviceQueueId = getQueueId('Customer Service Queue');

        List<Support_Ticket__c> ticketsToInsert = new List<Support_Ticket__c>();
        List<Order__c> ordersToUpdate = new List<Order__c>();

        for(Order__c orderRec : orders) {

            // ✅ Skip if already ticket exists
            if(existingTicketOrderIds.contains(orderRec.Id)) continue;

            // ✅ Only allow valid states
            if(orderRec.Order_Status__c != 'DELIVERED') continue;

            // ✅ Basic safety
            if(orderRec.Customer__c == null) continue;

            Support_Ticket__c ticket = new Support_Ticket__c(
                Order__c = orderRec.Id,
                Customer__c = orderRec.Customer__c,
                Restaurant__c = orderRec.Restaurant__c,
                Delivery_Agent__c = orderRec.Delivery_Agent__c,
                Ticket_Status__c = 'NEW',
                Finance_Approval_Status__c = 'NOT_REQUIRED',
                Priority__c = 'HIGH',
                Issue_Type__c = 'Refund Request'
            );

            if(serviceQueueId != null) {
                ticket.OwnerId = serviceQueueId;
            }

            ticketsToInsert.add(ticket);

            // ✅ Update only if not already in refund flow
            if(orderRec.Order_Status__c != 'REFUND_REQUESTED') {
                orderRec.Order_Status__c = 'REFUND_REQUESTED';
                ordersToUpdate.add(orderRec);
            }
        }

        if(!ticketsToInsert.isEmpty()) {
            insert ticketsToInsert;
        }

        if(!ordersToUpdate.isEmpty()) {
            update ordersToUpdate;
        }
    }

    // 🔹 Queue Fetcher (Optimized)
    private static Id getQueueId(String queueName) {

        List<Group> queues = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
            AND Name = :queueName
            LIMIT 1
        ];

        return queues.isEmpty() ? null : queues[0].Id;
    }
}