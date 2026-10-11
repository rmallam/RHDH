```
appConfig:
  auth:
    environment: development
    providers:
      guest:
        dangerouslyAllowOutsideDevelopment: true
  permission:
    enabled: true
    rbac:
      admin:
        users:
          - name: user:development/guest
  ```
