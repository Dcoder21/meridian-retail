# Deployment runbook

## 1. Provision AWS

Use an authorized AWS account with Terraform credentials on your workstation.
No AWS access keys are stored in this repository.

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Set operator public IPv4 /32, SSH public key, and GitHub owner/repository.
terraform -chdir=terraform init
terraform -chdir=terraform plan -out=meridian.tfplan
terraform -chdir=terraform apply meridian.tfplan
terraform -chdir=terraform output
```

Terraform creates a custom VPC, public and isolated private subnets, internet
gateway, public route, Ubuntu 22.04 EC2 instance, encrypted gp3 disk, Elastic IP,
four immutable ECR repositories, and an EC2 profile limited to pulling those
repositories. ECR authorization-token permission uses Resource "*" because
AWS does not support a repository resource for that action; layer/image actions
are scoped to repository ARNs. See [AWS ECR permissions](https://docs.aws.amazon.com/AmazonECR/latest/userguide/security_iam_id-based-policy-examples.html).

The private subnet has no internet route or NAT. The single host remains a
single point of failure. Changing user_data replaces the instance; this can
lose locally stored data. Back up off-host before any replacement. Protect
local Terraform state; adopt an encrypted remote backend with locking before
multiple operators use Terraform. State and plans are ignored by Git.

If your account already has a GitHub OIDC provider, supply its ARN through
existing_github_oidc_provider_arn rather than attempting to create another.
The deployment role trusts only this repository's main branch using GitHub's
standard subject format. See [GitHub AWS OIDC](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws).

## Local testing and workstation ECR push

Local builds do not require AWS. ECR repositories must exist before a push.
To follow the project schedule, complete Terraform provisioning first, then
run these commands from PowerShell:

```powershell
$env:COMPOSE_BAKE = 'false' # Workaround if Docker Desktop's Bake builder fails.
docker compose -f docker-compose.yml -f docker-compose.test.yml up -d --build --wait --wait-timeout 180
python scripts/smoke_test.py http://localhost:8088
.\scripts\test_local.ps1
.\scripts\push_ecr.ps1 -Profile default -Region eu-west-2 -Prefix meridian
```

The local test script runs the storefront journey and an isolated PostgreSQL
restore rehearsal, saving evidence/local-restore.txt. It uses docker cp to
preserve binary archives on Windows PowerShell. The Linux cron scripts remain
the production backup path and are verified separately in CI/on EC2.

The push script verifies that all four repositories are immutable, builds
linux/amd64 images locally, logs into ECR through the selected AWS CLI profile,
pushes unique tags, and logs out. The current working tree is included in the
images. Review and commit changes before treating a tag as a production release.
The workstation profile needs ECR push permissions; the EC2 role remains pull-only.

## 2. Bootstrap storefront

SSH to the Elastic IP as ubuntu. Wait for cloud-init to finish:

```bash
sudo cloud-init status --wait
cd /opt/meridian
git init
git remote add origin https://github.com/YOUR_OWNER/YOUR_REPOSITORY.git
git fetch origin main
git checkout -B main origin/main
cp .env.example .env
chmod 600 .env
# Edit DB_PASSWORD and JWT_SECRET with independently generated strong secrets.
# Set DOMAIN to your registered DuckDNS name. Leave ECR_REGISTRY blank initially.
docker compose up -d --build --wait --wait-timeout 180
```

For a private repository, transfer the checked-out files securely instead of
installing a personal access token on EC2. Application files are pre-built and
unchanged; local source builds bootstrap the first release before CI publishes
ECR images. Do not commit the production .env. Docker group access is equivalent
to root access; only the intended deployment user is granted membership.

## 3. DNS and TLS

Register a DuckDNS subdomain and update it to the Elastic IP. In Bash, read
the token without echoing it, then use the supplied updater:

```bash
read -rs -p 'DuckDNS token: ' DUCKDNS_TOKEN; echo
export DUCKDNS_TOKEN
bash scripts/update_duckdns.sh YOUR-SHOP YOUR_ELASTIC_IP
unset DUCKDNS_TOKEN
dig YOUR-SHOP.duckdns.org A +short
sudo bash scripts/configure_tls.sh YOUR-SHOP.duckdns.org YOUR_EMAIL
curl -I http://YOUR-SHOP.duckdns.org/
curl -I https://YOUR-SHOP.duckdns.org/
python3 scripts/smoke_test.py https://YOUR-SHOP.duckdns.org
```

DNS must resolve to the Elastic IP before certificate issuance. Remove an
unrelated AAAA record if present. Elastic IP avoids needing a periodic updater.
The updater follows the [DuckDNS HTTPS API](https://www.duckdns.org/spec.jsp).
The TLS script runs a renewal dry-run; inspect systemctl status certbot.timer
and verify the browser padlock. See [Certbot renewal guidance](https://certbot.eff.org/instructions?ws=nginx&os=ubuntufocal).

## 4. Configure GitHub Actions

Set repository Actions variables:

| Variable | Value |
| --- | --- |
| DEPLOY_ENABLED | Set to true only after provisioning and configuring the current host; false while infrastructure is removed |
| AWS_REGION | Terraform region, default eu-west-2 |
| AWS_DEPLOY_ROLE_ARN | github_role_arn output |
| ECR_REGISTRY | ecr_registry output |
| ECR_REPOSITORY_PREFIX | Terraform project, default meridian |
| EC2_HOST | ec2_public_ip output |
| EC2_SECURITY_GROUP_ID | security_group_id output |
| DOMAIN | YOUR-SHOP.duckdns.org |

Set repository Actions secrets:

| Secret | Value |
| --- | --- |
| EC2_SSH_PRIVATE_KEY | Private key matching Terraform's public key |
| EC2_SSH_KNOWN_HOSTS | Verified known_hosts line for the Elastic IP |

Obtain the host key through a trusted channel such as EC2's console; compare
its fingerprint before saving the known_hosts entry. The workflow deliberately
does not trust an unverified ssh-keyscan result.

Push to main. The deployment workflow first invokes the reusable CI workflow:
Terraform checks, ShellCheck, image builds, auth tests, Nginx routing and an
order journey, then backup/restore recovery. It assumes the scoped AWS role
using OIDC, builds and pushes four images tagged COMMIT-RUN_ID-ATTEMPT, then
temporarily admits the runner's /32 on TCP 22. Unique run/attempt tags avoid
immutable-tag collisions on reruns.

An EXIT trap revokes the newly created security-group rule on success or
failure. Hard runner termination or AWS connectivity failure can prevent
cleanup; inspect for stale github-RUN_ID rules after an interrupted job and
revoke them. Existing operator access is preserved. Terraform uses standalone
rules so it does not reconcile away transient CI rules.

SSH transfers only deployment configuration and scripts. EC2 pulls images
using its own instance profile, backs up the current database, waits for
container health checks, and records the successful image tag in .env.
Live HTTPS smoke tests create a synthetic user and order on each deploy;
these are observable test records and should be excluded from sales reports.
CI-created records live only in its disposable database.

Nginx and TLS are installed during initial setup. To roll out changes to their
configuration, rerun configure_tls.sh on the host. Application deployments
transfer the new templates but do not overwrite an active TLS installation.

## 5. Evidence and rollback

Capture terraform output and state list, AWS ECR immutability and IAM policy,
security-group ports, DNS resolution, HTTP/HTTPS curl output, the browser
padlock, manual restore PASS output, and a successful main deployment run.
Do not include private keys, tokens, .env contents, or Terraform state in evidence.

For rollback, find a previous successful tag in the Actions log and invoke
bash scripts/deploy.sh REGION REGISTRY PREFIX PREVIOUS_TAG on EC2. Old images
are retained. Application rollback does not roll back database changes.
A failed health check fails the job but does not automatically roll back
containers; use the prior tag and investigate logs.

## Validation performed in this workspace

Terraform init and validate succeeded; Compose configuration parsed. Bash
syntax, dependency-lock generation, and additional static checks are recorded
in the task response. Container integration and manual EC2 recovery require
a working Docker engine and provisioned host. No cloud resources or certificate
were created by the repository implementation.
