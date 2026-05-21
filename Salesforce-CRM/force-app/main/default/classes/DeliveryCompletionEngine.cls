public with sharing class DeliveryCompletionEngine {

    @InvocableMethod(label='Handle Delivery Completion')
    public static void completeDelivery(List<Id> orderIds) {

        if(orderIds == null || orderIds.isEmpty()) return;

        // 1️⃣ Fetch Orders
        List<Order__c> orders = [
            SELECT Id,
                   Delivery_Agent__c,
                   Order_Status__c,
                   Order_Closed_At__c
            FROM Order__c
            WHERE Id IN :orderIds
        ];

        if(orders.isEmpty()) return;

        // 2️⃣ Collect Agent Ids
        Set<Id> agentIds = new Set<Id>();

        for(Order__c o : orders) {
            if(o.Delivery_Agent__c != null) {
                agentIds.add(o.Delivery_Agent__c);
            }
        }

        if(agentIds.isEmpty()) return;

        // 3️⃣ Fetch Agents
        Map<Id, Delivery_Agent__c> agentMap = new Map<Id, Delivery_Agent__c>(
            [SELECT Id,
                    Active_Orders_Count__c,
                    Max_Active_Orders__c,
                    Service_Status__c,
                    Last_Delivery_Completed_At__c
             FROM Delivery_Agent__c
             WHERE Id IN :agentIds]
        );

        Map<Id, Delivery_Agent__c> agentsToUpdateMap = new Map<Id, Delivery_Agent__c>();
        List<Order__c> ordersToUpdate = new List<Order__c>();

        // 4️⃣ Process Orders
        for(Order__c orderRec : orders) {

            // ✅ Skip if already closed (idempotency)
            if(orderRec.Order_Closed_At__c != null) continue;

            // ✅ Only process assigned + delivered orders
            if(orderRec.Delivery_Agent__c == null ||
               orderRec.Order_Status__c != 'OUT_FOR_DELIVERY') continue;

            if(!agentMap.containsKey(orderRec.Delivery_Agent__c)) continue;

            Delivery_Agent__c agent = agentMap.get(orderRec.Delivery_Agent__c);

            Decimal currentLoad =
                agent.Active_Orders_Count__c == null ? 0 :
                agent.Active_Orders_Count__c;

            // ✅ Prevent negative values
            Decimal updatedLoad = currentLoad > 0 ? currentLoad - 1 : 0;

            agent.Active_Orders_Count__c = updatedLoad;

            agent.Last_Delivery_Completed_At__c = System.now();

            // ✅ Safe comparison
            Decimal maxLoad =
                agent.Max_Active_Orders__c == null ? 1 :
                agent.Max_Active_Orders__c;

            if(updatedLoad < maxLoad) {
                agent.Service_Status__c = 'ONLINE';
            }

            agentsToUpdateMap.put(agent.Id, agent);

            // ✅ Close order properly
            orderRec.Order_Status__c = 'DELIVERED';
            orderRec.Order_Closed_At__c = System.now();

            ordersToUpdate.add(orderRec);
        }

        // 5️⃣ DML
        if(!agentsToUpdateMap.isEmpty()) {
            update agentsToUpdateMap.values();
        }

        if(!ordersToUpdate.isEmpty()) {
            update ordersToUpdate;
        }
    }
}