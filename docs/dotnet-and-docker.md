# .NET workflows and Dockerfile patterns

## Lint and test a .NET repo

```yaml
jobs:
  lint:
    uses: jmpa-io/pipelines/.github/workflows/10-lint.yml@<sha>
    with:
      dotnet: true
  test:
    uses: jmpa-io/pipelines/.github/workflows/20-test.yml@<sha>
    with:
      dotnet: true
```

Runs `make lint-csharp` / `make test-csharp` (from `Makefile.common.mk`) on the
runner via `actions/setup-dotnet`. No AWS or secrets are needed.
`dotnet-version` defaults to `10.0.x`.

## Dockerfile patterns (from jmpa-io/crozzle)

.NET API (chiseled, non-root, publish first with `dotnet publish`):

```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:10.0-noble-chiseled
WORKDIR /app
COPY dist/<svc>/publish/ ./
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "<svc>.dll"]
```

Static site / reverse proxy (non-root, listens on 8080):

```dockerfile
FROM nginxinc/nginx-unprivileged:1.27-alpine
COPY public/ /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
LABEL org.opencontainers.image.source="https://github.com/jmpa-io/<repo>"
```
