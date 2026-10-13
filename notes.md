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
```
https://docs.redhat.com/en/documentation/red_hat_developer_hub/1.7/html/authentication_in_red_hat_developer_hub/enabling-user-authentication-with-microsoft-azure
```
