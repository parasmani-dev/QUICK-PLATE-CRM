public with sharing class RefundApprovalController {

    // Helper method for permission check
    private static void validatePermission() {
        if (!FeatureManagement.checkPermission('Finance_LWC_Components')) {
            throw new AuraHandledException('Access Denied: You do not have the necessary permissions to perform this action.');
        }
    }

    @AuraEnabled
    public static List<RefundItemWrapper> getPendingRefundTickets() {
        validatePermission();
        
        List<RefundItemWrapper> result = new List<RefundItemWrapper>();
        
        // 1. Get Prefix to filter target records
        String supportTicketPrefix = Support_Ticket__c.sObjectType.getDescribe().getKeyPrefix();
        
        // 2. Query pending refund approval work items
        List<ProcessInstanceWorkitem> workItems = [
            SELECT ProcessInstance.TargetObjectId 
            FROM ProcessInstanceWorkitem 
            WHERE ProcessInstance.ProcessDefinition.Name LIKE '%Refund Approval to Finance Team%'
              AND ProcessInstance.Status = 'Pending'
        ];
        
        Set<Id> targetIds = new Set<Id>();
        for (ProcessInstanceWorkitem item : workItems) {
            if (item.ProcessInstance.TargetObjectId != null && 
                String.valueOf(item.ProcessInstance.TargetObjectId).startsWith(supportTicketPrefix)) {
                targetIds.add(item.ProcessInstance.TargetObjectId);
            }
        }
        
        if (targetIds.isEmpty()) return result;
        
        // 3. Query the related Support Tickets actively in the process
        List<Support_Ticket__c> tickets = [
            SELECT Id, Name, Priority__c, CreatedDate, 
                   Order__r.Name, Customer__r.Name, Restaurant__r.Name
            FROM Support_Ticket__c
            WHERE Id IN :targetIds
            ORDER BY CreatedDate ASC
        ];
        
        for (Support_Ticket__c t : tickets) {
            RefundItemWrapper wrapper = new RefundItemWrapper();
            wrapper.Id = t.Id;
            wrapper.Name = t.Name;
            wrapper.OrderNumber = t.Order__r != null ? t.Order__r.Name : '';
            wrapper.CustomerName = t.Customer__r != null ? t.Customer__r.Name : '';
            wrapper.RestaurantName = t.Restaurant__r != null ? t.Restaurant__r.Name : '';
            wrapper.Priority = t.Priority__c;
            wrapper.CreatedDate = t.CreatedDate;
            result.add(wrapper);
        }
        
        return result;
    }

    @AuraEnabled
    public static RefundDetailWrapper getRefundDetails(Id ticketId) {
        validatePermission();
        
        Support_Ticket__c ticket = [
            SELECT Id, Name, Issue_Type__c, Customer_Issue_Count__c, Investigation_Notes__c, 
                   Recommended_Refund_Amount__c,
                   Order__c, Order__r.Name, Order__r.Payment_Status__c, Order__r.Order_Total__c, Order__r.Credits_Used__c,
                   Customer__r.Name, Restaurant__r.Name, Delivery_Agent__r.Name
            FROM Support_Ticket__c
            WHERE Id = :ticketId
            LIMIT 1
        ];
        
        RefundDetailWrapper wrap = new RefundDetailWrapper();
        wrap.TicketNumber = ticket.Name;
        
        // Section 1
        if (ticket.Order__c != null) {
            wrap.OrderNumber = ticket.Order__r.Name;
            wrap.PaymentStatus = ticket.Order__r.Payment_Status__c;
            wrap.OrderTotal = ticket.Order__r.Order_Total__c;
            wrap.CreditsUsed = ticket.Order__r.Credits_Used__c;
        }
        
        // Section 2
        wrap.CustomerName = ticket.Customer__r != null ? ticket.Customer__r.Name : '';
        wrap.RestaurantName = ticket.Restaurant__r != null ? ticket.Restaurant__r.Name : '';
        wrap.DeliveryAgent = ticket.Delivery_Agent__r != null ? ticket.Delivery_Agent__r.Name : '';
        
        // Section 3
        wrap.IssueType = ticket.Issue_Type__c;
        wrap.CustomerIssueCount = ticket.Customer_Issue_Count__c != null ? Integer.valueOf(ticket.Customer_Issue_Count__c) : 0;
        wrap.InvestigationNotes = ticket.Investigation_Notes__c;
        
        // Pre-fill
        wrap.RecommendedRefundAmount = ticket.Recommended_Refund_Amount__c;

        return wrap;
    }

    @AuraEnabled
    public static void approveRefund(Id ticketId, Decimal amount, String notes) {
        validatePermission();
        
        try {
            // Retrieve Ticket and Order to perform updates
            Support_Ticket__c ticket = [
                SELECT Id, Order__c 
                FROM Support_Ticket__c 
                WHERE Id = :ticketId 
                LIMIT 1
            ];
            
            // 1. Process standard Approval (if it's in a standard Approval Process)
            List<ProcessInstanceWorkitem> workItems = [
                SELECT Id 
                FROM ProcessInstanceWorkitem 
                WHERE ProcessInstance.TargetObjectId = :ticketId 
                  AND ProcessInstance.ProcessDefinition.Name LIKE '%Refund Approval to Finance Team%'
                  AND ProcessInstance.Status = 'Pending'
                LIMIT 1
            ];
            
            if (!workItems.isEmpty()) {
                Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
                req.setComments(notes);
                req.setAction('Approve');
                req.setWorkitemId(workItems[0].Id);
                Approval.process(req);
            } else {
                // If it isn't in an approval process, we fall back to updating the status field manually
                ticket.Finance_Approval_Status__c = 'APPROVED';
            }
            
        } catch (Exception e) {
            throw new AuraHandledException('Failed to approve refund: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void rejectRefund(Id ticketId, String notes) {
        validatePermission();
        
        try {
            // 1. Process standard Approval Rejection
            List<ProcessInstanceWorkitem> workItems = [
                SELECT Id 
                FROM ProcessInstanceWorkitem 
                WHERE ProcessInstance.TargetObjectId = :ticketId 
                  AND ProcessInstance.ProcessDefinition.Name LIKE '%Refund Approval to Finance Team%'
                  AND ProcessInstance.Status = 'Pending'
                LIMIT 1
            ];
            
            if (!workItems.isEmpty()) {
                Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
                req.setComments(notes);
                req.setAction('Reject');
                req.setWorkitemId(workItems[0].Id);
                Approval.process(req);
            } 
            
            // 2. Update Ticket Status
            Support_Ticket__c ticket = new Support_Ticket__c(Id = ticketId);
            // Updating standard finance status assuming the approval process might not catch it 
            // or if we rely purely on fields. Best practice is to set them safely.
            ticket.Finance_Approval_Status__c = 'REJECTED'; 
            ticket.Ticket_Status__c = 'WAITING_FOR_CUSTOMER'; // Typical rejection status back to support/customer
            ticket.Internal_Notes__c = notes; // Store rejection notes
            update ticket;
            
        } catch (Exception e) {
            throw new AuraHandledException('Failed to reject refund: ' + e.getMessage());
        }
    }

    // --- WRAPPERS ---
    
    public class RefundItemWrapper {
        @AuraEnabled public Id Id { get; set; }
        @AuraEnabled public String Name { get; set; }
        @AuraEnabled public String OrderNumber { get; set; }
        @AuraEnabled public String CustomerName { get; set; }
        @AuraEnabled public String RestaurantName { get; set; }
        @AuraEnabled public String Priority { get; set; }
        @AuraEnabled public DateTime CreatedDate { get; set; }
    }

    public class RefundDetailWrapper {
        @AuraEnabled public String TicketNumber { get; set; }
        @AuraEnabled public String OrderNumber { get; set; }
        @AuraEnabled public String PaymentStatus { get; set; }
        @AuraEnabled public Decimal OrderTotal { get; set; }
        @AuraEnabled public Decimal CreditsUsed { get; set; }
        @AuraEnabled public String CustomerName { get; set; }
        @AuraEnabled public String RestaurantName { get; set; }
        @AuraEnabled public String DeliveryAgent { get; set; }
        @AuraEnabled public String IssueType { get; set; }
        @AuraEnabled public Integer CustomerIssueCount { get; set; }
        @AuraEnabled public String InvestigationNotes { get; set; }
        @AuraEnabled public Decimal RecommendedRefundAmount { get; set; }
    }
}
