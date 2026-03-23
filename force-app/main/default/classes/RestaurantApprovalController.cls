public with sharing class RestaurantApprovalController {

    public class ApprovalRequestWrapper {
        @AuraEnabled public Id workItemId { get; set; }
        @AuraEnabled public Id restaurantId { get; set; }
        @AuraEnabled public String restaurantName { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public String city { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String address { get; set; }
        @AuraEnabled public Decimal avgPrepTime { get; set; }
        @AuraEnabled public String prepTimeRiskLevel { get; set; }
        @AuraEnabled public Datetime createdDate { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static List<ApprovalRequestWrapper> getPendingApprovals() {
        List<ApprovalRequestWrapper> requests = new List<ApprovalRequestWrapper>();
        
        try {
            // Get the key prefix for Restaurant__c to filter WorkItems
            String restaurantPrefix = Restaurant__c.sObjectType.getDescribe().getKeyPrefix();
            
            // Query all pending approval work items
            List<ProcessInstanceWorkitem> workItems = [
                SELECT Id, ProcessInstance.TargetObjectId
                FROM ProcessInstanceWorkitem
            ];
            
            if(workItems.isEmpty()) return requests;
            
            Set<Id> targetIds = new Set<Id>();
            Map<Id, Id> targetToWorkItemMap = new Map<Id, Id>();
            for(ProcessInstanceWorkitem item : workItems) {
                // Ensure target is not null and belongs to Restaurant__c (using key prefix)
                if(item.ProcessInstance.TargetObjectId != null && 
                   String.valueOf(item.ProcessInstance.TargetObjectId).startsWith(restaurantPrefix)) {
                    targetIds.add(item.ProcessInstance.TargetObjectId);
                    targetToWorkItemMap.put(item.ProcessInstance.TargetObjectId, item.Id);
                }
            }
            
            if(targetIds.isEmpty()) return requests;
            
            List<Restaurant__c> restaurants = [
                SELECT Id, Name, Owner.Name, City__c, Onboarding_Status__c, Address__c, CreatedDate, Avg_Prep_Time_Min__c, Prep_Time_Risk_Level__c
                FROM Restaurant__c
                WHERE Id IN :targetIds
            ];
            
            for(Restaurant__c rest : restaurants) {
                ApprovalRequestWrapper wrapper = new ApprovalRequestWrapper();
                wrapper.workItemId = targetToWorkItemMap.get(rest.Id);
                wrapper.restaurantId = rest.Id;
                wrapper.restaurantName = rest.Name;
                wrapper.ownerName = rest.Owner.Name;
                wrapper.city = rest.City__c != null ? rest.City__c : 'N/A';
                wrapper.status = rest.Onboarding_Status__c != null ? rest.Onboarding_Status__c : 'DRAFT';
                wrapper.address = rest.Address__c != null ? rest.Address__c : 'N/A';
                wrapper.avgPrepTime = rest.Avg_Prep_Time_Min__c;
                wrapper.prepTimeRiskLevel = rest.Prep_Time_Risk_Level__c != null ? rest.Prep_Time_Risk_Level__c : 'N/A';
                wrapper.createdDate = rest.CreatedDate;
                requests.add(wrapper);
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching approvals: ' + e.getMessage());
        }
        
        return requests;
    }

    @AuraEnabled
    public static void processApproval(Id workItemId, String action, String comments) {
        try {
            Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
            req.setComments(comments);
            req.setAction(action); // 'Approve' or 'Reject'
            req.setWorkitemId(workItemId);
            Approval.ProcessResult result = Approval.process(req);
            if(!result.isSuccess()) {
                throw new AuraHandledException('Error processing approval.');
            }
        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
