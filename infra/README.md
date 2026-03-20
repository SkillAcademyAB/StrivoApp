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
| Entra ID app registration | ⏳ Created by `setup-azure-oidc.yml` bootstrap workflow (run once) |

---

## Repository layout

```
StrivoApp/
├── .github/
│   └── workflows/
│       ├── main_dataconsumerdemo.yml   # CI/CD pipeline (build → infra → deploy)
│       └── setup-azure-oidc.yml        # One-time bootstrap: creates app, SP, roles, federated credential
├── infra/
│   ├── aad-app.bicep                   # Entra ID app registration + service principal (IaC)
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

### Azure prerequisites (one-time bootstrap)

The `infra` and `deploy` jobs authenticate to Azure via OIDC (passwordless — no client secrets in GitHub).  
The app registration, service principal, and federated identity credential **do not need to exist beforehand** — the bootstrap workflow creates everything.

#### Step 1 — Create a temporary admin service principal

This is the only manual step (done once in Azure Portal or Azure CLI):

```sh
# Creates a SP with Contributor + User Access Administrator scoped to the
# resource group only.  The "Application Administrator" Entra ID directory
# role must also be assigned manually in the Azure Portal after this
# (Entra ID → Roles and administrators → Application Administrator →
# Add assignments → select "StrivoApp-bootstrap").
SUBSCRIPTION_ID="<your-subscription-id>"
RG="rg-day1-bear"

az ad sp create-for-rbac \
  --name "StrivoApp-bootstrap" \
  --role "Contributor" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG"

# Also grant User Access Administrator so the workflow can assign
# the Contributor role to the new DemoIaCApp service principal:
BOOTSTRAP_OBJ_ID=$(az ad sp show --display-name "StrivoApp-bootstrap" \
                     --query id -o tsv)
az role assignment create \
  --assignee "$BOOTSTRAP_OBJ_ID" \
  --role "User Access Administrator" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG"
```

Then **manually** assign the **Application Administrator** directory role in the Azure Portal:
Entra ID → Roles and administrators → Application Administrator → Add assignments → select `StrivoApp-bootstrap`.

Note the `az ad sp create-for-rbac` output values (`appId`, `password`, `tenant`).

#### Step 2 — Add bootstrap secrets to the repository

Go to **Settings → Secrets and variables → Actions → New repository secret** and add:

| Secret name | Value |
|---|---|
| `AZURE_ADMIN_CLIENT_ID` | `appId` from Step 1 |
| `AZURE_ADMIN_CLIENT_SECRET` | `password` from Step 1 |
| `AZURE_TENANT_ID` | `tenant` from Step 1 (or Azure AD → Overview → Tenant ID) |
| `AZURE_SUBSCRIPTION_ID` | Subscription → Overview → Subscription ID |

#### Step 3 — Run the bootstrap workflow

1. Go to **Actions → Bootstrap Azure Identity → Run workflow**.
2. Keep the default app name (`DemoIaCApp`) or change it.
3. Type **`yes`** in the confirm field and click **Run workflow**.

The workflow will create:
- An Entra ID app registration (`DemoIaCApp`)
- Its service principal
- A `Contributor` role assignment on `rg-day1-bear`
- A federated identity credential for the `main` branch

At the end of the run the job log prints:

```
AZURE_CLIENT_ID = <appId>
```

#### Step 4 — Add the final secret

Add the `AZURE_CLIENT_ID` value printed above as a repository secret:

| Secret name | Value |
|---|---|
| `AZURE_CLIENT_ID` | App registration client ID printed by the bootstrap workflow |

#### Step 5 — Done

Push to `main` (or manually trigger the deployment workflow).  
The `infra` and `deploy` jobs will now authenticate via OIDC automatically.

> The `AZURE_ADMIN_CLIENT_ID` and `AZURE_ADMIN_CLIENT_SECRET` secrets can be deleted after the bootstrap is complete — they are only needed for the one-time setup. Also delete or disable the `StrivoApp-bootstrap` service principal in Azure (Entra ID → App registrations → StrivoApp-bootstrap → Delete) to fully remove the elevated privileges.

#### Bicep alternative (`infra/aad-app.bicep`)

`infra/aad-app.bicep` declares the same app registration and service principal using the **Microsoft Graph Bicep extensibility provider** (Bicep CLI ≥ 0.33, preview feature).  
This can be deployed with:

```sh
az deployment sub create \
  --location swedencentral \
  --template-file infra/aad-app.bicep
```

> **Note:** `Microsoft.Azure.ActiveDirectory/b2cApplications` is the Azure AD **B2C** resource type and is not applicable here — OIDC federation for GitHub Actions uses standard Entra ID, which is managed via the `Microsoft.Graph` provider.

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

- [ ] Create a temporary admin service principal (Step 1 above) and add the four bootstrap secrets to the repository.
- [ ] Run the **Bootstrap Azure Identity** workflow with `confirm=yes` to create the app registration, service principal, role assignment, and federated credential.
- [ ] Add the `AZURE_CLIENT_ID` output value as a repository secret.
- [ ] Trigger the main deployment workflow on `main` to validate the Bicep deployment end-to-end.
- [ ] Delete the `AZURE_ADMIN_CLIENT_ID` and `AZURE_ADMIN_CLIENT_SECRET` secrets once bootstrap is complete.
- [ ] Delete or disable the `StrivoApp-bootstrap` service principal in Azure (Entra ID → App registrations → StrivoApp-bootstrap → Delete) to fully remove the elevated privileges from Azure.
- [ ] Open a GitHub Issue to track environment promotion (`dev` → `staging` → `production` with separate `.bicepparam` files and workflow environment gates).
- [ ] Open a GitHub Issue to track Key Vault integration for sensitive app settings.