# Lab 9, Part 3 — Spry's core on AWS and on Google Cloud: what it costs

On-demand list prices in USD, AWS us-east-1 and Google Cloud us-central1, 730 hours a month, no tax.
GCP prices: Lab 9 page (checked 5 Nov 2026) / Google Cloud Pricing Calculator. AWS: Lab 4.

## My project, nobody using it for a month

Services chosen in the ADR (`docs/adr/0008-spry-on-google-cloud.md`): Firebase Hosting, Cloud Run,
Cloud SQL `db-f1-micro` with 10 GB SSD, Artifact Registry, Secret Manager.

| Piece | AWS (Lab 4, Stage 2) | Google Cloud (Lab 9) |
|---|---|---|
| Frontend + CDN + HTTPS | CloudFront Free plan, WAF included → $0 | Firebase Hosting free plan → $0 |
| API | Lambda, idle → $0 | Cloud Run, scaled to zero → $0 |
| Database compute | Aurora Serverless v2, paused → $0 | Cloud SQL db-f1-micro running, $0.0105/h × 730 h → $7.67 |
| Database storage | ~1 GB at $0.10/GB → $0.10 | 10 GB SSD at $0.17/GB → $1.70 |
| Registry, secrets, logs | ECR, SSM, CloudWatch → a few cents (~$0.20) | Artifact Registry < 0.5 GB, 1 secret version, Cloud Logging → $0 (free tier) |
| **Total** | **≈ $0.30** | **≈ $9.40**, or **≈ $1.70** with the instance stopped |

## The four traffic profiles from Lab 4

**Assumptions**

- *Nobody:* no requests. *Class demos:* 10 sessions × 2 h = 20 h of use a month. *Office hours:* 8 h × 22 days = 176 h.
  *Busy around the clock:* 730 h, ~1 request per second → ~2.6 M requests a month, 100 ms each, 2 database reads per request.
- Aurora Serverless v2: $0.12 per ACU-hour, ~0.5 ACU on average while awake (min 0 = paused, max 1);
  it pauses after 5 minutes idle, so each session adds ~5 min awake → demos ≈ 21 h, office hours ≈ 178 h, busy 730 h.
- Lambda: 512 MB; free tier 1 M requests and 400,000 GB-s a month, then $0.20 per million requests.
- Cloud Run (request-based billing, 1 vCPU, 0.5 GiB): free 2 M requests, 180,000 vCPU-s, 360,000 GiB-s a month;
  then $0.40 per million requests, $0.000024 per vCPU-s, $0.0000025 per GiB-s.
- Cloud SQL: storage $1.70 is billed always; compute $0.0105/h only while running. "Stopped when idle" = started
  for the hours of use (manually for demos, by 2 Cloud Scheduler jobs for office hours — within the 3 free jobs).
- Firestore: 50,000 reads and 20,000 writes free *per day*, then $0.03 per 100,000 reads.

**Monthly cost**

| Profile | AWS: Lambda + Aurora (paused when idle) | GCP: Cloud SQL running 24/7 (as in `gcp/`) | GCP: Cloud SQL stopped when idle | GCP: Firestore instead of SQL |
|---|---|---|---|---|
| Nobody (0 h) | 0.30 → **$0.30** | 9.37 → **$9.40** | 1.70 → **$1.70** | **$0** |
| Class demos (20 h) | 0.30 + 21 h × 0.5 × 0.12 = 1.26 → **$1.56** | **$9.40** | 1.70 + 20 × 0.0105 = 0.21 → **$1.91** | **$0** |
| Office hours (176 h) | 0.30 + 178 × 0.06 = 10.68 → **$10.98** | **$9.40** | 1.70 + 176 × 0.0105 = 1.85 → **$3.55** | **$0** |
| Busy 24/7 (2.6 M req) | 0.30 + 730 × 0.06 = 43.80 + Lambda 1.6 M × 0.20 = 0.32 → **$44.42** | 9.37 + Cloud Run ≈ 2.16 → **$11.53** * | same as 24/7 → **$11.53** * | Cloud Run 2.16 + reads ≈ 1.11 → **≈ $3.30** |

\* Cloud Run, busy: requests (2.6 − 2.0) M × $0.40 = $0.24; CPU 260,000 vCPU-s − 180,000 free = 80,000 × $0.000024 = $1.92;
memory 130,000 GiB-s is inside the free 360,000. A shared-core `db-f1-micro` (0.6 GB) is probably too small for steady
load; with `db-g1-small` ($0.035/h → $25.55) the busy GCP total is ≈ $29.40, still below Aurora.
Firestore, busy: 5.2 M reads/month ≈ 173,000/day − 50,000 free = 123,000/day × 30 × $0.03/100,000 ≈ $1.11.

## Answers

**Which cloud is cheaper for each profile, and which single line decides it?**

- *Nobody* and *class demos*: **AWS** ($0.30 and $1.56 against $9.40 for Cloud SQL left running, or $1.70–1.91 stopped).
- *Office hours*: **Google Cloud** ($9.40 running, $3.55 stopped at night, against $10.98).
- *Busy around the clock*: **Google Cloud** (~$11.50, or ~$29 with a bigger instance, against ~$44).
- The deciding line is always **database compute**. Everything else (CDN, API, registry, secrets) is free or
  cents on both clouds. Aurora costs nothing while paused but ~$0.06/h while awake; Cloud SQL costs ~$0.01/h
  but never pauses by itself. So AWS wins when the app sleeps most of the month, GCP wins once the database is
  awake more than ~150 hours (≈ $9.40 / $0.06) — and Firestore beats both at student traffic if we give up SQL.

**Lab 4 showed Aurora can become more expensive than an instance when something keeps it awake. Where is the
equivalent trap on the GCP side?**

- **Cloud SQL simply does not pause**: the trap is not "something keeps it awake" but "nobody stops it". A demo
  instance forgotten after the lab bills $7.67 a month for compute plus storage, and storage is billed even while stopped.
- **Cloud Run** stays near zero only with `min_instance_count = 0` and request-based billing. Setting a minimum
  instance "to avoid cold starts" or switching to instance-based billing (CPU always allocated) bills the instance
  around the clock — the same as an Aurora that never sleeps.
- **Firestore** is the per-request version of the trap: a list page or a poll that reads hundreds of documents on
  every visit spends the 50,000 free daily reads after ~100 visits, and from then on every visit costs money.
