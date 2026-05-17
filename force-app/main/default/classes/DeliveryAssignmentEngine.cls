public with sharing class DeliveryAssignmentEngine {

    public class Request {
        @InvocableVariable(required=true)
        public Id orderId;
    }

    @InvocableMethod(label='Assign Delivery Agent')
    public static void assignAgent(List<Request> requests) {

        if (requests == null || requests.isEmpty()) return;

        Set<Id> orderIds = new Set<Id>();
        for (Request r : requests) {
            if (r.orderId != null) orderIds.add(r.orderId);
        }
        if (orderIds.isEmpty()) return;

        // 🔥 Fetch orders safely
        List<Order__c> orders = [
            SELECT Id,
                   Delivery_Agent__c,
                   Order_Status__c,
                   Requires_Manual_Action__c,
                   Restaurant__r.City__c
            FROM Order__c
            WHERE Id IN :orderIds
        ];

        if (orders.isEmpty()) return;

        Set<String> cities = new Set<String>();

        for (Order__c o : orders) {
            if (o.Restaurant__r != null &&
                String.isNotBlank(o.Restaurant__r.City__c)) {

                cities.add(o.Restaurant__r.City__c);
            }
        }

        if (cities.isEmpty()) return;

        // 🔥 Fetch agents
        List<Delivery_Agent__c> agents = [
            SELECT Id,
                   Current_City__c,
                   Active_Orders_Count__c,
                   Max_Active_Orders__c,
                   Service_Status__c,
                   Is_Active__c
            FROM Delivery_Agent__c
            WHERE Is_Active__c = TRUE
            AND Service_Status__c = 'ONLINE'
            AND Current_City__c IN :cities
            ORDER BY Active_Orders_Count__c ASC
        ];

        if (agents.isEmpty()) return;

        // 🔥 Group agents by city
        Map<String, List<Delivery_Agent__c>> cityMap =
            new Map<String, List<Delivery_Agent__c>>();

        for (Delivery_Agent__c a : agents) {
            if (!cityMap.containsKey(a.Current_City__c)) {
                cityMap.put(a.Current_City__c, new List<Delivery_Agent__c>());
            }
            cityMap.get(a.Current_City__c).add(a);
        }

        List<Order__c> ordersToUpdate = new List<Order__c>();
        List<Delivery_Agent__c> agentsToUpdate = new List<Delivery_Agent__c>();

        for (Order__c orderRec : orders) {

            // ✅ Skip if already assigned
            if (orderRec.Delivery_Agent__c != null) continue;

            // ✅ Only confirmed orders
            if (orderRec.Order_Status__c != 'CONFIRMED') continue;

            if (orderRec.Restaurant__r == null ||
                String.isBlank(orderRec.Restaurant__r.City__c)) continue;

            List<Delivery_Agent__c> cityAgents =
                cityMap.get(orderRec.Restaurant__r.City__c);

            if (cityAgents == null || cityAgents.isEmpty()) continue;

            Delivery_Agent__c selectedAgent;

            for (Delivery_Agent__c agent : cityAgents) {

                Decimal currentLoad =
                    agent.Active_Orders_Count__c == null ? 0 :
                    agent.Active_Orders_Count__c;

                Decimal maxLoad =
                    agent.Max_Active_Orders__c == null ? 1 :
                    agent.Max_Active_Orders__c;

                if (currentLoad < maxLoad) {
                    selectedAgent = agent;
                    break;
                }
            }

            if (selectedAgent == null) continue;

            // ✅ Assign order
            orderRec.Delivery_Agent__c = selectedAgent.Id;
            orderRec.Order_Status__c = 'ASSIGNED';
            orderRec.Requires_Manual_Action__c = false;

            // ✅ Update agent load
            Decimal updatedLoad =
                (selectedAgent.Active_Orders_Count__c == null ? 0 :
                 selectedAgent.Active_Orders_Count__c) + 1;

            selectedAgent.Active_Orders_Count__c = updatedLoad;

            if (selectedAgent.Max_Active_Orders__c != null &&
                updatedLoad >= selectedAgent.Max_Active_Orders__c) {

                selectedAgent.Service_Status__c = 'ON_BREAK';
            }

            ordersToUpdate.add(orderRec);
            agentsToUpdate.add(selectedAgent);
        }

        if (!agentsToUpdate.isEmpty()) update agentsToUpdate;
        if (!ordersToUpdate.isEmpty()) update ordersToUpdate;
    }
}