/**
* qwic
* @author           Sebastian Ortiz href=<sortiz@qwic.com>
* Proyect:         	QWIC Dealer Portal 
* Description:      test class for GetListBatteries rest webservice.
* Changes (Version)
* -------------------------------------
*            No.    Date            Autor                           Description        
*            ----   ----------      ---------------------------     -------------    
* @version   1.0    29-01-2019     Sebastián Ortiz  (SO)           Class Created 
***********************************************************************************************************************/
@isTest
private class GetListBatteries_tst
{
	/**
	* @author Sebastián Ortiz (SO)
	* @date 29-01-2019
	* @description 	Method to create the test data
	**/
	@testSetup
	public static void LoadData()
	{
		Product2 testbattery 		= new Product2(
			Name 					= 'Testbattery',
			ProductCode 			= 'BA0001',
			Description 			= 'Accu 375Wh PREM FRONT MOTOR',
			EAN_Code__c 			= '1234567',
			Producttype__c 			= 'Accu',
			Sneak_preview__c 		= true,
			PSerie__c 				= 'Premium',
			PModel__c 				= 'Battery',
			PVersion__c 			= 'FRONT MOTOR',
			PSize__c 				= '375WH',
			PColor__c 				= 'Other',
			InCollection__c 		= true,
			BikeInOrder__c 			= true
		);
		insert testbattery;

		Pricebook2 standardPricebook = new Pricebook2(Id = Test.getStandardPricebookId(),IsActive = true);
		Update standardPricebook;

		PriceBookEntry pbbattery 		= new PriceBookEntry(
			Product2Id 					= testbattery.Id,
			PriceBook2Id 				= standardPricebook.Id,
			UnitPrice 					= 10.0,
			IsActive 					= true
		);
		insert pbbattery;

		
	}

	/**
	* @author Sebastián Ortiz (SO)
	* @date 29-01-2019
	* @description test method to simulate when: there no list of batteries
	**/
	@isTest
	public static void TestONE()
	{
		Product2 objBatterie 	= [SELECT Id FROM Product2 WHERE ProductCode = 'BA0001' LIMIT 1];
		delete objBatterie;
		RestRequest req 		= new RestRequest(); 
		RestResponse res 		= new RestResponse();
		req.requestURI 			= '/services/apexrest/getBatteries/';
		req.httpMethod 			= 'GET';
		RestContext.request 	= req;
		RestContext.response 	= res;
		
		Test.startTest();
			GetListBatteries_ws.doGet();
			System.assertEquals(404, res.statusCode, 'if 404 error that means the method return no records');
		Test.stopTest();
	}

	/**
	* @author Sebastián Ortiz (SO)
	* @date 29-01-2019
	* @description test method to simulate when: there is a list of batteries
	**/
	@isTest
	public static void TestTWO()
	{
		RestRequest req 		= new RestRequest(); 
		RestResponse res 		= new RestResponse();
		req.requestURI 			= '/services/apexrest/getBatteries/';
		req.httpMethod 			= 'GET';
		RestContext.request 	= req;
		RestContext.response 	= res;
		
		Test.startTest();
			GetListBatteries_ws.doGet();
			System.assertEquals(200, res.statusCode, 'if 200 status, then the rest is working');
		Test.stopTest();
	}
}