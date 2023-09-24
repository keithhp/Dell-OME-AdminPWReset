
# Quick and dirty reset script to change the password of the "admin" account within OME.
#
# This uses the API to call a password reset.  You still need ADMIN rights..  but not BACKUP ADMIN rights (as the admin account is the only one to have this)...
#
# This script assumes you have admin access using a different account other than "admin"..   With Admin being the "Backup Admin"...  that you cannot access..
#
# Create a NEW LOCAL admin user - those creds are used by the script to access the API and reset the local admin account. You can delete that account once this script works.
#
# Written by Keith Hensby-Peck 22-SEP-2023
# Tested on OME V3.10.2 (Build 13)
#

function OpenOMESession(){
    param(
        [Parameter(Mandatory)][string] $OMEServer,
        [Parameter(Mandatory)][string] $UserName,
        [Parameter(Mandatory)][string] $Password
    )
    $SessionUrl  = "https://$($OMEServer)/api/SessionService/Sessions"
    $Type        = "application/json"
    $UserDetails = @{"UserName"=$UserName;"Password"=$Password;"SessionType"="API"} | ConvertTo-Json
    try {
        $SessResponse = Invoke-WebRequest -Uri $SessionUrl -Method Post -Body $UserDetails -ContentType "application/json"
        if ($SessResponse.StatusCode -eq 200 -or $SessResponse.StatusCode -eq 201) {
            $obj = New-Object PSObject -Property @{
                SessionId = ($SessResponse | convertfrom-json).Id
                AuthToken = $SessResponse.Headers["X-Auth-Token"]
            }
            $obj
        } else { Write-Error "Error: Opening Session to ($OMEServer)" }
    } catch { Write-Error "Error Debug: $_" }
}

function CloseOMESession(){
    param(
        [Parameter(Mandatory)][string] $OMEServer,
        [Parameter(Mandatory)][string] $SessionId
    )
    try {
        $SessClose = Invoke-WebRequest -Uri "https://$($OMEServer)/api/SessionService/Sessions('$($SessionID)')" -Method Delete -Headers $Headers -ContentType $Type
        $SessClose
    } catch {
        "Error: Could not close session`n`n$Error[0]"
    }
}


# Get the connection details of the OME Server
$OMEServer = read-host "Enter the resolvable name or IP address of the OME Server"

# Get the user credentials to use when accessing the API
$CredsToUse = Get-Credential -Message "Enter the credentials to use when accessing OME" 

# Get the NEW password to use
$NewPW = Get-Credential -Message "Enter the NEW password to use" -UserName "admin"

# Open the API Session to the OME Server
$OMESession = OpenOMESession $OMEServer "$($CredsToUse.UserName)" "$($CredsToUse.GetNetworkCredential().Password)"

# Build the URI Header for future use as invoke-webrequest needs it for authentication.
$Headers = @{}
$Headers."X-Auth-Token" = $OMESession.AuthToken

# Get the admin account details, the ID is mainly what is needed, as well as the odata URL to use when updating the account.
$UserDetail = $null ; $UserCall = $null
$UserCall = Invoke-WebRequest -Uri "https://$($OMEServer)/api/AccountService/Accounts" -Method Get -Headers $Headers -ContentType "application/json"

# Check we have a valid response..
if ($UserCall.StatusCode -eq 200){

    # Get the user details..  and check its a local account (UserTypeID=1)
    $UserDetail = ($UserCall | ConvertFrom-Json).value | ?{$_.Name -eq $NewPW.UserName -and $_.UserTypeID -eq 1}
    $URIToAdd = $UserDetail.'@odata.id'

    if ($UserDetail){
        # Tests have shown the payload MUST include everything here, sending just the ID and password DOES NOT WORK! which is why we set everything to what it is already!
        $body = "{
         `"Id`": `"$($UserDetail.ID)`",
         `"UserTypeId`": $($UserDetail.UserTypeID),
         `"DirectoryServiceId`": $($UserDetail.DirectoryServiceID),
         `"Name`": `"$($UserDetail.Name)`",
         `"Password`": `"$($NewPW.GetNetworkCredential().password)`",
         `"UserName`": `"$($UserDetail.UserName)`",
         `"Description`": `"$($UserDetail.Description)`",
         `"RoleId`": `"$($UserDetail.RoleID)`",
         `"Locked`": false,
         `"Enabled`": true
        }" | ConvertFrom-Json | ConvertTo-json    # Just to make sure it is formatted right, and any missing parameters dont skew the next statement!

        if ($body){
            $Rtn=Invoke-WebRequest -Uri "https://$($OMEServer)$($URIToAdd)" -UseBasicParsing -Method Put -Body $body -Headers $Headers -ContentType "application/json"
            if ($Rtn.StatusCode -eq 200) {
                Write-Verbose "Password reset for '$($UserDetail.UserName)' successful."
            } else {
                Write-Error "Reset password failed..."
            }
        } else {
            write-host "Payload missing.. unable to send to API."
        }
    } else {
        write-host "Existing user detail to reset could not be found using the API. Ensure the username specified is a LOCAL account, AD integrated accounts cannot be reset here."
    }
} else {
    Write-Error "Issues accessing API."
    $Usercall
}

# Tidy up and close the API session - resource is finite!
$SessClose = CloseOMESession -OMEServer $OMEServer -SessionId $OMESession.SessionId
switch ($SessClose.StatusCode) {
    204     { write-host "API Session Closed."}
    202     { write-host "Session close pending.."}
    default { write-host "Unknown session close state.. $($Sessclose.StatusCode)"}
}


