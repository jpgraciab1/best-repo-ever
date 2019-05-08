@RestResource(urlMapping='/update/*')
global with sharing class FactoryToolAPIUpdateController
{

	global class RelatedAsset
	{
		public String 	FrameNumber 			{get;set;}
		public String 	Part 					{get;set;}
		public String 	SerialNumber 			{get;set;}
		public String 	FirmwareVersion 		{get;set;}
		public String 	Status					{get;set;}
	}

	@HttpPost
	global static List<RelatedAsset> doPost()
	{
		//Method variables
		RestResponse res											= RestContext.response;
		RestRequest req 											= RestContext.request;
		String body 												= req.RequestBody.toString();
		List<String> asset_numbers 									= new List<String>();
		//deserialize body
		List<RelatedAsset> RelatedAssets 							= (List<RelatedAsset>) JSON.deserialize(body, List<RelatedAsset>.class);
		//to separate records into good ones and incomplete
		List<RelatedAsset> dropped_assets 							= new List<RelatedAsset>();
		List<RelatedAsset> kept_assets 								= new List<RelatedAsset>();
		//list to serialize into JSON and sent to Hyena
		List<RelatedAsset> LstReturn								= new List<RelatedAsset>();
		//to create log
		IntegrationLog__c objLog 									= new IntegrationLog__c();
		objLog.RunningUser__c 										= UserInfo.getUserId();
		objLog.RequestedDateTime__c 								= System.now();
		objLog.Request__c 											= body;
		//to look for duplicate records on JSON
		Set<String> setDupOnJSON 									= new Set<String>();
		//maps for factory asset and relationship.
		Map<String,FactoryAsset__c> assets_map 						= new Map<String,FactoryAsset__c>();
		Map<String,Map<String,FactoryAsset__c>> Bike_Parts_map 		= new Map<String,Map<String,FactoryAsset__c>>();
		//List to upsert parts or replacement.
		List<FactoryAsset__c> upsert_assets = new List<FactoryAsset__c>();
		//Map for log
		Map<String, RelatedAsset> mapRelAsset = new Map<String, RelatedAsset>();

		//pre process queried records
		for (RelatedAsset asset : RelatedAssets)
		{
			asset_numbers.add(asset.SerialNumber);
			asset_numbers.add(asset.FrameNumber);
		}

		for (FactoryAsset__c asset : [SELECT Id, SerialNumber__c, FirmwareVersion__c,ExParent__c, ProductName__c, Replaced__c, 
										ParentAsset__r.SerialNumber__c,ParentAsset__c, 
										( SELECT SerialNumber__c, Replaced__c,ProductName__c from FactoryAssets__r where Replaced__c = FALSE ) 
										FROM FactoryAsset__c WHERE SerialNumber__c IN: asset_numbers])
		{
			assets_map.put(asset.SerialNumber__c, asset);
			Map<String, FactoryAsset__c> Parts_map = new Map<String, FactoryAsset__c>();
			for(FactoryAsset__c sobjToReplacePart: asset.FactoryAssets__r)
				Parts_map.put( sobjToReplacePart.ProductName__c , sobjToReplacePart );

			if( asset.ProductName__c.equalsIgnoreCase( 'Bike' ) )
				Bike_Parts_map.put(asset.SerialNumber__c, Parts_map);
		}
		//scenarios
		/*
			1. when has no serialnumber
			2. update a part if does not have a Framenumber
			3. reject update a part if do have a Framenumber
			4. create a replacement and relate to Framenumber
			5. update a replacement with correct framenumber
		*/
		//loop through request
		for(Integer i = RelatedAssets.size() - 1; i >= 0; i--)
		{
			// check if there's no blank fields on the JSON
			if( String.isNotBlank( RelatedAssets.get( i ).SerialNumber ) && String.isNotBlank( RelatedAssets.get( i ).FrameNumber ) 
				&& String.isNotBlank( RelatedAssets.get( i ).FirmwareVersion ) && String.isNotBlank( RelatedAssets.get( i ).Part ) 
				&& !setDupOnJSON.contains( RelatedAssets.get( i ).SerialNumber ) )
			{
				//Validate if FrameNumber exist in Salesforce.
				if( assets_map.containsKey( RelatedAssets.get( i ).FrameNumber ) && assets_map.get( RelatedAssets.get( i ).FrameNumber ).ProductName__c == 'Bike' )
				{
					//flow for Part or Replacement
					if( assets_map.containsKey( RelatedAssets.get( i ).FrameNumber ) && 
						RelatedAssets.get( i ).FrameNumber.equalsIgnoreCase( assets_map.get(RelatedAssets.get( i ).SerialNumber).ParentAsset__r.SerialNumber__c) 
						)
					{
						//update FirmwareVersion
						FactoryAsset__c objFAssetPart 						= new FactoryAsset__c();
						objFAssetPart.SerialNumber__c 						= RelatedAssets.get( i ).SerialNumber;
						objFAssetPart.FirmwareVersion__c 					= RelatedAssets.get( i ).FirmwareVersion;
						setDupOnJSON.add(RelatedAssets.get( i ).SerialNumber);
						upsert_assets.add( objFAssetPart );
						mapRelAsset.put( RelatedAssets.get( i ).SerialNumber, RelatedAssets.get( i ) );
					}
					else
					{
						//Add error response, add to dropped list and remove from currently list
						RelatedAssets.get(i).Status = 'Part not match with FrameNumber';
						dropped_assets.add(RelatedAssets.get(i));
						RelatedAssets.remove(i);
					}
				}
				else
				{
					//Add error response, add to dropped list and remove from currently list
					RelatedAssets.get(i).Status = 'FrameNumber is not correct';
					dropped_assets.add(RelatedAssets.get(i));
					RelatedAssets.remove(i);
				}
			}
			else
			{
				//Add error response, add to dropped list and remove from currently list
				RelatedAssets.get(i).Status = setDupOnJSON.contains( RelatedAssets.get( i ).SerialNumber ) ? 'SerialNumber Already on update process, ' : '';
				RelatedAssets.get(i).Status += String.isBlank( RelatedAssets.get( i ).FrameNumber ) ? 'FrameNumber should not be blank, ' : '';
				RelatedAssets.get(i).Status += String.isBlank( RelatedAssets.get( i ).SerialNumber ) ? 'SerialNumber should not be blank, ' : '';
				RelatedAssets.get(i).Status += String.isBlank( RelatedAssets.get( i ).FirmwareVersion ) ? 'FirmwareVersion should not be blank, ' : '';
				RelatedAssets.get(i).Status += String.isBlank( RelatedAssets.get( i ).Part ) ? 'Part should not be blank, ' : '';
				RelatedAssets.get(i).Status = RelatedAssets.get(i).Status.removeEnd(', ');
				dropped_assets.add(RelatedAssets.get(i));
				RelatedAssets.remove(i);
			}
		}

		Schema.SObjectField exKey 		= FactoryAsset__c.Fields.SerialNumber__c;
		Database.UpsertResult[] upRes 	= Database.upsert( upsert_assets, exKey, false );
		for(Integer idx = 0; idx < upRes.size(); idx++)
		{
			RelatedAsset objRel 		= mapRelAsset.get(upsert_assets[idx].SerialNumber__c);
			objRel.Status 				= 'Part: ' + upsert_assets[idx].SerialNumber__c ;
			Database.UpsertResult sr 		= upRes[idx];
			if (!sr.isSuccess())
			{
				for (Database.Error er : sr.getErrors()) 
				{
					objRel.Status += ' Error (' +  er.getStatusCode() + '):' + er.getMessage()+' \r\n';
				}
				dropped_assets.add(objRel);
			}
			else
			{
				objRel.Status 	= 'Sucess on update';
				kept_assets.add( objRel );
			}
		}

		lstReturn.addAll(dropped_assets);
		lstReturn.addAll(kept_assets);
		objLog.Response__c = JSON.serialize(lstReturn);
		objLog.Status__c = ( dropped_assets.isEmpty() ) ? 'Success' : ( !dropped_assets.isEmpty() && !kept_assets.isEmpty() ? 'Partial Creation' : 'Error');
		insert objLog;
		res.statusCode = 200;
		return lstReturn;
	}
}