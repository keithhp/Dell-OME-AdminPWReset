# Dell-OME-AdminPWReset
> Written by Keith Hensby-Peck (2023-09-22)
> 
> Tesed on Dell OpenManage Enterprise v3.10.32B13

A quick PowerShell to allow for the reset of the admin password within a virtual v-app deployment of OME when it is unknown.

Allows for the rescue of the admin account without needing to wipe and reinstall a vanilla OME deployment in its place.

Tested and applicable to : Dell OpenManage Enterprise (OME) Virtual Machine deployments on ESXi running version 3.10.32
( It may work on other deployments, but I don't have other types of deployments to test it with! )

As of version 3.10.32(Build 13), when logging in with credentials that have administration rights, you cannot update the "admin" account using the UI.

Most installations of OME will have secondary user account with administration rights even if these are local or AD integrated, but these account also cannot use the UI to update the "admin" password.
> **Note:** If all you have is one account - the "admin" account, this script WILL NOT HELP YOU and your only choice is Dells recommendation to re-deploy a vanilla instance.

The only location where you can update the "admin" account password (according to the documentation) is using the virtual machine console, which you still need the existing password to do, and if this password is unknown, Dell's official stance is to delete the VM and redeploy a vanilla instance, and to ensure that the password does not get forgotten after it has been typed in.


This script uses existing and "supported by Dell" methods to reset the "admin" account password. It does not use exploits or any direct file manipulation to update the password.

You will still need administration role access to the OME deployment, but as most installations use secondary admin accounts, this should not be an issue.
 
 
 
**Process:**
- Download the script
- Log into OME using a known administration account (local or AD, does not matter, you just need administration role rights)
- Create a new LOCAL administration role account called whatever you like with a password you know.
- Run the powershell script
  - You will be asked to enter the name or IP of the OME Server
  - You will be asked for the credentials of the account you created to use when resetting the account.    This has been tested with LOCAL accounts only..
  - You will be asked for the password to reset the "admin" account to..  You CAN change the username at this point if you wish to reset a different account other than "admin".
- Once the password is reset, the account you created to do this with can be deleted from OME.
 
 
  
**What Happens when you run the script:**
- The script will create an API Session with the OME Server using the given credentials that it asks for.
- It will call the API to /api/AccountService/Accounts to get the internal ID of the account you provided the new password for (if you amended the username, it will look for that account instead of "admin")
- Using that ID, it will then build a payload to PUT to the API using the given odata links to update the existing account details.
    - The payload includes the string to update the password, as well as keeping all other details the same.
    - The payload also enables the account if needed, and also unlocks it.



**Note from the author:**
The main reason I wrote this was to recover the admin password of a very well established and multiply upgraded OME instance, which has been in service for many many years with A LOT of monitored devices. After a network change to extend the subnet, the IPv4 details within OME needed to be updated, which the admin account was needed for -
- It was at this point it was found out that nobody (other than who deployed it) knew the admin password..  and they were not around to ask!

This does however lead to other uses for this script....  or modified versions of the script..
- As this can update the admin account password to a known value, it can be re-written to update it to an unknown RANDOM value, possibly daily to comply with security policies, or after the account is used.  As you cannot disable the admin account, you can ensure that no one will ever know the password for it and use it..  and of needed, use this to reset it back to a know value again, and then randomise it once more when no longer required.

I'm not the tidiest coder..  and this was written in a rush so forgive any code that doesn't follow industry practise ;)

