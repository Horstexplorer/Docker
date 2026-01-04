[Generate configuration for the Matrix Authentication Service](../../../how-to%60s/matrix.md#generate-matrix-auth-configuration), adjusting the parameters as shown below.
```yaml
http:
  listeners:
  - name: web
    resources:
    ...
    - name: adminapi
  public_base: https://<auth>.<domain.tld>
  issuer: https://<auth>.<domain.tld>
...
database:
  host: matrix-postgresql
  port: 5432
  database: matrixauthenticationservice
  username: matrixauthenticationservice
  password: "<matrixauthenticationservice>"
  max_connections: 10
  min_connections: 1
  connect_timeout: 30
  idle_timeout: 600
  max_lifetime: 1800
...
email:
  from: '"Authentication Service" <matrix@<domain.tld>'
  reply_to: '"Authentication Service" <matrix@<domain.tld>>'
  transport: blackhole
...
secrets:
  ...
  matrix:
    kind: synapse
    homeserver: <domain.tld>
    secret: <secret>
    endpoint: http://matrix-synapse:8008/
```