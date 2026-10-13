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
