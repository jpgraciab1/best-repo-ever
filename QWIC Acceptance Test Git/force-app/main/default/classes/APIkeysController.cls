global with sharing class APIkeysController {

    public APIkeysController(ApexPages.StandardController controller) {
        //get account, I put all hidden inputfields in VF page to avoid more database queries
        this.dealer = (Account)controller.getRecord();
        Schema.DescribeFieldResult ServicesObject = APIKey__c.Service__c.getDescribe();
        List<Schema.PicklistEntry> PicklistEntries = ServicesObject.getPicklistValues();
        for (Schema.PicklistEntry picklistEntry : PicklistEntries) { 
            this.Services.add(picklistEntry.getValue());
        }
    }
    
    //this is the dealer id  
    public final Account dealer;
    
    //service choosen
    public String Service {get;set;}
    
    //services in picklist on APIKey object
    public List<String> Services {  
        get{   
            if (Services == null) {
                Services = new List<String>();
            }   
            return Services;
        }
        set;
    }
    
    public void createPrivateKey() {

        Blob GeneratedPrivateKey = Crypto.generateAesKey(256);
        if (dealer.PrivateKey__c == null || dealer.PrivateKey__c == '') {
            dealer.PrivateKey__c = EncodingUtil.base64encode(GeneratedPrivateKey);
            update dealer;     
        } 

    }
    
    public void createAPIKey() {

        Blob StoredPrivateKey = EncodingUtil.base64decode(dealer.PrivateKey__c);
        DateTime DateTimeCreated = Datetime.now();
        Long EpochCreated = DateTimeCreated.getTime();
        Blob ServiceCreatedDateTime = EncodingUtil.base64decode(Service + '+' + String.valueOf(EpochCreated));
        Blob BlobAPIKey = Crypto.encryptWithManagedIV('AES256', StoredPrivateKey, ServiceCreatedDateTime);
        APIKey__c APIKey = new APIKey__c();
        APIKey.Account__c = dealer.Id;
        APIKey.Service__c = Service;
        APIKey.Key__c = EncodingUtil.base64encode(BlobAPIKey);
        APIKey.DateTimeCreated__c = DateTimeCreated;
        insert APIKey;
        

    }

}