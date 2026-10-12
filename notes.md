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
```
spec:
  networking:
    hostname: devspaces.platform.example.com
    domain: platform.example.com
    labels:
      router: platform
```
