## Build Jenkins
docker compose build --no-cache
docker compose build

## Start Jenkins
docker compose up -d
docker compose down -v

## Verify
docker ps

## Should show
jenkins-jcasc

## Open
http://localhost:8080

## Login
Username : admin
Password : admin123


## For a production-grade setup, keep three repositories:

```
jenkins-config
    ├── Dockerfile
    ├── plugins.txt
    └── jenkins.yaml

jenkins-seed-jobs
    ├── folders/
    ├── pipelines/
    └── shared/

jenkins-shared-library
    ├── vars/
    ├── src/
    └── resources/
```

This cleanly separates:
- Configuration (JCasC)
- Job definitions (Job DSL)
- Pipeline logic (Shared Library)