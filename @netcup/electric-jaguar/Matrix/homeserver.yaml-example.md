[Generate configuration for the Matrix Synapse Service](../../../how-to%60s/matrix.md#generate-home-server-configuration), adjusting the parameters as shown below.
```yaml
...
database:
  name: psycopg2
  allow_unsafe_locale: true
  args:
    user: synapse
    password: "<synapse>"
    database: synapse
    host: matrix-postgresql
    port: 5432
    cp_min: 5
    cp_max: 10
...
matrix_authentication_service:
  enabled: true
  endpoint: http://matrix-auth:8080/
  secret: "<secret>"
...
enable_registration: false
enable_registration_without_verification: false
```