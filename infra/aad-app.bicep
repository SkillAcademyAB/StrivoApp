// ============================================================
// StrivoApp — Azure AD App Registration + Service Principal
//
// Creates the Entra ID (Azure AD) application registration and
// its service principal.  The federated identity credential
// (GitHub Actions OIDC) is added by the bootstrap workflow:
//   .github/workflows/setup-azure-oidc.yml
//
// This template uses the Microsoft Graph Bicep extensibility
// provider (requires Bicep CLI >= 0.33 and opt-in below).
// Alternatively, run the bootstrap workflow which uses the
// Azure CLI and does not require any local Bicep tooling.
//
// NOTE: Microsoft.Azure.ActiveDirectory/b2cApplications is the
// Azure AD B2C resource type and is *not* applicable here.
// OIDC federation for GitHub Actions uses standard Entra ID,
// which is managed through the Microsoft.Graph provider below.
// ============================================================

extension microsoftGraph

@description('Display name for the Azure AD application.')
param appName string = 'DemoIaCApp'

var appUniqueName = toLower(replace(appName, ' ', '-'))

// ------------------------------------------------------------
// App registration
// ------------------------------------------------------------
resource aadApp 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: appUniqueName
  displayName: appName
  // No passwordCredentials block: the bootstrap workflow adds a
  // federated credential (OIDC), which is passwordless and does
  // not require a client secret at all.
}

// ------------------------------------------------------------
// Service principal — required for role assignments
// ------------------------------------------------------------
resource servicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: aadApp.appId
}

// ------------------------------------------------------------
// Outputs
// ------------------------------------------------------------
@description('Application (client) ID — add this as the AZURE_CLIENT_ID repository secret.')
output clientId string = aadApp.appId
