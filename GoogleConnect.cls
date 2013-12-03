public with sharing class GoogleConnect {
	public string valueToShow{get;set;}	
	private final string googleClientID = 'clientID.apps.googleusercontent.com';
	private final string googleSecretCode = 'SecretCode';
	private final string redirectURI = 'https://c.na9.visual.force.com/apex/googleconnect';
	private final string ENTRY = 'entry';
	private final string SPREADSHEET_UPDATE = 'SpreadsheetUpdate';
	private final string CREATE_CONTACT = 'CreateContact';
	private final string UPDATE_CALENDAR = 'UpdateCalendar';
	private string authorizationCode = '';
	private string state = '';
	private string accessToken;
	private string refreshToken;
	private string expiresIn;
	private string tokenType;
		
	//Before doing this setup Remote Site Settings for
	//https://www.googleapis.com
	//https://accounts.google.com
	//https://spreadsheets.google.com
	//https://www.google.com
	
	/*
	{"web":{"auth_uri":"https://accounts.google.com/o/oauth2/auth",
		"client_secret":"SecretCode",
		"token_uri":"https://accounts.google.com/o/oauth2/token",
		"client_email":"ClientEmail@developer.gserviceaccount.com",
		"redirect_uris":["https://c.na9.visual.force.com/apex/googleconnect"],
		"client_x509_cert_url":"https://www.googleapis.com/robot/v1/metadata/x509/clientID@developer.gserviceaccount.com",
		"client_id":"clientID.apps.googleusercontent.com",
		"auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs"}}
	*/
	
	public GoogleConnect(){
		valueToShow = '<Press Button To Try>';
		//Check if we received the authorization code from Google because the redirectUI
		// URI points to this page.  It will look like this...
		//https://c.na9.visual.force.com/apex/googleconnect#state=MyState
			//&access_token=ya29.1.AADtN_XhXOiqLhJHOQE-ZXhuQwoNnH58euoCWWy5xzfeA3foZZzLBEWgynyF4gs
			//&token_type=Bearer
			//&expires_in=3600
		//If it is an error it will look like this...
		//https://c.na9.visual.force.com/apex/googleconnect#error=access_denied
		
		//All of these parameters are not query string paramenters, but rather they are fragments after the # sign
		// This article on oAuth with Salesforce explains these fragments: http://wiki.developerforce.com/page/Digging_Deeper_into_OAuth_2.0_on_Force.com
		//Maybe I am using the wrong flow.  This link says to use the web server flow instead of the user agent oauth flow
		// http://boards.developerforce.com/t5/Security/SSO-with-OAuth-returning-access-token-in-URL-fragment-rather/m-p/449093/highlight/true#M1505
		
		//https://oauth2-login-demo.appspot.com/code?state=/profile&code=4/P7q7W91a-oMsCeLvIaQm6bTrgtp7
		//https://oauth2-login-demo.appspot.com/code?error=access_denied&state=/profile
		authorizationCode = System.currentPageReference().getParameters().get('code');
		if(authorizationCode == null || authorizationCode == ''){
			valueToShow = '<Press Button To Try - No Authorization Code Yet>';			
		}else{
			state = System.currentPageReference().getParameters().get('state');
			valueToShow = '<We have an Authorization Code>';
			accessToken = '';
			if(state == SPREADSHEET_UPDATE){
				retrieveGoogleAccessToken();
				if(accessToken <> ''){
					setGoogleSpreadSheetCellValue();
				}
				valueToShow = '<Update Google Spreadsheet Complete>';
			}else if(state == CREATE_CONTACT){
				retrieveGoogleAccessToken();
				if(accessToken <> ''){
					addContact();
				}
				//valueToShow = '<Add Contact Complete>';
			}else if(state == UPDATE_CALENDAR){
				retrieveGoogleAccessToken();
				if(accessToken <> ''){
					addCalendarEntry();
				}
				//valueToShow = '<Add Calendar Entry Complete>';
			}else{
				valueToShow = '<We have an Authorization Code, but the state value is not valid>';
			}
						
		}
	}
	
	public pageReference updateSpreadsheet(){ //Called from Button		
		return DoGoogleConnectCall(SPREADSHEET_UPDATE);
	}	
	
	public pageReference createContact(){ //Called from Button		
		return DoGoogleConnectCall(CREATE_CONTACT);
	}
	
	public pageReference updateCalendar(){ //Called from Button		
		return DoGoogleConnectCall(UPDATE_CALENDAR);
	}
	
	//This call must be done before all Google API actions to get the authorization code
	//This will prompt the user to log into Google and it will also prompt for permissions as needed
	private pageReference DoGoogleConnectCall(string stateValue){
		//Get Authorization Code
		//Redirect to the OAuth page at Google so the login credentials can be entered.
		//https://accounts.google.com/o/oauth2/auth?response_type=code&client_id=777197791162.apps.googleusercontent.com&redirect_uri=https://c.na9.visual.force.com/apex/googleconnect&scope=
		//This URL lists for parameters for the oauth2 login URL
		// https://developers.google.com/accounts/docs/OAuth2UserAgent	
		
		//The scope for the speadsheets api list listed under this section of this URL: https://developers.google.com/google-apps/spreadsheets/#setting_up_your_client_library
		// Authorizing requests with OAuth 2.0
		//scope is space delimited set of permissions
		//scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fuserinfo.email+https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fuserinfo.profile&
		//scope=https://www.googleapis.com/auth/userinfo.email https//www.googleapis.com://auth//userinfo.profile&
		
		//Scope for 4 APIs 
		//1) Spreadsheets: https://spreadsheets.google.com/feeds
		//2) Google Docs: https://docs.google.com/feeds
		//3) Google Docs: https://www.google.com/m8/feeds - For Contacts
		//4) Google Docs: https://www.googleapis.com/auth/calendar
		PageReference pr = new PageReference('https://accounts.google.com/o/oauth2/auth' +
			'?response_type=code' +
			'&client_id=' + googleClientID + 
			'&redirect_uri=' + redirectURI +
			'&scope=https%3A%2F%2Fspreadsheets.google.com%2Ffeeds+https%3A%2F%2Fdocs.google.com%2Ffeeds+https%3A%2F%2Fwww.google.com%2Fm8%2Ffeeds+https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fcalendar' +
			'&state=' + stateValue + 
			'&access_type=online' +
			'&approval_prompt=auto' +  //auto, force
			'&login_hint=terryluschen@gmail.com');
		return pr;
	}
	
	private void retrieveGoogleAccessToken(){
		//After the web server receives the authorization code, 
		// it may exchange the authorization code for an access token and a refresh token. 
		//This is described in the 'Validating the Token' section on this URL:
		// https://developers.google.com/accounts/docs/OAuth2UserAgent
		Http h = new Http();
    	HttpRequest req = new HttpRequest();
    	string endPointValue = 'https://accounts.google.com/o/oauth2/token';  	
    	req.setEndpoint(endPointValue);
    	
    	string bodyRequest = '';
    	bodyRequest = 'code=' + EncodingUtil.urlEncode(authorizationCode, 'UTF-8');
    	bodyRequest += '&client_id=' + EncodingUtil.urlEncode(googleClientID, 'UTF-8');
    	bodyRequest += '&client_secret=' + EncodingUtil.urlEncode(googleSecretCode, 'UTF-8');
    	bodyRequest += '&redirect_uri=' + EncodingUtil.urlEncode(redirectURI, 'UTF-8');
    	bodyRequest += '&grant_type=authorization_code';
    	req.setBody(bodyRequest);    	
    	req.setHeader('Content-length', string.ValueOf(bodyRequest.length()));	
    	req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
    	req.setMethod('POST');
    	req.setTimeout(10000);
		HttpResponse res = h.send(req);		
		map<string, string> jsonValues = new map<string, string>();
		valueToShow = res.getBody();

		jsonValues = parseJSONToMap(res.getBody());
		if(jsonValues.containsKey('error')){
			//Just some debug lines to see the request and response
			valuetoShow = 'Get Access Token Error: ' + res.getBody() + ' end point value: ' + endPointValue + 'request: ' +
				req.toString() + 'request headers: ' + req.getHeader('Content-Type') + '; ' + req.getHeader('charset') + 
				'request body: ' + req.getBody();			
		}else{
			//Try to get a cell value in the Google Spreadsheet
			accessToken = jsonValues.get('access_token');
			refreshToken = jsonValues.get('refresh_token');
			expiresIn = jsonValues.get('expires_in');
			tokenType = jsonValues.get('token_type');			
		}		
	}
	
	//Appendix 2 - SECTION START: The routines below here relate to setting the value of a cell in a Google Spreadsheet
	private void setGoogleSpreadSheetCellValue(){
		SpreadSheetEntry ssEItem;
		//First get the information about the spreadsheet we want to update
		ssEItem = getGoogleSpreadSheetEntry('Salesforce Opportunity Report');
		
		string cellsFeedEdit = '';
		cellsFeedEdit = getGoogleSpreadSheetWorksheetFeed(ssEItem.worksheetsFeed);
		//These values like Worksheet Name, New Value, Column and Row should be saved in a custom setting
		string maxValue = getMaxOpportunityValue();
		setGoogleSpreadSheetValue(cellsFeedEdit, ssEItem.IDValue, ssEItem.WorksheetID, ssEItem.KeyValue, maxValue, 'R1C2', '1', '2');			
	}
	
	private string getMaxOpportunityValue(){
		string maxValue = '';
		list<AggregateResult> arList = new list<AggregateResult>();
		arList = [SELECT MAX(Amount)
					FROM Opportunity];
		for (AggregateResult ar : arList)  {
			maxValue = string.ValueOf(ar.get('expr0'));
		}
		return maxValue;
	}
	
	private SpreadSheetEntry getGoogleSpreadSheetEntry(string spreadSheetName){		
		Http h = new Http();
    	HttpRequest req = new HttpRequest();
    	string endPointValue = 'https://spreadsheets.google.com/feeds/spreadsheets/private/full';    	
    	req.setEndpoint(endPointValue);	
    	req.setHeader('Authorization', 'Bearer ' + accessToken);
    	req.setMethod('GET');
    	req.setTimeout(10000);
		HttpResponse res = h.send(req);
		
		//Now we could parse through the XML and get the values that we want
		string tempID = '';
		XmlStreamReader reader = new XmlStreamReader(res.getBody());
		list<SpreadSheetEntry> ssEList = parseSpreadSheetEntry(reader);
		SpreadSheetEntry ssEItemReturn;
		for(SpreadSheetEntry ssEItem : ssEList){
			if(ssEItem.Title == spreadSheetName){
				ssEItemReturn = ssEItem;
			}
		}
		return ssEItemReturn;
					
	}
	
	/* This https://spreadsheets.google.com/feeds/spreadsheets/private/full returns
    	<?xml version='1.0' encoding='UTF-8'?>
    		<feed xmlns='http://www.w3.org/2005/Atom' xmlns:openSearch='http://a9.com/-/spec/opensearchrss/1.0/'>
    			<id>https://spreadsheets.google.com/feeds/spreadsheets/private/full</id>
    			<updated>2013-11-25T12:32:14.775Z</updated>
    			<category scheme='http://schemas.google.com/spreadsheets/2006' term='http://schemas.google.com/spreadsheets/2006#spreadsheet'/>
    			<title type='text'>Available Spreadsheets - terryluschen@gmail.com</title>
    			<link rel='alternate' type='text/html' href='http://docs.google.com'/>
    			<link rel='http://schemas.google.com/g/2005#feed' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/spreadsheets/private/full'/>
    			<link rel='self' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/spreadsheets/private/full'/>
    			<openSearch:totalResults>2</openSearch:totalResults>
    			<openSearch:startIndex>1</openSearch:startIndex>
    			<entry>
    				<id>https://spreadsheets.google.com/feeds/spreadsheets/private/full/tqJ0qc1ctVWrPDG2Cv2fTiA</id>
    				<updated>2013-11-25T12:30:33.171Z</updated>
    				<category scheme='http://schemas.google.com/spreadsheets/2006' term='http://schemas.google.com/spreadsheets/2006#spreadsheet'/>
    				<title type='text'>Salesforce Opportunity Report</title>
    				<content type='text'>Salesforce Opportunity Report</content>
    				<link rel='http://schemas.google.com/spreadsheets/2006#worksheetsfeed' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/worksheets/tqJ0qc1ctVWrPDG2Cv2fTiA/private/full'/>
    				<link rel='alternate' type='text/html' href='https://spreadsheets.google.com/ccc?key=0Al9_lvrq9LB6dHFKMHFjMWN0VldyUERHMkN2MmZUaUE'/>
    				<link rel='self' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/spreadsheets/private/full/tqJ0qc1ctVWrPDG2Cv2fTiA'/>
    				<author>
    					<name>terryluschen</name>
    					<email>terryluschen@gmail.com</email>
    				</author>
    			</entry>
    			<entry>
    				<id>https://spreadsheets.google.com/feeds/spreadsheets/private/full/tMf-_tsyB_wMLX5rbjAAHCw</id>
    				<updated>2013-11-21T17:24:03.816Z</updated>
    				<category scheme='http://schemas.google.com/spreadsheets/2006' term='http://schemas.google.com/spreadsheets/2006#spreadsheet'/>
    				<title type='text'>Salesforce Unit Tests</title>
    				<content type='text'>Salesforce Unit Tests</content>
    				<link rel='http://schemas.google.com/spreadsheets/2006#worksheetsfeed' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/worksheets/tMf-_tsyB_wMLX5rbjAAHCw/private/full'/>
    				<link rel='alternate' type='text/html' href='https://spreadsheets.google.com/ccc?key=0Al9_lvrq9LB6dE1mLV90c3lCX3dNTFg1cmJqQUFIQ3c'/>
    				<link rel='self' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/spreadsheets/private/full/tMf-_tsyB_wMLX5rbjAAHCw'/>
    				<author>
    					<name>terryluschen</name>
    					<email>terryluschen@gmail.com</email>
    				</author>
    			</entry>
    		</feed>
    	*/
		
	private string getGoogleSpreadSheetWorksheetFeed(string worksheetFeedURL){	
		//This is only needed to get the URL for the cells feed	
		Http h = new Http();
    	HttpRequest req = new HttpRequest();
    	string endPointValue = worksheetFeedURL;    	
    	req.setEndpoint(endPointValue);	
    	req.setHeader('Authorization', 'Bearer ' + accessToken);
    	req.setMethod('GET');
    	req.setTimeout(10000);
		HttpResponse res = h.send(req);	
		
		XmlStreamReader reader = new XmlStreamReader(res.getBody());
		list<SpreadSheetEntry> ssEList = parseSpreadSheetEntry(reader);
		string cellsFeed;
		for(SpreadSheetEntry ssEItem : ssEList){
			cellsFeed = ssEItem.cellsFeed;
		}
		string cellsFeedEdit;
		if(cellsFeed <> null){
			if(cellsFeed.length() > 0){
				cellsFeedEdit = getGoogleSpreadSheetCellFeed(cellsFeed);
			}
		}
		return cellsFeedEdit;
	}
	
		/* The call in getGoogleSpreadSheetWorksheetFeed returns
		<?xml version='1.0' encoding='UTF-8'?>
		<feed xmlns='http://www.w3.org/2005/Atom' xmlns:openSearch='http://a9.com/-/spec/opensearchrss/1.0/' xmlns:gs='http://schemas.google.com/spreadsheets/2006'>
			<id>https://spreadsheets.google.com/feeds/worksheets/tqJ0qc1ctVWrPDG2Cv2fTiA/private/full</id>
			<updated>2013-11-25T15:28:29.556Z</updated>
			<category scheme='http://schemas.google.com/spreadsheets/2006' term='http://schemas.google.com/spreadsheets/2006#worksheet'/>
			<title type='text'>Salesforce Opportunity Report</title>
			<link rel='alternate' type='text/html' href='https://spreadsheets.google.com/ccc?key=tqJ0qc1ctVWrPDG2Cv2fTiA'/>
			<link rel='http://schemas.google.com/g/2005#feed' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/worksheets/tqJ0qc1ctVWrPDG2Cv2fTiA/private/full'/>
			<link rel='http://schemas.google.com/g/2005#post' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/worksheets/tqJ0qc1ctVWrPDG2Cv2fTiA/private/full'/>
			<link rel='self' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/worksheets/tqJ0qc1ctVWrPDG2Cv2fTiA/private/full'/>
			<author>
				<name>terryluschen</name>
				<email>terryluschen@gmail.com</email>
			</author>
			<openSearch:totalResults>1</openSearch:totalResults>
			<openSearch:startIndex>1</openSearch:startIndex>
			<entry>
				<id>https://spreadsheets.google.com/feeds/worksheets/tqJ0qc1ctVWrPDG2Cv2fTiA/private/full/od6</id>
				<updated>2013-11-25T15:28:29.556Z</updated>
				<category scheme='http://schemas.google.com/spreadsheets/2006' term='http://schemas.google.com/spreadsheets/2006#worksheet'/>
				<title type='text'>Sheet1</title>
				<content type='text'>Sheet1</content>
				<link rel='http://schemas.google.com/spreadsheets/2006#listfeed' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/list/tqJ0qc1ctVWrPDG2Cv2fTiA/od6/private/full'/>
				<link rel='http://schemas.google.com/spreadsheets/2006#cellsfeed' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/cells/tqJ0qc1ctVWrPDG2Cv2fTiA/od6/private/full'/>
				<link rel='http://schemas.google.com/visualization/2008#visualizationApi' type='application/atom+xml' href='https://spreadsheets.google.com/tq?key=tqJ0qc1ctVWrPDG2Cv2fTiA&amp;sheet=od6'/>
				<link rel='self' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/worksheets/tqJ0qc1ctVWrPDG2Cv2fTiA/private/full/od6'/>
				<link rel='edit' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/worksheets/tqJ0qc1ctVWrPDG2Cv2fTiA/private/full/od6/dn2wweppuo'/>
				<gs:rowCount>100</gs:rowCount><gs:colCount>20</gs:colCount>
			</entry>
		</feed>
		*/
		
	private string getGoogleSpreadSheetCellFeed(string cellFeedURL){		
		Http h = new Http();
    	HttpRequest req = new HttpRequest();
    	//System.LimitException: Apex heap size too large: 6155590 (Got this error with return-empty=true and no range parameter);
    	//Without the return-empty=true any blank cells will not be returned.   This range could be saved in a custom setting.
    	string endPointValue = cellFeedURL + '?return-empty=true&range=R1C1:R3C3';  	
    	req.setEndpoint(endPointValue);	
    	req.setHeader('Authorization', 'Bearer ' + accessToken);
    	req.setMethod('GET');
    	req.setTimeout(10000);
		HttpResponse res = h.send(req);
		valueToShow = 'Cell Feed Values: ' + res.getBody();	
		
		XmlStreamReader reader = new XmlStreamReader(res.getBody());
		list<SpreadSheetEntry> ssEList = parseSpreadSheetEntry(reader);
		string cellsFeedEdit;
		for(SpreadSheetEntry ssEItem : ssEList){
			//The cell to fill could be saved in a custom setting for more control
			if(ssEItem.Title == 'B1'){			
			//Another way to find the cell to update would be to place some specific text like '-FILL_HERE-' in it.
			//if(ssEItem.currentContent == '-FILL_HERE-'){
				valueToShow += 'Cell Feed Values editURL: ' + ssEItem.editURL;	
				cellsFeedEdit = ssEItem.editURL;
			}			
		}
		return cellsFeedEdit;
		
	}
	/* The call in getGoogleSpreadSheetCellFeed returns this
	<?xml version='1.0' encoding='UTF-8'?>
	<feed xmlns='http://www.w3.org/2005/Atom' xmlns:openSearch='http://a9.com/-/spec/opensearchrss/1.0/' xmlns:gs='http://schemas.google.com/spreadsheets/2006' xmlns:batch='http://schemas.google.com/gdata/batch'>
		<id>https://spreadsheets.google.com/feeds/cells/tqJ0qc1ctVWrPDG2Cv2fTiA/od6/private/full</id>
		<updated>2013-11-25T15:28:29.556Z</updated>
		<category scheme='http://schemas.google.com/spreadsheets/2006' term='http://schemas.google.com/spreadsheets/2006#cell'/>
		<title type='text'>Sheet1</title>
		<link rel='alternate' type='text/html' href='https://spreadsheets.google.com/ccc?key=tqJ0qc1ctVWrPDG2Cv2fTiA'/>
		<link rel='http://schemas.google.com/g/2005#feed' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/cells/tqJ0qc1ctVWrPDG2Cv2fTiA/od6/private/full'/>
		<link rel='http://schemas.google.com/g/2005#post' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/cells/tqJ0qc1ctVWrPDG2Cv2fTiA/od6/private/full'/>
		<link rel='http://schemas.google.com/g/2005#batch' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/cells/tqJ0qc1ctVWrPDG2Cv2fTiA/od6/private/full/batch'/>
		<link rel='self' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/cells/tqJ0qc1ctVWrPDG2Cv2fTiA/od6/private/full'/>
		<author>
			<name>terryluschen</name>
			<email>terryluschen@gmail.com</email>
		</author>
		<openSearch:totalResults>3</openSearch:totalResults>
		<openSearch:startIndex>1</openSearch:startIndex>
		<gs:rowCount>100</gs:rowCount><gs:colCount>20</gs:colCount>
		<entry>
			<id>https://spreadsheets.google.com/feeds/cells/tqJ0qc1ctVWrPDG2Cv2fTiA/od6/private/full/R1C1</id>
			<updated>2013-11-25T15:28:29.556Z</updated>
			<category scheme='http://schemas.google.com/spreadsheets/2006' term='http://schemas.google.com/spreadsheets/2006#cell'/>
			<title type='text'>A1</title>
			<content type='text'>Current Max Opportunity Amount:</content>
			<link rel='self' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/cells/tqJ0qc1ctVWrPDG2Cv2fTiA/od6/private/full/R1C1'/>
			<link rel='edit' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/cells/tqJ0qc1ctVWrPDG2Cv2fTiA/od6/private/full/R1C1/83qbhu'/>
			<gs:cell row='1' col='1' inputValue='Current Max Opportunity Amount:'>Current Max Opportunity Amount:</gs:cell>
		</entry>
		<entry>
			<id>https://spreadsheets.google.com/feeds/cells/tqJ0qc1ctVWrPDG2Cv2fTiA/od6/private/full/R1C3</id>
			<updated>2013-11-25T15:28:29.556Z</updated>
			<category scheme='http://schemas.google.com/spreadsheets/2006' term='http://schemas.google.com/spreadsheets/2006#cell'/>
			<title type='text'>C1</title>
			<content type='text'>Other Values:</content>
			<link rel='self' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/cells/tqJ0qc1ctVWrPDG2Cv2fTiA/od6/private/full/R1C3'/>
			<link rel='edit' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/cells/tqJ0qc1ctVWrPDG2Cv2fTiA/od6/private/full/R1C3/tjei2w'/>
			<gs:cell row='1' col='3' inputValue='Other Values:'>Other Values:</gs:cell>
		</entry>
		<entry>
			<id>https://spreadsheets.google.com/feeds/cells/tqJ0qc1ctVWrPDG2Cv2fTiA/od6/private/full/R2C1</id>
			<updated>2013-11-25T15:28:29.556Z</updated>
			<category scheme='http://schemas.google.com/spreadsheets/2006' term='http://schemas.google.com/spreadsheets/2006#cell'/>
			<title type='text'>A2</title>
			<content type='text'>Other Rows:</content>
			<link rel='self' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/cells/tqJ0qc1ctVWrPDG2Cv2fTiA/od6/private/full/R2C1'/>
			<link rel='edit' type='application/atom+xml' href='https://spreadsheets.google.com/feeds/cells/tqJ0qc1ctVWrPDG2Cv2fTiA/od6/private/full/R2C1/acyfqp'/>
			<gs:cell row='2' col='1' inputValue='Other Rows:'>Other Rows:</gs:cell>
		</entry>
	</feed>
	*/
	
	//Finally set the new value in the spreadsheet
	private void setGoogleSpreadSheetValue(string cellsFeedEdit, string IDValue, string worksheetID, 
		string keyValue, string newValue, string cellName, string row, string column){
		//cellsFeedEdit is like: https://spreadsheets.google.com/feeds/cells/key/worksheetId/private/full/R2C4
		Http h = new Http();
    	HttpRequest req = new HttpRequest();
    	string endPointValue = cellsFeedEdit;
    	req.setEndpoint(endPointValue);    	
    	string bodyRequest = '';
    	bodyRequest = '<entry xmlns="http://www.w3.org/2005/Atom" xmlns:gs="http://schemas.google.com/spreadsheets/2006">';
    	bodyRequest += '<id>' + endPointValue + '</id>';
    	bodyRequest += '<link rel="edit" type="application/atom+xml" href="' + endPointValue + '"/>';
    	bodyRequest += '<gs:cell row="' + row + '" col="' + column + '" inputValue="' + newValue + '"/>';
    	bodyRequest += '</entry>';
    	req.setBody(bodyRequest);    	
    	req.setHeader('Authorization', 'Bearer ' + accessToken);
    	req.setHeader('Content-length', string.ValueOf(bodyRequest.length()));	
    	req.setHeader('Content-Type', 'application/atom+xml');
    	req.setMethod('PUT');
    	req.setTimeout(10000);
		HttpResponse res = h.send(req);
	}
	
	//Appendix 3 - SECTION START: Below here is all the code to interact with the Contact API
	private void addContact(){
		Http h = new Http();
    	HttpRequest req = new HttpRequest();
    	string endPointValue = 'https://www.google.com/m8/feeds/contacts/terryluschen@gmail.com/full';
    	req.setEndpoint(endPointValue);    	
    	string bodyRequest = '';
    	
    	bodyRequest = '<atom:entry xmlns:atom="http://www.w3.org/2005/Atom" xmlns:gd="http://schemas.google.com/g/2005">';
    	bodyRequest += '<atom:category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/contact/2008#contact"/>';
    	bodyRequest += '<gd:name>';
    	bodyRequest += '<gd:givenName>NewFirstAPI</gd:givenName>';
    	bodyRequest += '<gd:familyName>NewLastAPI</gd:familyName>';
    	bodyRequest += '<gd:fullName>NewFirstAPI NewLastAPI</gd:fullName>';
    	bodyRequest += '</gd:name>';
    	bodyRequest += '<atom:content type="text">This is for the Notes field</atom:content>';
    	bodyRequest += '<gd:email rel="http://schemas.google.com/g/2005#work" primary="true" address="workEmail@gmail.com" displayName="N. New"/>';
    	bodyRequest += '<gd:email rel="http://schemas.google.com/g/2005#home" address="homeEmail@example.org"/>';
    	bodyRequest += '<gd:phoneNumber rel="http://schemas.google.com/g/2005#work" primary="true">(222)222-2222</gd:phoneNumber>';
    	bodyRequest += '<gd:phoneNumber rel="http://schemas.google.com/g/2005#home">(333)333-3333</gd:phoneNumber>';
    	bodyRequest += '<gd:im address="workEmail@gmail.com" protocol="http://schemas.google.com/g/2005#GOOGLE_TALK" primary="true" rel="http://schemas.google.com/g/2005#home"/>';
    	bodyRequest += '<gd:structuredPostalAddress rel="http://schemas.google.com/g/2005#work" primary="true">';
    	bodyRequest += '<gd:city>Fargo</gd:city>';
    	bodyRequest += '<gd:street>1800 1st Street South</gd:street>';
    	bodyRequest += '<gd:region>ND</gd:region>';
    	bodyRequest += '<gd:postcode>58103</gd:postcode>';
    	bodyRequest += '<gd:country>United States</gd:country>';
    	bodyRequest += '<gd:formattedAddress>1800 1st Street South Fargo</gd:formattedAddress>';
    	bodyRequest += '</gd:structuredPostalAddress>';
    	bodyRequest += '</atom:entry>';
    	    	  	//</pre>
    	req.setBody(bodyRequest);    	
    	req.setHeader('Authorization', 'Bearer ' + accessToken);
    	req.setHeader('Content-length', string.ValueOf(bodyRequest.length()));	
    	req.setHeader('Content-Type', 'application/atom+xml');
    	req.setHeader('GData-Version', '3.0');
    	req.setMethod('POST');
    	req.setTimeout(10000);
		HttpResponse res = h.send(req);
		valueToShow += 'Create Contact Response: ' + res.getBody();	
	}
	
	/* The response for the Contact create looks like this:
	<?xml version='1.0' encoding='UTF-8'?>
	<entry xmlns='http://www.w3.org/2005/Atom' xmlns:gContact='http://schemas.google.com/contact/2008' xmlns:batch='http://schemas.google.com/gdata/batch' xmlns:gd='http://schemas.google.com/g/2005' gd:etag='&quot;Q384fTVSLit7I2A9Wh5WFU8ITww.&quot;'>
	<id>http://www.google.com/m8/feeds/contacts/terryluschen%40gmail.com/base/5fee9aeb0a06be72</id>
	<updated>2013-11-27T03:28:02.135Z</updated>
	<app:edited xmlns:app='http://www.w3.org/2007/app'>2013-11-27T03:28:02.135Z</app:edited>
	<category scheme='http://schemas.google.com/g/2005#kind' term='http://schemas.google.com/contact/2008#contact'/>
	<title>NewFirstAPI NewLastAPI</title>
	<content>This is for the Notes field</content>
	<link rel='http://schemas.google.com/contacts/2008/rel#photo' type='image/*' href='https://www.google.com/m8/feeds/photos/media/terryluschen%40gmail.com/5fee9aeb0a06be72'/>
	<link rel='self' type='application/atom+xml' href='https://www.google.com/m8/feeds/contacts/terryluschen%40gmail.com/full/5fee9aeb0a06be72'/>
	<link rel='edit' type='application/atom+xml' href='https://www.google.com/m8/feeds/contacts/terryluschen%40gmail.com/full/5fee9aeb0a06be72'/>
	<gd:name>
	<gd:fullName>NewFirstAPI NewLastAPI</gd:fullName>
	<gd:givenName>NewFirstAPI</gd:givenName>
	<gd:familyName>NewLastAPI</gd:familyName>
	</gd:name>
	<gd:email rel='http://schemas.google.com/g/2005#work' address='workEmail@gmail.com' primary='true' displayName='N. New'/>
	<gd:email rel='http://schemas.google.com/g/2005#home' address='homeEmail@example.org'/>
	<gd:im address='workEmail@gmail.com' primary='true' protocol='http://schemas.google.com/g/2005#GOOGLE_TALK' rel='http://schemas.google.com/g/2005#home'/>
	<gd:phoneNumber rel='http://schemas.google.com/g/2005#work' primary='true'>(222)222-2222</gd:phoneNumber>
	<gd:phoneNumber rel='http://schemas.google.com/g/2005#home'>(333)333-3333</gd:phoneNumber>
	<gd:structuredPostalAddress primary='true' rel='http://schemas.google.com/g/2005#work'>
	<gd:formattedAddress>1800 1st Street South Fargo</gd:formattedAddress>
	<gd:street>1800 1st Street South</gd:street>
	<gd:postcode>58103</gd:postcode>
	<gd:city>Fargo</gd:city>
	<gd:region>ND</gd:region>
	<gd:country>United States</gd:country>
	</gd:structuredPostalAddress>
	</entry>
	*/
	
	//Appendix 4 - SECTION START: Below here is all the code to interact with the Calendar API
	private void addCalendarEntry(){
		Http h = new Http();
    	HttpRequest req = new HttpRequest();
    	string endPointValue = 'https://www.googleapis.com/calendar/v3/calendars/primary/events';
    	//This end point does seem to work, but it is not creating an event, just creating a new calendar
    	//endPointValue = 'https://www.googleapis.com/calendar/v3/calendars?key=' + googleClientID;
    	req.setEndpoint(endPointValue);    	
    	string bodyRequest = '';
    	bodyRequest = '{';
    	bodyRequest += '\r\n';
    	bodyRequest += '"summary": "Sales Call",';
    	bodyRequest += '\r\n';
    	bodyRequest += '"location": "Conference Room A",';
    	bodyRequest += '\r\n';
    	bodyRequest += '"start": {';
    	bodyRequest += '\r\n';
    	bodyRequest += '"dateTime": "2013-11-28T11:00:00.000-07:00",';
    	bodyRequest += '\r\n';
    	bodyRequest += '"timeZone": "America/Los_Angeles"';
    	bodyRequest += '\r\n';
    	bodyRequest += '},';
    	bodyRequest += '\r\n';
    	bodyRequest += '"end": {';
    	bodyRequest += '\r\n';
    	bodyRequest += '"dateTime": "2013-11-28T11:30:00.000-07:00",';
    	bodyRequest += '\r\n';
    	bodyRequest += '"timeZone": "America/Los_Angeles"';
    	bodyRequest += '\r\n';
    	bodyRequest += '},'; 
    	bodyRequest += '\r\n';
    	bodyRequest += '"recurrence": [';
    	bodyRequest += '\r\n';
    	bodyRequest += '"RRULE:FREQ=WEEKLY;UNTIL=20131226T000000Z"';
    	bodyRequest += '\r\n';
    	bodyRequest += '],';    	
    	bodyRequest += '\r\n';
    	bodyRequest += '"attendees": [';
    	bodyRequest += '\r\n';
    	bodyRequest += '{';
    	bodyRequest += '\r\n';
    	bodyRequest += '"email": "Terry.Luschen@SundogInteractive.com"';
    	bodyRequest += '\r\n';
    	bodyRequest += '}';
    	bodyRequest += '\r\n';
    	bodyRequest += ']'; 
    	bodyRequest += '}';
    	
    	req.setBody(bodyRequest);    	
    	req.setHeader('Authorization', 'Bearer ' + accessToken);
    	req.setHeader('Content-length', string.ValueOf(bodyRequest.length()));	
    	req.setHeader('Content-Type', 'application/json; charset=UTF-8');
    	req.setMethod('POST');
    	req.setTimeout(10000);
		HttpResponse res = h.send(req);
		valueToShow = 'Create Calendar Body Request: ' + bodyRequest;
		valueToShow += 'Create Calendar Response: ' + res.getBody();	
	}
	
	/*
	{
	"summary": "Daily Scrum",
	"location": "Conference Room A",
	"start": {"dateTime": "2013-11-28T11:00:00.000-07:00","timeZone": "America/Los_Angeles"},
	"end": {"dateTime": "2013-11-28T11:30:00.000-07:00","timeZone": "America/Los_Angeles""},
	"recurrence": ["RRULE:FREQ=WEEKLY;UNTIL=20141128T100000-07:00"],
	"attendees": [{"email": "Terry.Luschen@SundogInteractive.com","email": "Joe.Jones@SundogInteractive.com"}]
	}
	
	 { 
	 "summary": "Daily Scrum", 
	 "location": "Conference Room A", 
	 "start": { "dateTime": "2013-11-28T11:00:00.000-07:00", "timeZone": "America/Los_Angeles" }, 
	 "end": { "dateTime": "2013-11-28T11:30:00.000-07:00", "timeZone": "America/Los_Angeles" "} }
	 
	*/
	
	//SECTION START: Below here is all the code to parse JSON and XML
	//Parse JSON
	private map<string, string> parseJSONToMap(string JSONValue){
		JSONParser parser = JSON.createParser(JSONValue);
		map<string, string> jsonMap = new map<string, string>();
		string keyValue = '';
		string tempValue = '';
		while (parser.nextToken() != null) {
            if(parser.getCurrentToken() == JSONToken.FIELD_NAME){
            	keyValue = parser.getText();
            	parser.nextToken();
            	tempValue = parser.getText();
            	jsonMap.put(keyValue, tempValue);            	
            }
        }
        return jsonMap;
	}
		
	//Parse XML
	list<SpreadSheetEntry> parseSpreadSheetEntry(XmlStreamReader reader) {
	     list<SpreadSheetEntry> spreadSheetEntryList = new list<SpreadSheetEntry>();
	     while(reader.hasNext()) {    
	         if (reader.getEventType() == XmlTag.START_ELEMENT) {
	            if (ENTRY == reader.getLocalName()) {
	                SpreadSheetEntry ssE = parseEntry(reader);
	                spreadSheetEntryList.add(ssE);
	            }
	         }
	        reader.next();
	     }
    	return spreadSheetEntryList;
    }
   
    SpreadSheetEntry parseEntry(XmlStreamReader reader) {
	   	 string typeValue = '';
	   	 string hrefValue = '';
	   	 string relValue = '';
	     SpreadSheetEntry ssE = new SpreadSheetEntry();
	     integer index;
	     
	     while(reader.hasNext()) {
	        if (reader.getEventType() == XmlTag.END_ELEMENT) {
	        	if (ENTRY == reader.getLocalName()) {
	        		break;	
	        	}	
	        }
	        if (reader.getEventType() == XmlTag.START_ELEMENT) {
	        	if ('ID' == reader.getLocalName()) {
	        		reader.next();
	        		if (reader.getEventType() == XmlTag.CHARACTERS) {
	        			ssE.IDValue = reader.getText();
	        			index = ssE.IDValue.indexOf('full/');
	        			if(index > 0){
	        				ssE.WorksheetID = ssE.IDValue.substring(index + 5);
	        			}
	        		}
	        	}	
	        	if ('content' == reader.getLocalName()) {
	        		reader.next();
	        		if (reader.getEventType() == XmlTag.CHARACTERS) {
	        			ssE.currentContent = reader.getText();
	        		}
	        	}	
	        	if ('title' == reader.getLocalName()) {
	        		reader.next();
	        		if (reader.getEventType() == XmlTag.CHARACTERS) {
	        			ssE.Title = reader.getText();
	        		}
	        	}	
	        	if ('link' == reader.getLocalName()) {
	        		typeValue = reader.getAttributeValue(null, 'type');
	        		relValue = reader.getAttributeValue(null, 'rel');
	        		if(typeValue == 'text/html' && relValue == 'alternate'){
	        			hrefValue = reader.getAttributeValue(null, 'href');
	        			index = hrefValue.indexOf('key=');
	        			if(index > 0){
	        				ssE.KeyValue = hrefValue.substring(index + 4);
	        			}
	        		}        		
	        	}	
	        	if ('link' == reader.getLocalName()) {
	        		typeValue = reader.getAttributeValue(null, 'type');
	        		relValue = reader.getAttributeValue(null, 'rel');
	        		if(typeValue == 'application/atom+xml' && relValue == 'http://schemas.google.com/spreadsheets/2006#worksheetsfeed'){
	        			hrefValue = reader.getAttributeValue(null, 'href');
	        			ssE.worksheetsFeed = hrefValue;        			
	        		}        		
	        	}	
	        	if ('link' == reader.getLocalName()) {
	        		typeValue = reader.getAttributeValue(null, 'type');
	        		relValue = reader.getAttributeValue(null, 'rel');
	        		if(typeValue == 'application/atom+xml' && relValue == 'http://schemas.google.com/spreadsheets/2006#cellsfeed'){
	        			hrefValue = reader.getAttributeValue(null, 'href');
	        			ssE.cellsFeed = hrefValue;        			
	        		}        		
	        	}	
	        	if ('link' == reader.getLocalName()) {
	        		typeValue = reader.getAttributeValue(null, 'type');
	        		relValue = reader.getAttributeValue(null, 'rel');
	        		if(typeValue == 'application/atom+xml' && relValue == 'self'){
	        			hrefValue = reader.getAttributeValue(null, 'href');
	        			ssE.selfURL = hrefValue;        			
	        		}        		
	        	}	
	        	if ('link' == reader.getLocalName()) {
	        		typeValue = reader.getAttributeValue(null, 'type');
	        		relValue = reader.getAttributeValue(null, 'rel');
	        		if(typeValue == 'application/atom+xml' && relValue == 'edit'){
	        			hrefValue = reader.getAttributeValue(null, 'href');
	        			ssE.editURL = hrefValue;        			
	        		}        		
	        	}	
	        }
	        reader.next();
	     }
	     return ssE;
    }
	
	//Class used when parsing XML from Google API calls
	public class SpreadSheetEntry {
	     String IDValue;
	     String KeyValue;
	     String Title;
	     String WorksheetID;
	     String worksheetsFeed;
	     String cellsFeed;
	     String editURL;
	     String selfURL;
	     String currentContent;
	}
				
}
