# k8s-pgbouncer

A hardened and modernized PgBouncer deployment for GKE.

## Features & Enhancements
- **Security Contexts:** Pods run as non-root (UID/GID `70`) with read-only root filesystems and dropped Linux capabilities.
- **Separate Secret Storage:** Database client credentials are split out of the ConfigMap and placed into a secure Kubernetes Secret.
- **SSL/TLS verify-ca Enforcement:** Encrypts backend PostgreSQL/Cloud SQL traffic and validates certificates securely.
- **No Root Wrap Script:** Avoids wrapper shell scripts running as `root` inside the container; utilizes a Debian multi-stage build.
- **High Availability & Fault Tolerance:** Configured with `replicas: 2`, a `PodDisruptionBudget` (`minAvailable: 1`), and soft Pod Anti-Affinity to spread pods across separate VMs when available.
- **Improved Logging:** Logs are routed directly to standard output/error, allowing native `kubectl logs` integration without log file storage overhead.
- **Zero-Downtime Hot-Reload:** Safe, separate mounting directories allow PgBouncer config changes to be reloaded live.

## Build and Deploy

### 1. Build and Push Docker Image (v2)

To build the new Debian Bookworm-based image compiling PgBouncer 1.23.1 and push to your registry:

Using Artifact Registry:
```bash
docker build --no-cache -t asia-docker.pkg.dev/zeus-007/pgbouncer/zeus-pgbouncer:v2 .
docker push asia-docker.pkg.dev/zeus-007/pgbouncer/zeus-pgbouncer:v2
```

### 2. Deploy Manifests to GKE

Deploy the Secrets, ConfigMap, and Deployment manifests in order:

```bash
# 1. Apply userlist credentials secret
kubectl apply -f secret-pgbouncer.yaml

# 2. Apply database SSL CA certificate secret
# (Make sure to populate secret-pgbouncer-certs.yaml with your CA cert first)
kubectl apply -f secret-pgbouncer-certs.yaml

# 3. Apply pgbouncer.ini configuration map
kubectl apply -f configmap-pgbouncer.yaml

# 4. Apply deployment, service, and PodDisruptionBudget
kubectl apply -f deployment-pgbouncer.yaml
```

---

## Connection Pool Sizing & Tuning

Since this deployment uses **2 replicas** in production for high availability, be mindful of how connection pools scale against your backend database's limits.

### Formula for Maximum Backend Connections
```text
Total Connections = (Number of Configured Database Users) * (default_pool_size) * (Replicas)
```

With **4 application users**, a `default_pool_size` of **40**, and **2 replicas**, the total maximum connections from PgBouncer to your PostgreSQL database can reach:
```text
4 * 40 * 2 = 320 connections
```

### Best Practices:
1. **Check Backend Limit:** Find your database's connection limit by running:
   ```sql
   SHOW max_connections;
   ```
2. **Leave Headroom:** Ensure the calculated maximum connections from PgBouncer are safely below your database's `max_connections`, leaving a margin (e.g., 20-30 connections) for direct administrator or analytics tool logins.
3. **Adjust Config:** Tune `default_pool_size` in `configmap-pgbouncer.yaml` accordingly before applying updates.

---

## Operations & Hot-Reloading

### Reloading configuration without downtime
Since we mount the ConfigMap and Secrets directly (without using `subPath`), Kubernetes automatically updates the mounted files inside the container when you update the ConfigMap/Secret.

To apply changes to `pgbouncer.ini` or `userlist.txt` without restarting the pod:

1. Update and apply the yaml (`kubectl apply -f ...`).
2. Run a SIGHUP command on the container process, or connect to the PgBouncer administrative console and run `RELOAD`:

```bash
# Option A: Send SIGHUP signal to the pgbouncer process
kubectl exec -it -n prod deployment/pgbouncer -- kill -HUP 1

# Option B: Connect to administrative console and reload
psql -h pgbouncer -p 5432 -U postgres pgbouncer
# (Enter the postgres admin password set in userlist.txt)
pgbouncer=# RELOAD;
```

---

## Test Benchmarking
Benchmark performance under load using `pgbench`:

```bash
# Initialize pgbench test database
pgbench -i -h 10.248.11.223 -U postgres postgres

# Run benchmark test through PgBouncer
pgbench -h pgbouncer -c 100 -T 60 -S -n -U postgres postgres
```
