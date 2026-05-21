public with sharing class OrderLifecycleController {

    public class OrderWrapper {
        @AuraEnabled public Order__c order { get; set; }
        @AuraEnabled public Boolean canEdit { get; set; }
        
        public OrderWrapper(Order__c o, Boolean canEdit) {
            this.order = o;
            this.canEdit = canEdit;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<OrderWrapper> getActiveOrders() {
        if (!FeatureManagement.checkPermission('Operation_LWC_Components')) {
            throw new AuraHandledException('Access Denied');
        }
        
        // Fetches orders that are NOT DELIVERED or were created in the last 24 hours
        Datetime last24h = Datetime.now().addHours(-24);
        
        List<Order__c> orderList = [
            SELECT Id, Name, Order_Status__c, Customer__r.Name, Restaurant__r.Name, 
                   Delivery_Agent__c, Delivery_Agent__r.Name, Order_Total__c, 
                   CreatedDate, SLA_Status__c
            FROM Order__c
            WHERE Order_Status__c != 'DELIVERED' OR CreatedDate >= :last24h
            ORDER BY CreatedDate ASC
        ];

        if (orderList.isEmpty()) {
            return new List<OrderWrapper>();
        }

        Map<Id, Order__c> orderMap = new Map<Id, Order__c>(orderList);
        List<OrderWrapper> wrappers = new List<OrderWrapper>();
        
        // Check edit access to respect Operations Team actions vs read-only users
        List<UserRecordAccess> accessList = [
            SELECT RecordId, HasEditAccess 
            FROM UserRecordAccess 
            WHERE UserId = :UserInfo.getUserId() 
            AND RecordId IN :orderMap.keySet()
        ];
        
        Map<Id, Boolean> accessMap = new Map<Id, Boolean>();
        for (UserRecordAccess access : accessList) {
            accessMap.put(access.RecordId, access.HasEditAccess);
        }

        for (Order__c o : orderList) {
            wrappers.add(new OrderWrapper(o, accessMap.get(o.Id) == true));
        }

        return wrappers;
    }

    @AuraEnabled
    public static void updateOrderStatus(Id orderId, String newStatus) {
        if (!FeatureManagement.checkPermission('Operation_LWC_Components')) {
            throw new AuraHandledException('Access Denied');
        }

        Order__c o = new Order__c(Id = orderId, Order_Status__c = newStatus);
        update o;
    }
}