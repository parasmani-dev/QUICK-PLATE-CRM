public with sharing class OperationsCommandCenterController {
    
    // Wrapper class to hold all dashboard metrics in one response
    public class DashboardData {
        // Top KPI Cards
        @AuraEnabled public Integer kpiTicketsResolved {get;set;}
        @AuraEnabled public Decimal kpiRefundAmount {get;set;}
        @AuraEnabled public Integer kpiNewRestaurants {get;set;}
        @AuraEnabled public Integer kpiActiveOrders {get;set;}
        
        // Support Analytics
        @AuraEnabled public Integer supportTicketsCreatedThisWeek {get;set;}
        @AuraEnabled public Integer supportTicketsResolvedThisWeek {get;set;}
        @AuraEnabled public String supportAvgResolutionTime {get;set;}
        @AuraEnabled public Integer supportPendingTickets {get;set;}
        
        // Finance Impact
        @AuraEnabled public Integer financeRefundsApproved {get;set;}
        @AuraEnabled public Decimal financeTotalRefundAmount {get;set;}
        @AuraEnabled public Integer financePaymentCount {get;set;}
        @AuraEnabled public Integer financeFailedPayments {get;set;}
        
        // Restaurant Growth
        @AuraEnabled public Integer restNewWeekly {get;set;}
        @AuraEnabled public Integer restPendingApprovals {get;set;}
        @AuraEnabled public Integer restApproved {get;set;}
        @AuraEnabled public Integer restRejected {get;set;}
        
        // Alerts
        @AuraEnabled public List<String> operationalAlerts {get;set;}
    }

    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData() {
        DashboardData data = new DashboardData();
        data.operationalAlerts = new List<String>();

        try {
            // ==========================================
            // 1. SUPPORT TICKETS ANALYTICS
            // ==========================================
            List<Support_Ticket__c> ticketsThisWeek = [
                SELECT Id, Ticket_Status__c, CreatedDate, Closed_At__c 
                FROM Support_Ticket__c 
                WHERE CreatedDate = THIS_WEEK OR Closed_At__c = THIS_WEEK
            ];
            
            Integer createdThisWeek = 0;
            Integer resolvedThisWeek = 0;
            Integer pendingCount = 0;
            
            Long totalResolutionTimeMillis = 0;
            Integer resolvedWithTimeCount = 0;
            
            Datetime startOfWeek = Datetime.newInstance(System.today().toStartOfWeek(), Time.newInstance(0,0,0,0));
            
            for(Support_Ticket__c tkt : ticketsThisWeek) {
                // Determine if created this week (using standard CreatedDate)
                if (tkt.CreatedDate >= startOfWeek) {
                    createdThisWeek++;
                }
                
                // Determine if resolved this week
                if (tkt.Ticket_Status__c == 'RESOLVED' || tkt.Ticket_Status__c == 'CLOSED') {
                    if (tkt.Closed_At__c != null && tkt.Closed_At__c >= startOfWeek) {
                        resolvedThisWeek++;
                    }
                    if (tkt.Closed_At__c != null) {
                        // Calculate resolution time diff in millis
                        totalResolutionTimeMillis += (tkt.Closed_At__c.getTime() - tkt.CreatedDate.getTime());
                        resolvedWithTimeCount++;
                    }
                } else {
                    pendingCount++;
                }
            }
            
            data.supportTicketsCreatedThisWeek = createdThisWeek;
            data.supportTicketsResolvedThisWeek = resolvedThisWeek;
            data.supportPendingTickets = pendingCount;
            
            if (resolvedWithTimeCount > 0) {
                Long avgMillis = totalResolutionTimeMillis / resolvedWithTimeCount;
                Long avgMinutes = avgMillis / (1000 * 60);
                Long avgHours = avgMinutes / 60;
                Long remainingMinutes = Math.mod(avgMinutes, 60);
                data.supportAvgResolutionTime = avgHours + 'h ' + remainingMinutes + 'm';
            } else {
                data.supportAvgResolutionTime = '0h 0m';
            }
            
            data.kpiTicketsResolved = resolvedThisWeek;

            // ==========================================
            // 2. FINANCE IMPACT
            // ==========================================
            List<Payment_Transaction__c> transactions = [
                SELECT Id, Transaction_Type__c, Transaction_Status__c, Amount__c
                FROM Payment_Transaction__c
                // Add WHERE clause for range if needed, fetching all recent for simplicity
                WHERE CreatedDate = THIS_MONTH
            ];
            
            Integer refundsApproved = 0;
            Decimal totalRefundAmount = 0;
            Integer paymentCount = 0;
            Integer failedPayments = 0;
            
            for(Payment_Transaction__c txn : transactions) {
                if(txn.Transaction_Type__c == 'REFUND') {
                    if(txn.Transaction_Status__c == 'REFUND_SUCCESS' || txn.Transaction_Status__c == 'SUCCESS') {
                        refundsApproved++;
                        if(txn.Amount__c != null) totalRefundAmount += txn.Amount__c;
                    }
                } else if(txn.Transaction_Type__c == 'PAYMENT') {
                    if(txn.Transaction_Status__c == 'SUCCESS') {
                        paymentCount++;
                    } else if(txn.Transaction_Status__c == 'FAILED') {
                        failedPayments++;
                    }
                }
            }
            
            data.financeRefundsApproved = refundsApproved;
            data.financeTotalRefundAmount = totalRefundAmount;
            data.financePaymentCount = paymentCount;
            data.financeFailedPayments = failedPayments;
            
            data.kpiRefundAmount = totalRefundAmount;

            // ==========================================
            // 3. RESTAURANT ONBOARDING
            // ==========================================
            List<Restaurant__c> restaurants = [
                SELECT Id, Onboarding_Status__c, CreatedDate
                FROM Restaurant__c
            ];
            
            Integer restNew = 0;
            Integer restPending = 0;
            Integer restAppr = 0;
            Integer restRej = 0;
            
            Datetime startOfWeekRest = Datetime.newInstance(System.today().toStartOfWeek(), Time.newInstance(0,0,0,0));
            
            for(Restaurant__c rest : restaurants) {
                if (rest.CreatedDate >= startOfWeekRest) {
                    restNew++;
                }
                
                if (rest.Onboarding_Status__c == 'DRAFT') {
                    restPending++;
                } else if (rest.Onboarding_Status__c == 'ACTIVE') {
                    restAppr++;
                } else if (rest.Onboarding_Status__c == 'SUSPENDED') {
                    restRej++;
                }
            }
            
            data.restNewWeekly = restNew;
            data.restPendingApprovals = restPending;
            data.restApproved = restAppr;
            data.restRejected = restRej;
            
            data.kpiNewRestaurants = restNew;

            // ==========================================
            // 4. ACTIVE ORDERS KPI
            // ==========================================
            Integer activeOrders = [
                SELECT COUNT()
                FROM Order__c
                WHERE Order_Status__c NOT IN ('DELIVERED', 'CANCELLED')
            ];
            data.kpiActiveOrders = activeOrders;

            // ==========================================
            // 5. OPERATIONAL ALERTS LOGIC
            // ==========================================
            if (refundsApproved > 20 || totalRefundAmount > 20000) {
                data.operationalAlerts.add('🚨 High Refund Spike: Abnormal refund volume detected this month.');
            }
            if (pendingCount > 50) {
                data.operationalAlerts.add('⚠️ High Ticket Queue: Over 50 support tickets currently pending.');
            }
            if (restPending > 15) {
                data.operationalAlerts.add('⏳ Delayed Approvals: ' + restPending + ' restaurant onboardings are stuck in Draft status.');
            }
            if (failedPayments > 10) {
                data.operationalAlerts.add('📛 Payment Gateway Warning: Abnormally high failed payment transactions observed.');
            }
            
            if (data.operationalAlerts.isEmpty()) {
                data.operationalAlerts.add('✅ All operations running smoothly.');
            }

        } catch (Exception e) {
            System.debug('Error in Operations Command Center: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error fetching dashboard data: ' + e.getMessage());
        }
        
        return data;
    }
}
