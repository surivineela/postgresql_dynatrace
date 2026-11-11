# Backend Dockerfile for direct Container Apps deployment
FROM mcr.microsoft.com/dotnet/aspnet:9.0-azurelinux3.0-distroless-extra AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src
COPY ["backend/Octopets.Backend.csproj", "backend/"]
COPY ["servicedefaults/Octopets.ServiceDefaults.csproj", "servicedefaults/"]
RUN dotnet restore "backend/Octopets.Backend.csproj"
COPY backend/ backend/
COPY servicedefaults/ servicedefaults/
WORKDIR "/src/backend"
RUN dotnet build "Octopets.Backend.csproj" -c $BUILD_CONFIGURATION -o /app/build

FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "Octopets.Backend.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

FROM base AS final
ARG SOURCE_REVISION=unknown
LABEL org.opencontainers.image.source="https://github.com/surivineela/postgresql_dynatrace" \
	org.opencontainers.image.revision=$SOURCE_REVISION
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Octopets.Backend.dll"]