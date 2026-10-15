# policy-bot on Cloud Run (prototype)

Deploys the upstream `palantirtechnologies/policy-bot` image to Cloud Run in
`xyla-development-2`, behind an external HTTPS load balancer at
`policy-bot.xyladev2.live`. Nothing here touches the Django environment's
Terraform state: this root has its own state prefix in the same bucket.

What gets created: Docker Hub pull-through repository in Artifact Registry,
a runtime service account, five Secret Manager secrets, the Cloud Run service,
a global load balancer with a managed certificate, and one DNS A record.

## Prerequisites

- `terraform` 1.5.7 or newer, `gcloud` authenticated with access to
  `xyla-development-2` and the `xyla-development-2-bucket-tfstate` bucket.
- `gcloud auth application-default login` for the Google provider.
- Admin on the `andyyoon2/policy-bot-test` repo.

## Steps

1. **Create the base resources.** The service is gated behind
   `deploy_service` so the GitHub App can be created with the final URL first.

   ```sh
   cd infra/policy-bot
   terraform init
   terraform apply
   terraform output public_url webhook_url oauth_callback_url
   ```

2. **Create the policy-bot GitHub App** under your personal account
   (Settings, Developer settings, GitHub Apps, New GitHub App).

   - Homepage URL: `public_url` output.
   - Callback URL: `oauth_callback_url` output. Uncheck "Request user
     authorization (OAuth) during installation". Leave "Expire user
     authorization tokens" as is.
   - Webhook: active, URL = `webhook_url` output, secret =
     `openssl rand -hex 32` (keep it for step 3).
   - Repository permissions: Actions read, Administration read, Checks read,
     Commit statuses **read & write**, Contents read, Custom properties read,
     Issues read, Merge queues read, Metadata read, Pull requests
     **read & write**.
   - Organization permissions: Members read (harmless on a personal account).
   - Subscribe to events: Check run, Issue comment, Merge group, Pull request,
     Pull request review, Status, Workflow run.
   - Where can this App be installed: only this account.

   After creation: note the **App ID** and **Client ID**, click "Generate a
   new client secret" and keep it, then "Generate a private key" and download
   the `.pem`.

3. **Load the secrets.**

   ```sh
   ../../scripts/set-secrets.sh ~/Downloads/<app-name>.<date>.private-key.pem
   ```

4. **Deploy the service.** Copy `terraform.tfvars.example` to
   `terraform.tfvars`, fill in `github_app_id` and `github_oauth_client_id`,
   set `deploy_service = true`, then:

   ```sh
   terraform apply
   ```

   The managed certificate takes 30 to 60 minutes to become ACTIVE. Until
   then `https://policy-bot.xyladev2.live` returns a TLS error, which is
   expected. Check with
   `gcloud compute ssl-certificates describe policy-bot-proto-cert --format='value(managed.status)'`.

5. **Install the App** on `andyyoon2/policy-bot-test` from the App's page
   (Install App). Open `public_url` in a browser and sign in with GitHub to
   confirm the UI works. Open the App's Advanced tab to see webhook
   deliveries and redeliver any that failed while the certificate was
   provisioning.

6. **Open a PR** touching `frontend/foo.txt`. The `policy-bot: main` status
   should appear within a few seconds. Then follow the ruleset and test
   matrix in the repo README.

## Day-to-day

- Logs: `gcloud run services logs read policy-bot-proto --region us-central1`.
- Rotate any secret by re-running `set-secrets.sh`; Cloud Run reads `latest`
  on the next instance start, so redeploy with `terraform apply -replace`
  on the service or roll a new revision.
- Upgrade policy-bot by bumping `policy_bot_version` after reading the
  release notes.
- Tear down: `terraform destroy`. Secrets and the state prefix are the only
  things left behind by design (`disable_on_destroy = false` on APIs).

## Notes

- Cloud Run's direct `run.app` URL returns 404 while the load balancer is in
  front, because ingress is restricted to the load balancer. Set
  `hostname = ""` to serve the `run.app` URL directly and skip LB and DNS.
- The `allUsers` invoker binding is required for GitHub webhooks and the
  browser UI. Other Cloud Run services in this project already use it.
- The DNS record is added to the existing `xyladev2-live` zone, which is
  managed by the Django environment's Terraform. Records are separate
  resources, so neither root will fight over it.
