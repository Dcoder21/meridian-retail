# Meridian Retail Group - Technical Walkthrough

Prepared 13 October 2026. Live session: Thursday, 15 October 2026. Time zone: Africa/Lagos (UTC+1).

## 1. Executive record and present state

Meridian is an 18-person Lagos e-commerce business serving UK/EU customers. The original operational risk was a single EC2 host managed through manual docker run commands and exposed application ports. This work built the infrastructure and operational files around the supplied, unchanged application code.

The completed practical milestone was local container build, reverse-proxy integration, database recovery rehearsal, and private ECR image publication. A broader London infrastructure stack was also provisioned briefly, verified, then removed when the requested scope changed to ECR only in us-east-1. All resources created in this session have now been torn down.

| Capability | What actually happened | Status now |
| --- | --- | --- |
| Four application images | Built locally: auth, catalog, orders, frontend | Local image tags deleted |
| Local application stack | Five application/database containers plus Nginx proxy; all healthy | Containers/network/volume removed |
| Storefront journey | Frontend, three health aliases, catalog, signup, order creation/listing, unknown API 404 passed | Evidence retained |
| Database recovery | Isolated copy: 5 products -> 4 -> 5; exact deleted row recovered | Backup/evidence retained locally |
| Full Terraform stack | 27 resources created in eu-west-2; EC2 bootstrap and IAM identity checked | All 27 destroyed |
| ECR-only Terraform | Four immutable repositories created in us-east-1 | All four destroyed |
| Registry publication | Four local images tagged, pushed, and verified by ECR digest | Remote images deleted |
| DuckDNS and public HTTPS | Updater and TLS templates/scripts written; Nginx syntax checked | No domain/certificate deployed |
| Cron backup on EC2 | Cron installed by bootstrap; no observed daily production backup/restore | Host removed |
| GitHub Actions | CI/deploy workflows written and linted | No successful remote workflow run demonstrated |

Do not present written configuration as a completed production deployment. In particular, no EC2 ECR image pull, public storefront, browser padlock, DNS record update, live HTTPS redirect, or successful GitHub deployment was demonstrated. The supplied auth pytest suite was configured in CI but was not run in the local session; the separate full storefront smoke test did run successfully.

## 2. Cost record and its limits

The read-only Cost Explorer query for 13 October returned UnblendedCost USD 0, Groups [], and Estimated true. This is an account-wide daily snapshot, not an exact project invoice or proof that the session was free. AWS refreshes Cost Explorer at least once every 24 hours, so same-day usage can arrive later.

CloudTrail recorded RunInstances at 08:12:21 and TerminateInstances at 08:23:00 on 13 October (Africa/Lagos). The interval is 639 seconds, or 10 minutes 39 seconds. This brackets the operational session; actual billable running time and disk/IP deletion times can differ slightly.

| Component | Verified price / assumption | Approximate session cost |
| --- | --- | --- |
| Linux t3.small, London | AWS Price List: USD 0.0236/hour | 0.0236 x 639/3600 = USD 0.00419 |
| 30 GB gp3, London | AWS Price List: USD 0.0928/GB-month; baseline IOPS/throughput | About USD 0.0007 for a similar lifetime |
| Public IPv4 | USD 0.005/address-hour; temporary initial IP plus Elastic IP | About USD 0.001; exact allocation lifetimes not measured |
| Private ECR storage | USD 0.10/GB-month; brief retention of four small images | Fraction of a cent; retained byte-hours not measured |
| ECR data transfer in | Upload into ECR | USD 0 for ingress |
| Cost Explorer query | One primary-billing-view API request | USD 0.01 |

The base infrastructure estimate is below one US cent, with a further one cent for the billing API query. A practical expectation is a few US cents overall, not a final settled amount. Possible T3 Unlimited surplus CPU credits, taxes, account credits/free-tier eligibility, billing rounding, and other account usage were not reconciled. No NGN conversion is supplied because the card/bank conversion rate is not known.

No active billable resources created by this task remain. Deleting resources prevents future use/storage charges; it does not cancel charges already accrued. Check the Billing console after the next refresh instead of repeatedly calling the paid API.

Executed billing command (end date is exclusive):

```powershell
aws ce get-cost-and-usage --profile default --region us-east-1 `
  --time-period Start=2026-10-13,End=2026-10-14 `
  --granularity DAILY --metrics UnblendedCost `
  --group-by Type=DIMENSION,Key=SERVICE Type=DIMENSION,Key=REGION `
  --output json > evidence/cost-explorer-2026-10-13.json

aws cloudtrail lookup-events --profile default --region eu-west-2 `
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=i-0648c049ca2a0ba48 `
  --query 'Events[].{Time:EventTime,Name:EventName}' --output json
```

Sources checked on 13 October 2026: AWS Price List API responses in evidence/ec2-pricing.json and evidence/ebs-pricing.json; https://aws.amazon.com/ec2/pricing/on-demand/ ; https://aws.amazon.com/ebs/pricing/ ; https://aws.amazon.com/vpc/pricing/ ; https://aws.amazon.com/ecr/pricing/ ; https://aws.amazon.com/aws-cost-management/aws-cost-explorer/pricing/ ; https://docs.aws.amazon.com/cost-management/latest/userguide/ce-what-is.html .

## 3. Working environment and file map

Workspace: C:/Users/NuelOjeabulu/Desktop/AmdariProjectSolutions/MeridianRetailGroup/meridian-retail. Repository remote: https://github.com/GfavourBraimah/meridian-retail.git . The recorded base commit was 87133b6a4bf9dc0536c2a84c65be71fd910fb368. Images included uncommitted infrastructure files from the working tree; the tag was a local-demo identifier, not a claim that the new files were committed or published to GitHub.

Use Windows PowerShell on the workstation. Bash commands marked EC2/Linux belong on Ubuntu or the GitHub Linux runner. Git Bash was used for syntax checks, but it lacked flock; therefore the local restore rehearsal used a PowerShell script. Docker Desktop must be in Linux-container mode.

| File or folder | Purpose |
| --- | --- |
| auth-service/Dockerfile | Python 3.12, pinned supplied requirements, non-root app user, port 8000 |
| catalog-service/Dockerfile and package-lock.json | Node 22, reproducible npm ci, non-root node user, port 4000 |
| orders-service/Dockerfile | Python 3.12, non-root app user, port 8001 |
| frontend/Dockerfile | Nginx static frontend image |
| docker-compose.yml | PostgreSQL plus four services; health checks, persistence, localhost bindings |
| docker-compose.test.yml | Additional local Nginx reverse proxy on localhost:8088 |
| nginx/ | Local routing, bootstrap HTTP routing, hand-written TLS template |
| terraform/ | Full infrastructure root; defaults to eu-west-2 and requires SSH inputs |
| terraform/ecr/ | Independent ECR-only root; defaults to us-east-1; no SSH inputs |
| scripts/test_local.ps1 | Windows storefront test plus isolated restore rehearsal |
| scripts/smoke_test.py | HTTP frontend/auth/catalog/order integration test |
| scripts/push_ecr.ps1 | Rebuild-and-push helper; explicitly pass -Region us-east-1 |
| scripts/backup_db.sh, restore_db.sh, verify_restore.sh | Linux/production backup, restore, isolated proof |
| scripts/server_setup.sh | Ubuntu Docker/Nginx/Certbot/AWS CLI/cron bootstrap |
| scripts/update_duckdns.sh, configure_tls.sh, deploy.sh | Future DNS, TLS, and EC2 deployment operations |
| .github/workflows/ | CI tests and OIDC/ECR/temporary-SSH deployment workflow |
| evidence/ and backups/ | Local proof files and database dump; ignored by Git |

.gitignore protects .env, private-key extensions, Terraform state/plans/local tfvars, local evidence, backups, dependencies, and caches. .gitattributes forces LF for shell scripts, YAML and Dockerfiles. Lockfiles are intended to be retained. Keep secrets out of slides and screen shares; never display .env, AWS credentials, or private-key contents.

The root terraform/terraform.tfvars still contains the historical London inputs, including the SSH public key later declared invalid. Do not reuse it for a new EC2 deployment. The ECR-only root does not read that file. The original push_ecr.ps1 and broader runbook default to London; the live demo commands below explicitly choose us-east-1.

## 4. Architecture and reverse-proxy explanation

Local request path: browser -> 127.0.0.1:8088 Nginx proxy -> frontend/auth/catalog/orders containers -> PostgreSQL over the Compose network. Orders verifies JWTs with auth-service:8000 and retrieves product details from catalog-service:4000. These internal service names resolve through Docker networking.

| Service | Container port | Host binding |
| --- | --- | --- |
| PostgreSQL | 5432 | 127.0.0.1:5432 |
| Auth | 8000 | 127.0.0.1:8001 |
| Catalog | 4000 | 127.0.0.1:8002 |
| Orders | 8001 | 127.0.0.1:8003 |
| Frontend | 80 | 127.0.0.1:8080 |
| Local reverse proxy | 80 | 127.0.0.1:8088 |

Port 8080 serves static HTML only. Use port 8088 for the functional local storefront because the frontend uses relative /api paths. In the planned EC2 design, Nginx runs on the host and proxies to the same localhost host ports; customers would use public ports 80/443 instead of raw backend ports.

| Request | Local Nginx upstream | Forwarded URI |
| --- | --- | --- |
| / | frontend:80 | Full original URI |
| /api/auth/* | auth-service:8000 | Full /api/auth/... |
| /api/catalog/* | catalog-service:4000 | Full /api/catalog/... |
| /api/orders and /api/orders/* | orders-service:8001 | Full original URI |
| /api/auth/healthz | auth-service:8000 | /healthz |
| /api/catalog/healthz | catalog-service:4000 | /healthz |
| /api/orders/healthz | orders-service:8001 | /healthz |
| Any other /api/* | No upstream | 404 |

Exact-match health locations win before prefix locations. API proxy_pass directives omit the URI suffix, preserving the /api prefix expected by the supplied applications. Health aliases deliberately replace the path with /healthz. Adding a trailing slash to the API proxy_pass would strip the matched prefix and break these routes. Nginx forwards Host, real IP, forwarding chain, and original protocol.

Explain the controls: localhost bindings remove direct network exposure; health checks control dependency startup; PostgreSQL's named volume persists data between restarts; Docker logs rotate at 10 MB with three files; no-new-privileges prevents privilege escalation; Python/Node application containers run as non-root users. PostgreSQL is still a single shared database and the broader EC2 design is still a single host, not high availability.

## 5. Historical command ledger - discovery and build preparation

The next sections preserve the operational sequence of this session. Long commands use PowerShell backticks for readable line continuation; they are equivalent to the one-line invocations used. Repeated polling, reading a file again, and tool transport/permission prompts are not infrastructure commands. Failed material attempts are identified separately, so do not copy a failed command as a recommended step.

Local image downloads/builds overlapped with AWS inspection and London provisioning. The ledger groups each operational flow in its start order; it does not imply the local build had finished before the AWS commands began. The successful local verification occurred after provisioning, and the successful us-east-1 publication occurred only after local tests passed and the London stack was removed.

Initial inventory and reading (executed):

```powershell
Get-Location
rg --files -g AGENTS.md -g '!node_modules' -g '!vendor' -g '!\.git'
rg --files -g '!node_modules' -g '!vendor' -g '!\.git'
Get-ChildItem -Force
Get-Content README.md,docker-compose.yml,scripts/server_setup.sh
Get-Content scripts/backup_db.sh,scripts/restore_db.sh
Get-Content catalog-service/app.js,auth-service/main.py,orders-service/main.py
git status --short
Get-Content .env.example,auth-service/requirements.txt
Get-Content orders-service/requirements.txt,catalog-service/package.json
Get-Content auth-service/tests/test_auth.py
Get-Command docker,terraform,python,bash -ErrorAction SilentlyContinue
terraform version
docker info --format '{{.ServerVersion}}'
```

README stated the application logic must not be changed. The Dockerfiles, Compose file, and operational scripts were empty. Infrastructure files were authored directly using file patches; application logic and supplied requirements/package.json were retained. New catalog package-lock.json was generated for npm ci.

The initial Docker info attempt failed because the Docker engine was not running. A command that included starting Docker Desktop was rejected by the execution environment. Later Docker info succeeded with engine 29.2.1. Docker Desktop was already available by then; no task-owned background daemon was installed on the workstation.

Node was not on the workstation PATH. A temporary Node 22 distribution was downloaded from nodejs.org to the OS temporary meridian-validation folder. The successful lock-generation command was executed from catalog-service using that Node binary:

```powershell
# Run from catalog-service; replace <TEMP_NODE> with the extracted Node folder.
& '<TEMP_NODE>/node.exe' '<TEMP_NODE>/node_modules/npm/bin/npm-cli.js' `
  install --package-lock-only --ignore-scripts
```

Result: 83 packages audited, zero known vulnerabilities reported at that time. This was an npm dependency audit only, not a container vulnerability scan or an assertion that all Python dependencies are vulnerability-free.

Material failed preparation attempts: an initial PowerShell array-filter expression produced an invalid Node download URL; the corrected array .Where expression worked. An npm --prefix invocation looked for package.json at the repository root; running npm from catalog-service resolved it. These did not change the application source.

## 6. Historical command ledger - static verification

Executed after writing the infrastructure files:

```powershell
terraform fmt -recursive terraform
terraform -chdir=terraform init -backend=false -input=false
terraform -chdir=terraform validate
terraform -chdir=terraform fmt -check
terraform -chdir=terraform providers lock `
  -platform=linux_amd64 -platform=windows_amd64
docker compose config --quiet
docker compose -f docker-compose.yml -f docker-compose.test.yml config --quiet
git diff --check

Get-ChildItem scripts -Filter *.sh | ForEach-Object {
  & 'C:/Program Files/Git/bin/bash.exe' -n $_.FullName
  if ($LASTEXITCODE -ne 0) { throw "Syntax failed: $($_.Name)" }
}
python -m py_compile scripts/smoke_test.py
```

Terraform 1.14.4 installed AWS provider 6.68.0 and generated lock checksums for Windows/Linux. Terraform validate and Compose parsing passed. The loop above correctly checks every shell file; a single bash -n invocation followed by many filenames only checks the first script.

ShellCheck and actionlint were downloaded into the temporary validation tools directory and executed:

```powershell
# Substitute actual executable paths from the temporary tools folder.
& '<SHELLCHECK_EXE>' (Get-ChildItem scripts -Filter *.sh | ForEach-Object FullName)
$taskLintArgs = @('-shellcheck=<SHELLCHECK_EXE>','-pyflakes=')
& '<ACTIONLINT_EXE>' @taskLintArgs
```

Two lint findings were fixed: ShellCheck needed source=/dev/null for the Ubuntu /etc/os-release import; actionlint's ShellCheck integration reported intentional client-side expansion in the SSH remote command, documented with disable=SC2029. Final ShellCheck and workflow lint passed.

HTTP and HTTPS Nginx templates were syntax-tested with a temporary Windows Nginx 1.28.0 binary and a self-signed certificate. This verified configuration syntax only. It did not issue a trusted certificate or prove public HTTPS.

```powershell
# Temporary certificate; never use this as a trusted production certificate.
& 'C:/Program Files/Git/usr/bin/openssl.exe' req -x509 `
  -newkey rsa:2048 -nodes -keyout '<TEMP>/tls.key' `
  -out '<TEMP>/tls.crt' -days 1 -subj '/CN=meridian-test.duckdns.org'
# Test config wrapped the template in events {} and http {}.
# __DOMAIN__ and certificate paths were replaced in the temporary copy only.
# Executed from the extracted temporary Nginx folder:
.\nginx.exe -p './' -c 'conf/validation.conf' -t
```

Initial Windows Nginx checks failed on temporary path resolution and then a relative certificate path. Using a relative config under conf/ and certificate names relative to that config fixed both. The repository TLS template itself was not changed to temporary certificate paths.

## 7. Historical command ledger - first local startup

Port inspection found unrelated containers including ctfd on 8000 and vaultapp on 5000. Meridian's 8001/8002/8003/8080/8088 bindings did not conflict, and unrelated containers were left running.

```powershell
docker ps --format '{{.Names}} {{.Ports}}'
docker context ls
docker info --format '{{.ServerVersion}}'
docker compose -f docker-compose.yml -f docker-compose.test.yml `
  up -d --build --wait --wait-timeout 180
```

The first build failed inside Docker Desktop's Buildx/Bake process. The corrected, successful invocation set process-local build options and captured a build log:

```powershell
$env:COMPOSE_BAKE = 'false'
$env:COMPOSE_PARALLEL_LIMIT = '1'
docker compose -f docker-compose.yml -f docker-compose.test.yml `
  up -d --build --wait --wait-timeout 180 `
  *> "$env:TEMP/meridian-validation/docker-build.log"
docker compose -f docker-compose.yml -f docker-compose.test.yml ps
```

The build took several minutes because base images and dependencies were downloaded for the first time. All six containers became healthy. The image names were meridian-local/meridian/auth-service:local, catalog-service:local, orders-service:local, and frontend:local. PostgreSQL used postgres:16-bookworm and the proxy used nginx:stable-alpine.

The local .env already existed and was ignored by Git. It was not copied into a Docker image. The provided template values are acceptable only for disposable demonstrations; use independent strong DB/JWT secrets for any deployed environment.

## 8. Historical command ledger - broader London provisioning

This is historical context, not the Thursday ECR-only path. The default AWS CLI profile authenticated to account 864365983971 as terraform-admin. The lab profile failed with InvalidClientTokenId. The default CLI region was us-east-1, but the initial broader stack followed the project configuration's eu-west-2 default before the later user clarification. That was corrected through complete teardown.

```powershell
aws configure list-profiles
aws sts get-caller-identity --profile default `
  --query '{Account:Account,Arn:Arn}' --output json
aws sts get-caller-identity --profile lab `
  --query '{Account:Account,Arn:Arn}' --output json
aws configure get region --profile default
git remote -v
Get-ChildItem "$env:USERPROFILE/.ssh" -Filter '*.pub'
(Invoke-WebRequest https://checkip.amazonaws.com -UseBasicParsing).Content.Trim()
aws ecr describe-repositories --profile default --region eu-west-2
aws ec2 describe-instances --profile default --region eu-west-2 `
  --filters Name=tag:Project,Values=meridian
aws iam list-open-id-connect-providers --profile default
```

The root terraform.tfvars was written with eu-west-2, project meridian, then-current operator /32, the existing public key, and GitHub repository GfavourBraimah/meridian-retail. No private key was placed into Terraform. The user subsequently declared that SSH key invalid; use no historical key for a future demo. The account and IP identifiers below are historical evidence, not reusable settings.

Successful plan/apply used argument arrays because an earlier unquoted PowerShell -out argument caused a 'Too many command line arguments' error:

```powershell
$env:AWS_PROFILE = 'default'
& terraform @('-chdir=terraform','plan','-out=meridian.tfplan',
  '-input=false','-no-color')
# Plan: 27 to add, 0 to change, 0 to destroy.
& terraform @('-chdir=terraform','apply','-input=false',
  '-no-color','meridian.tfplan')
terraform -chdir=terraform output
terraform -chdir=terraform state list
```

Created: VPC 10.42.0.0/16; public subnet 10.42.1.0/24; isolated private subnet 10.42.2.0/24; internet gateway/public route; two route tables/associations; security group with public 80/443 and operator-only 22; four immutable ECR repositories; pull-only EC2 role/profile; SSH key-pair resource; Ubuntu 22.04 t3.small with 30 GB encrypted gp3 and required IMDSv2; Elastic IP; GitHub OIDC provider and scoped main-branch deployment role/policy. No NAT gateway, load balancer, RDS instance, or S3 bucket was created.

Historical outputs: EC2 i-0648c049ca2a0ba48; Elastic IP 16.61.64.48; VPC vpc-08c847b3f903efec7; security group sg-08cff967c6552a28d; EBS vol-0ba2b3c7034554078. All were subsequently removed or terminated.

The EC2 role allowed ecr:GetAuthorizationToken on * and repository-scoped BatchCheckLayerAvailability, GetDownloadUrlForLayer and BatchGetImage. Token authorization cannot be scoped to a repository ARN; image/layer operations can. The GitHub role added upload actions and ingress/revoke permissions on only the created security group. OIDC trust required the repository's main-branch subject and sts.amazonaws.com audience.

## 9. Historical command ledger - EC2 verification and scope correction

AWS API evidence was saved locally:

```powershell
terraform -chdir=terraform output -json > evidence/terraform-outputs.json
aws ecr describe-repositories --profile default --region eu-west-2 `
  --query 'repositories[].{Name:repositoryName,Mutability:imageTagMutability}'
aws iam list-role-policies --profile default --role-name meridian-ec2
aws iam get-role-policy --profile default --role-name meridian-ec2 `
  --policy-name '<INLINE_POLICY_NAME>' --query PolicyDocument --output json
aws ec2 describe-security-groups --profile default --region eu-west-2 `
  --group-ids sg-08cff967c6552a28d --query 'SecurityGroups[0].IpPermissions'
aws ec2 describe-instance-status --profile default --region eu-west-2 `
  --instance-ids i-0648c049ca2a0ba48
```

System and instance status checks returned ok. The public SSH host key was scanned, fingerprinted, then matched against AWS's authenticated console-output API before SSH was trusted:

```powershell
& 'C:/Program Files/Git/usr/bin/ssh-keyscan.exe' `
  -T 10 -t ed25519 16.61.64.48 > '<TEMP>/ec2-known-hosts'
& 'C:/Program Files/Git/usr/bin/ssh-keygen.exe' -lf '<TEMP>/ec2-known-hosts'
aws ec2 get-console-output --profile default --region eu-west-2 `
  --instance-id i-0648c049ca2a0ba48 --latest `
  --query "contains(Output, 'SHA256:oi/lBTGJ0qArobiizp9hFmyAhKADXJNC96aSBOJLaxk')" `
  --output text
# Returned True. Do not trust ssh-keyscan alone.
& 'C:/Program Files/Git/usr/bin/ssh.exe' -o BatchMode=yes `
  -o StrictHostKeyChecking=yes -o 'UserKnownHostsFile=<TEMP>/ec2-known-hosts' `
  -i '<HISTORICAL_KEY_PATH>' ubuntu@16.61.64.48 `
  'sudo cloud-init status --long; docker --version; docker compose version; aws sts get-caller-identity --query Arn --output text'
```

Observed: cloud-init done with no errors; Docker 29.9.0 and Compose v5.6.0 installed; identity arn:aws:sts::864365983971:assumed-role/meridian-ec2/i-0648c049ca2a0ba48. This verified bootstrap and instance-profile identity, not an actual ECR pull or deployed storefront on EC2.

Attempts to print the full EC2 console output hit a Windows charmap encoding error. A contains query returned only True/False and avoided dumping Unicode console output. The historical private key was used through its file path and was never printed; it must not be used for Thursday.

The user then requested us-east-1 and ECR/push only. An initial London push attempt was stopped. It left a local London auth image tag but no completed remote image; that local tag was later deleted. The full stack was removed through its own Terraform state:

```powershell
docker logout 864365983971.dkr.ecr.eu-west-2.amazonaws.com
$env:AWS_PROFILE = 'default'
& terraform @('-chdir=terraform','plan','-destroy','-out=cleanup.tfplan',
  '-input=false','-no-color')
# Plan: 0 to add, 0 to change, 27 to destroy.
& terraform @('-chdir=terraform','apply','-input=false',
  '-no-color','cleanup.tfplan')
# Apply complete: 27 destroyed.
```

The ECR-only directory was then initialized. An attempt to plan before initialization finished failed with an inconsistent lockfile; waiting for init resolved it. Keep dependent Terraform operations sequential.

## 10. Historical command ledger - local functional and recovery proof

Executed after the six local containers were healthy:

```powershell
.\scripts\test_local.ps1
docker compose -f docker-compose.yml -f docker-compose.test.yml `
  exec -T proxy nginx -t
```

The first restore-script run encountered PowerShell 5 native-argument quote stripping: psql tried to connect to a database named FROM. The wrapper was corrected to escape embedded double quotes for PowerShell versions <= 5, then the test was rerun successfully.

The script calls python scripts/smoke_test.py http://localhost:8088. That test checks the frontend HTML, all health aliases, seeded products, a new signup/JWT, order placement, order retrieval, and unknown /api path 404. Synthetic users/orders are intentional test records. HTTP calls are same-origin relative API requests through Nginx, not direct service shortcuts.

Recovery operations inside test_local.ps1, in order:

```bash
# Inside PostgreSQL container; environment values are container-local.
pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc -f /tmp/ARCHIVE.dump
pg_restore --list /tmp/ARCHIVE.dump
createdb -U "$POSTGRES_USER" ISOLATED_TEST_DB
pg_restore -U "$POSTGRES_USER" -d ISOLATED_TEST_DB \
  --no-owner --no-acl --exit-on-error --single-transaction /tmp/ARCHIVE.dump
psql -U "$POSTGRES_USER" -d ISOLATED_TEST_DB -At -v ON_ERROR_STOP=1 \
  -c 'SELECT count(*) FROM products;'
psql -U "$POSTGRES_USER" -d ISOLATED_TEST_DB -At -v ON_ERROR_STOP=1 \
  -c 'SELECT row_to_json(p)::text FROM products p ORDER BY id LIMIT 1;'
psql -U "$POSTGRES_USER" -d ISOLATED_TEST_DB -v ON_ERROR_STOP=1 \
  -c 'DELETE FROM products WHERE id = (SELECT min(id) FROM products);'
# Recount, recreate isolated DB, restore the same archive, compare count/full row.
dropdb -U "$POSTGRES_USER" --force ISOLATED_TEST_DB
createdb -U "$POSTGRES_USER" ISOLATED_TEST_DB
# pg_restore and SELECT commands repeated; isolated database dropped on exit.
```

The Windows wrapper uses docker compose cp to move the binary archive to backups/, then Get-FileHash -Algorithm SHA256. PowerShell 5 text redirection must not be used to capture a binary pg_dump archive. The archive/checksum pair is retained locally and ignored by Git.

Observed evidence: PASS before=5 deleted=4 restored=5; exact product row recovered. Archive: meridian-local-20261013T081817.dump. SHA256: 6c752b0fe89edee50fb1c7204af06fa8257e73aeb4a82f3b2e8061df1de51b0f. Timestamp: 07:18:47 UTC / 08:18:47 Lagos on 13 October 2026. This is a local manual recovery rehearsal, not the still-pending EC2 production restore deliverable.

## 11. Historical command ledger - us-east-1 ECR publication

The ECR-only Terraform root had no networking, IAM instance profile, EC2, or SSH inputs. Its successful plan showed only four repositories:

```powershell
terraform -chdir=terraform/ecr init -input=false
terraform -chdir=terraform/ecr validate
terraform -chdir=terraform/ecr plan -input=false -no-color
# Plan: 4 to add, 0 to change, 0 to destroy; region us-east-1.
terraform -chdir=terraform/ecr apply -auto-approve -input=false -no-color
```

Auto-approve was used only after reviewing the preceding four-resource plan and explicit authorization to create ECR/push. For the live walkthrough, use a saved plan or the normal interactive confirmation.

The four existing tested local images were tagged without rebuilding. The successful publication used this sequence (historical shared tag shown):

```powershell
$taskRegistry = '864365983971.dkr.ecr.us-east-1.amazonaws.com'
$taskTag = 'local-20261013-083114-e10a31be'
$taskServices = @('auth-service','catalog-service','orders-service','frontend')
foreach ($taskService in $taskServices) {
  docker tag "meridian-local/meridian/${taskService}:local" `
    "${taskRegistry}/meridian/${taskService}:${taskTag}"
  if ($LASTEXITCODE -ne 0) { throw "Tag failed: $taskService" }
}
$taskPassword = aws ecr get-login-password --profile default --region us-east-1
if ($LASTEXITCODE -ne 0) { throw 'ECR authentication failed.' }
try {
  $taskPassword | docker login --username AWS --password-stdin $taskRegistry
  $taskPassword = $null
  if ($LASTEXITCODE -ne 0) { throw 'Docker login failed.' }
  foreach ($taskService in $taskServices) {
    docker push --quiet "${taskRegistry}/meridian/${taskService}:${taskTag}"
    if ($LASTEXITCODE -ne 0) { throw "Push failed: $taskService" }
    aws ecr describe-images --profile default --region us-east-1 `
      --repository-name "meridian/$taskService" --image-ids "imageTag=$taskTag" `
      --query 'imageDetails[0].imageDigest' --output text
  }
} finally {
  $taskPassword = $null
  docker logout $taskRegistry
}
```

Docker tag adds another reference to the existing local image; it does not build or upload it. Docker push uploads layers and the image manifest. DescribeImages verifies publication in AWS, independent of a local tag listing. Immutable repositories prevent reusing a tag for changed content. Use a new unique tag on each future demo.

| Image | Verified ECR digest (SHA256 suffix) |
| --- | --- |
| auth-service | f011fc41d6a4720416991b2dc47cadfe90254b5d69ed84d0449f7ce427c2a615 |
| catalog-service | f503c5faa35fd076e7cbc7ab064209885c96be94cb40fd5d1b96a37c698cdf77 |
| orders-service | 172d66cde574aea190e07afde74ab753873078049f6c0c0315ceb5c6853bd3b8 |
| frontend | 269812cecfce2cfa63f2b30dd0a51c3c0da5ec1ae3ccbedc98615e88546a9352 |

All four were confirmed. evidence/ecr-push-us-east-1.json contains full image URLs and digests. These are historical proofs; the images no longer exist remotely after teardown.

## 12. Historical command ledger - final teardown and confirmation

User requested removal of everything created to prevent ongoing costs. Root terraform/ state was already empty from the London cleanup. The ECR root still owned four nonempty repositories; local Meridian containers were running.

Inventory before deletion:

```powershell
terraform -chdir=terraform/ecr state list
terraform -chdir=terraform state list
aws ecr describe-repositories --profile default --region us-east-1
aws ec2 describe-instances --profile default --region eu-west-2 `
  --filters Name=tag:Project,Values=meridian
docker ps -a --filter label=com.docker.compose.project=meridian
docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}'
```

ECR force_delete was temporarily changed from false to true in terraform/ecr/main.tf and applied into state, allowing Terraform to delete the repositories with their images. It was restored to false after cleanup; the checked-in design retains accidental-deletion protection.

```powershell
# Edit only terraform/ecr/main.tf: force_delete = true.
terraform -chdir=terraform/ecr apply -auto-approve -input=false -no-color
# 0 added, 4 changed, 0 destroyed (teardown setting only).
terraform -chdir=terraform/ecr destroy -auto-approve -input=false -no-color
# Destroy complete: 4 destroyed.
docker compose -f docker-compose.yml -f docker-compose.test.yml `
  down --volumes --remove-orphans

$taskImages = docker images --format '{{.Repository}}:{{.Tag}}' |
  Where-Object {
    $_ -match '^meridian-local/meridian/(auth-service|catalog-service|orders-service|frontend):' -or
    $_ -match '^864365983971\.dkr\.ecr\.(us-east-1|eu-west-2)\.amazonaws\.com/meridian/(auth-service|catalog-service|orders-service|frontend):'
  }
foreach ($taskImage in $taskImages) { docker image rm $taskImage }
docker image rm postgres:16-bookworm nginx:stable-alpine
# Restore terraform/ecr/main.tf: force_delete = false.
```

This deleted the six containers, meridian_default network, meridian_postgres-data volume, four local application images and ECR tags, the abandoned London auth tag, and the two task-added base-image tags. Image removal did not use --force. Unrelated containers and image tags were retained. No broad docker system prune was run; shared BuildKit cache can remain locally without AWS charges.

Read-only verification commands:

```powershell
aws ecr describe-repositories --profile default --region us-east-1
aws ecr describe-repositories --profile default --region eu-west-2
aws ec2 describe-addresses --profile default --region eu-west-2 `
  --filters Name=tag:Project,Values=meridian
aws ec2 describe-volumes --profile default --region eu-west-2 `
  --volume-ids vol-0ba2b3c7034554078
aws ec2 describe-security-group-rules --profile default --region eu-west-2 `
  --filters Name=group-id,Values=sg-08cff967c6552a28d
aws ec2 describe-instances --profile default --region eu-west-2 `
  --instance-ids i-0648c049ca2a0ba48 --query 'Reservations[].Instances[].State.Name'
docker ps -a --filter label=com.docker.compose.project=meridian
docker volume ls --filter label=com.docker.compose.project=meridian
terraform -chdir=terraform/ecr state list
terraform -chdir=terraform state list
```

Results: no Meridian repositories in either region; no Elastic IP; InvalidVolume.NotFound for the exact disk; no old security-group rules; instance state terminated; no local Meridian containers/volumes; both Terraform states empty. AWS Resource Groups Tagging API still listed some historical deleted identifiers, so exact EC2 queries were used to confirm removal. An old resource appearing in the tag index alone does not establish it is still active.

Source/configuration, state history, backups and evidence remain on the workstation; they do not incur AWS resource charges. The storefront at localhost:8088 is now offline until you rebuild/start it.

## 13. Thursday walkthrough - preparation and scope

Recommended live scope: explain the secure design; build/start locally; show routing and an order; prove recovery; provision only ECR in us-east-1; tag/push/verify; tear down. Use historical evidence for the briefly tested EC2/IAM infrastructure and describe DNS/TLS/CI as next steps. This follows the latest requested scope and needs no SSH key.

Suggested 35-minute session: 0-4 min business problem/status; 4-9 min Dockerfiles/Compose/networking; 9-15 min storefront and routing; 15-20 min restore proof; 20-24 min Terraform ECR plan/apply; 24-29 min tag/push/digest verification; 29-33 min security/CI design and limitations; 33-35 min teardown and questions. First uncached downloads/pushes may exceed this schedule. Rehearse the build beforehand, then remove containers/volume if a clean live seed is needed; retain local build cache for speed.

Before Thursday: confirm Docker Desktop Linux engine, AWS CLI default profile, Terraform, Python 3.12, internet connectivity, screen sharing and terminal font. Ensure ports 5432, 8001, 8002, 8003, 8080 and 8088 are free for Meridian. Keep evidence/local-restore.txt and evidence/ecr-push-us-east-1.json available as fallback. Display no secrets or unrelated account billing details.

If you advertise all ten original deliverables as live-complete, additional work is required: a new authorized EC2 SSH key, chosen region, provisioned full stack, registered DuckDNS name/token, contact email, certificate issuance/renewal test, EC2 image pull/deploy, manual EC2 restore proof, GitHub variables/secrets, reviewed commits, and an observed successful workflow run. None of that should be improvised with the invalid historical SSH key.

## 14. Thursday walkthrough - repeatable PowerShell commands

These commands are the recommended repeat sequence, not a claim they have already been rerun after teardown. Use a normal PowerShell terminal, from the workspace. Do not apply the full terraform/ root for this demo. Each external command should be checked before continuing if it fails.

Step A - verify tools, account and local settings:

```powershell
Set-Location 'C:/Users/NuelOjeabulu/Desktop/AmdariProjectSolutions/MeridianRetailGroup/meridian-retail'
docker info --format '{{.ServerVersion}}'
docker context ls
aws sts get-caller-identity --profile default
terraform version
python --version
git status --short
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
# Privately edit .env; do not show its contents during the session.
$env:AWS_PROFILE = 'default'
$env:COMPOSE_BAKE = 'false'
$env:COMPOSE_PARALLEL_LIMIT = '1'
# Force local images even if a previous .env contains an ECR release.
$env:ECR_REGISTRY = 'meridian-local'
$env:ECR_REPOSITORY_PREFIX = 'meridian'
$env:IMAGE_TAG = 'local'
docker compose -f docker-compose.yml -f docker-compose.test.yml config --quiet
```

Step B - build/start, inspect health and routes:

```powershell
docker compose -f docker-compose.yml -f docker-compose.test.yml `
  up -d --build --wait --wait-timeout 180
docker compose -f docker-compose.yml -f docker-compose.test.yml ps
docker images --filter 'reference=meridian-local/meridian/*'
docker compose -f docker-compose.yml -f docker-compose.test.yml `
  exec -T proxy nginx -t
(Invoke-WebRequest http://localhost:8088 -UseBasicParsing).StatusCode
Invoke-RestMethod http://localhost:8088/api/auth/healthz
Invoke-RestMethod http://localhost:8088/api/catalog/healthz
Invoke-RestMethod http://localhost:8088/api/orders/healthz
Invoke-RestMethod http://localhost:8088/api/catalog/products
python scripts/smoke_test.py http://localhost:8088
.\scripts\test_local.ps1
Get-Content evidence/local-restore.txt
```

Open http://localhost:8088 in your browser. Explain that localhost HTTP is the demonstrated path, not public trusted HTTPS. Expected health JSON has status ok; seeded catalog has five products; scripts print PASS. The smoke script and test_local each create a synthetic user/order, so a repeated demo adds test records.

Step C - provision only immutable ECR in us-east-1, using a saved reviewed plan:

```powershell
terraform -chdir=terraform/ecr init -input=false
terraform -chdir=terraform/ecr validate
& terraform @('-chdir=terraform/ecr','plan','-input=false',
  '-var=aws_region=us-east-1','-out=demo-registry.tfplan')
# Inspect: 4 repositories, all IMMUTABLE, region us-east-1.
& terraform @('-chdir=terraform/ecr','apply','demo-registry.tfplan')
terraform -chdir=terraform/ecr output
aws ecr describe-repositories --profile default --region us-east-1 `
  --query 'repositories[].{Name:repositoryName,Mutability:imageTagMutability}'
```

Step D - tag the built images with a new unique tag, authenticate, push and verify:

```powershell
$taskAccount = (aws sts get-caller-identity --profile default --query Account --output text).Trim()
$taskRegistry = "$taskAccount.dkr.ecr.us-east-1.amazonaws.com"
$taskTag = 'demo-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8)
$taskServices = @('auth-service','catalog-service','orders-service','frontend')
foreach ($taskService in $taskServices) {
  docker tag "meridian-local/meridian/${taskService}:local" `
    "${taskRegistry}/meridian/${taskService}:${taskTag}"
  if ($LASTEXITCODE -ne 0) { throw "Tag failed: $taskService" }
}
Write-Host "Tag: $taskTag"
$taskPassword = aws ecr get-login-password --profile default --region us-east-1
if ($LASTEXITCODE -ne 0) { throw 'AWS login token failed.' }
try {
  $taskPassword | docker login --username AWS --password-stdin $taskRegistry
  $taskPassword = $null
  if ($LASTEXITCODE -ne 0) { throw 'Docker login failed.' }
  foreach ($taskService in $taskServices) {
    docker push "${taskRegistry}/meridian/${taskService}:${taskTag}"
    if ($LASTEXITCODE -ne 0) { throw "Push failed: $taskService" }
    aws ecr describe-images --profile default --region us-east-1 `
      --repository-name "meridian/$taskService" --image-ids "imageTag=$taskTag" `
      --query 'imageDetails[0].{Tag:imageTags,Digest:imageDigest,Bytes:imageSizeInBytes}'
    if ($LASTEXITCODE -ne 0) { throw "Verification failed: $taskService" }
  }
} finally {
  $taskPassword = $null
  docker logout $taskRegistry
}
```

In the AWS Console select us-east-1 (N. Virginia), open private ECR repositories, and show the shared tag and immutable setting. Repository names alone do not prove images were pushed; show image digests. Never reuse the historical tag for rebuilt content. Do not display the login token.

Step E - remove the cloud resources before ending:

```powershell
# Temporarily edit terraform/ecr/main.tf: force_delete = true.
terraform -chdir=terraform/ecr apply -input=false
# Review that only the four teardown flags change, then confirm.
terraform -chdir=terraform/ecr destroy -input=false
# Confirm destruction of only the four demo repositories.
# Restore terraform/ecr/main.tf: force_delete = false.
aws ecr describe-repositories --profile default --region us-east-1
terraform -chdir=terraform/ecr state list
docker compose -f docker-compose.yml -f docker-compose.test.yml `
  down --volumes --remove-orphans
```

down --volumes deletes the demo database. Keep the proof backup/evidence if needed. Remove your exact demo/local image tags with docker image rm if you also want workstation cleanup; leaving local build cache does not incur AWS charges. Do not use broad prune commands on a workstation that hosts unrelated projects.

## 15. Backup and CI/CD design to explain accurately

Linux backups: server_setup.sh installs cron at 02:00 host time daily. Default Ubuntu host time is UTC, so this is 03:00 Lagos; verify timedatectl on any future host. backup_db.sh sets umask 077, locks via flock, creates a PostgreSQL custom-format dump, validates its archive index, renames the temporary file atomically, writes SHA256, and removes completed backups older than 14 days. Cron logs rotate weekly. File-list validation is not recovery proof; the restore rehearsal supplies that proof.

restore_db.sh validates the checksum/archive before recreating the target database. It requires ALLOW_PRODUCTION_RESTORE=yes when the target equals the live database. The caller must stop writers; the script does not automatically do that. Restore uses a single transaction and stops on error. verify_restore.sh uses an isolated database and checks the full product row as well as the count. Backups are on the same host disk, so they are not a disaster-recovery solution for disk/instance loss; an encrypted off-host copy and alerting remain future work.

Future Linux/EC2 commands - not executed as a complete production recovery in this session:

```bash
cd /opt/meridian
bash scripts/backup_db.sh
backup=$(find backups -maxdepth 1 -name '*.dump' | sort | tail -1)
bash scripts/verify_restore.sh "$backup"
# Production replacement: stop all writers first; use actual DB name.
docker compose stop auth-service catalog-service orders-service
ALLOW_PRODUCTION_RESTORE=yes bash scripts/restore_db.sh "$backup" meridian_db
docker compose up -d --wait
```

CI design: pull requests and non-main pushes trigger ci.yml; main pushes trigger deploy.yml, which invokes CI first. CI checks Terraform, ShellCheck, Compose, builds the six-container stack, runs supplied auth pytest tests, executes the full storefront smoke test and Linux restore proof, and destroys its disposable database. Locally only lint/config/smoke/PowerShell restore checks were observed, not the remote Actions job.

Deployment design: GitHub OIDC assumes a scoped role without long-lived AWS keys; images receive commit-run-attempt tags; ECR pushes occur before firewall opening; the runner's detected /32 is admitted to SSH; the host key must be preverified; deployment transfers config/scripts, pulls via the EC2 profile, backs up the running database, waits for health, and persists the successful image tag. An EXIT trap revokes the exact temporary rule. Hard runner termination/network failure can leave a stale rule, requiring a manual check. A failing deployment does not implement automatic rollback; a prior retained release tag must be redeployed.

Required future GitHub variables: AWS_REGION, AWS_DEPLOY_ROLE_ARN, ECR_REGISTRY, ECR_REPOSITORY_PREFIX, EC2_HOST, EC2_SECURITY_GROUP_ID, DOMAIN. Secrets: EC2_SSH_PRIVATE_KEY and EC2_SSH_KNOWN_HOSTS. GitHub settings were not populated in this session and no workflow was triggered by pushing these new files.

## 16. DNS/TLS and EC2 deployment - written, not demonstrated

The planned public request path is DuckDNS A record -> EC2 Elastic IP -> host Nginx 80/443 -> localhost container ports. HTTP template is installed first for certificate issuance; the TLS script obtains a Certbot certificate, installs the hand-written HTTPS template and tests renewal. HTTP uses a fixed-domain 301 redirect; TLS allows 1.2/1.3; a Certbot renewal deploy hook validates/reloads Nginx.

Future Bash/EC2 sequence - needs a new valid key, provisioned host and registered domain:

```bash
sudo cloud-init status --wait
cd /opt/meridian
# Install application/config files and a protected production .env first.
docker compose up -d --build --wait --wait-timeout 180
read -rs -p 'DuckDNS token: ' DUCKDNS_TOKEN; echo
export DUCKDNS_TOKEN
bash scripts/update_duckdns.sh YOUR-SHOP YOUR_ELASTIC_IP
unset DUCKDNS_TOKEN
dig YOUR-SHOP.duckdns.org A +short
sudo bash scripts/configure_tls.sh YOUR-SHOP.duckdns.org YOUR_EMAIL
curl -I http://YOUR-SHOP.duckdns.org/
curl -I https://YOUR-SHOP.duckdns.org/
sudo certbot renew --dry-run
python3 scripts/smoke_test.py https://YOUR-SHOP.duckdns.org
```

Verify DNS matches the current Elastic IP; do not reuse 16.61.64.48. Remove an unrelated AAAA record if it directs validation elsewhere. Verify a trusted certificate in the browser separately. The HTTPS template is not a certificate and the temporary self-signed syntax-test certificate is not a trusted public certificate.

Important tag compatibility: scripts/deploy.sh currently accepts only a 40-character commit hash followed by two numeric run/attempt components. It will reject the local-... or demo-... tags used for the ECR-only walkthrough. For future EC2 deployment, use the workflow's tag format or deliberately update/test the validation. The repeatable ECR-only demo does not call deploy.sh.

The two Terraform roots independently declare the same repository names. After a future ECR-only deployment, do not apply the full root in the same region without deliberately transferring/importing ownership and removing duplicate ownership from the old state. For a future all-in-one deployment from today's empty state, choose one root to own ECR. Terraform state/lockfile is part of the operation, not disposable bookkeeping.

## 17. Troubleshooting and presenter questions

| Symptom | Check / recovery |
| --- | --- |
| Docker pipe/daemon unavailable | Start Docker Desktop in Linux mode; docker context ls; docker info |
| Buildx/Bake failure | Set COMPOSE_BAKE=false and COMPOSE_PARALLEL_LIMIT=1, then retry the failed build |
| Slow first build/push | Rehearse/cached build beforehand; keep historical evidence; do not cancel a successful upload just for lack of progress text |
| Address already in use | docker ps and host port check; stop only a known conflicting demo service or choose new local mappings |
| Browser API requests fail on 8080 | Use the reverse proxy at 8088; inspect proxy config and health aliases |
| Service unhealthy | docker compose logs SERVICE; inspect DB health and .env without exposing secrets |
| PostgreSQL auth fails after password change | Existing volume retains its initialized password; use the original value or intentionally reset only the disposable demo volume |
| InvalidClientTokenId | Confirm AWS_PROFILE/default identity; lab was invalid; do not print credentials |
| ECR repository not found | Confirm account, explicit us-east-1 region, Terraform state and repository prefix |
| Tag already exists in immutable ECR | Generate a new unique tag; do not make the repository mutable |
| Native PowerShell SQL quote failure | Use corrected test_local.ps1; PowerShell 5 needs escaped embedded quotes |
| Binary backup corrupted | Use docker cp; do not pipe a binary dump through PowerShell 5 text redirection |
| Terraform lock mismatch | Finish init before plan; keep lockfile; do not run dependent operations concurrently |
| Nonempty ECR cannot be destroyed | Explicit temporary force_delete=true, apply setting into state, destroy, restore false |
| Tagging API shows deleted resources | Query exact EC2/EBS IDs and state; historical tag index entries may linger |

Short answers to rehearse: 'Docker tags name content; pushes publish it.' 'Immutability protects release tags from overwriting.' 'The EC2 instance profile grants temporary pull credentials without copied AWS keys.' 'A /32 permits one IPv4 address.' 'Root/frontend and APIs share one Nginx origin.' 'The full original API prefix is retained.' 'A restore test proves recoverability; a dump file alone does not.' 'Infrastructure teardown is different from deleting code.'

Close the demo with accurate evidence: healthy stack, successful smoke/restore output, four immutable us-east-1 repositories with verified digests, then an empty owning Terraform state after destruction. Say explicitly that public DNS/HTTPS and an observed GitHub deployment are remaining milestones.

## 18. Evidence index and references

| Evidence | Meaning / caution |
| --- | --- |
| evidence/local-restore.txt | Successful local isolated restore and checksum |
| evidence/ecr-push-us-east-1.json | Four historical uploaded tags/digests; deleted after proof |
| evidence/terraform-outputs.json | Historical London outputs; all obsolete after cleanup |
| evidence/ec2-pull-policy.json | Historical scoped EC2 pull policy |
| evidence/security-group-ingress.json | Historical localhost-independent AWS ingress control |
| evidence/ecr-repositories.json | Historical London immutability evidence, not current us-east-1 state |
| evidence/cost-explorer-2026-10-13.json | Lagging account-wide estimated daily cost snapshot |
| evidence/ec2-event-times.json | CloudTrail launch/terminate event timestamps |
| evidence/ec2-pricing.json and ebs-pricing.json | Public price catalog responses used for estimate |
| terraform/*tfstate and terraform/ecr/*tfstate | Local ownership history; current resources arrays empty |
| OS temp meridian-validation/*.log | Build, plan, apply and first cleanup logs; may be cleared by OS |

Technical references: https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass ; https://docs.aws.amazon.com/AmazonECR/latest/userguide/security_iam_id-based-policy-examples.html ; https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-tag-mutability.html ; https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws ; https://www.duckdns.org/spec.jsp ; https://certbot.eff.org/instructions ; https://docs.docker.com/reference/cli/docker/compose/up/ .

The following appendix contains exact snapshots of the task-owned operational files needed to inspect commands inside the scripts. Pre-built application source is excluded to avoid duplicating the supplied application. Read alongside the repository when rehearsing; future edits to the repository can differ from this dated snapshot.

## Appendix A. Terraform source snapshots

### terraform/versions.tf

```text
terraform {
  required_version = ">= 1.6, < 2.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}
provider "aws" {
  region = var.aws_region
  default_tags { tags = { Project = var.project } }
}
```

### terraform/variables.tf

```text
variable "aws_region" {
  type    = string
  default = "eu-west-2"
}
variable "project" {
  type    = string
  default = "meridian"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.project))
    error_message = "Use a lowercase project name, 3 to 31 characters."
  }
}
variable "ssh_cidr" {
  type        = string
  description = "Operator's public IPv4 address with /32."
  validation {
    condition     = can(cidrnetmask(var.ssh_cidr)) && can(regex("/32$", var.ssh_cidr)) && var.ssh_cidr != "0.0.0.0/32"
    error_message = "SSH requires a specific IPv4 /32."
  }
}
variable "ssh_public_key" {
  type        = string
  description = "SSH public key; never supply the private key."
}
variable "instance_type" {
  type    = string
  default = "t3.small"
}
variable "github_repository" {
  type        = string
  description = "GitHub owner/repository allowed to deploy from main."
  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "Expected owner/repository."
  }
}
variable "existing_github_oidc_provider_arn" {
  type        = string
  default     = ""
  description = "Existing GitHub OIDC provider ARN, if this AWS account already has one."
}
```

### terraform/main.tf

```text
data "aws_availability_zones" "available" { state = "available" }
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
data "aws_caller_identity" "current" {}
resource "aws_vpc" "main" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.42.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
}
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.42.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
}
resource "aws_internet_gateway" "main" { vpc_id = aws_vpc.main.id }
resource "aws_route_table" "public" { vpc_id = aws_vpc.main.id }
resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table" "private" { vpc_id = aws_vpc.main.id }
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
resource "aws_security_group" "web" {
  name_prefix = "${var.project}-web-"
  vpc_id      = aws_vpc.main.id
  description = "HTTPS, HTTP certificate validation, and operator SSH"
}
# Standalone rules preserve temporary CI ingress rules during Terraform applies.
resource "aws_vpc_security_group_ingress_rule" "web" {
  for_each          = toset(["80", "443"])
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
}
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = var.ssh_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}
resource "aws_vpc_security_group_egress_rule" "outbound" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
resource "aws_ecr_repository" "service" {
  for_each             = toset(["auth-service", "catalog-service", "orders-service", "frontend"])
  name                 = "${var.project}/${each.key}"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
  force_delete = false
}
locals {
  repository_arns = [for repo in aws_ecr_repository.service : repo.arn]
  ecr_auth        = { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" }
}
resource "aws_iam_role" "ec2" {
  name               = "${var.project}-ec2"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy" "pull" {
  role = aws_iam_role.ec2.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [local.ecr_auth, {
    Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"], Resource = local.repository_arns
  }] })
}
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-ec2"
  role = aws_iam_role.ec2.name
}
resource "aws_key_pair" "operator" {
  key_name   = "${var.project}-operator"
  public_key = var.ssh_public_key
}
resource "aws_instance" "web" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = aws_key_pair.operator.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }
  user_data                   = file("${path.module}/../scripts/server_setup.sh")
  user_data_replace_on_change = true
  depends_on                  = [aws_route.internet, aws_route_table_association.public]
  tags                        = { Name = "${var.project}-web" }
}
resource "aws_eip" "web" {
  domain     = "vpc"
  instance   = aws_instance.web.id
  depends_on = [aws_internet_gateway.main]
}
resource "aws_iam_openid_connect_provider" "github" {
  count          = var.existing_github_oidc_provider_arn == "" ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}
resource "aws_iam_role" "github" {
  name = "${var.project}-github-deploy"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect    = "Allow", Action = "sts:AssumeRoleWithWebIdentity",
    Principal = { Federated = var.existing_github_oidc_provider_arn != "" ? var.existing_github_oidc_provider_arn : aws_iam_openid_connect_provider.github[0].arn },
    Condition = { StringEquals = {
      "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com",
      "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:ref:refs/heads/main"
    } }
  }] })
}
resource "aws_iam_role_policy" "deploy" {
  role = aws_iam_role.github.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [local.ecr_auth, {
    Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage"], Resource = local.repository_arns
    }, {
    Effect   = "Allow", Action = ["ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress"],
    Resource = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:security-group/${aws_security_group.web.id}"
  }] })
}
```

### terraform/outputs.tf

```text
output "vpc_id" { value = aws_vpc.main.id }
output "ec2_public_ip" { value = aws_eip.web.public_ip }
output "security_group_id" { value = aws_security_group.web.id }
output "ecr_registry" { value = split("/", values(aws_ecr_repository.service)[0].repository_url)[0] }
output "ecr_repositories" { value = { for name, repo in aws_ecr_repository.service : name => repo.repository_url } }
output "github_role_arn" { value = aws_iam_role.github.arn }
output "instance_id" { value = aws_instance.web.id }
```

### terraform/ecr/versions.tf

```text
terraform {
  required_version = ">= 1.6, < 2.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}
provider "aws" {
  region = var.aws_region
  default_tags { tags = { Project = var.project } }
}
```

### terraform/ecr/main.tf

```text
# Standalone local-build milestone: no VPC, instance, SSH key, or instance profile.
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "project" {
  type    = string
  default = "meridian"
}
resource "aws_ecr_repository" "service" {
  for_each             = toset(["auth-service", "catalog-service", "orders-service", "frontend"])
  name                 = "${var.project}/${each.key}"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
  force_delete = false
}
output "ecr_registry" {
  value = split("/", values(aws_ecr_repository.service)[0].repository_url)[0]
}
output "ecr_repositories" {
  value = { for name, repo in aws_ecr_repository.service : name => repo.repository_url }
}
```


## Appendix B. Containers and Nginx source snapshots

### auth-service/Dockerfile

```text
FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && useradd --uid 10001 --create-home app
COPY main.py .
USER app
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers", "--forwarded-allow-ips", "*"]
```

### catalog-service/Dockerfile

```text
FROM node:22-bookworm-slim
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY app.js .
USER node
EXPOSE 4000
CMD ["node", "app.js"]
```

### orders-service/Dockerfile

```text
FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && useradd --uid 10001 --create-home app
COPY main.py .
USER app
EXPOSE 8001
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001", "--proxy-headers", "--forwarded-allow-ips", "*"]
```

### frontend/Dockerfile

```text
FROM nginx:stable-alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
```

### docker-compose.yml

```text
name: meridian
x-db-env: &db-env
  DB_HOST: postgres
  DB_PORT: "5432"
  DB_NAME: ${DB_NAME:-meridian_db}
  DB_USER: ${DB_USER:-meridian}
  DB_PASSWORD: ${DB_PASSWORD:?Set DB_PASSWORD in .env}
x-service: &service
  restart: unless-stopped
  security_opt: ["no-new-privileges:true"]
  logging:
    driver: json-file
    options: {max-size: "10m", max-file: "3"}
services:
  postgres:
    <<: *service
    image: postgres:16-bookworm
    environment:
      POSTGRES_DB: ${DB_NAME:-meridian_db}
      POSTGRES_USER: ${DB_USER:-meridian}
      POSTGRES_PASSWORD: ${DB_PASSWORD:?Set DB_PASSWORD in .env}
    ports: ["127.0.0.1:5432:5432"]
    volumes: ["postgres-data:/var/lib/postgresql/data"]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB"]
      interval: 5s
      timeout: 5s
      retries: 20
  auth-service:
    <<: *service
    build: ./auth-service
    image: ${ECR_REGISTRY:-meridian-local}/${ECR_REPOSITORY_PREFIX:-meridian}/auth-service:${IMAGE_TAG:-local}
    environment:
      <<: *db-env
      JWT_SECRET: ${JWT_SECRET:?Set JWT_SECRET in .env}
      JWT_EXPIRY_MINUTES: ${JWT_EXPIRY_MINUTES:-60}
    ports: ["127.0.0.1:8001:8000"]
    depends_on:
      postgres: {condition: service_healthy}
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/healthz')"]
      interval: 10s
      timeout: 5s
      retries: 12
  catalog-service:
    <<: *service
    build: ./catalog-service
    image: ${ECR_REGISTRY:-meridian-local}/${ECR_REPOSITORY_PREFIX:-meridian}/catalog-service:${IMAGE_TAG:-local}
    environment: *db-env
    ports: ["127.0.0.1:8002:4000"]
    depends_on:
      postgres: {condition: service_healthy}
    healthcheck:
      test: ["CMD", "node", "-e", "fetch('http://localhost:4000/healthz').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"]
      interval: 10s
      timeout: 5s
      retries: 12
  orders-service:
    <<: *service
    build: ./orders-service
    image: ${ECR_REGISTRY:-meridian-local}/${ECR_REPOSITORY_PREFIX:-meridian}/orders-service:${IMAGE_TAG:-local}
    environment:
      <<: *db-env
      AUTH_SERVICE_URL: http://auth-service:8000
      CATALOG_SERVICE_URL: http://catalog-service:4000
    ports: ["127.0.0.1:8003:8001"]
    depends_on:
      auth-service: {condition: service_healthy}
      catalog-service: {condition: service_healthy}
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8001/healthz')"]
      interval: 10s
      timeout: 5s
      retries: 12
  frontend:
    <<: *service
    build: ./frontend
    image: ${ECR_REGISTRY:-meridian-local}/${ECR_REPOSITORY_PREFIX:-meridian}/frontend:${IMAGE_TAG:-local}
    ports: ["127.0.0.1:8080:80"]
    healthcheck:
      test: ["CMD", "wget", "-q", "-O", "/dev/null", "http://localhost/"]
      interval: 10s
      timeout: 5s
      retries: 12
volumes:
  postgres-data:
```

### docker-compose.test.yml

```text
services:
  proxy:
    image: nginx:stable-alpine
    ports: ["127.0.0.1:8088:80"]
    volumes: ["./nginx/meridian-local.conf:/etc/nginx/conf.d/default.conf:ro"]
    depends_on:
      auth-service: {condition: service_healthy}
      catalog-service: {condition: service_healthy}
      orders-service: {condition: service_healthy}
      frontend: {condition: service_healthy}
```

### nginx/meridian-local.conf

```text
# Local integration proxy, mounted by docker-compose.test.yml.
server {
    listen 80;
    server_name localhost;
    client_max_body_size 1m;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_connect_timeout 5s;
    proxy_read_timeout 30s;

    # Only health aliases replace the URI.
    location = /api/auth/healthz { proxy_pass http://auth-service:8000/healthz; }
    location = /api/catalog/healthz { proxy_pass http://catalog-service:4000/healthz; }
    location = /api/orders/healthz { proxy_pass http://orders-service:8001/healthz; }
    # No trailing slash: application APIs require the full /api/... path.
    location /api/auth/ { proxy_pass http://auth-service:8000; }
    location /api/catalog/ { proxy_pass http://catalog-service:4000; }
    location = /api/orders { proxy_pass http://orders-service:8001; }
    location /api/orders/ { proxy_pass http://orders-service:8001; }
    location /api/ { return 404; }
    location / { proxy_pass http://frontend:80; }
}
```

### nginx/meridian-http.conf

```text
# Bootstrap HTTP configuration; replace __DOMAIN__ with your DuckDNS hostname.
server {
    listen 80;
    server_name __DOMAIN__;
    client_max_body_size 1m;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_connect_timeout 5s;
    proxy_read_timeout 30s;

    # Only health aliases replace the URI.
    location = /api/auth/healthz { proxy_pass http://127.0.0.1:8001/healthz; }
    location = /api/catalog/healthz { proxy_pass http://127.0.0.1:8002/healthz; }
    location = /api/orders/healthz { proxy_pass http://127.0.0.1:8003/healthz; }
    # No trailing slash: application APIs require the full /api/... path.
    location /api/auth/ { proxy_pass http://127.0.0.1:8001; }
    location /api/catalog/ { proxy_pass http://127.0.0.1:8002; }
    location = /api/orders { proxy_pass http://127.0.0.1:8003; }
    location /api/orders/ { proxy_pass http://127.0.0.1:8003; }
    location /api/ { return 404; }
    location / { proxy_pass http://127.0.0.1:8080; }
}
```

### nginx/meridian-https-reference.conf

```text
# Hand-written TLS template, installed only AFTER Certbot issues the certificate.
# This is not evidence of a live issued certificate.
server {
    listen 80;
    server_name __DOMAIN__;
    return 301 https://__DOMAIN__$request_uri;
}
server {
    listen 443 ssl;
    server_name __DOMAIN__;
    ssl_certificate /etc/letsencrypt/live/__DOMAIN__/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/__DOMAIN__/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:MeridianTLS:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;
    add_header X-Content-Type-Options nosniff always;
    add_header Strict-Transport-Security "max-age=31536000" always;
    client_max_body_size 1m;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_connect_timeout 5s;
    proxy_read_timeout 30s;

    # Only health aliases replace the URI.
    location = /api/auth/healthz { proxy_pass http://127.0.0.1:8001/healthz; }
    location = /api/catalog/healthz { proxy_pass http://127.0.0.1:8002/healthz; }
    location = /api/orders/healthz { proxy_pass http://127.0.0.1:8003/healthz; }
    # No trailing slash: application APIs require the full /api/... path.
    location /api/auth/ { proxy_pass http://127.0.0.1:8001; }
    location /api/catalog/ { proxy_pass http://127.0.0.1:8002; }
    location = /api/orders { proxy_pass http://127.0.0.1:8003; }
    location /api/orders/ { proxy_pass http://127.0.0.1:8003; }
    location /api/ { return 404; }
    location / { proxy_pass http://127.0.0.1:8080; }
}
```


## Appendix C. Local test and publication source snapshots

### scripts/smoke_test.py

```text
"""Check routing and a signup/catalog/order journey through the proxy."""
import json
import sys
import uuid
from urllib.error import HTTPError
from urllib.request import Request, urlopen

base = sys.argv[1].rstrip("/")


def request(path, data=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    body = json.dumps(data).encode() if data is not None else None
    with urlopen(Request(base + path, body, headers), timeout=15) as response:
        assert response.status == 200
        return json.load(response)


with urlopen(base + "/", timeout=15) as response:
    assert response.status == 200 and b"Meridian" in response.read()
for service in ("auth", "catalog", "orders"):
    assert request(f"/api/{service}/healthz")["status"] == "ok"
products = request("/api/catalog/products")
assert products, "Catalog must contain seeded products"
user = request("/api/auth/signup", {
    "email": f"smoke-{uuid.uuid4().hex}@example.com",
    "password": "smoke-test-correct-horse-battery-staple",
})
order = request("/api/orders", {"product_id": products[0]["id"], "quantity": 1}, user["token"])
orders = request("/api/orders", token=user["token"])
assert any(row["id"] == order["order_id"] for row in orders)
try:
    request("/api/unknown")
except HTTPError as error:
    assert error.code == 404
else:
    raise AssertionError("Unknown API route should return 404")
print("PASS: storefront, health aliases, catalog, signup, order, and unknown API routing")
```

### scripts/test_local.ps1

```text
# Test the storefront and rehearse database recovery on Docker Desktop.
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
$taskDatabase = "meridian_restore_test_$(Get-Random -Minimum 100000 -Maximum 999999)"
$taskArchive = "meridian-local-$(Get-Date -Format 'yyyyMMddTHHmmss').dump"
function Invoke-DatabaseCommand {
    param([string]$Command, [string]$Target)
    # Windows PowerShell 5 strips embedded quotes when calling native programs.
    if ($PSVersionTable.PSVersion.Major -le 5) { $Command = $Command.Replace('"','\"') }
    $taskResult = & docker compose exec -T postgres sh -ec $Command sh $Target
    if ($LASTEXITCODE -ne 0) { throw "Database operation failed for $Target" }
    return $taskResult
}
try {
    & python scripts/smoke_test.py http://localhost:8088
    if ($LASTEXITCODE -ne 0) { throw 'Storefront integration failed.' }
    New-Item -ItemType Directory -Force backups,evidence | Out-Null
    # Use docker cp for binary archives: Windows PowerShell redirection is text-based.
    Invoke-DatabaseCommand 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc -f "/tmp/$1"; pg_restore --list "/tmp/$1" > /dev/null' $taskArchive
    & docker compose cp "postgres:/tmp/$taskArchive" "backups/$taskArchive"
    if ($LASTEXITCODE -ne 0) { throw 'Copying backup archive failed.' }
    $taskChecksum = (Get-FileHash "backups/$taskArchive" -Algorithm SHA256).Hash.ToLower()
    [System.IO.File]::WriteAllText((Join-Path $PWD "backups/$taskArchive.sha256"),"$taskChecksum  $taskArchive`n",[System.Text.UTF8Encoding]::new($false))
    Invoke-DatabaseCommand 'createdb -U "$POSTGRES_USER" "$1"' $taskDatabase
    $taskRestoreCommand = 'pg_restore -U "$POSTGRES_USER" -d "$1" --no-owner --no-acl --exit-on-error --single-transaction "/tmp/ARCHIVE"'.Replace('ARCHIVE',$taskArchive)
    Invoke-DatabaseCommand $taskRestoreCommand $taskDatabase
    $taskCountCommand = 'psql -U "$POSTGRES_USER" -d "$1" -At -v ON_ERROR_STOP=1 -c "SELECT count(*) FROM products;"'
    $taskRowCommand = 'psql -U "$POSTGRES_USER" -d "$1" -At -v ON_ERROR_STOP=1 -c "SELECT row_to_json(p)::text FROM products p ORDER BY id LIMIT 1;"'
    $taskBefore = [int](Invoke-DatabaseCommand $taskCountCommand $taskDatabase)
    if ($taskBefore -lt 1) { throw 'Seed data is required for recovery proof.' }
    $taskRow = Invoke-DatabaseCommand $taskRowCommand $taskDatabase
    Invoke-DatabaseCommand 'psql -U "$POSTGRES_USER" -d "$1" -v ON_ERROR_STOP=1 -c "DELETE FROM products WHERE id = (SELECT min(id) FROM products);"' $taskDatabase
    $taskDeleted = [int](Invoke-DatabaseCommand $taskCountCommand $taskDatabase)
    Invoke-DatabaseCommand 'dropdb -U "$POSTGRES_USER" --force "$1"; createdb -U "$POSTGRES_USER" "$1"' $taskDatabase
    Invoke-DatabaseCommand $taskRestoreCommand $taskDatabase
    $taskRestored = [int](Invoke-DatabaseCommand $taskCountCommand $taskDatabase)
    $taskRestoredRow = Invoke-DatabaseCommand $taskRowCommand $taskDatabase
    if ($taskDeleted -ne ($taskBefore - 1) -or $taskRestored -ne $taskBefore -or $taskRow -ne $taskRestoredRow) {
        throw 'Database restore did not recover the exact deleted row.'
    }
    $taskEvidence = "PASS: before=$taskBefore deleted=$taskDeleted restored=$taskRestored; exact product row recovered.`nArchive: $taskArchive`nSHA256: $taskChecksum`nUTC: $([DateTimeOffset]::UtcNow.ToString('o'))"
    $taskEvidence | Set-Content evidence/local-restore.txt
    Write-Host $taskEvidence
}
finally {
    Invoke-DatabaseCommand 'dropdb -U "$POSTGRES_USER" --if-exists --force "$1"' $taskDatabase
    & docker compose exec -T postgres rm -f "/tmp/$taskArchive"
    Pop-Location
}
```

### scripts/push_ecr.ps1

```text
param(
    [Parameter(Mandatory = $true)][Alias('Profile')][string]$AwsProfile,
    [string]$Region = 'eu-west-2',
    [string]$Prefix = 'meridian'
)
$ErrorActionPreference = 'Stop'
if ($Region -notmatch '^[a-z]{2}-[a-z]+-[0-9]+$' -or $Prefix -notmatch '^[a-z][a-z0-9-]{2,30}$') {
    throw 'Invalid AWS region or repository prefix.'
}
Push-Location (Split-Path $PSScriptRoot -Parent)
$taskRegistry = $null
try {
    $taskAccount = (& aws sts get-caller-identity --profile $AwsProfile --query Account --output text).Trim()
    if ($LASTEXITCODE -ne 0 -or $taskAccount -notmatch '^[0-9]{12}$') { throw 'AWS profile authentication failed.' }
    $taskRegistry = "$taskAccount.dkr.ecr.$Region.amazonaws.com"
    $taskServices = @('auth-service', 'catalog-service', 'orders-service', 'frontend')
    # Require provisioned, immutable repositories before building or pushing.
    foreach ($taskService in $taskServices) {
        $taskMutability = & aws ecr describe-repositories --profile $AwsProfile --region $Region --repository-names "$Prefix/$taskService" --query 'repositories[0].imageTagMutability' --output text
        if ($LASTEXITCODE -ne 0 -or $taskMutability -ne 'IMMUTABLE') { throw "Provision immutable ECR repository $Prefix/$taskService first." }
    }
    $taskCommit = (& git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $taskCommit -notmatch '^[a-f0-9]{40}$') { throw 'A Git commit is required.' }
    $taskEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $taskAttempt = Get-Random -Minimum 100000 -Maximum 999999
    $taskTag = "$taskCommit-$taskEpoch-$taskAttempt"
    # Windows/ARM workstations still build the architecture of the EC2 target.
    foreach ($taskService in $taskServices) {
        & docker build --platform linux/amd64 --pull -t "${taskRegistry}/${Prefix}/${taskService}:${taskTag}" $taskService
        if ($LASTEXITCODE -ne 0) { throw "Build failed: $taskService" }
    }
    $taskPassword = & aws ecr get-login-password --profile $AwsProfile --region $Region
    if ($LASTEXITCODE -ne 0) { throw 'ECR authentication failed.' }
    $taskPassword | & docker login --username AWS --password-stdin $taskRegistry
    $taskPassword = $null
    if ($LASTEXITCODE -ne 0) { throw 'Docker registry login failed.' }
    foreach ($taskService in $taskServices) {
        & docker push "${taskRegistry}/${Prefix}/${taskService}:${taskTag}"
        if ($LASTEXITCODE -ne 0) { throw "Push failed: $taskService" }
    }
    Write-Host "Pushed all four images. IMAGE_TAG=$taskTag"
    Write-Host 'These images include the current working tree. Commit reviewed changes before publishing a release.'
}
finally {
    if ($taskRegistry) { & docker logout $taskRegistry | Out-Null }
    Pop-Location
}
```


## Appendix D. Linux operational source snapshots

### scripts/server_setup.sh

```text
#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run as root.' >&2; exit 1; }
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gnupg nginx certbot python3-certbot-nginx awscli cron unzip git logrotate
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
# shellcheck source=/dev/null
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker nginx cron certbot.timer
# Membership in docker grants root-equivalent access; only the deployment user is added.
usermod -aG docker ubuntu
install -d -m 0750 -o ubuntu -g ubuntu /opt/meridian
install -d -m 0700 -o ubuntu -g ubuntu /opt/meridian/backups
cat > /etc/cron.d/meridian-backup <<'EOF'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# 02:00 UTC daily (03:00 Lagos on the default Ubuntu UTC host).
0 2 * * * ubuntu cd /opt/meridian && /bin/bash scripts/backup_db.sh >> /opt/meridian/backups/cron.log 2>&1
EOF
chmod 0644 /etc/cron.d/meridian-backup
cat > /etc/logrotate.d/meridian-backup <<'EOF'
/opt/meridian/backups/cron.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    su ubuntu ubuntu
    create 0600 ubuntu ubuntu
}
EOF
install -d /etc/letsencrypt/renewal-hooks/deploy
printf '#!/bin/sh\nnginx -t && systemctl reload nginx\n' > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx
chmod 0755 /etc/letsencrypt/renewal-hooks/deploy/reload-nginx
echo 'Bootstrap complete. Install .env, deploy services, configure DNS, then run configure_tls.sh.'
```

### scripts/backup_db.sh

```text
#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
cd "$(dirname "$0")/.."
backup_dir=${BACKUP_DIR:-$PWD/backups}
mkdir -p "$backup_dir"
exec 9>"$backup_dir/.backup.lock"
flock -n 9 || { echo 'Backup already running.' >&2; exit 1; }
file="$backup_dir/meridian-$(date -u +%Y%m%dT%H%M%S)-$$.dump"
trap 'rm -f "$file.tmp"' EXIT
docker compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$file.tmp"
# Reject empty or unreadable archives before publishing or pruning backups.
docker compose exec -T postgres pg_restore --list < "$file.tmp" > /dev/null
mv "$file.tmp" "$file"
(cd "$backup_dir" && sha256sum "$(basename "$file")") > "$file.sha256"
find "$backup_dir" -maxdepth 1 -type f \( -name 'meridian-*.dump' -o -name 'meridian-*.dump.sha256' \) -mtime +14 -delete
echo "Backup created: $file"
```

### scripts/restore_db.sh

```text
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
file=$(realpath "${1:?Usage: restore_db.sh BACKUP TARGET_DATABASE}")
target=${2:?Supply an isolated target database, or explicitly approve production via ALLOW_PRODUCTION_RESTORE=yes}
[[ $target =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo 'Invalid database name.' >&2; exit 1; }
[[ -f $file && -f $file.sha256 ]] || { echo 'Backup and checksum required.' >&2; exit 1; }
(cd "$(dirname "$file")" && sha256sum --check "$(basename "$file").sha256")
docker compose exec -T postgres pg_restore --list < "$file" > /dev/null
production=$(docker compose exec -T postgres sh -c 'printf "%s" "$POSTGRES_DB"')
if [[ $target == "$production" && ${ALLOW_PRODUCTION_RESTORE:-no} != yes ]]; then
  echo 'Production restore requires stopped application services and ALLOW_PRODUCTION_RESTORE=yes.' >&2
  exit 1
fi
docker compose exec -T postgres sh -ec 'dropdb -U "$POSTGRES_USER" --if-exists --force "$1"; createdb -U "$POSTGRES_USER" "$1"' sh "$target"
docker compose exec -T postgres sh -c 'pg_restore -U "$POSTGRES_USER" -d "$1" --no-owner --no-acl --exit-on-error --single-transaction' sh "$target" < "$file"
docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$1" -v ON_ERROR_STOP=1 -c "SELECT count(*) AS products FROM products;"' sh "$target"
echo "Restore complete: $target"
```

### scripts/verify_restore.sh

```text
#!/usr/bin/env bash
# Mandatory manual rehearsal: copy production, delete a row in the copy, restore, compare.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
file=${1:?Usage: verify_restore.sh BACKUP}
target="meridian_restore_test_$$"
sql() {
  docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$1" -At -v ON_ERROR_STOP=1 -c "$2"' sh "$target" "$1"
}
cleanup() { docker compose exec -T postgres sh -c 'dropdb -U "$POSTGRES_USER" --if-exists --force "$1"' sh "$target"; }
trap cleanup EXIT
bash scripts/restore_db.sh "$file" "$target"
before=$(sql 'SELECT count(*) FROM products;')
[[ $before -gt 0 ]] || { echo 'No seeded rows; cannot prove recovery.' >&2; exit 1; }
row=$(sql 'SELECT row_to_json(p)::text FROM products p ORDER BY id LIMIT 1;')
sql 'DELETE FROM products WHERE id = (SELECT min(id) FROM products);'
after_delete=$(sql 'SELECT count(*) FROM products;')
[[ $after_delete -eq $((before - 1)) ]]
bash scripts/restore_db.sh "$file" "$target"
after_restore=$(sql 'SELECT count(*) FROM products;')
restored_row=$(sql 'SELECT row_to_json(p)::text FROM products p ORDER BY id LIMIT 1;')
[[ $before == "$after_restore" && $row == "$restored_row" ]]
echo "PASS: row recovered exactly; before=$before deleted=$after_delete restored=$after_restore"
```

### scripts/update_duckdns.sh

```text
#!/usr/bin/env bash
set -Eeuo pipefail
subdomain=${1:?Usage: DUCKDNS_TOKEN=... bash scripts/update_duckdns.sh SUBDOMAIN PUBLIC_IP}
address=${2:?Supply Terraform ec2_public_ip output}
: "${DUCKDNS_TOKEN:?Supply DuckDNS token via environment}"
[[ $subdomain =~ ^[a-z0-9-]+$ && $address =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ && $DUCKDNS_TOKEN =~ ^[a-zA-Z0-9-]+$ ]] || exit 1
# Read the token from stdin so it is absent from curl's process arguments.
response=$(printf 'url = "https://www.duckdns.org/update"\nget\ndata-urlencode = "domains=%s"\ndata-urlencode = "token=%s"\ndata-urlencode = "ip=%s"\n' "$subdomain" "$DUCKDNS_TOKEN" "$address" | curl --config - --fail --silent --show-error)
[[ $response == OK ]] || { echo 'DuckDNS update failed.' >&2; exit 1; }
echo "DuckDNS updated: $subdomain.duckdns.org -> $address"
```

### scripts/configure_tls.sh

```text
#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run as root.' >&2; exit 1; }
cd "$(dirname "$0")/.."
domain=${1:?Usage: sudo bash scripts/configure_tls.sh DOMAIN EMAIL}
email=${2:?Supply certificate contact email}
[[ $domain =~ ^[a-z0-9-]+\.duckdns\.org$ ]] || { echo 'Expected a DuckDNS hostname.' >&2; exit 1; }
if [[ ! -s /etc/letsencrypt/live/$domain/fullchain.pem ]]; then
  sed "s/__DOMAIN__/$domain/g" nginx/meridian-http.conf > /etc/nginx/sites-available/meridian
  ln -sfn /etc/nginx/sites-available/meridian /etc/nginx/sites-enabled/meridian
  rm -f /etc/nginx/sites-enabled/default
  nginx -t
  systemctl reload nginx
  certbot certonly --nginx --non-interactive --agree-tos --email "$email" -d "$domain"
fi
sed "s/__DOMAIN__/$domain/g" nginx/meridian-https-reference.conf > /etc/nginx/sites-available/meridian
ln -sfn /etc/nginx/sites-available/meridian /etc/nginx/sites-enabled/meridian
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx
certbot renew --dry-run
```

### scripts/deploy.sh

```text
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
region=${1:?AWS region required}
registry=${2:?ECR registry required}
prefix=${3:?Repository prefix required}
tag=${4:?Immutable image tag required}
[[ $region =~ ^[a-z]{2}-[a-z]+-[0-9]+$ && $registry =~ ^[0-9]{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com$ && $prefix =~ ^[a-z][a-z0-9-]+$ && $tag =~ ^[a-f0-9]{40}-[0-9]+-[0-9]+$ ]] || exit 1
[[ -f .env ]] || { echo 'Install production .env first.' >&2; exit 1; }
exec 9>/opt/meridian/.deploy.lock
flock -n 9 || { echo 'Another deploy is running.' >&2; exit 1; }
export ECR_REGISTRY=$registry ECR_REPOSITORY_PREFIX=$prefix IMAGE_TAG=$tag
docker compose config --quiet
aws ecr get-login-password --region "$region" | docker login --username AWS --password-stdin "$registry"
trap 'docker logout "$registry" >/dev/null' EXIT
docker compose pull
# Protect the existing database before replacing application containers.
if docker compose ps --status running --services | grep -qx postgres; then
  bash scripts/backup_db.sh
fi
docker compose up -d --no-build --wait --wait-timeout 180
for port in 8001 8002 8003; do curl --fail --silent --show-error "http://127.0.0.1:$port/healthz"; done
curl --fail --silent --show-error http://127.0.0.1:8080/ > /dev/null
# Persist the exact release for cron and future compose commands.
sed -i '/^ECR_REGISTRY=/d; /^ECR_REPOSITORY_PREFIX=/d; /^IMAGE_TAG=/d' .env
printf '\nECR_REGISTRY=%s\nECR_REPOSITORY_PREFIX=%s\nIMAGE_TAG=%s\n' "$registry" "$prefix" "$tag" >> .env
chmod 600 .env
echo "Deployed $tag"
```


## Appendix E. GitHub workflow source snapshots

### .github/workflows/ci.yml

```text
name: CI
on:
  pull_request:
  push:
    branches-ignore: [main]
  workflow_call:
permissions:
  contents: read
jobs:
  validate:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    env:
      DB_PASSWORD: ci-only-database-password
      JWT_SECRET: ci-only-long-random-secret-not-for-production
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.14.4
      - name: Validate Terraform
        run: |
          terraform -chdir=terraform fmt -check
          terraform -chdir=terraform init -backend=false -input=false
          terraform -chdir=terraform validate
      - name: Check shell scripts and Compose
        run: |
          sudo apt-get update
          sudo apt-get install -y shellcheck
          shellcheck scripts/*.sh
          docker compose config --quiet
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - name: Build and start integration stack
        run: docker compose -f docker-compose.yml -f docker-compose.test.yml up -d --build --wait --wait-timeout 180
      - name: Auth tests against real PostgreSQL
        env:
          DB_HOST: 127.0.0.1
        run: |
          python -m pip install -r auth-service/requirements.txt pytest==8.3.5 httpx==0.27.0
          python -m pytest auth-service/tests -q
      - name: Reverse proxy and storefront integration
        run: python scripts/smoke_test.py http://127.0.0.1:8088
      - name: Backup and restore rehearsal
        run: |
          bash scripts/backup_db.sh
          backup=$(find backups -maxdepth 1 -name '*.dump' | sort | tail -1)
          bash scripts/verify_restore.sh "$backup"
      - name: Logs on failure
        if: failure()
        run: docker compose -f docker-compose.yml -f docker-compose.test.yml logs --no-color
      - name: Stop isolated CI stack
        if: always()
        run: docker compose -f docker-compose.yml -f docker-compose.test.yml down --volumes
```

### .github/workflows/deploy.yml

```text
name: Deploy main
on:
  push:
    branches: [main]
permissions:
  contents: read
concurrency:
  group: meridian-production
  cancel-in-progress: false
jobs:
  ci:
    uses: ./.github/workflows/ci.yml
  deploy:
    needs: ci
    runs-on: ubuntu-latest
    timeout-minutes: 35
    permissions:
      contents: read
      id-token: write
    env:
      AWS_REGION: ${{ vars.AWS_REGION }}
      ECR_REGISTRY: ${{ vars.ECR_REGISTRY }}
      ECR_REPOSITORY_PREFIX: ${{ vars.ECR_REPOSITORY_PREFIX }}
      EC2_HOST: ${{ vars.EC2_HOST }}
      EC2_SECURITY_GROUP_ID: ${{ vars.EC2_SECURITY_GROUP_ID }}
      IMAGE_TAG: ${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}
      DOMAIN: ${{ vars.DOMAIN }}
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}
          role-session-name: meridian-${{ github.run_id }}
      - name: Build and push unique immutable images
        run: |
          set -Eeuo pipefail
          : "${AWS_REGION:?}" "${ECR_REGISTRY:?}" "${ECR_REPOSITORY_PREFIX:?}"
          [[ "$AWS_REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]+$ ]]
          [[ "$ECR_REGISTRY" =~ ^[0-9]{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com$ ]]
          [[ "$ECR_REPOSITORY_PREFIX" =~ ^[a-z][a-z0-9-]{2,30}$ ]]
          aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"
          trap 'docker logout "$ECR_REGISTRY" >/dev/null' EXIT
          for service in auth-service catalog-service orders-service frontend; do
            image="$ECR_REGISTRY/$ECR_REPOSITORY_PREFIX/$service:$IMAGE_TAG"
            docker build --pull -t "$image" "$service"
            docker push "$image"
          done
      - name: Whitelist runner, deploy over verified SSH, revoke ingress
        env:
          SSH_PRIVATE_KEY: ${{ secrets.EC2_SSH_PRIVATE_KEY }}
          SSH_KNOWN_HOSTS: ${{ secrets.EC2_SSH_KNOWN_HOSTS }}
        run: |
          set -Eeuo pipefail
          : "${EC2_HOST:?}" "${EC2_SECURITY_GROUP_ID:?}" "${SSH_PRIVATE_KEY:?}" "${SSH_KNOWN_HOSTS:?}"
          [[ "$EC2_HOST" =~ ^[0-9.]+$ ]]
          install -d -m 700 ~/.ssh
          printf '%s\n' "$SSH_PRIVATE_KEY" > ~/.ssh/meridian
          printf '%s\n' "$SSH_KNOWN_HOSTS" > ~/.ssh/known_hosts
          chmod 600 ~/.ssh/meridian ~/.ssh/known_hosts
          runner_ip=$(curl --fail --silent --show-error https://checkip.amazonaws.com)
          [[ "$runner_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
          rule_id=''
          cleanup() {
            result=$?
            trap - EXIT
            if [[ -n "$rule_id" ]]; then
              aws ec2 revoke-security-group-ingress --group-id "$EC2_SECURITY_GROUP_ID" --security-group-rule-ids "$rule_id" || result=1
            fi
            rm -f ~/.ssh/meridian
            exit "$result"
          }
          trap cleanup EXIT
          rule_id=$(aws ec2 authorize-security-group-ingress --group-id "$EC2_SECURITY_GROUP_ID" \
            --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$runner_ip/32,Description=github-$GITHUB_RUN_ID}]" \
            --query 'SecurityGroupRules[0].SecurityGroupRuleId' --output text)
          [[ "$rule_id" == sgr-* ]]
          # Packages contain operational files only; production secrets stay on the host.
          tar -czf release.tgz docker-compose.yml scripts nginx
          ssh_opts=(-i ~/.ssh/meridian -o StrictHostKeyChecking=yes -o ConnectTimeout=15)
          scp "${ssh_opts[@]}" release.tgz "ubuntu@$EC2_HOST:/opt/meridian/release-$IMAGE_TAG.tgz"
          # shellcheck disable=SC2029
          ssh "${ssh_opts[@]}" "ubuntu@$EC2_HOST" \
            "cd /opt/meridian && tar -xzf release-$IMAGE_TAG.tgz && rm release-$IMAGE_TAG.tgz && bash scripts/deploy.sh '$AWS_REGION' '$ECR_REGISTRY' '$ECR_REPOSITORY_PREFIX' '$IMAGE_TAG'"
      - name: Verify live HTTPS and HTTP redirect
        run: |
          set -Eeuo pipefail
          [[ "$DOMAIN" =~ ^[a-z0-9-]+\.duckdns\.org$ ]]
          python scripts/smoke_test.py "https://$DOMAIN"
          code=$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' "http://$DOMAIN/")
          [[ "$code" == 301 || "$code" == 308 ]]
```


## Appendix F. Environment and Git hygiene snapshots

### .env.example

```text
# Copy this file to .env and fill in real values.
# NEVER commit your actual .env file.

# --- Database ---
DB_NAME=meridian_db
DB_USER=meridian
DB_PASSWORD=change-me-strong-password

# --- Auth ---
# Generate a strong random secret, e.g.: openssl rand -hex 32
JWT_SECRET=change-me-to-a-long-random-string
JWT_EXPIRY_MINUTES=60

# --- Domain (used in Week 1 Wed onward, not by docker-compose directly) ---
DOMAIN=your-shop.duckdns.org

# --- AWS / ECR (used by the CI/CD pipeline you build in Week 2) ---
AWS_REGION=eu-west-2
ECR_REGISTRY=
ECR_REPOSITORY_PREFIX=meridian
IMAGE_TAG=local

# --- EC2 deploy target (used by the CI/CD pipeline you build in Week 2) ---
EC2_HOST=
EC2_SSH_USER=ubuntu
```

### .gitignore

```text
.env
.env.*
!.env.example
*.pem
*.key
__pycache__/
.pytest_cache/
.venv/
node_modules/
backups/
evidence/
terraform/.terraform/
**/.terraform/
*.tfstate*
*.tfplan
terraform/terraform.tfvars
**/terraform.tfvars
```

### .gitattributes

```text
* text=auto
*.sh text eol=lf
*.yml text eol=lf
Dockerfile text eol=lf
```
