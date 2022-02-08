// ===========================================================================
// Object: Test_ManageAccountsController
// Company: Sun Life
// Author: Reid Beckett
// Purpose: Test coverage for the ManageAccountsController apex class
// ===========================================================================
// Changes: 2021-03-03 Reid Beckett
//           Class created
// ===========================================================================
@isTest
public class Test_ManageAccountsController {
    //test setup: create 10 accounts, and a test user with the test profile
    @TestSetup
    static void setUp(){
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Apple', Industry = 'Financial Services'),
            new Account(Name = 'Microsoft', Industry = 'Financial Services'),
            new Account(Name = 'Tesla', Industry = 'Financial Services'),
            new Account(Name = 'Square', Industry = 'Financial Services'),
            new Account(Name = 'Oracle', Industry = 'Financial Services'),
            new Account(Name = 'Facebook', Industry = 'Financial Services'),
            new Account(Name = 'Twitter', Industry = 'Financial Services'),
            new Account(Name = 'Alphabet', Industry = 'Financial Services'),
            new Account(Name = 'Amazon', Industry = 'Financial Services'),
            new Account(Name = 'Samsung', Industry = 'Financial Services')
        };

        insert accounts;

        createTestUser();
    }

    //create a test user
    private static User createTestUser(){
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Sun Life User'];
        User user = new User();
        user.Username = 'test_user'+DateTime.now().getTime()+'@example.com';
        user.FirstName = 'Test';
        user.LastName = 'SunLife';
        user.ProfileId = p.Id;
        user.Alias = 'tst';
        user.Email = 'test_user@example.com';
        user.CommunityNickname = 'Test_nick_name';
        user.TimeZoneSidKey = 'GMT';
        user.LocaleSidKey = 'en_US';
        user.LanguageLocaleKey = 'en_US';
        user.EmailEncodingKey = 'ISO-8859-1';
        insert user;
        return user;
    }

    //Test retrieving the accounts
    @isTest
    static void testGetAccounts(){
        List<Account> accounts = ManageAccountsController.getAccounts();
        system.assertEquals(10, accounts.size());
    }

    //Test updating the accounts, changing an owner
    @isTest
    static void testUpdateAccount(){
        Account acct = ManageAccountsController.getAccounts().get(0);
        List<Map<Object,Object>> data = new List<Map<Object,Object>>();
        data.add(new Map<Object,Object>{
            'Id' => acct.Id,
            'ownerName' => 'Test SunLife'
        });

        system.assertEquals('result', ManageAccountsController.updateAccounts(data));
    }

    //Test updating the accounts exception, changing an owner to a user that does not exist
    @isTest
    static void testUpdateAccountException(){
        Account acct = ManageAccountsController.getAccounts().get(0);
        List<Map<Object,Object>> data = new List<Map<Object,Object>>();
        data.add(new Map<Object,Object>{
            'Id' => acct.Id,
            'ownerName' => 'UserNotFound'
        });

        try {
            ManageAccountsController.updateAccounts(data);
            system.assertNotEquals(1,1,'This should have thrown an exception');
        }catch(Exception e) {

        }
    }
}