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
| OIDC authentication | ✅ All three jobs use `azure/login@v2` — no long-lived secrets |
| Parameter file | ✅ `infra/main.bicepparam` holds all production values |

---

## Repository layout

```
StrivoApp/
├── .github/
│   └── workflows/
│       └── main_dataconsumerdemo.yml   # CI/CD pipeline (build → infra → deploy)
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

1. **Create or reuse a service principal / app registration** in Azure AD.
2. **Add a federated credential** on the app registration:
   - *Issuer*: `https://token.actions.githubusercontent.com`
   - *Subject*: `repo:SkillAcademyAB/StrivoApp:ref:refs/heads/main`
   - *Audience*: `api://AzureADTokenExchange`
3. **Assign the `Contributor` role** to the service principal on the `rg-day1-bear` resource group.
4. Add the three secrets above to the GitHub repository.

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
- [ ] Create federated credential on the service principal and assign `Contributor` role (see Azure prerequisites above).
- [ ] Trigger the workflow on this branch to validate the Bicep deployment end-to-end.
- [ ] Open a GitHub Issue to track environment promotion (`dev` → `staging` → `production` with separate `.bicepparam` files and workflow environment gates).
- [ ] Open a GitHub Issue to track Key Vault integration for sensitive app settings.