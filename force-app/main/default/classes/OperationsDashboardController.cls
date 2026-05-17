public with sharing class OperationsDashboardController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getOrderStatusSummary() {

        Map<String, Integer> statusCount =
            new Map<String, Integer>();

        for (AggregateResult ar : [

            SELECT
                Order_Status__c status,
                COUNT(Id) totalCount

            FROM Order__c

            GROUP BY Order_Status__c

        ]) {

            statusCount.put(

                (String) ar.get('status'),

                (Integer) ar.get('totalCount')
            );
        }

        return statusCount;
    }
}