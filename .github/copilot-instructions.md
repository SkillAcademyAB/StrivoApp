# Copilot Instructions for StrivoApp

## Project Overview

StrivoApp is a minimal ASP.NET Core 10 REST API that demonstrates clean layered architecture, dependency injection, and automated cloud deployment to Azure App Service.

## Repository Structure

```
StrivoApp/
├── .github/
│   └── workflows/          # GitHub Actions CI/CD pipelines
├── infra/                  # Bicep Infrastructure-as-Code templates
└── src/
    └── StrivoApp.Api/
        ├── Controllers/    # HTTP endpoints (routing, request/response mapping)
        ├── Services/       # Business logic layer
        ├── Data/           # Repository layer (data access)
        └── Models/         # DTOs and entity models
```

## Tech Stack

- **Language:** C# with nullable reference types enabled and implicit usings
- **Framework:** ASP.NET Core 10 (`net10.0`)
- **API Documentation:** Swagger/OpenAPI via Swashbuckle (served at `/`)
- **Cloud Platform:** Azure App Service
- **Infrastructure:** Bicep (Azure Resource Manager)
- **CI/CD:** GitHub Actions with OIDC authentication to Azure

## Architecture

The API follows a clean 3-tier layered architecture with dependency injection:

1. **Controllers** (`Controllers/`) – Handle HTTP routing, validate input, and return appropriate status codes. Inject `IItemService`.
2. **Services** (`Services/`) – Contain business logic. Implement interfaces (e.g. `IItemService`). Inject `IItemRepository`.
3. **Repository** (`Data/`) – Manage data persistence. Currently in-memory with thread-safe locking. Implement interfaces (e.g. `IItemRepository`).
4. **Models** (`Models/`) – Define entities (e.g. `Item`) and request DTOs (`CreateItemRequest`, `UpdateItemRequest`).

Dependency injection is configured in `Program.cs`:
- Repositories are registered as `Singleton` (shared in-memory store).
- Services are registered as `Scoped` (per-request lifetime).

## Build Instructions

```bash
# Build the project
dotnet build src/StrivoApp.Api/StrivoApp.Api.csproj

# Build in Release configuration
dotnet build src/StrivoApp.Api/StrivoApp.Api.csproj --configuration Release

# Publish for deployment
dotnet publish src/StrivoApp.Api/StrivoApp.Api.csproj -c Release -o ./output
```

## Running Locally

```bash
dotnet run --project src/StrivoApp.Api/StrivoApp.Api.csproj
```

The Swagger UI will be available at the root URL (e.g. `https://localhost:PORT/`).

## Testing

There is currently no test project. When adding tests:
- Place test projects under `src/` alongside the API project (e.g. `src/StrivoApp.Api.Tests/`).
- Use xUnit as the test framework, consistent with the .NET ecosystem conventions.
- Run tests with `dotnet test`.

## Coding Conventions

- Follow standard C# naming conventions (PascalCase for types and public members, camelCase for local variables).
- All new interfaces must be prefixed with `I` (e.g. `IItemService`, `IItemRepository`).
- Enable nullable reference types; handle or annotate all nullable return values.
- Annotate controller actions with `[ProducesResponseType]` attributes for all possible HTTP status codes.
- Keep controllers thin – delegate business logic to the service layer.
- Keep services free of HTTP concerns – they must not reference `HttpContext` or `IActionResult`.
- New entities and DTOs go in `Models/`.
- New endpoints go in `Controllers/` following the existing `ItemsController` pattern.

## Infrastructure

The `infra/` directory contains Bicep templates for the Azure environment:
- `main.bicep` – App Service Plan and Web App definition.
- `main.bicepparam` – Production parameter values.
- `aad-app.bicep` – Microsoft Entra ID app registration definition.

Refer to `infra/README.md` for bootstrap and deployment instructions.

## CI/CD

The main pipeline (`.github/workflows/main_dataconsumerdemo.yml`) runs on every push to `main`:
1. **build** – Builds and publishes the API.
2. **infra** – Deploys Bicep templates to Azure (resource group `rg-day1-bear`).
3. **deploy** – Deploys the published artifact to Azure App Service (`DemoIaCApp`).
