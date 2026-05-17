@RestResource(urlMapping='/wallet/balance')
global without sharing class CustomerWalletController {

    global class WalletResponse {
        public Boolean success;
        public Decimal availableBalance;
        public String message;
    }

    @HttpGet
    global static WalletResponse getBalance() {

        WalletResponse res =
            new WalletResponse();

        try {

            RestRequest req =
                RestContext.request;

            // =====================================
            // READ AUTH HEADER
            // =====================================

            String authHeader =
                req.headers.get('Authorization');

            if (
                String.isBlank(authHeader) ||
                !authHeader.startsWith('Bearer ')
            ) {

                return error(
                    res,
                    'Authentication required.',
                    401
                );
            }

            // =====================================
            // EXTRACT FIREBASE TOKEN
            // =====================================

            String idToken =
                authHeader.replace(
                    'Bearer ',
                    ''
                ).trim();

            // =====================================
            // VERIFY TOKEN
            // =====================================

            String firebaseUid =
                FirebaseAuthUtil.verifyToken(
                    idToken
                );

            if (
                String.isBlank(firebaseUid)
            ) {

                return error(
                    res,
                    'Invalid authentication.',
                    401
                );
            }

            // =====================================
            // FIND CUSTOMER
            // =====================================

            List<Customer__c> customers = [

                SELECT Id

                FROM Customer__c

                WHERE Firebase_UID__c =
                    :firebaseUid

                LIMIT 1
            ];

            if (customers.isEmpty()) {

                return error(
                    res,
                    'Customer not found.',
                    404
                );
            }

            Id customerId =
                customers[0].Id;

            // =====================================
            // FETCH WALLET
            // =====================================

            List<Customer_Credit__c> credits = [

                SELECT Id,
                       Available_Amount__c

                FROM Customer_Credit__c

                WHERE Customer__c =
                    :customerId

                LIMIT 1
            ];

            Decimal balance = 0;

            if (!credits.isEmpty()) {

                balance =
                    credits[0]
                    .Available_Amount__c;
            }

            res.success = true;

            res.availableBalance =
                balance == null
                ? 0
                : balance;

            RestContext.response.statusCode =
                200;

            return res;

        }
        catch (Exception e) {

            System.debug(
                'Wallet Error: '
                + e.getMessage()
            );

            return error(
                res,
                'Wallet fetch failed.',
                500
            );
        }
    }

    // =====================================
    // ERROR HANDLER
    // =====================================

    private static WalletResponse error(

        WalletResponse res,
        String msg,
        Integer code

    ) {

        res.success = false;

        res.message = msg;

        RestContext.response.statusCode =
            code;

        return res;
    }
}