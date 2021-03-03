// ===========================================================================
// Object: ManageAccountsController
// Company: Sun Life
// Author: Reid Beckett
// Purpose: Controller to manage the Financial Services Account Listing component
// ===========================================================================
// Changes: 2021-03-03 Reid Beckett
//           Class created
// ===========================================================================
public inherited sharing class ManageAccountsController {
    //This method is used by the wired list in the LWC component to fetch 
    //the Financial Services accounts list
    //By default, the return is sorted by Name ascending
    @AuraEnabled(cacheable=true)
    public static List<Account> getAccounts() {
        return [
            SELECT Id, Name, Industry, OwnerId, Owner.Name, Phone, Website, AnnualRevenue
            FROM Account
            WHERE Industry = 'Financial Services'
            WITH SECURITY_ENFORCED
            ORDER BY Name ASC
        ];
    }

    //This method is used to support inline editing
    //data will be received as a list of data
    //each record in the data is a Map, with key being the field name as defined in the LWC component and the value
    //being the updated value from the inline edit cell
    //Special treatment is given to Owner since we are displaying the Owner Name on the front end component,
    //we need to lookup the Owner ID value by name to assign that to the Account > OwnerId field.
    //The owner name is provided in the ownerName field in the LWC datatable, hence we expect it in the record map received
    @AuraEnabled
    public static string updateAccounts(Object data) {
        //Collect the owner names, will only be present if some owners have been modified        
        Set<String> ownerNames = new Set<String>();
        for(Object record : (List<Object>)data) {
            Map<Object,Object> recordMap = (Map<Object,Object>)record;
            if(recordMap.containsKey('ownerName')) {
                ownerNames.add((String)recordMap.get('ownerName'));
            }
        }

        //Create a map of owner Id by account Id
        Map<Id, Id> ownerIdsByRecordId = new Map<Id,Id>();
        if(!ownerNames.isEmpty()) {
            Map<String,Id> ownersMap = new Map<String, Id>();
            //query the User table by name
            for(User u : [SELECT Id, Name FROM User WHERE Name IN :ownerNames]) {
                ownersMap.put(u.Name, u.Id);
            }

            //loop through the received data to match up Account Id to Owner Id
            for(Object record : (List<Object>)data) {
                system.debug(record);
                Map<Object,Object> recordMap = (Map<Object,Object>)record;
                if(recordMap.containsKey('Id')) {
                    Id accountId = (Id)recordMap.get('Id');
                    if(recordMap.containsKey('ownerName')) {
                        String ownerName = (String)recordMap.get('ownerName');
                        if(!ownersMap.containsKey(ownerName)) {
                            throw new AuraHandledException(ownerName + ' is an invalid user name');
                        }else{
                            ownerIdsByRecordId.put(accountId, ownersMap.get(ownerName));
                        }
                    }
                }
            }
        }

        //Now deserialize the data as accounts list
        //Note this will not include the OwnerId
        List<Account> accountsForUpdate = (List<Account>) JSON.deserialize(
            JSON.serialize(data),
            List<Account>.class
        );

        //modify the OwnerId for each record where the owner was modified
        for(Account acct : accountsForUpdate){
            if(ownerIdsByRecordId.containsKey(acct.Id)) acct.OwnerId = ownerIdsByRecordId.get(acct.Id);
        }

        //finally perform the DML update and return a success message
        update accountsForUpdate;
        return 'Success: accounts updated successfully';
    }

}