#!/usr/bin/env bash
# TAI-style Order Management Portal
# Platform: Amazon Linux 2023
# Web: Nginx + PHP-FPM
# Database: PostgreSQL at 10.0.2.12
# App: English order management, manual creation, search, status updates, 75 sample orders

set -Eeuo pipefail
umask 027

# ============================================================
# CONFIGURATION
# ============================================================

APP_NAME="TAI Order Management"
APP_DIR="/var/www/tai-order-portal"
APP_USER="nginx"
APP_GROUP="nginx"
NGINX_CONF="/etc/nginx/conf.d/tai-order-portal.conf"
PHP_FPM_POOL="/etc/php-fpm.d/www.conf"

PG_HOST="10.0.2.12"
PG_PORT="5432"
PG_DATABASE="crm"
PG_USER="app"

# Override this before running the script if needed:
# export PG_PASSWORD='your-database-password'
PG_PASSWORD="${PG_PASSWORD:-App#2026}"

MAX_ATTEMPTS=60
RETRY_SECONDS=5

# ============================================================
# ROOT CHECK
# ============================================================

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: Run this script as root:"
    echo "sudo bash $0"
    exit 1
fi

echo "============================================================"
echo "Installing ${APP_NAME}"
echo "============================================================"

# ============================================================
# INSTALL PACKAGES
# Do not install curl: Amazon Linux 2023 may have curl-minimal.
# ============================================================

dnf install -y \
    nginx \
    php-fpm \
    php-cli \
    php-pgsql \
    php-mbstring \
    php-json \
    php-common \
    postgresql15 \
    python3 \
    util-linux

# Verify required commands and extensions.
command -v nginx >/dev/null || {
    echo "ERROR: nginx was not installed."
    exit 1
}

command -v php >/dev/null || {
    echo "ERROR: PHP was not installed."
    exit 1
}

command -v psql >/dev/null || {
    echo "ERROR: psql was not installed. Check the available PostgreSQL client package."
    exit 1
}

php -m | grep -qi '^pgsql$' || {
    echo "ERROR: PHP PostgreSQL extension (pgsql) is missing."
    exit 1
}

php -m | grep -qi '^pdo_pgsql$' || {
    echo "ERROR: PHP PDO PostgreSQL extension (pdo_pgsql) is missing."
    exit 1
}

# ============================================================
# WAIT FOR POSTGRESQL
# ============================================================

echo
echo "Waiting for PostgreSQL at ${PG_HOST}:${PG_PORT}..."

DB_READY=0

for ((i=1; i<=MAX_ATTEMPTS; i++)); do
    if timeout 3 bash -c ":</dev/tcp/${PG_HOST}/${PG_PORT}" 2>/dev/null; then
        DB_READY=1
        echo "PostgreSQL TCP port is reachable."
        break
    fi

    echo "Attempt ${i}/${MAX_ATTEMPTS}: PostgreSQL is not reachable yet."
    sleep "${RETRY_SECONDS}"
done

if [[ "${DB_READY}" -ne 1 ]]; then
    echo "ERROR: PostgreSQL did not become reachable."
    echo "Check the database server, routing, security groups, and firewall."
    exit 1
fi

# Verify credentials and the target database.
echo "Checking PostgreSQL credentials and database..."

if ! PGPASSWORD="${PG_PASSWORD}" psql \
    "host=${PG_HOST} port=${PG_PORT} dbname=${PG_DATABASE} user=${PG_USER} connect_timeout=5" \
    -v ON_ERROR_STOP=1 \
    -c "SELECT 1;" >/dev/null; then
    echo
    echo "ERROR: Could not connect to the PostgreSQL database."
    echo "Expected database: ${PG_DATABASE}"
    echo "Expected user: ${PG_USER}"
    echo "Host: ${PG_HOST}:${PG_PORT}"
    echo
    echo "Ensure the database server has the database and user configured."
    echo "Also verify that pg_hba.conf permits this app server's private IP."
    exit 1
fi

echo "PostgreSQL authentication successful."

# ============================================================
# CREATE DATABASE TABLES AND SEED 75 ORDERS
# The configured database user needs CREATE privileges on schema public.
# ============================================================

echo "Creating the orders table and indexes..."

PGPASSWORD="${PG_PASSWORD}" psql \
    "host=${PG_HOST} port=${PG_PORT} dbname=${PG_DATABASE} user=${PG_USER} connect_timeout=5" \
    -v ON_ERROR_STOP=1 <<'SQL'
CREATE TABLE IF NOT EXISTS public.orders (
    id BIGSERIAL PRIMARY KEY,
    order_number VARCHAR(40) NOT NULL UNIQUE,
    customer_name VARCHAR(180) NOT NULL,
    customer_email VARCHAR(180) NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    status VARCHAR(30) NOT NULL DEFAULT 'Pending'
        CHECK (status IN ('Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled')),
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE,
    amount NUMERIC(12,2) NOT NULL DEFAULT 0
        CHECK (amount >= 0),
    notes TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orders_order_date
    ON public.orders (order_date DESC);

CREATE INDEX IF NOT EXISTS idx_orders_status
    ON public.orders (status);

CREATE INDEX IF NOT EXISTS idx_orders_customer_name
    ON public.orders (customer_name);

CREATE INDEX IF NOT EXISTS idx_orders_order_number
    ON public.orders (order_number);
SQL

# Seed only if the table is empty.
ORDER_COUNT="$(
    PGPASSWORD="${PG_PASSWORD}" psql \
        "host=${PG_HOST} port=${PG_PORT} dbname=${PG_DATABASE} user=${PG_USER} connect_timeout=5" \
        -t -A -v ON_ERROR_STOP=1 \
        -c "SELECT COUNT(*) FROM public.orders;"
)"

if [[ "${ORDER_COUNT}" == "0" ]]; then
    echo "Adding 75 sample orders..."

    PGPASSWORD="${PG_PASSWORD}" psql \
        "host=${PG_HOST} port=${PG_PORT} dbname=${PG_DATABASE} user=${PG_USER} connect_timeout=5" \
        -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO public.orders
    (order_number, customer_name, customer_email, description,
     status, order_date, due_date, amount, notes)
SELECT
    'TAI-' || LPAD(n::TEXT, 5, '0'),
    (ARRAY[
        'Acme Industries',
        'Globex Retail',
        'Initech Software',
        'Umbrella Trading',
        'Wayne Enterprises',
        'Stark Logistics',
        'Northwind Supplies',
        'BlueSky Manufacturing',
        'Pinnacle Systems',
        'Atlas Distribution',
        'Contoso Group',
        'Apex Components',
        'Summit Electronics',
        'Redwood Services',
        'Silverline Products'
    ])[((n - 1) % 15) + 1],
    'orders' || n || '@example.com',
    (ARRAY[
        'Standard equipment order',
        'Replacement parts',
        'Quarterly supplies',
        'Customer replenishment',
        'Industrial components',
        'Hardware shipment',
        'Maintenance materials',
        'Software equipment order',
        'Bulk inventory request',
        'Express delivery order'
    ])[((n - 1) % 10) + 1],
    (ARRAY[
        'Pending',
        'Processing',
        'Shipped',
        'Delivered',
        'Cancelled'
    ])[((n - 1) % 5) + 1],
    CURRENT_DATE - ((n - 1) % 90),
    CURRENT_DATE + ((n % 30) - 10),
    ROUND((50 + ((n * 137) % 9500))::NUMERIC, 2),
    'Sample record for demonstration'
FROM generate_series(1, 75) AS n
ON CONFLICT (order_number) DO NOTHING;
SQL
else
    echo "The orders table already contains ${ORDER_COUNT} records; keeping existing data."
fi

# ============================================================
# CREATE APPLICATION DIRECTORY
# ============================================================

mkdir -p "${APP_DIR}"
chown -R "${APP_USER}:${APP_GROUP}" "${APP_DIR}"
chmod 0750 "${APP_DIR}"

# Store DB credentials in a root-owned environment file.
# PHP-FPM reads this through its pool configuration.
install -o root -g root -m 0640 /dev/null /etc/tai-order-portal.env

cat > /etc/tai-order-portal.env <<EOF
PG_HOST=${PG_HOST}
PG_PORT=${PG_PORT}
PG_DATABASE=${PG_DATABASE}
PG_USER=${PG_USER}
PG_PASSWORD=${PG_PASSWORD}
EOF

# ============================================================
# PHP APPLICATION
# ============================================================

cat > "${APP_DIR}/index.php" <<'PHP'
<?php
declare(strict_types=1);

session_start();

function envv(string $key, string $default = ''): string {
    $value = getenv($key);
    return $value === false ? $default : $value;
}

function h(mixed $value): string {
    return htmlspecialchars((string)$value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function db(): PDO {
    static $pdo = null;

    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $host = envv('PG_HOST', '10.0.2.12');
    $port = envv('PG_PORT', '5432');
    $database = envv('PG_DATABASE', 'crm');
    $user = envv('PG_USER', 'app');
    $password = envv('PG_PASSWORD');

    $dsn = "pgsql:host={$host};port={$port};dbname={$database};connect_timeout=5";

    $pdo = new PDO($dsn, $user, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);

    return $pdo;
}

function csrfToken(): string {
    if (empty($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

function verifyCsrf(): void {
    $sent = (string)($_POST['csrf_token'] ?? '');
    $saved = (string)($_SESSION['csrf_token'] ?? '');

    if ($saved === '' || !hash_equals($saved, $sent)) {
        http_response_code(403);
        exit('Invalid request token. Refresh the page and try again.');
    }
}

function redirectHome(string $query = ''): never {
    header('Location: /' . ($query !== '' ? '?' . $query : ''));
    exit;
}

$statuses = ['Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled'];
$message = '';
$error = '';

try {
    $pdo = db();

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        verifyCsrf();
        $action = (string)($_POST['action'] ?? '');

        if ($action === 'create') {
            $customer = trim((string)($_POST['customer_name'] ?? ''));
            $email = trim((string)($_POST['customer_email'] ?? ''));
            $description = trim((string)($_POST['description'] ?? ''));
            $status = (string)($_POST['status'] ?? 'Pending');
            $orderDate = (string)($_POST['order_date'] ?? date('Y-m-d'));
            $dueDate = trim((string)($_POST['due_date'] ?? ''));
            $amountText = trim((string)($_POST['amount'] ?? '0'));
            $notes = trim((string)($_POST['notes'] ?? ''));
            $orderNumber = trim((string)($_POST['order_number'] ?? ''));

            if ($customer === '') {
                throw new RuntimeException('Customer name is required.');
            }

            if (!in_array($status, $statuses, true)) {
                throw new RuntimeException('Invalid order status.');
            }

            if (!filter_var($email, FILTER_VALIDATE_EMAIL) && $email !== '') {
                throw new RuntimeException('Enter a valid email address.');
            }

            if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $orderDate)) {
                throw new RuntimeException('Enter a valid order date.');
            }

            if ($dueDate !== '' && !preg_match('/^\d{4}-\d{2}-\d{2}$/', $dueDate)) {
                throw new RuntimeException('Enter a valid due date.');
            }

            if (!is_numeric($amountText) || (float)$amountText < 0) {
                throw new RuntimeException('Amount must be a non-negative number.');
            }

            if ($orderNumber === '') {
                $orderNumber = 'TAI-' . strtoupper(bin2hex(random_bytes(5)));
            }

            $stmt = $pdo->prepare(
                'INSERT INTO public.orders
                 (order_number, customer_name, customer_email, description,
                  status, order_date, due_date, amount, notes)
                 VALUES
                 (:number, :customer, :email, :description,
                  :status, :order_date, :due_date, :amount, :notes)'
            );

            $stmt->execute([
                ':number' => $orderNumber,
                ':customer' => $customer,
                ':email' => $email,
                ':description' => $description,
                ':status' => $status,
                ':order_date' => $orderDate,
                ':due_date' => $dueDate !== '' ? $dueDate : null,
                ':amount' => number_format((float)$amountText, 2, '.', ''),
                ':notes' => $notes,
            ]);

            redirectHome('created=1');
        }

        if ($action === 'update_status') {
            $id = filter_var($_POST['id'] ?? null, FILTER_VALIDATE_INT);
            $status = (string)($_POST['status'] ?? '');

            if (!$id || !in_array($status, $statuses, true)) {
                throw new RuntimeException('Invalid order or status.');
            }

            $stmt = $pdo->prepare(
                'UPDATE public.orders
                 SET status = :status, updated_at = NOW()
                 WHERE id = :id'
            );
            $stmt->execute([':status' => $status, ':id' => $id]);

            redirectHome('updated=1');
        }

        if ($action === 'delete') {
            $id = filter_var($_POST['id'] ?? null, FILTER_VALIDATE_INT);

            if (!$id) {
                throw new RuntimeException('Invalid order ID.');
            }

            $stmt = $pdo->prepare('DELETE FROM public.orders WHERE id = :id');
            $stmt->execute([':id' => $id]);

            redirectHome('deleted=1');
        }

        throw new RuntimeException('Unknown action.');
    }

    if (isset($_GET['created'])) $message = 'Order created successfully.';
    if (isset($_GET['updated'])) $message = 'Order status updated.';
    if (isset($_GET['deleted'])) $message = 'Order deleted.';

    $search = trim((string)($_GET['q'] ?? ''));
    $statusFilter = (string)($_GET['status'] ?? '');
    $page = max(1, (int)($_GET['page'] ?? 1));
    $perPage = 15;

    if (!in_array($statusFilter, $statuses, true)) {
        $statusFilter = '';
    }

    $where = [];
    $params = [];

    if ($search !== '') {
        $where[] = "(order_number ILIKE :search
                     OR customer_name ILIKE :search
                     OR customer_email ILIKE :search
                     OR description ILIKE :search)";
        $params[':search'] = '%' . $search . '%';
    }

    if ($statusFilter !== '') {
        $where[] = 'status = :status';
        $params[':status'] = $statusFilter;
    }

    $whereSql = $where ? ' WHERE ' . implode(' AND ', $where) : '';

    $countStmt = $pdo->prepare('SELECT COUNT(*) FROM public.orders' . $whereSql);
    $countStmt->execute($params);
    $total = (int)$countStmt->fetchColumn();

    $pages = max(1, (int)ceil($total / $perPage));
    $page = min($page, $pages);
    $offset = ($page - 1) * $perPage;

    $stmt = $pdo->prepare(
        'SELECT * FROM public.orders' . $whereSql .
        ' ORDER BY order_date DESC, id DESC LIMIT :limit OFFSET :offset'
    );

    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $perPage, PDO::PARAM_INT);
    $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
    $stmt->execute();
    $orders = $stmt->fetchAll();

    $stats = $pdo->query(
        "SELECT
            COUNT(*) AS total,
            COUNT(*) FILTER (WHERE status = 'Pending') AS pending,
            COUNT(*) FILTER (WHERE status = 'Processing') AS processing,
            COUNT(*) FILTER (WHERE status = 'Shipped') AS shipped,
            COUNT(*) FILTER (WHERE status = 'Delivered') AS delivered
         FROM public.orders"
    )->fetch();

} catch (Throwable $e) {
    error_log('TAI Order Portal: ' . $e->getMessage());
    $error = 'An error occurred. Check the application and database logs.';
    $orders = $orders ?? [];
    $stats = $stats ?? [
        'total' => 0, 'pending' => 0, 'processing' => 0,
        'shipped' => 0, 'delivered' => 0
    ];
    $search = $search ?? '';
    $statusFilter = $statusFilter ?? '';
    $page = $page ?? 1;
    $pages = $pages ?? 1;
    $total = $total ?? 0;
}

$csrf = csrfToken();
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>TAI | Order Management</title>
<style>
:root {
    --navy:#102a43; --blue:#1769aa; --blue2:#eaf3fb;
    --bg:#f4f7fb; --text:#243447; --muted:#6b7c93;
    --border:#dbe4ee; --white:#fff; --green:#16845b;
    --orange:#ad6500; --red:#b42318;
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font:14px/1.45 Arial,Helvetica,sans-serif}
header{background:var(--navy);color:white;padding:17px 28px;display:flex;justify-content:space-between;align-items:center;gap:20px}
.brand{font-weight:700;font-size:19px;letter-spacing:.3px}
.brand small{display:block;color:#b8c9dc;font-size:11px;font-weight:400;margin-top:3px}
.header-right{font-size:12px;color:#d5e2ef}
nav{background:white;border-bottom:1px solid var(--border);padding:0 28px;display:flex;gap:25px}
nav span{padding:14px 0;border-bottom:3px solid var(--blue);font-weight:700;color:var(--blue)}
main{max-width:1500px;margin:auto;padding:25px 28px}
.page-title{display:flex;justify-content:space-between;align-items:center;gap:16px;margin-bottom:20px}
h1{font-size:25px;margin:0 0 5px;color:var(--navy)}
.subtitle{color:var(--muted);font-size:13px}
button,.btn{border:0;border-radius:5px;background:var(--blue);color:white;padding:10px 15px;font-weight:700;cursor:pointer;text-decoration:none;display:inline-block}
button:hover,.btn:hover{filter:brightness(.94)}
.btn-secondary{background:white;border:1px solid var(--border);color:var(--text)}
.stats{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:14px;margin-bottom:22px}
.stat{background:white;border:1px solid var(--border);border-radius:8px;padding:17px}
.stat-label{color:var(--muted);font-size:12px}
.stat-value{font-size:27px;font-weight:700;margin-top:5px;color:var(--navy)}
.panel{background:white;border:1px solid var(--border);border-radius:8px;margin-bottom:22px;overflow:hidden}
.panel-head{padding:16px 18px;border-bottom:1px solid var(--border);display:flex;justify-content:space-between;align-items:center;gap:12px}
.panel-head h2{font-size:16px;margin:0;color:var(--navy)}
.panel-body{padding:18px}
.filters{display:flex;gap:10px;flex-wrap:wrap}
input,select,textarea{font:inherit;width:100%;border:1px solid #cbd5e1;border-radius:5px;padding:10px;background:white;color:var(--text)}
.filters input{flex:1;min-width:210px}
.filters select{width:auto;min-width:160px}
.form-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px}
.field label{display:block;font-weight:700;font-size:12px;margin-bottom:6px}
.field textarea{min-height:75px;resize:vertical}
.field-wide{grid-column:span 3}
.form-actions{display:flex;gap:10px;margin-top:16px}
.table-wrap{overflow-x:auto}
table{border-collapse:collapse;width:100%;white-space:nowrap}
th{background:#f8fafc;color:#64748b;text-align:left;font-size:11px;text-transform:uppercase;letter-spacing:.4px}
th,td{padding:13px 15px;border-bottom:1px solid #e8eef4}
tbody tr:hover{background:#f8fbff}
.order-id{font-weight:700;color:var(--blue)}
.customer{font-weight:700}
.small{font-size:12px;color:var(--muted);margin-top:3px}
.status{display:inline-block;padding:4px 9px;border-radius:99px;font-size:11px;font-weight:700}
.s-Pending{background:#fff1d6;color:#8a5200}
.s-Processing{background:#e5efff;color:#2354a5}
.s-Shipped{background:#e5f5ff;color:#075985}
.s-Delivered{background:#dff7e9;color:#126b43}
.s-Cancelled{background:#fee4e2;color:#a11a13}
.inline-form{display:flex;gap:5px;align-items:center}
.inline-form select{min-width:125px;padding:7px;font-size:12px}
.inline-form button{padding:7px 9px;font-size:11px}
.pagination{display:flex;justify-content:space-between;align-items:center;gap:10px;padding:15px 18px;color:var(--muted)}
.pagination a{color:var(--blue);text-decoration:none;padding:6px 10px;border:1px solid var(--border);border-radius:4px;margin-left:5px}
.alert{padding:12px 15px;border-radius:5px;margin-bottom:17px}
.alert-success{background:#e3f8ed;color:#126b43}
.alert-error{background:#fee4e2;color:#a11a13}
.empty{text-align:center;padding:40px;color:var(--muted)}
footer{text-align:center;padding:22px;color:#8593a5;font-size:12px}
@media(max-width:900px){.stats{grid-template-columns:repeat(2,minmax(0,1fr))}.form-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.field-wide{grid-column:span 2}}
@media(max-width:600px){header{padding:15px}.header-right{display:none}nav{padding:0 15px}main{padding:18px 12px}.page-title{align-items:flex-start;flex-direction:column}.stats{grid-template-columns:repeat(2,minmax(0,1fr))}.form-grid{grid-template-columns:1fr}.field-wide{grid-column:span 1}.panel-body{padding:13px}.pagination{flex-direction:column;align-items:flex-start}}
</style>
</head>
<body>
<header>
    <div class="brand">TAI <span style="font-weight:400">| Order Management</span>
        <small>Internal Operations Portal</small>
    </div>
    <div class="header-right">ORDER OPERATIONS &nbsp;·&nbsp; LIVE DATABASE</div>
</header>
<nav><span>Orders</span></nav>
<main>
    <div class="page-title">
        <div>
            <h1>Order Management</h1>
            <div class="subtitle">Manage customer orders, monitor status and track fulfillment.</div>
        </div>
        <a class="btn" href="#new-order">+ Create order</a>
    </div>

    <?php if ($message !== ''): ?>
        <div class="alert alert-success"><?= h($message) ?></div>
    <?php endif; ?>
    <?php if ($error !== ''): ?>
        <div class="alert alert-error"><?= h($error) ?></div>
    <?php endif; ?>

    <section class="stats">
        <div class="stat"><div class="stat-label">Total orders</div><div class="stat-value"><?= h($stats['total']) ?></div></div>
        <div class="stat"><div class="stat-label">Pending</div><div class="stat-value"><?= h($stats['pending']) ?></div></div>
        <div class="stat"><div class="stat-label">Processing</div><div class="stat-value"><?= h($stats['processing']) ?></div></div>
        <div class="stat"><div class="stat-label">Shipped</div><div class="stat-value"><?= h($stats['shipped']) ?></div></div>
        <div class="stat"><div class="stat-label">Delivered</div><div class="stat-value"><?= h($stats['delivered']) ?></div></div>
    </section>

    <section class="panel">
        <div class="panel-head"><h2>Order register</h2><span class="subtitle"><?= h($total ?? 0) ?> results</span></div>
        <div class="panel-body">
            <form method="get" class="filters">
                <input name="q" value="<?= h($search ?? '') ?>" placeholder="Search order number, customer or description...">
                <select name="status">
                    <option value="">All statuses</option>
                    <?php foreach ($statuses as $s): ?>
                        <option value="<?= h($s) ?>" <?= ($statusFilter ?? '') === $s ? 'selected' : '' ?>><?= h($s) ?></option>
                    <?php endforeach; ?>
                </select>
                <button type="submit">Search</button>
                <a class="btn btn-secondary" href="/">Reset</a>
            </form>
        </div>
        <div class="table-wrap">
            <table>
                <thead><tr>
                    <th>Order</th><th>Customer</th><th>Description</th><th>Order date</th>
                    <th>Due date</th><th>Amount</th><th>Status</th><th>Update status</th>
                </tr></thead>
                <tbody>
                <?php if (empty($orders)): ?>
                    <tr><td colspan="8" class="empty">No orders found. Create an order or change your filters.</td></tr>
                <?php else: foreach ($orders as $o): ?>
                    <tr>
                        <td>
                            <div class="order-id"><?= h($o['order_number']) ?></div>
                            <div class="small">ID <?= h($o['id']) ?></div>
                        </td>
                        <td>
                            <div class="customer"><?= h($o['customer_name']) ?></div>
                            <div class="small"><?= h($o['customer_email']) ?></div>
                        </td>
                        <td><?= h($o['description']) ?></td>
                        <td><?= h($o['order_date']) ?></td>
                        <td><?= h($o['due_date'] ?? '—') ?></td>
                        <td><?= h(number_format((float)$o['amount'], 2)) ?></td>
                        <td><span class="status s-<?= h($o['status']) ?>"><?= h($o['status']) ?></span></td>
                        <td>
                            <form method="post" class="inline-form">
                                <input type="hidden" name="csrf_token" value="<?= h($csrf) ?>">
                                <input type="hidden" name="action" value="update_status">
                                <input type="hidden" name="id" value="<?= h($o['id']) ?>">
                                <select name="status" aria-label="New status for <?= h($o['order_number']) ?>">
                                    <?php foreach ($statuses as $s): ?>
                                        <option value="<?= h($s) ?>" <?= $o['status'] === $s ? 'selected' : '' ?>><?= h($s) ?></option>
                                    <?php endforeach; ?>
                                </select>
                                <button type="submit">Save</button>
                            </form>
                        </td>
                    </tr>
                <?php endforeach; endif; ?>
                </tbody>
            </table>
        </div>
        <div class="pagination">
            <span>Page <?= h($page ?? 1) ?> of <?= h($pages ?? 1) ?></span>
            <div>
                <?php if (($page ?? 1) > 1): ?>
                    <a href="?<?= h(http_build_query(['q'=>$search ?? '', 'status'=>$statusFilter ?? '', 'page'=>$page-1])) ?>">Previous</a>
                <?php endif; ?>
                <?php if (($page ?? 1) < ($pages ?? 1)): ?>
                    <a href="?<?= h(http_build_query(['q'=>$search ?? '', 'status'=>$statusFilter ?? '', 'page'=>$page+1])) ?>">Next</a>
                <?php endif; ?>
            </div>
        </div>
    </section>

    <section class="panel" id="new-order">
        <div class="panel-head"><h2>Create a new order</h2></div>
        <div class="panel-body">
            <form method="post">
                <input type="hidden" name="csrf_token" value="<?= h($csrf) ?>">
                <input type="hidden" name="action" value="create">
                <div class="form-grid">
                    <div class="field">
                        <label for="order_number">Order number (optional)</label>
                        <input id="order_number" name="order_number" placeholder="Auto-generated if blank">
                    </div>
                    <div class="field">
                        <label for="customer_name">Customer name *</label>
                        <input id="customer_name" name="customer_name" required maxlength="180">
                    </div>
                    <div class="field">
                        <label for="customer_email">Customer email</label>
                        <input id="customer_email" name="customer_email" type="email" maxlength="180">
                    </div>
                    <div class="field">
                        <label for="description">Description *</label>
                        <input id="description" name="description" required>
                    </div>
                    <div class="field">
                        <label for="status">Status</label>
                        <select id="status" name="status">
                            <?php foreach ($statuses as $s): ?>
                                <option value="<?= h($s) ?>"><?= h($s) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                    <div class="field">
                        <label for="amount">Amount</label>
                        <input id="amount" name="amount" type="number" min="0" step="0.01" value="0.00" required>
                    </div>
                    <div class="field">
                        <label for="order_date">Order date *</label>
                        <input id="order_date" name="order_date" type="date" value="<?= h(date('Y-m-d')) ?>" required>
                    </div>
                    <div class="field">
                        <label for="due_date">Due date</label>
                        <input id="due_date" name="due_date" type="date">
                    </div>
                    <div class="field field-wide">
                        <label for="notes">Notes</label>
                        <textarea id="notes" name="notes" placeholder="Additional internal notes..."></textarea>
                    </div>
                </div>
                <div class="form-actions">
                    <button type="submit">Create order</button>
                    <button class="btn-secondary" type="reset">Clear form</button>
                </div>
            </form>
        </div>
    </section>
</main>
<footer>TAI Internal Operations Portal &nbsp;·&nbsp; Order Management</footer>
</body>
</html>
PHP

chown "${APP_USER}:${APP_GROUP}" "${APP_DIR}/index.php"
chmod 0640 "${APP_DIR}/index.php"

# ============================================================
# CONFIGURE PHP-FPM
# ============================================================

if [[ ! -f "${PHP_FPM_POOL}" ]]; then
    echo "ERROR: PHP-FPM pool configuration not found: ${PHP_FPM_POOL}"
    exit 1
fi

cp -a "${PHP_FPM_POOL}" "${PHP_FPM_POOL}.bak.$(date +%Y%m%d%H%M%S)"

# Set the PHP-FPM pool user/group and Unix socket for Nginx.
sed -i \
    -e 's/^[;[:space:]]*user[[:space:]]*=.*/user = nginx/' \
    -e 's/^[;[:space:]]*group[[:space:]]*=.*/group = nginx/' \
    -e 's#^[;[:space:]]*listen[[:space:]]*=.*#listen = /run/php-fpm/www.sock#' \
    -e 's/^[;[:space:]]*listen.owner[[:space:]]*=.*/listen.owner = nginx/' \
    -e 's/^[;[:space:]]*listen.group[[:space:]]*=.*/listen.group = nginx/' \
    -e 's/^[;[:space:]]*listen.mode[[:space:]]*=.*/listen.mode = 0660/' \
    "${PHP_FPM_POOL}"

# Ensure socket directives exist, even if commented defaults were absent.
grep -qE '^[[:space:]]*listen\.owner[[:space:]]*=' "${PHP_FPM_POOL}" ||
    printf '\nlisten.owner = nginx\n' >> "${PHP_FPM_POOL}"

grep -qE '^[[:space:]]*listen\.group[[:space:]]*=' "${PHP_FPM_POOL}" ||
    printf 'listen.group = nginx\n' >> "${PHP_FPM_POOL}"

grep -qE '^[[:space:]]*listen\.mode[[:space:]]*=' "${PHP_FPM_POOL}" ||
    printf 'listen.mode = 0660\n' >> "${PHP_FPM_POOL}"

# Add database environment variables to the PHP-FPM pool.
if ! grep -q '^\[tai-order-portal-env\]' "${PHP_FPM_POOL}"; then
    cat >> "${PHP_FPM_POOL}" <<'POOL'

; TAI Order Portal environment variables
env[PG_HOST] = $PG_HOST
env[PG_PORT] = $PG_PORT
env[PG_DATABASE] = $PG_DATABASE
env[PG_USER] = $PG_USER
env[PG_PASSWORD] = $PG_PASSWORD
POOL
fi

# Remove PHP-FPM's explicit environment allowlist entries if present and
# add values directly to the pool so the app receives them reliably.
sed -i \
    -e '/^env\[PG_HOST\][[:space:]]*=/d' \
    -e '/^env\[PG_PORT\][[:space:]]*=/d' \
    -e '/^env\[PG_DATABASE\][[:space:]]*=/d' \
    -e '/^env\[PG_USER\][[:space:]]*=/d' \
    -e '/^env\[PG_PASSWORD\][[:space:]]*=/d' \
    "${PHP_FPM_POOL}"

cat >> "${PHP_FPM_POOL}" <<EOF

; TAI Order Portal environment
env[PG_HOST] = ${PG_HOST}
env[PG_PORT] = ${PG_PORT}
env[PG_DATABASE] = ${PG_DATABASE}
env[PG_USER] = ${PG_USER}
env[PG_PASSWORD] = ${PG_PASSWORD}
EOF

# ============================================================
# CONFIGURE NGINX
# ============================================================

cat > "${NGINX_CONF}" <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    root /var/www/tai-order-portal;
    index index.php index.html;

    access_log /var/log/nginx/tai-order-portal-access.log;
    error_log  /var/log/nginx/tai-order-portal-error.log;

    server_tokens off;
    client_max_body_size 2m;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        try_files $uri =404;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT $document_root;
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_read_timeout 60s;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
NGINX

# ============================================================
# CONFIG VALIDATION AND START SERVICES
# ============================================================

echo "Validating PHP-FPM configuration..."
php-fpm -t

echo "Validating Nginx configuration..."
nginx -t

systemctl enable --now php-fpm
systemctl restart php-fpm

systemctl enable --now nginx
systemctl restart nginx

# Wait for PHP-FPM socket.
for ((i=1; i<=20; i++)); do
    if [[ -S /run/php-fpm/www.sock ]]; then
        break
    fi
    sleep 1
done

if [[ ! -S /run/php-fpm/www.sock ]]; then
    echo "ERROR: PHP-FPM socket was not created."
    systemctl --no-pager --full status php-fpm || true
    exit 1
fi

# Set ownership and permissions after installation.
chown -R nginx:nginx "${APP_DIR}"
chmod 0750 "${APP_DIR}"
chmod 0640 "${APP_DIR}/index.php"

# ============================================================
# FIREWALL NOTE AND FINAL STATUS
# ============================================================

echo
echo "============================================================"
echo "INSTALLATION COMPLETED"
echo "============================================================"
echo "Application: ${APP_NAME}"
echo "Web root:    ${APP_DIR}"
echo "Database:    ${PG_HOST}:${PG_PORT}/${PG_DATABASE}"
echo "DB user:     ${PG_USER}"
echo "Sample data: ${ORDER_COUNT} initial rows before seeding; target is 75"
echo
echo "Check services:"
echo "  sudo systemctl status nginx php-fpm --no-pager"
echo
echo "Check application logs:"
echo "  sudo tail -n 100 /var/log/nginx/tai-order-portal-error.log"
echo "  sudo journalctl -u php-fpm -n 100 --no-pager"
echo
echo "Open the web server using its private/public IP or DNS name."
echo "Ensure the EC2 security group allows inbound TCP/80 from intended clients."
echo "Ensure the database security group allows TCP/5432 from this app server."
echo
echo "SECURITY: change the database password and restrict HTTP access as appropriate."
echo "============================================================"