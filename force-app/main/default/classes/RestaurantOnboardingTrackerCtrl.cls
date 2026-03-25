public with sharing class RestaurantOnboardingTrackerCtrl {

    @AuraEnabled
    public static Id submitRestaurantForApproval(Id restaurantId) {
        try {
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setComments('Submitted for Onboarding via Ops Tracker');
            req.setObjectId(restaurantId);
            // Submit targeting the specific process the user mentioned
            req.setProcessDefinitionNameOrId('Restaurant_Approval'); 
            Approval.ProcessResult result = Approval.process(req);
            return restaurantId;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<TrackerWrapper> getMySubmittedRestaurants() {
        List<TrackerWrapper> results = new List<TrackerWrapper>();
        
        List<Restaurant__c> restaurants = [
            SELECT Id, Name, City__c, Restaurant_Code__c, Onboarding_Status__c, CreatedDate, Restaurant_Owner__r.Name
            FROM Restaurant__c
            WHERE CreatedById = :UserInfo.getUserId()
            ORDER BY CreatedDate DESC
            LIMIT 15
        ];
        
        if (restaurants.isEmpty()) {
            return results;
        }
        
        Set<Id> resIds = new Set<Id>();
        for (Restaurant__c r : restaurants) {
            resIds.add(r.Id);
        }
        
        List<ProcessInstance> instances = [
            SELECT TargetObjectId, Status,
                (SELECT StepStatus, Actor.Name, Comments, CreatedDate
                 FROM StepsAndWorkitems
                 ORDER BY CreatedDate ASC)
            FROM ProcessInstance
            WHERE TargetObjectId IN :resIds
        ];
        
        Map<Id, ProcessInstance> resToProcessMap = new Map<Id, ProcessInstance>();
        for (ProcessInstance pi : instances) {
            resToProcessMap.put(pi.TargetObjectId, pi);
        }
        
        for (Restaurant__c r : restaurants) {
            TrackerWrapper wrap = new TrackerWrapper();
            wrap.restaurantId = r.Id;
            wrap.name = r.Name;
            wrap.city = r.City__c;
            wrap.restaurantCode = r.Restaurant_Code__c;
            wrap.status = r.Onboarding_Status__c;
            wrap.ownerName = r.Restaurant_Owner__r != null ? r.Restaurant_Owner__r.Name : 'No Owner';
            wrap.createdDate = r.CreatedDate;
            
            if (resToProcessMap.containsKey(r.Id)) {
                ProcessInstance pi = resToProcessMap.get(r.Id);
                wrap.approvalStatus = pi.Status;
                
                List<TimelineStep> tSteps = new List<TimelineStep>();
                for (ProcessInstanceHistory pih : pi.StepsAndWorkitems) {
                    TimelineStep ts = new TimelineStep();
                    ts.stepStatus = pih.StepStatus;
                    ts.actorName = pih.Actor.Name;
                    ts.comments = pih.Comments != null ? pih.Comments : '';
                    ts.actionDate = pih.CreatedDate;
                    
                    if(ts.stepStatus == 'Approved') ts.statusClass = 'status-approved';
                    else if(ts.stepStatus == 'Rejected') ts.statusClass = 'status-rejected';
                    else if(ts.stepStatus == 'Pending') ts.statusClass = 'status-pending';
                    else ts.statusClass = 'status-info';
                    
                    tSteps.add(ts);
                }
                wrap.timeline = tSteps;
            } else {
                wrap.approvalStatus = 'Not Submitted';
                wrap.timeline = new List<TimelineStep>();
            }
            results.add(wrap);
        }
        
        return results;
    }

    public class TrackerWrapper {
        @AuraEnabled public Id restaurantId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String city { get; set; }
        @AuraEnabled public String restaurantCode { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public Datetime createdDate { get; set; }
        @AuraEnabled public String approvalStatus { get; set; }
        @AuraEnabled public List<TimelineStep> timeline { get; set; }
    }
    
    public class TimelineStep {
        @AuraEnabled public String stepStatus { get; set; }
        @AuraEnabled public String actorName { get; set; }
        @AuraEnabled public String comments { get; set; }
        @AuraEnabled public Datetime actionDate { get; set; }
        @AuraEnabled public String statusClass { get; set; }
    }
}
