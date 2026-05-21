public with sharing class RefundApprovalController {

    // ================================
    // PERMISSION CHECK
    // ================================
    private static void validatePermission() {
        if (!FeatureManagement.checkPermission('Finance_LWC_Components')) {
            throw new AuraHandledException('Access Denied');
        }
    }

    // ================================
    // GET PENDING REFUND TICKETS
    // ================================
    @AuraEnabled
    public static List<RefundItemWrapper> getPendingRefundTickets() {

        validatePermission();

        List<RefundItemWrapper> result = new List<RefundItemWrapper>();

        // STEP 1: Get all pending approvals
        List<ProcessInstance> processes = [
            SELECT Id, TargetObjectId, ProcessDefinition.Name
            FROM ProcessInstance
            WHERE Status = 'Pending'
        ];

        if (processes.isEmpty()) return result;

        // STEP 2: Filter only refund approvals
        Set<Id> ticketIds = new Set<Id>();
        String prefix = Support_Ticket__c.sObjectType.getDescribe().getKeyPrefix();

        for (ProcessInstance pi : processes) {
            if (pi.ProcessDefinition != null &&
                pi.ProcessDefinition.Name != null &&
                pi.ProcessDefinition.Name.contains('Refund Approval to Finance Team') &&
                pi.TargetObjectId != null &&
                String.valueOf(pi.TargetObjectId).startsWith(prefix)) {

                ticketIds.add(pi.TargetObjectId);
            }
        }

        if (ticketIds.isEmpty()) return result;

        // STEP 3: Fetch tickets
        List<Support_Ticket__c> tickets = [
            SELECT Id, Name, Priority__c, CreatedDate,
                   Order__r.Name, Customer__r.Name, Restaurant__r.Name
            FROM Support_Ticket__c
            WHERE Id IN :ticketIds
            ORDER BY CreatedDate ASC
        ];

        for (Support_Ticket__c t : tickets) {
            RefundItemWrapper w = new RefundItemWrapper();
            w.Id = t.Id;
            w.Name = t.Name;
            w.OrderNumber = t.Order__r != null ? t.Order__r.Name : '';
            w.CustomerName = t.Customer__r != null ? t.Customer__r.Name : '';
            w.RestaurantName = t.Restaurant__r != null ? t.Restaurant__r.Name : '';
            w.Priority = t.Priority__c;
            w.CreatedDate = t.CreatedDate;
            result.add(w);
        }

        return result;
    }

    // ================================
    // GET REFUND DETAILS
    // ================================
    @AuraEnabled
    public static RefundDetailWrapper getRefundDetails(Id ticketId) {

        validatePermission();

        Support_Ticket__c ticket = [
            SELECT Id, Name, Issue_Type__c, Customer_Issue_Count__c,
                   Investigation_Notes__c, Recommended_Refund_Amount__c,
                   Order__r.Name, Order__r.Payment_Status__c,
                   Order__r.Order_Total__c, Order__r.Credits_Used__c,
                   Customer__r.Name, Restaurant__r.Name,
                   Delivery_Agent__r.Name
            FROM Support_Ticket__c
            WHERE Id = :ticketId
            LIMIT 1
        ];

        RefundDetailWrapper wrap = new RefundDetailWrapper();

        wrap.TicketNumber = ticket.Name;
        wrap.OrderNumber = ticket.Order__r != null ? ticket.Order__r.Name : '';
        wrap.PaymentStatus = ticket.Order__r != null ? ticket.Order__r.Payment_Status__c : '';
        wrap.OrderTotal = ticket.Order__r != null ? ticket.Order__r.Order_Total__c : 0;
        wrap.CreditsUsed = ticket.Order__r != null ? ticket.Order__r.Credits_Used__c : 0;

        wrap.CustomerName = ticket.Customer__r != null ? ticket.Customer__r.Name : '';
        wrap.RestaurantName = ticket.Restaurant__r != null ? ticket.Restaurant__r.Name : '';
        wrap.DeliveryAgent = ticket.Delivery_Agent__r != null ? ticket.Delivery_Agent__r.Name : '';

        wrap.IssueType = ticket.Issue_Type__c;
        wrap.CustomerIssueCount = ticket.Customer_Issue_Count__c != null
            ? Integer.valueOf(ticket.Customer_Issue_Count__c)
            : 0;

        wrap.InvestigationNotes = ticket.Investigation_Notes__c;
        wrap.RecommendedRefundAmount = ticket.Recommended_Refund_Amount__c;

        return wrap;
    }

    // ================================
    // UPDATE REFUND AMOUNT (IMPORTANT)
    // ================================
    @AuraEnabled
    public static void updateRefundAmount(Id ticketId, Decimal amount) {

        validatePermission();

        try {
            Support_Ticket__c ticket = new Support_Ticket__c(
                Id = ticketId,
                Recommended_Refund_Amount__c = amount
            );

            update ticket;

        } catch (Exception e) {
            throw new AuraHandledException('Failed to update amount: ' + e.getMessage());
        }
    }

    // ================================
    // APPROVE REFUND
    // ================================
    @AuraEnabled
    public static void approveRefund(Id ticketId, String notes) {

        validatePermission();

        try {

            // STEP 1: Get ProcessInstances
            List<ProcessInstance> processes = [
                SELECT Id, ProcessDefinition.Name
                FROM ProcessInstance
                WHERE TargetObjectId = :ticketId
                AND Status = 'Pending'
            ];

            Set<Id> processIds = new Set<Id>();

            for (ProcessInstance pi : processes) {
                if (pi.ProcessDefinition != null &&
                    pi.ProcessDefinition.Name != null &&
                    pi.ProcessDefinition.Name.contains('Refund Approval to Finance Team')) {

                    processIds.add(pi.Id);
                }
            }

            if (processIds.isEmpty()) {
                throw new AuraHandledException('No pending approval found.');
            }

            // STEP 2: Get Workitems
            List<ProcessInstanceWorkitem> workItems = [
                SELECT Id
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstanceId IN :processIds
            ];

            if (workItems.isEmpty()) {
                throw new AuraHandledException('No approval task found.');
            }

            // STEP 3: Approve
            Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
            req.setComments(notes);
            req.setAction('Approve');
            req.setWorkitemId(workItems[0].Id);

            Approval.process(req);

        } catch (Exception e) {
            throw new AuraHandledException('Approval Failed: ' + e.getMessage());
        }
    }

    // ================================
    // REJECT REFUND
    // ================================
    @AuraEnabled
    public static void rejectRefund(Id ticketId, String notes) {

        validatePermission();

        try {

            List<ProcessInstance> processes = [
                SELECT Id, ProcessDefinition.Name
                FROM ProcessInstance
                WHERE TargetObjectId = :ticketId
                AND Status = 'Pending'
            ];

            Set<Id> processIds = new Set<Id>();

            for (ProcessInstance pi : processes) {
                if (pi.ProcessDefinition != null &&
                    pi.ProcessDefinition.Name != null &&
                    pi.ProcessDefinition.Name.contains('Refund Approval to Finance Team')) {

                    processIds.add(pi.Id);
                }
            }

            List<ProcessInstanceWorkitem> workItems = [
                SELECT Id
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstanceId IN :processIds
            ];

            if (!workItems.isEmpty()) {
                Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
                req.setComments(notes);
                req.setAction('Reject');
                req.setWorkitemId(workItems[0].Id);

                Approval.process(req);
            }

        } catch (Exception e) {
            throw new AuraHandledException('Rejection Failed: ' + e.getMessage());
        }
    }

    // ================================
    // WRAPPERS
    // ================================
    public class RefundItemWrapper {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String OrderNumber;
        @AuraEnabled public String CustomerName;
        @AuraEnabled public String RestaurantName;
        @AuraEnabled public String Priority;
        @AuraEnabled public Datetime CreatedDate;
    }

    public class RefundDetailWrapper {
        @AuraEnabled public String TicketNumber;
        @AuraEnabled public String OrderNumber;
        @AuraEnabled public String PaymentStatus;
        @AuraEnabled public Decimal OrderTotal;
        @AuraEnabled public Decimal CreditsUsed;
        @AuraEnabled public String CustomerName;
        @AuraEnabled public String RestaurantName;
        @AuraEnabled public String DeliveryAgent;
        @AuraEnabled public String IssueType;
        @AuraEnabled public Integer CustomerIssueCount;
        @AuraEnabled public String InvestigationNotes;
        @AuraEnabled public Decimal RecommendedRefundAmount;
    }
}