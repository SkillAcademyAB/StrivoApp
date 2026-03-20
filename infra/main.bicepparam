// ============================================================
// StrivoApp — Bicep parameter file (production)
// Target resource group: rg-day1-bear
//
// NOTE: This file contains the subscription ID as part of the
// App Service Plan resource ID. For a private/internal demo this
// is intentional (explicit values). If this repo is ever made
// public, move appServicePlanId to a GitHub Actions variable
// (vars.APP_SERVICE_PLAN_ID) and remove it from this file.
// ============================================================
using './main.bicep'

param siteName = 'DemoIaCApp'
param location = 'Sweden Central'
param appServicePlanId = '/subscriptions/03692fc9-40be-48b5-b035-4363056559bd/resourceGroups/rg-day1-bear/providers/Microsoft.Web/serverfarms/asp-dataconsumer'
