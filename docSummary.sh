
adminUsername="admin"
adminPassword="admin"
concatenatedUsernamePassword=$adminUsername":"$adminPassword
host="localhost"
HTTPSServletTransportPort=9443
NIOPort=8243


echo $concatenatedUsernamePassword
base64EncodedUsernamePassword=$(echo -n $concatenatedUsernamePassword | base64)
echo $base64EncodedUsernamePassword

tstamp=`date +%H_%M_%S`
DCClientResponse=`curl -k -X POST -H "Authorization: Basic '$base64EncodedUsernamePassword'" -H "Content-Type: application/json" -d "{\"callbackUrl\": \"www.google.lk\", \"clientName\": \"rest_api_publisher${tstamp}\",\"tokenScope\": \"Production\", \"owner\": \"admin\", \"grantType\": \"password refresh_token\", \"saasApp\": true}" https://${host}:${HTTPSServletTransportPort}/client-registration/v0.11/register`
echo "${DCClientResponse}" | jq -r '.'
clientID=`echo "${DCClientResponse}" | jq -r '.clientId'`;
clientSE=`echo "${DCClientResponse}" | jq -r '.clientSecret'`;

concatenatedClientIdClientSecret=$clientID":"$clientSE
echo $concatenatedClientIdClientSecret
base64EncodedClientIdClientSecret=$(echo -n $concatenatedClientIdClientSecret | base64)
echo $base64EncodedClientIdClientSecret

#For token generation, include the scopes here
scopeList="apim:api_view apim:api_create"
tokenGenerationResponse=`curl -k -d "grant_type=password&username=${adminUsername}&password=${adminPassword}&scope=${scopeList}" -H "Authorization: Basic '$base64EncodedClientIdClientSecret'" https://${host}:${NIOPort}/token`
echo $tokenGenerationResponse
accessToken=`echo $tokenGenerationResponse | jq -r '.access_token'`



#Get All API details
listAPI=`curl -k -H "Authorization: Bearer ${accessToken}" https://${host}:${HTTPSServletTransportPort}/api/am/publisher/v0.11/apis`
echo "${listAPI}" | jq '.'
list=`echo $listAPI | jq -r '.list[].id '`
echo $listAPI

for APIID in $list; do
	#Get API documents
	listDocs=`curl -k -H "Authorization: Bearer ${accessToken}" "https://${host}:${HTTPSServletTransportPort}/api/am/publisher/v0.11/apis/${APIID}/documents"`
	echo "${listDocs}" | jq '.'
	docID=`echo $listDocs | jq -r '.list[].documentId'`
	y=`echo $listDocs | jq -c '.list[]| @base64'`
			
	for x in $y; do
		x=`echo $x  | sed 's/^"\(.*\)"$/\1/' | base64 -d`
		#echo $x
		Visibility=`echo $x | jq -r '.visibility'`
		SourceType=`echo $x | jq -r '.sourceType'`
		SourceUrl=`echo $x | jq -r '.sourceUrl'`
		OtherTypeName=`echo $x | jq -r '.otherTypeName'`
		DocumentId=`echo $x | jq -r '.documentId'`
		Summary=`echo $x | jq -r '.summary'`
		Name=`echo $x | jq -r '.name'`
		Type=`echo $x | jq -r '.type'`
#Add a valid value to the doc summary field if it is empty.
		if [[ $Summary = null ]]; then
 			echo "Empty summary with doc ID $DocumentId"
 			DocSummaryUpdate=`curl -k -H "Authorization:Bearer ${accessToken}" -H "Content-Type: application/json" -X PUT -d "{ \"visibility\": \"${Visibility}\", \"sourceType\": \"${SourceType}\", \"sourceUrl\": ${SourceUrl}, \"otherTypeName\": ${OtherTypeName}, \"documentId\": \"${DocumentId}\", \"summary\": \"Sample_summary\", \"name\": \"${Name}\", \"type\": \"${Type}\" }" "https://${host}:${HTTPSServletTransportPort}/api/am/publisher/v0.11/apis/${APIID}/documents/${DocumentId}"`
 			echo "${DocSummaryUpdate}" | jq '.'
		fi
	done

done	
