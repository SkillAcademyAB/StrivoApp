# Infrastructure as Code — Path Forward

## Overview

This directory contains the **Bicep** Infrastructure-as-Code (IaC) definition for StrivoApp's Azure hosting environment.  
The goal is to make the infrastructure **reproducible, version-controlled, and automated** so that every merge to `main` deploys both the application _and_ the underlying cloud resources in a single, auditable pipeline.

---

## Current state

| Concern | Status |
|---|---|
| App build & deploy | ✅ GitHub Actions workflow (`main_dataconsumerdemo.yml`) |
| Infrastructure provisioning | ✅ Bicep template (`infra/main.bicep`) |
| IaC deployment in CI/CD | ✅ `infra` job wired into the pipeline |
| App Service Plan | ✅ Shared external plan `asp-dataconsumer` in `rg-day1-bear` |
| OIDC authentication | ✅ All three jobs use `azure/login@v3` — no long-lived secrets |
| Parameter file | ✅ `infra/main.bicepparam` holds all production values |

---

## Repository layout

```
StrivoApp/
├── .github/
│   └── workflows/
│       ├── main_dataconsumerdemo.yml   # CI/CD pipeline (build → infra → deploy)
│       └── setup-azure-oidc.yml        # One-time bootstrap: creates federated credential
├── infra/
│   ├── main.bicep                      # Azure Web App + config resources
│   ├── main.bicepparam                 # Production parameter values
│   └── README.md                       # This file
└── src/
    └── StrivoApp.Api/                  # ASP.NET Core 10 application
```

---

## Bicep template (`main.bicep`)

### Resources declared

| Resource type | Name | Purpose |
|---|---|---|
| `Microsoft.Web/sites` | `DemoIaCApp` | The App Service Web App |
| `Microsoft.Web/sites/basicPublishingCredentialsPolicies` | `ftp` | FTP publishing policy (disabled) |
| `Microsoft.Web/sites/basicPublishingCredentialsPolicies` | `scm` | SCM (Kudu) publishing policy (disabled) |
| `Microsoft.Web/sites/config` | `web` | App Service configuration (runtime, TLS, etc.) |

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `siteName` | `DemoIaCApp` | Web App name |
| `appServicePlanId` | _(required)_ | Resource ID of the App Service Plan to use |
| `location` | `Sweden Central` | Azure region |

Production values are supplied by `infra/main.bicepparam`.

### Key configuration choices

- **HTTPS only** — `httpsOnly: true`
- **TLS 1.2 minimum** for both app and SCM endpoints
- **FTPS only** for FTP publishing (`ftpsState: FtpsOnly`)
- **Basic publishing credentials disabled** — both FTP and SCM basic auth (`allow: false`) because the CI/CD pipeline uses OIDC authentication
- **.NET 10** runtime (`netFrameworkVersion: v10.0`)
- **Always On** enabled
- Public network access enabled (restrict with IP rules as needed)

---

## CI/CD pipeline

The workflow (`.github/workflows/main_dataconsumerdemo.yml`) runs three sequential jobs on every push to `main`:

```
push → main
         │
         ▼
    ┌─────────┐
    │  build  │  dotnet build + publish → upload artifact
    └────┬────┘
         │
         ▼
    ┌─────────┐
    │  infra  │  Bicep --what-if preview, then incremental deploy to rg-day1-bear
    └────┬────┘
         │
         ▼
    ┌─────────┐
    │  deploy │  azure/webapps-deploy (OIDC, no publish-profile)
    └─────────┘
```

### Required GitHub Secrets

These three secrets must be added to the repository (**Settings → Secrets and variables → Actions → New repository secret**):

| Secret name | Where to find it |
|---|---|
| `AZURE_CLIENT_ID` | App registration → Overview → Application (client) ID |
| `AZURE_TENANT_ID` | Azure Active Directory → Overview → Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Subscription → Overview → Subscription ID |

> No `AZURE_RESOURCE_GROUP` variable is needed — the resource group `rg-day1-bear` is hardcoded in the workflow and the parameter file.

### Azure prerequisites (one-time setup)

The `infra` and `deploy` jobs authenticate to Azure via OIDC (no passwords).  
This requires a **federated identity credential** to exist on the Azure AD app registration.

#### Automated setup (recommended)

A dedicated workflow automates this one-time step:

1. Create a **temporary client secret** on the app registration (Azure Portal → App Registrations → *your app* → Certificates & secrets → New client secret).
2. Add four secrets to the GitHub repository (**Settings → Secrets and variables → Actions**):
   | Secret name | Value |
   |---|---|
   | `AZURE_CLIENT_ID` | Application (client) ID |
   | `AZURE_TENANT_ID` | Azure AD Tenant ID |
   | `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID |
   | `AZURE_CLIENT_SECRET` | The temporary client secret from step 1 |
3. Go to **Actions → "Setup Azure OIDC Federated Credential" → Run workflow**, type `yes` in the confirmation field, and click **Run workflow**.
4. Once the workflow succeeds, **delete the `AZURE_CLIENT_SECRET`** secret from the repository — it is no longer needed.
5. The main deployment workflow will now authenticate via OIDC.

#### Manual setup (alternative)

Run the following Azure CLI command locally (requires `Application Administrator` or app **Owner** rights):

```sh
az ad app federated-credential create \
  --id "<AZURE_CLIENT_ID>" \
  --parameters '{
    "name": "github-actions-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:SkillAcademyAB/StrivoApp:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

3. **Assign the `Contributor` role** to the service principal on the `rg-day1-bear` resource group.
4. Add the three OIDC secrets above to the GitHub repository.

---

## Decisions made

| # | Decision | Choice |
|---|---|---|
| 1 | App Service Plan ownership | External/shared — `asp-dataconsumer` in `rg-day1-bear` |
| 2 | Authentication method | OIDC throughout — no publish-profile or passwords |
| 3 | Resource group | Existing `rg-day1-bear` — hardcoded for clarity |
| 4 | Bicep parameters | Single `main.bicepparam` file for production |
| 5 | Environment promotion | Deferred — tracked in [issue](https://github.com/SkillAcademyAB/StrivoApp/issues) |
| 6 | Key Vault secrets management | Deferred for a later iteration |

---

## Next steps (suggested order)

- [ ] Add `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` secrets to the repository (manual — GitHub Settings).
- [ ] Create federated credential using the **Setup Azure OIDC Federated Credential** workflow (see Azure prerequisites above).
- [ ] Assign `Contributor` role to the service principal on the `rg-day1-bear` resource group.
- [ ] Trigger the main deployment workflow on `main` to validate the Bicep deployment end-to-end.
- [ ] Open a GitHub Issue to track environment promotion (`dev` → `staging` → `production` with separate `.bicepparam` files and workflow environment gates).
- [ ] Open a GitHub Issue to track Key Vault integration for sensitive app settings.