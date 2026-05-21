public without sharing class FirebaseAuthUtil {

    private static final String FIREBASE_API_KEY =
        'AIzaSyAeucTNcAromiBgbhjCQ_HTFFeNkcsK_X4';

    public static String verifyToken(
        String idToken
    ) {

        try {

            if (String.isBlank(idToken)) {

                System.debug(
                    'FirebaseAuthUtil: Token missing'
                );

                return null;
            }

            HttpRequest req =
                new HttpRequest();

            req.setEndpoint(

                'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key='
                + FIREBASE_API_KEY
            );

            req.setMethod('POST');

            req.setHeader(
                'Content-Type',
                'application/json'
            );

            req.setBody(

                JSON.serialize(

                    new Map<String, String>{
                        'idToken' => idToken
                    }
                )
            );

            Http http =
                new Http();

            HttpResponse res =
                http.send(req);

            System.debug(
                'Firebase Verify Status: '
                + res.getStatusCode()
            );

            System.debug(
                'Firebase Verify Response: '
                + res.getBody()
            );

            if (
                res.getStatusCode() != 200
            ) {

                return null;
            }

            Map<String, Object> result =

                (Map<String, Object>)
                JSON.deserializeUntyped(
                    res.getBody()
                );

            List<Object> users =

                (List<Object>)
                result.get('users');

            if (
                users == null ||
                users.isEmpty()
            ) {

                System.debug(
                    'FirebaseAuthUtil: No users found'
                );

                return null;
            }

            Map<String, Object> user =

                (Map<String, Object>)
                users[0];

            String firebaseUid =

                (String)
                user.get('localId');

            System.debug(
                'Firebase UID: '
                + firebaseUid
            );

            return firebaseUid;

        }
        catch (Exception e) {

            System.debug(
                'FirebaseAuthUtil ERROR: '
                + e.getMessage()
            );

            return null;
        }
    }
}