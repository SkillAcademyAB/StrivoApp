# Infrastructure as Code — Path Forward

## Overview

This directory contains the **Bicep** Infrastructure-as-Code (IaC) definition for StrivoApp's Azure hosting environment.  
The goal is to make the infrastructure **reproducible, version-controlled, and automated** so that every merge to `main` deploys both the application _and_ the underlying cloud resources in a single, auditable pipeline.

---

## Current state

| Concern | Status |
|---|---|
| App build & deploy | ✅ GitHub Actions workflow exists (`main_dataconsumerdemo.yml`) |
| Infrastructure provisioning | 🆕 Bicep template added (`infra/main.bicep`) |
| IaC deployment in CI/CD | 🆕 `infra` job added to the existing workflow |
| App Service Plan | ⚠️ Referenced by external resource ID — see [open decisions](#open-decisions) |

---

## Repository layout

```
StrivoApp/
├── .github/
│   └── workflows/
│       └── main_dataconsumerdemo.yml   # CI/CD pipeline (build → infra → deploy)
├── infra/
│   ├── main.bicep                      # Azure Web App + config resources
│   └── README.md                       # This file
└── src/
    └── StrivoApp.Api/                  # ASP.NET Core 10 application
```

---

## Bicep template (`main.bicep`)

### Resources declared

| Resource type | Name | Purpose |
|---|---|---|
| `Microsoft.Web/sites` | `DataConsumerDemo` | The App Service Web App |
| `Microsoft.Web/sites/basicPublishingCredentialsPolicies` | `ftp` | FTP publishing policy |
| `Microsoft.Web/sites/basicPublishingCredentialsPolicies` | `scm` | SCM (Kudu) publishing policy |
| `Microsoft.Web/sites/config` | `web` | App Service configuration (runtime, TLS, etc.) |

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `siteName` | `DataConsumerDemo` | Web App name — override per environment |
| `appServicePlanId` | _(required)_ | Resource ID of the App Service Plan to use |
| `location` | `Sweden Central` | Azure region |

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
    │  infra  │  az deployment group create (Bicep)
    └────┬────┘
         │
         ▼
    ┌─────────┐
    │  deploy │  azure/webapps-deploy → app artifact
    └─────────┘
```

### Required GitHub Secrets / Variables

| Name | Type | Purpose |
|---|---|---|
| `AZURE_CLIENT_ID` | Secret | Service principal / workload identity client ID |
| `AZURE_TENANT_ID` | Secret | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Secret | Target Azure subscription |
| `AZURE_RESOURCE_GROUP` | Variable | Resource group that hosts the Web App |
| `APP_SERVICE_PLAN_ID` | Variable | Full resource ID of the App Service Plan |
| `AZUREAPPSERVICE_PUBLISHPROFILE_*` | Secret | Publish profile for app deployment (existing) |

> **Recommended**: Replace the publish-profile secret with **OIDC / federated credentials** (`azure/login@v2`) for a secretless authentication flow. The `infra` job already uses OIDC.

---

## Open decisions

1. **App Service Plan ownership** — The current template references an _existing_ plan by resource ID.  
   Options:
   - Keep it external (shared plan, lower cost).
   - Add a `Microsoft.Web/serverfarms` resource to `main.bicep` so the plan is also managed as code.

2. **Environment promotion** — Should we have `dev` → `staging` → `production` stages?  
   This can be modelled with Bicep parameter files (`main.dev.bicepparam`, `main.prod.bicepparam`) and workflow environment gates.

3. **Secrets management** — Consider moving app settings into **Azure Key Vault** and referencing them as Key Vault references from the App Service configuration.

4. **Publish profile vs. OIDC** — The deploy job still uses a publish-profile secret. Migrating to `azure/login` with OIDC removes the need to rotate that secret.

5. **Resource group creation** — The pipeline assumes the resource group already exists. A `az group create --if-not-exists` step (or a separate Bicep subscription-scoped deployment) can make the pipeline fully self-contained.

---

## Next steps (suggested order)

- [ ] Add `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`, and `APP_SERVICE_PLAN_ID` to the repository secrets/variables.
- [ ] Run the workflow on a feature branch to validate the Bicep deployment (`what-if` mode first).
- [ ] Decide whether to own the App Service Plan in Bicep (see open decision 1).
- [ ] Add Bicep parameter files per environment.
- [ ] Replace publish-profile authentication with OIDC.
- [ ] Add Key Vault integration for sensitive app settings.
- [ ] Consider adding a `Microsoft.Web/serverfarms` (App Service Plan) resource to the template.
