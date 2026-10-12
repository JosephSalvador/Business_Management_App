FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY Directory.Build.props ./
COPY src/Shared/BusinessOS.Shared.csproj src/Shared/
COPY src/Domain/BusinessOS.Domain.csproj src/Domain/
COPY src/Application/BusinessOS.Application.csproj src/Application/
COPY src/Infrastructure/BusinessOS.Infrastructure.csproj src/Infrastructure/
COPY src/Notifications/BusinessOS.Notifications.csproj src/Notifications/
COPY src/Localizations/BusinessOS.Localizations.csproj src/Localizations/
COPY src/Modules/Sales/BusinessOS.Modules.Sales.csproj src/Modules/Sales/
COPY src/API/BusinessOS.API.csproj src/API/
COPY src/Workers/BusinessOS.Workers.csproj src/Workers/

RUN dotnet restore src/API/BusinessOS.API.csproj
RUN dotnet restore src/Workers/BusinessOS.Workers.csproj

COPY src/ src/

RUN dotnet publish src/API/BusinessOS.API.csproj -c Release -o /app/api --no-restore
RUN dotnet publish src/Workers/BusinessOS.Workers.csproj -c Release -o /app/workers --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

RUN mkdir -p /app/storage

COPY --from=build /app/api /app/api
COPY --from=build /app/workers /app/workers
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/app/docker-entrypoint.sh"]
