public with sharing class RestaurantManagerController {

    public class KPIData {
        @AuraEnabled public Integer totalRestaurants { get; set; }
        @AuraEnabled public Integer activeRestaurants { get; set; }
        @AuraEnabled public Integer inactiveRestaurants { get; set; }
        @AuraEnabled public Integer pendingApprovals { get; set; }
        @AuraEnabled public Integer restaurantsWithIssues { get; set; }
    }

    public class TopRestaurant {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public Integer totalOrders { get; set; }
        @AuraEnabled public Integer completedOrders { get; set; }
        @AuraEnabled public Decimal slaPerformance { get; set; }
    }

    public class ProblematicRestaurant {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public Integer openTicketsCount { get; set; }
        @AuraEnabled public String riskLevel { get; set; }
        @AuraEnabled public List<TicketDetail> tickets { get; set; }
    }

    public class TicketDetail {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String issueType { get; set; }
        @AuraEnabled public String customerInvestigation { get; set; }
        @AuraEnabled public String resolutionNotes { get; set; }
    }

    public class RecentApproval {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Datetime createdDate { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDashboardData() {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            // 1. KPI Data
            KPIData kpi = new KPIData();
            kpi.totalRestaurants = [SELECT COUNT() FROM Restaurant__c];
            
            // Assuming Is_Active__c and Is_Temporarily_Closed__c exist. If they don't, this will throw an exception,
            // which should be fixed in the org's fields, or updated here. For now we follow the user's explicit schema.
            // Using a dynamic string to avoid compile-time errors if the user hasn't pulled metadata locally for Is_Active__c.
            String activeQuery = 'SELECT COUNT() FROM Restaurant__c WHERE Is_Active__c = true AND Is_Temporarily_Closed__c = false';
            kpi.activeRestaurants = Database.countQuery(activeQuery);
            
            String inactiveQuery = 'SELECT COUNT() FROM Restaurant__c WHERE Is_Active__c = false OR Is_Temporarily_Closed__c = true';
            kpi.inactiveRestaurants = Database.countQuery(inactiveQuery);
            
            kpi.pendingApprovals = [SELECT COUNT() FROM Restaurant__c WHERE Onboarding_Status__c IN ('Pending', 'Draft')];
            
            // Restaurants with Issues: distinct restaurants from Support_Ticket__c
            AggregateResult[] issueAggs = [SELECT Restaurant__c FROM Support_Ticket__c WHERE Ticket_Status__c NOT IN ('RESOLVED', 'CLOSED') GROUP BY Restaurant__c];
            kpi.restaurantsWithIssues = issueAggs.size();
            
            result.put('kpis', kpi);

            // 2. Top Performing Restaurants
            // SOQL doesn't support CASE WHEN inside aggregations, so we group by restaurant and status.
            List<AggregateResult> orderStats = [
                SELECT Restaurant__c restId, Restaurant__r.Name name, Restaurant__r.Owner.Name owner, Order_Status__c status, COUNT(Id) cnt
                FROM Order__c
                GROUP BY Restaurant__c, Restaurant__r.Name, Restaurant__r.Owner.Name, Order_Status__c
            ];
            
            Map<Id, TopRestaurant> topRestaurantsMap = new Map<Id, TopRestaurant>();
            for(AggregateResult ar : orderStats) {
                Id restId = (Id)ar.get('restId');
                String status = (String)ar.get('status');
                Integer cnt = (Integer)ar.get('cnt');
                
                if(!topRestaurantsMap.containsKey(restId)) {
                    TopRestaurant tr = new TopRestaurant();
                    tr.id = restId;
                    tr.name = (String)ar.get('name');
                    tr.ownerName = (String)ar.get('owner');
                    tr.totalOrders = 0;
                    tr.completedOrders = 0;
                    topRestaurantsMap.put(restId, tr);
                }
                
                TopRestaurant ptr = topRestaurantsMap.get(restId);
                ptr.totalOrders += cnt;
                if(status == 'DELIVERED' || status == 'COMPLETED') {
                    ptr.completedOrders += cnt;
                }
            }
            
            List<TopRestaurant> sortedTopRests = topRestaurantsMap.values();
            // Sort by total orders in Apex (Bubble sort or simple logic)
            for(Integer i=0; i<sortedTopRests.size(); i++) {
                for(Integer j=i+1; j<sortedTopRests.size(); j++) {
                    if(sortedTopRests[j].totalOrders > sortedTopRests[i].totalOrders) {
                        TopRestaurant temp = sortedTopRests[i];
                        sortedTopRests[i] = sortedTopRests[j];
                        sortedTopRests[j] = temp;
                    }
                }
            }
            // limit to top 5
            List<TopRestaurant> finalTopRests = new List<TopRestaurant>();
            for(Integer i=0; i<sortedTopRests.size() && i<5; i++) {
                TopRestaurant top = sortedTopRests[i];
                if(top.totalOrders > 0) {
                    top.slaPerformance = (Decimal)top.completedOrders / top.totalOrders * 100.0;
                } else {
                    top.slaPerformance = 0;
                }
                finalTopRests.add(top);
            }
            result.put('topRestaurants', finalTopRests);

            // 3. Problematic Restaurants
            List<Support_Ticket__c> openTickets = [
                SELECT Id, Restaurant__c, Restaurant__r.Name, Restaurant__r.Owner.Name, 
                       Issue_Type__c, Investigation_Notes__c, Resolution_Notes__c
                FROM Support_Ticket__c
                WHERE Ticket_Status__c NOT IN ('RESOLVED', 'CLOSED') AND Restaurant__c != null
                ORDER BY CreatedDate DESC
            ];
            
            Map<Id, ProblematicRestaurant> problemMap = new Map<Id, ProblematicRestaurant>();
            for(Support_Ticket__c st : openTickets) {
                if(!problemMap.containsKey(st.Restaurant__c)) {
                    ProblematicRestaurant pr = new ProblematicRestaurant();
                    pr.id = st.Restaurant__c;
                    pr.name = st.Restaurant__r.Name;
                    pr.ownerName = st.Restaurant__r.Owner.Name;
                    pr.openTicketsCount = 0;
                    pr.tickets = new List<TicketDetail>();
                    problemMap.put(st.Restaurant__c, pr);
                }
                
                ProblematicRestaurant pr = problemMap.get(st.Restaurant__c);
                pr.openTicketsCount++;
                
                TicketDetail td = new TicketDetail();
                td.id = st.Id;
                td.issueType = st.Issue_Type__c != null ? st.Issue_Type__c : 'General Issue';
                td.customerInvestigation = st.Investigation_Notes__c != null ? st.Investigation_Notes__c : 'No notes provided.';
                td.resolutionNotes = st.Resolution_Notes__c != null ? st.Resolution_Notes__c : 'Pending resolution.';
                
                // Add up to 5 tickets for display sample
                if (pr.tickets.size() < 5) {
                    pr.tickets.add(td);
                }
            }
            
            List<ProblematicRestaurant> finalizedProbRests = new List<ProblematicRestaurant>();
            for(ProblematicRestaurant pr : problemMap.values()) {
                if(pr.openTicketsCount > 10) {
                    pr.riskLevel = 'HIGH';
                } else if(pr.openTicketsCount > 4) {
                    pr.riskLevel = 'MEDIUM';
                } else {
                    pr.riskLevel = 'LOW';
                }
                finalizedProbRests.add(pr);
            }
            
            // Sort to show highest count first
            for(Integer i=0; i<finalizedProbRests.size(); i++) {
                for(Integer j=i+1; j<finalizedProbRests.size(); j++) {
                    if(finalizedProbRests[j].openTicketsCount > finalizedProbRests[i].openTicketsCount) {
                        ProblematicRestaurant temp = finalizedProbRests[i];
                        finalizedProbRests[i] = finalizedProbRests[j];
                        finalizedProbRests[j] = temp;
                    }
                }
            }
            result.put('problemRestaurants', finalizedProbRests);

            // 4. Recent Restaurant Approvals
            List<Restaurant__c> recents = [
                SELECT Id, Name, Owner.Name, Onboarding_Status__c, CreatedDate
                FROM Restaurant__c
                ORDER BY CreatedDate DESC
                LIMIT 5
            ];
            
            List<RecentApproval> recentList = new List<RecentApproval>();
            for(Restaurant__c r : recents) {
                RecentApproval ra = new RecentApproval();
                ra.id = r.Id;
                ra.name = r.Name;
                ra.ownerName = r.Owner.Name;
                ra.status = r.Onboarding_Status__c != null ? r.Onboarding_Status__c : 'N/A';
                ra.createdDate = r.CreatedDate;
                recentList.add(ra);
            }
            result.put('recentApprovals', recentList);

        } catch(Exception e) {
            throw new AuraHandledException('Dashboard Data Error: ' + e.getMessage());
        }
        
        return result;
    }
}