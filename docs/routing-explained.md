# Reverse proxy routing

Nginx runs on the EC2 host. Only ports 80 and 443 are public; SSH is limited
to the operator's /32 and a temporary runner /32 during deployment. Compose
binds every published application and database port to 127.0.0.1.

| Incoming request | Upstream | URI forwarded |
| --- | --- | --- |
| / | 127.0.0.1:8080 | Original URI |
| /api/auth/* | 127.0.0.1:8001 | Original URI |
| /api/catalog/* | 127.0.0.1:8002 | Original URI |
| /api/orders and /api/orders/* | 127.0.0.1:8003 | Original URI |
| /api/auth/healthz | 127.0.0.1:8001 | /healthz |
| /api/catalog/healthz | 127.0.0.1:8002 | /healthz |
| /api/orders/healthz | 127.0.0.1:8003 | /healthz |
| Unknown /api/* | No upstream | 404 |

Exact health locations take precedence over prefix locations. The exact
/api/orders location handles the application's endpoint without a slash.
API proxy_pass directives have no URI suffix, preserving the application's
/api prefix. Adding a trailing slash would strip the matched prefix and
break these APIs. Health aliases deliberately supply /healthz instead.
See the [Nginx proxy_pass documentation](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass).

Orders calls auth-service:8000 and catalog-service:4000 internally through
Compose DNS. Host ports are only for the host's reverse proxy and diagnostics.
Host, client IP, forwarding chain, and original protocol headers are forwarded.
Frontend calls relative API paths so browser requests remain on the same origin.

meridian-http.conf is used for first certificate issuance.
configure_tls.sh obtains a certificate with Certbot and installs the
hand-written HTTPS template, which redirects HTTP to the fixed domain and
allows TLS 1.2/1.3. The reference file is a template, not an issued certificate.
Certbot's timer renews certificates and a deploy hook reloads Nginx.
The default HTTP challenge works through the redirect to HTTPS on renewal.

For local integration, docker-compose.test.yml adds an Nginx container on
localhost:8088 with equivalent routing through service names. Use this port
for the functional local storefront; port 8080 serves static HTML only.

Validate on EC2 with nginx -t, curl each health alias, run smoke_test.py
against HTTPS, and verify that HTTP returns 301 and a Location header
pointing to the HTTPS URL. Record browser padlock evidence separately.
