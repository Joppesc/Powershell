# Azure AD SAML Enterprise App Setup

This PowerShell script automates creating a **non-gallery Enterprise Application** (service principal) in Azure AD with SAML-based single sign-on.  It registers the app, generates or uploads a SAML signing certificate, configures the SAML **Entity ID** (Identifier) and **Reply URL**, assigns any required groups or app roles, and attaches a **Claims Mapping Policy** to customize the token claims.

## Major Steps

* **Create the Service Principal:** Register a new Azure AD enterprise app (non-gallery) and create a service principal with SAML enabled.
* **Configure SAML SSO:** Set the Identifier (Entity ID) and Reply URL for SAML, and add the signing certificate (self-signed or provided).
* **Assign Groups/Roles:** (Optional) Assign user groups or app roles so Azure AD will include those claims or enforce access controls.
* **Apply Claims Mapping Policy:** Define additional SAML claims (e.g. user attributes) via a claims mapping policy and assign it to the service principal.

## Defining a Claims Mapping Policy (Portal + DevTools)

Azure’s docs on the exact JSON schema for a claims mapping policy are limited, so a practical workaround is to create/edit the policy in the portal and capture the resulting network request.  Follow these steps:

1. **Create or edit the policy in the Azure portal.**  In the Entra ID portal, open your Enterprise Application and go to the **User Attributes & Claims** (or **Token configuration**) blade.  Add or modify a claim mapping as needed (for example, map `user.mail` to a custom SAML claim name) and save.
2. **Capture the HTTP request.**  Press F12 to open the browser DevTools and go to the Network tab (ensure "Preserve log" is enabled).  Repeat the save action you did in step 1.  The portal will send a REST API request to create/update the claims policy.
3. **Save the network trace as HAR.**  In Chrome/Edge DevTools, right-click the list of network requests and select **Save as HAR with content**.  This saves all captured requests to a `.har` file.
4. **Extract the JSON payload.**  Open the HAR file in a text editor and search for `"ClaimsMappingPolicy"` or `"definition"`.  In the request payload, you will find the full policy JSON string.  It will look like this (with your values):

   ```json
   {"ClaimsMappingPolicy":{"Version":1,"IncludeBasicClaimSet":"true","ClaimsSchema":[
     {"Source":"user","ID":"mail","SamlClaimType":"urn:example:email"},
     {"Source":"user","ID":"department"}
   ]}}
   ```

   Here each entry in `ClaimsSchema` defines a claim to emit. `Source` and `ID` specify the user attribute (e.g. `user.mail`), and `SamlClaimType` (or `Value`) defines the outgoing SAML claim name or constant.  This exact JSON follows the Microsoft Graph schema for a claimsMappingPolicy.
5. **Use the JSON in your script.**  Copy the JSON string (taking care to escape quotes or wrap it as an array of strings per Graph API requirements).  For example, in PowerShell you might set:

   ```powershell
   $policyDefinition = '{"ClaimsMappingPolicy":{"Version":1,"IncludeBasicClaimSet":"true","ClaimsSchema":[{"Source":"user","ID":"mail","SamlClaimType":"urn:example:email"},{"Source":"user","ID":"department"}]}}'
   New-MgPolicyClaimMappingPolicy -Definition @($policyDefinition) -DisplayName "MyPolicy"
   ```

   Assign this policy to your service principal. Using the HAR payload ensures your JSON matches exactly what Azure expects, since the portal UI doesn’t expose the raw schema and official examples are minimal.
