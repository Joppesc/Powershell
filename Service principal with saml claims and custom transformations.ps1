# Fill variables with your tenant and application details
$TenantID = "fill in" # Your Azure AD tenant ID
$SPNName = "fill in" # Display name for the Service Principal
$group = 'fill in' # Name of the group to be assigned to the Service Principal
$groupdiscription = "fill in" # Description of the group
$notificationmail = "fill in" # Email for certificate expiry notifications
$IdentifierUri = 'https://engine.govconext.nl/authentication/sp/metadata' # Identifier URI for the application
$ReplyUri = 'https://engine.govconext.nl/authentication/sp/consume-assertion' # Reply URL for the application
$LoginUri = 'https://engine.govconext.nl/authentication/sp/debug' # Login URL for the application
$Graphroles = "Application.ReadWrite.All", "Policy.Read.All", "Policy.ReadWrite.ApplicationConfiguration", "Group.Create" # Graph roles needed to assign to the authenticated service principal

# Connect to Microsoft Graph using certificate-based authentication
Connect-MgGraph -scopes $Graphroles -TenantId $TenantID

# Template ID for non-gallery applications
$applicationTemplateId = "8adf8e6e-67b2-4cf2-a259-e3dc5476c621"

# Instantiate the application template with the specified display name
Invoke-MgInstantiateApplicationTemplate -ApplicationTemplateId $applicationTemplateId -DisplayName $SPNName

# Wait for the application and service principal to be fully created
Start-Sleep -Seconds 60

# Retrieve the newly created Service Principal
$SPN = Get-MgServicePrincipal -Filter "DisplayName eq '$SPNName'"

# Retrieve the associated Application Registration
$createdAppReg = Get-MgApplication -Filter "DisplayName eq '$SPNName'" | Select-Object *

# Check if the group already exists; create it if it doesn't
if ($APPGroup = Get-MgGroup -Filter "displayname eq '$group'") 
{
    Write-Host "Group already exists"
} else 
    {
        # Define parameters for the group to be created
        $groupparam = @{
        description     = $groupdiscription # Description of the group
        displayName     = $group
        groupTypes      = @()
        mailEnabled     = $false
        mailNickname    = $spnName
        securityEnabled = $true
    }
    
    $APPGroup = New-MgGroup -BodyParameter $groupparam
    Start-Sleep -Seconds 30
}

# Prepare parameters to assign the group to the Service Principal with the 'User' role
$Groupassignmentparams = @{
    PrincipalId = $APPGroup.id
    ResourceId  = $SPN.Id
    AppRoleId   = ($SPN.AppRoles | Where-Object { $_.DisplayName -eq 'User' }).Id
}

# Assign the group to the Service Principal
New-MgGroupAppRoleAssignment -GroupId $APPGroup.id -BodyParameter $Groupassignmentparams

# Set Single Sign-On mode to SAML
$params = @{
    preferredSingleSignOnMode = "saml"
}

Update-MgServicePrincipal -ServicePrincipalId $SPN.id -BodyParameter $params

# Update the Application with Identifier URI and Reply URL
$params = @{
    identifierUris = @($IdentifierUri)
    web = @{
        redirectUris = @($ReplyUri)
    }
}

Update-MgApplication -ApplicationId $createdAppReg.Id -BodyParameter $params

# Add a token signing certificate to the Service Principal
Add-MgServicePrincipalTokenSigningCertificate -ServicePrincipalId $SPN.id -ErrorAction SilentlyContinue
Start-Sleep -Seconds 5

# Update the Service Principal with notification email and login URL
$params = @{
    NotificationEmailAddresses = $notificationmail # Email for certificate expiry notifications
    LoginUrl                   = $LoginUri          # Sign-on URL parameter
    SamlSingleSignOnSettings   = "saml"
}

Update-MgServicePrincipal -ServicePrincipalId $SPN.id -BodyParameter $params


# Define claims mapping policy parameters
$claimMappingPolicyParams = @{
    definition = @(
@"
{
    "ClaimsMappingPolicy": {
        "Version": 1,
        "IncludeBasicClaimSet": false,
        "claimsSchema": [
            {
                "samlClaimType": "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier",
                "samlNameIdFormat": "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress",
                "source": "User",
                "id": "userprincipalname"
            },
            {
                "samlClaimType": "urn:mace:dir:attribute-def:uid",
                "source": "user",
                "id": "userprincipalname"
            },
            {
                "samlClaimType": "urn:mace:dir:attribute-def:givenName",
                "source": "user",
                "id": "givenname"
            },
            {
                "samlClaimType": "urn:mace:dir:attribute-def:displayName",
                "source": "user",
                "id": "displayname"
            },
            {
                "samlClaimType": "urn:mace:dir:attribute-def:sn",
                "source": "user",
                "id": "surname"
            },
            {
                "samlClaimType": "urn:mace:dir:attribute-def:cn",
                "source": "user",
                "id": "displayname"
            },
            {
                "samlClaimType": "urn:mace:dir:attribute-def:eduPersonPrincipalName",
                "source": "user",
                "id": "userprincipalname"
            },
            {
                "samlClaimType": "urn:mace:dir:attribute-def:mail",
                "source": "user",
                "id": "mail"
            },
            {
                "samlClaimType": "urn:mace:dir:attribute-def:preferredLanguage",
                "source": "user",
                "id": "preferredlanguage"
            },
            {
                "samlClaimType": "urn:mace:dir:attribute-def:eduPersonAffiliation",
                "value": "employee"
            },
            {
                "samlClaimType": "urn:mace:terena.org:attribute-def:schacHomeOrganization",
                "source": "transformation",
                "id": "outputClaim-schachome-extract",
                "transformationId": "schachome-extract"
            },
            {
                "samlClaimType": "urn:mace:dir:attribute-def:eduPersonScopedAffiliation",
                "source": "transformation",
                "id": "outputclaim-edupersonscopedaffiliation-regexreplace",
                "transformationId": "edupersonscopedaffiliation-regexreplace"
            }
        ],
        "claimsTransformations": [
            {
                "transformationMethod": "RegexReplace",
                "id": "schachome-extract",
                "inputParameters": [
                    {
                        "id": "regex",
                        "value": "^.*?@(?'captureGroup'.*)$"
                    },
                    {
                        "id": "replacement",
                        "value": "{captureGroup}"
                    }
                ],
                "parameters": [
                    {
                        "name": "sourceClaim",
                        "required": true
                    }
                ],
                "inputClaims": [
                    {
                        "treatAsMultiValue": false,
                        "claimTypeReferenceSource": "user",
                        "claimTypeReferenceId": "userprincipalname",
                        "transformationClaimType": "sourceClaim"
                    }
                ],
                "outputClaims": [
                    {
                        "claimTypeReferenceId": "outputClaim-schachome-extract",
                        "transformationClaimType": "outputClaim"
                    }
                ]
            },
            {
                "transformationMethod": "RegexReplace",
                "id": "edupersonscopedaffiliation-regexreplace",
               "inputParameters": [
                    {
                        "id": "regex",
                        "value": "^.*\\@(?'domain')"
                    },
                    {
                        "id": "replacement",
                        "value": "employee@{domain}"
                    }
                ],
                "parameters": [
                    {
                        "name": "sourceClaim",
                        "required": true
                    }
                ],
                "inputClaims": [
                    {
                        "treatAsMultiValue": false,
                        "claimTypeReferenceSource": "user",
                        "claimTypeReferenceId": "userprincipalname",
                        "transformationClaimType": "sourceClaim"
                    }
                ],
                "outputClaims": [
                    {
                        "claimTypeReferenceId": "outputclaim-edupersonscopedaffiliation-regexreplace",
                        "transformationClaimType": "outputClaim"
                    }
                ]
            }
        ]
    }
}
"@
    )
    displayName          = $SPNName
    IsOrganizationDefault = $false
}

# Create a new claims mapping policy
$claimMappingPolicy = New-MgPolicyClaimMappingPolicy -BodyParameter $claimMappingPolicyParams
Start-Sleep -Seconds 5

# Associate the claims mapping policy with the Service Principal
$Setclaimsparam = @{
    "@odata.id" = "https://graph.microsoft.com/v1.0/policies/claimsMappingPolicies/$($claimMappingPolicy.id)"
}

New-MgServicePrincipalClaimMappingPolicyByRef -ServicePrincipalId $SPN.id -BodyParameter $Setclaimsparam
