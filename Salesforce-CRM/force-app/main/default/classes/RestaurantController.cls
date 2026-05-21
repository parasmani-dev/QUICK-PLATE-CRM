@RestResource(urlMapping='/restaurant/list')
global without sharing class RestaurantController {

    global class RestaurantResponse {
        public String id;
        public String name;
        public String city;
        public Decimal avgPrepTime;
    }

    @HttpGet
    global static List<RestaurantResponse> getRestaurants() {

        List<RestaurantResponse> result = new List<RestaurantResponse>();

        try {

            List<Restaurant__c> restaurants = [
                SELECT Id,
                       Name,
                       City__c,
                       Avg_Prep_Time_Min__c
                FROM Restaurant__c
                WHERE Is_Active__c = true
                  AND Is_Temporarily_Closed__c = false
                ORDER BY Name ASC
                LIMIT 500
            ];

            for (Restaurant__c r : restaurants) {

                RestaurantResponse res = new RestaurantResponse();
                res.id = r.Id;
                res.name = r.Name;
                res.city = r.City__c;

                // ✅ Safe null handling
                res.avgPrepTime =
                    r.Avg_Prep_Time_Min__c == null
                    ? 0
                    : r.Avg_Prep_Time_Min__c;

                result.add(res);
            }

            return result;

        } catch (Exception e) {

            System.debug('Restaurant API Error: ' + e.getMessage());

            return new List<RestaurantResponse>(); // safe fallback
        }
    }
}