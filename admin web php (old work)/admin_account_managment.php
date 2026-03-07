<?php
session_start();
require_once __DIR__ . '/../api/db.php';

if (!isset($_SESSION['account_id']) || ($_SESSION['account_type'] ?? '') !== 'admin') {
    header('Location: login.php');
    exit;
}

// -------- Filters & sorting --------
$search = trim($_GET['search'] ?? '');
$filterType = $_GET['filter_type'] ?? '';
$filterStatus = $_GET['filter_status'] ?? '';
$sort = $_GET['sort'] ?? 'created_at';
$order = (strtolower($_GET['order'] ?? 'desc') === 'asc') ? 'ASC' : 'DESC';

$allowedSort = ['first_name', 'last_name', 'email_address', 'account_type', 'status', 'created_at'];
if (!in_array($sort, $allowedSort, true)) {
    $sort = 'created_at';
}

// Build where + params
$where = [];
$types = '';
$vals = [];
if ($search !== '') {
    $where[] = '(first_name LIKE ? OR last_name LIKE ? OR email_address LIKE ?)';
    $types .= 'sss';
    $like = "%{$search}%";
    array_push($vals, $like, $like, $like);
}
if ($filterType !== '') {
    $where[] = 'account_type = ?';
    $types .= 's';
    $vals[] = $filterType;
}
if ($filterStatus !== '') {
    $where[] = 'status = ?';
    $types .= 's';
    $vals[] = $filterStatus;
}
$whereSql = $where ? 'WHERE ' . implode(' AND ', $where) : '';

$sql = "SELECT account_id, first_name, middle_name, last_name, extension_name, email_address, account_type, status, created_at
        FROM accounts $whereSql
        ORDER BY $sort $order";

$stmt = $conn->prepare($sql);
if ($types !== '') {
    $stmt->bind_param($types, ...$vals);
}
$stmt->execute();
$res = $stmt->get_result();
$accounts = $res->fetch_all(MYSQLI_ASSOC);

// -------- Updates (AJAX + full post) --------
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['account_id'])) {
    $id = (int) $_POST['account_id'];
    $newType = $_POST['account_type'] ?? null;
    $newStatus = $_POST['status'] ?? null;

    $response = ['success' => false];
    try {
        if (!$newType) {
            throw new Exception('Account type is required');
        }
        $updSql = 'UPDATE accounts SET account_type = ?' . ($newStatus !== null ? ', status = ?' : '') . ' WHERE account_id = ?';
        $updStmt = $conn->prepare($updSql);
        if ($newStatus !== null) {
            $updStmt->bind_param('ssi', $newType, $newStatus, $id);
        } else {
            $updStmt->bind_param('si', $newType, $id);
        }
        $updStmt->execute();
        $response['success'] = true;
    } catch (Throwable $e) {
        $response['success'] = false;
        $response['message'] = $e->getMessage();
    }

    if (($_POST['ajax'] ?? '') === '1') {
        header('Content-Type: application/json');
        echo json_encode($response);
        exit;
    }

    if ($response['success']) {
        header('Location: admin_account_management.php?updated=1');
        exit;
    }
}

$updated = isset($_GET['updated']);
?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Account Management - InaAgapay</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
    <style>
        body {
            background: #f6f8fb;
            font-family: 'Poppins', 'Segoe UI', sans-serif;
        }

        .app-shell {
            display: grid;
            grid-template-columns: 260px 1fr;
            min-height: 100vh;
        }

        .sidebar {
            background: #0f172a;
            color: #e2e8f0;
            padding: 1.5rem 1rem;
        }

        .sidebar .brand {
            font-weight: 700;
            letter-spacing: 0.5px;
            margin-bottom: 1.5rem;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }

        .sidebar .nav-link {
            color: #cbd5e1;
            border-radius: 10px;
            padding: 0.65rem 0.9rem;
            margin-bottom: 0.35rem;
        }

        .sidebar .nav-link.active,
        .sidebar .nav-link:hover {
            background: #1e293b;
            color: #fff;
        }

        .topbar {
            background: #ffffff;
            border-bottom: 1px solid #e2e8f0;
            padding: 0.85rem 1.5rem;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        .page-title {
            margin: 0;
            font-weight: 700;
            color: #0f172a;
        }

        .stat-badge {
            background: #e0f2fe;
            color: #0369a1;
            border-radius: 12px;
            padding: 0.4rem 0.75rem;
            font-weight: 600;
        }

        .card {
            border: none;
            border-radius: 16px;
            box-shadow: 0 12px 40px rgba(15, 23, 42, 0.08);
        }

        .table thead th {
            border-bottom: none;
            background: #f8fafc;
            color: #475569;
            text-transform: uppercase;
            letter-spacing: 0.4px;
            font-size: 12px;
        }

        .table> :not(caption)>*>* {
            padding: 0.9rem 0.75rem;
            vertical-align: middle;
        }

        .badge-status {
            padding: 0.45rem 0.7rem;
            border-radius: 10px;
            font-weight: 600;
            text-transform: capitalize;
        }

        .btn-brand {
            background: linear-gradient(135deg, #2563eb, #7c3aed);
            border: none;
        }

        .btn-ghost {
            border: 1px solid #e2e8f0;
        }
    </style>
</head>

<body>
    <div class="app-shell">
        <aside class="sidebar">
            <div class="brand"><i class="fa-solid fa-heart-pulse"></i> InaAgapay Admin</div>
            <nav class="nav flex-column">
                <a class="nav-link" href="dashboard.php"><i class="fa-solid fa-gauge me-2"></i>Dashboard</a>
                <a class="nav-link active" href="admin_account_management.php"><i
                        class="fa-solid fa-users-gear me-2"></i>Accounts</a>
                <a class="nav-link" href="admin_backup.php"><i class="fa-solid fa-database me-2"></i>Backup</a>
                <a class="nav-link" href="midwife_assignment.php"><i class="fa-solid fa-user-nurse me-2"></i>Midwife
                    Assignment</a>
            </nav>
        </aside>

        <div class="d-flex flex-column">
            <div class="topbar">
                <h4 class="page-title">Account Management</h4>
                <div class="d-flex align-items-center gap-2">
                    <span class="stat-badge">Total: <?= count($accounts) ?></span>
                    <a href="logout.php" class="btn btn-outline-secondary btn-sm">Logout</a>
                </div>
            </div>

            <main class="p-4">
                <?php if ($updated): ?>
                    <div class="alert alert-success alert-dismissible fade show" role="alert">
                        Account updated successfully.
                        <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
                    </div>
                <?php endif; ?>

                <div class="card mb-4">
                    <div class="card-body">
                        <form class="row gy-2 gx-2 align-items-end">
                            <div class="col-md-4">
                                <label class="form-label fw-semibold">Search</label>
                                <input type="text" name="search" class="form-control" placeholder="Name or email"
                                    value="<?= htmlspecialchars($search) ?>">
                            </div>
                            <div class="col-md-2">
                                <label class="form-label fw-semibold">Type</label>
                                <select class="form-select" name="filter_type">
                                    <option value="">All</option>
                                    <option value="admin" <?= $filterType === 'admin' ? 'selected' : '' ?>>Admin</option>
                                    <option value="midwife" <?= $filterType === 'midwife' ? 'selected' : '' ?>>Midwife
                                    </option>
                                    <option value="mother" <?= $filterType === 'mother' ? 'selected' : '' ?>>Mother
                                    </option>
                                </select>
                            </div>
                            <div class="col-md-2">
                                <label class="form-label fw-semibold">Status</label>
                                <select class="form-select" name="filter_status">
                                    <option value="">All</option>
                                    <option value="active" <?= $filterStatus === 'active' ? 'selected' : '' ?>>Active
                                    </option>
                                    <option value="inactive" <?= $filterStatus === 'inactive' ? 'selected' : '' ?>>Inactive
                                    </option>
                                </select>
                            </div>
                            <div class="col-md-2">
                                <label class="form-label fw-semibold">Sort</label>
                                <select class="form-select" name="sort">
                                    <option value="created_at" <?= $sort === 'created_at' ? 'selected' : '' ?>>Newest
                                    </option>
                                    <option value="first_name" <?= $sort === 'first_name' ? 'selected' : '' ?>>First name
                                    </option>
                                    <option value="last_name" <?= $sort === 'last_name' ? 'selected' : '' ?>>Last name
                                    </option>
                                    <option value="email_address" <?= $sort === 'email_address' ? 'selected' : '' ?>>Email
                                    </option>
                                    <option value="account_type" <?= $sort === 'account_type' ? 'selected' : '' ?>>Type
                                    </option>
                                    <option value="status" <?= $sort === 'status' ? 'selected' : '' ?>>Status</option>
                                </select>
                            </div>
                            <div class="col-md-1">
                                <label class="form-label fw-semibold">Order</label>
                                <select class="form-select" name="order">
                                    <option value="desc" <?= $order === 'DESC' ? 'selected' : '' ?>>Desc</option>
                                    <option value="asc" <?= $order === 'ASC' ? 'selected' : '' ?>>Asc</option>
                                </select>
                            </div>
                            <div class="col-md-1 d-grid">
                                <button class="btn btn-ghost">Apply</button>
                            </div>
                        </form>
                    </div>
                </div>

                <div class="d-flex justify-content-between align-items-center mb-3">
                    <div>
                        <a class="btn btn-brand text-white" href="admin_account_creation.php"><i
                                class="fa-solid fa-user-plus me-2"></i>Create Account</a>
                    </div>
                    <div class="text-muted small">Select type/status then click Update or Activate/Deactivate.</div>
                </div>

                <div class="card">
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table mb-0 align-middle">
                                <thead>
                                    <tr>
                                        <th>Full Name</th>
                                        <th>Email</th>
                                        <th>Type</th>
                                        <th>Status</th>
                                        <th class="text-end">Actions</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php foreach ($accounts as $acc): ?>
                                        <?php
                                        $full = trim(($acc['first_name'] ?? '') . ' ' . ($acc['middle_name'] ?? '') . ' ' . ($acc['last_name'] ?? '')) .
                                            (!empty($acc['extension_name']) ? ' ' . $acc['extension_name'] : '');
                                        ?>
                                        <tr>
                                            <td class="fw-semibold"><?= htmlspecialchars($full) ?></td>
                                            <td><?= htmlspecialchars($acc['email_address'] ?? '') ?></td>
                                            <td>
                                                <select class="form-select form-select-sm account-type"
                                                    data-id="<?= (int) $acc['account_id'] ?>">
                                                    <option value="admin" <?= $acc['account_type'] === 'admin' ? 'selected' : '' ?>>Admin</option>
                                                    <option value="midwife" <?= $acc['account_type'] === 'midwife' ? 'selected' : '' ?>>Midwife</option>
                                                    <option value="mother" <?= $acc['account_type'] === 'mother' ? 'selected' : '' ?>>Mother</option>
                                                </select>
                                            </td>
                                            <td>
                                                <span
                                                    class="badge-status bg-<?= ($acc['status'] === 'active') ? 'success text-dark bg-opacity-25' : 'secondary text-dark bg-opacity-25' ?>"
                                                    id="status-label-<?= (int) $acc['account_id'] ?>">
                                                    <?= htmlspecialchars($acc['status']) ?>
                                                </span>
                                            </td>
                                            <td class="text-end">
                                                <div class="btn-group">
                                                    <button class="btn btn-outline-secondary btn-sm update-btn"
                                                        data-id="<?= (int) $acc['account_id'] ?>">Update</button>
                                                    <button
                                                        class="btn btn-sm <?= ($acc['status'] === 'active') ? 'btn-outline-danger' : 'btn-outline-success' ?> status-btn"
                                                        data-id="<?= (int) $acc['account_id'] ?>"
                                                        data-action="<?= ($acc['status'] === 'active') ? 'deactivate' : 'activate' ?>">
                                                        <?= ($acc['status'] === 'active') ? 'Deactivate' : 'Activate' ?>
                                                    </button>
                                                </div>
                                            </td>
                                        </tr>
                                    <?php endforeach; ?>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </main>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        function postUpdate(payload) {
            return fetch('admin_account_management.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: new URLSearchParams(payload)
            }).then(r => r.json());
        }

        document.querySelectorAll('.update-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const id = btn.dataset.id;
                const type = document.querySelector(`select.account-type[data-id="${id}"]`).value;
                postUpdate({ ajax: '1', account_id: id, account_type: type }).then(res => {
                    if (res.success) {
                        alert('Account type updated.');
                    } else {
                        alert(res.message || 'Update failed.');
                    }
                });
            });
        });

        document.querySelectorAll('.status-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const id = btn.dataset.id;
                const type = document.querySelector(`select.account-type[data-id="${id}"]`).value;
                const action = btn.dataset.action;
                const newStatus = action === 'deactivate' ? 'inactive' : 'active';
                postUpdate({ ajax: '1', account_id: id, account_type: type, status: newStatus }).then(res => {
                    if (res.success) {
                        const label = document.getElementById(`status-label-${id}`);
                        label.textContent = newStatus;
                        btn.dataset.action = newStatus === 'active' ? 'deactivate' : 'activate';
                        btn.textContent = newStatus === 'active' ? 'Deactivate' : 'Activate';
                        btn.className = 'btn btn-sm ' + (newStatus === 'active' ? 'btn-outline-danger status-btn' : 'btn-outline-success status-btn');
                    } else {
                        alert(res.message || 'Update failed.');
                    }
                });
            });
        });
    </script>
</body>

</html>