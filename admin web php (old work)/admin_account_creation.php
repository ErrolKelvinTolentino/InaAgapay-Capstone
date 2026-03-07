<?php
session_start();
require_once __DIR__ . '/../api/db.php';

if (!isset($_SESSION['account_id']) || ($_SESSION['account_type'] ?? '') !== 'admin') {
    header('Location: login.php');
    exit;
}

$message = '';
$error = '';
$old = [
    'account_type' => $_POST['account_type'] ?? 'midwife',
    'email_address' => $_POST['email_address'] ?? '',
    'first_name' => $_POST['first_name'] ?? '',
    'middle_name' => $_POST['middle_name'] ?? '',
    'last_name' => $_POST['last_name'] ?? '',
    'extension_name' => $_POST['extension_name'] ?? '',
    'phone_number' => $_POST['phone_number'] ?? '',
    'bhc_id' => $_POST['bhc_id'] ?? '',
];

// Fetch BHC list
$bhc = [];
if ($res = $conn->query('SELECT bhc_id, bhc_name FROM bhc ORDER BY bhc_name')) {
    while ($row = $res->fetch_assoc()) {
        $bhc[] = $row;
    }
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $allowedTypes = ['admin', 'midwife'];
    $type = $_POST['account_type'] ?? 'midwife';
    $first = trim($_POST['first_name'] ?? '');
    $middle = trim($_POST['middle_name'] ?? '');
    $last = trim($_POST['last_name'] ?? '');
    $ext = trim($_POST['extension_name'] ?? '');
    $email = trim($_POST['email_address'] ?? '');
    $phone = trim($_POST['phone_number'] ?? '');
    $password = $_POST['password'] ?? '';
    $bhcId = isset($_POST['bhc_id']) ? (int) $_POST['bhc_id'] : null;

    if (!in_array($type, $allowedTypes, true)) {
        $error = 'Invalid account type selected.';
    } elseif (!$first || !$last || !$email || !$password) {
        $error = 'First name, last name, email, and password are required.';
    } elseif (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        $error = 'Please provide a valid email address.';
    } elseif (strlen($password) < 8) {
        $error = 'Password must be at least 8 characters.';
    } else {
        try {
            // Enforce unique email
            $check = $conn->prepare('SELECT 1 FROM accounts WHERE email_address = ? LIMIT 1');
            $check->bind_param('s', $email);
            $check->execute();
            $checkRes = $check->get_result();
            if ($checkRes && $checkRes->num_rows) {
                throw new Exception('That email is already in use.');
            }

            if ($type === 'midwife' && !$bhcId) {
                throw new Exception('Please select a Barangay Health Center for the midwife.');
            }

            // Transaction to keep account + midwife insert consistent
            $conn->begin_transaction();

            $hash = password_hash($password, PASSWORD_DEFAULT);
            $stmt = $conn->prepare('INSERT INTO accounts (email_address, password_hash, account_type, first_name, middle_name, last_name, extension_name, phone_number, is_verified, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, "active", NOW())');
            $stmt->bind_param('ssssssss', $email, $hash, $type, $first, $middle, $last, $ext, $phone);
            $stmt->execute();
            $accountId = $stmt->insert_id;

            if ($type === 'midwife') {
                $midwifeStmt = $conn->prepare('INSERT INTO midwives (account_id, assigned_bhc_id) VALUES (?, ?)');
                $midwifeStmt->bind_param('ii', $accountId, $bhcId);
                $midwifeStmt->execute();
            }

            $conn->commit();

            header('Location: admin_account_management.php?created=1&type=' . urlencode($type));
            exit;
        } catch (Throwable $e) {
            if ($conn->errno) {
                $conn->rollback();
            }
            $error = 'Error creating account: ' . $e->getMessage();
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Create Account - InaAgapay</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
    <link rel="stylesheet" href="../styles/header_navbar.css">
    <style>
        :root {
            --pink: #ec407a;
            --pink-light: #ffd9e8;
            --pink-soft: #ffe9f2;
            --pink-strong: #d81b60;
            --gray-ink: #3f3d56;
            --surface: #ffffff;
            --border: #f0c6d8;
            --shadow: 0 12px 40px rgba(236, 64, 122, 0.14);
        }

        body {
            background: radial-gradient(circle at 20% 20%, #ffeef6, #ffffff 35%),
                radial-gradient(circle at 80% 0%, #fff5fb, #ffffff 40%);
            font-family: 'Poppins', 'Segoe UI', sans-serif;
            color: var(--gray-ink);
        }

        .page-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 12px;
            margin-bottom: 18px;
        }

        .card {
            border: 1px solid var(--border);
            border-radius: 18px;
            box-shadow: var(--shadow);
            background: var(--surface);
        }

        .btn-brand {
            background: linear-gradient(135deg, var(--pink) 0%, var(--pink-strong) 100%);
            border: none;
            box-shadow: 0 10px 30px rgba(236, 64, 122, 0.35);
        }

        .btn-brand:hover {
            filter: brightness(1.05);
        }

        label.form-label {
            color: var(--gray-ink);
            font-weight: 600;
        }

        input.form-control,
        select.form-select {
            border: 1px solid var(--border);
            border-radius: 10px;
        }

        input.form-control:focus,
        select.form-select:focus {
            border-color: var(--pink);
            box-shadow: 0 0 0 0.2rem rgba(236, 64, 122, 0.15);
        }

        .alert-success {
            background: var(--pink-soft);
            color: var(--pink-strong);
            border: 1px solid var(--border);
        }

        .alert-danger {
            border: 1px solid var(--border);
        }
    </style>
</head>

<body>
    <?php include __DIR__ . '/header_navbar.php'; ?>

    <main class="main-content" id="mainContent">
        <div class="container py-4">
            <div class="page-header">
                <h4 class="m-0">Create Account</h4>
                <a href="admin_account_management.php" class="btn btn-outline-secondary btn-sm">Back to Accounts</a>
            </div>

            <div class="row justify-content-center">
                <div class="col-xl-7">
                    <div class="card p-4">
                        <?php if ($message): ?>
                            <div class="alert alert-success"><?= htmlspecialchars($message) ?></div>
                        <?php endif; ?>
                        <?php if ($error): ?>
                            <div class="alert alert-danger"><?= htmlspecialchars($error) ?></div>
                        <?php endif; ?>

                        <form method="post" class="row g-3">
                            <div class="col-md-6">
                                <label class="form-label fw-semibold">Account Type</label>
                                <select name="account_type" class="form-select" required>
                                    <option value="admin" <?= ($old['account_type'] === 'admin') ? 'selected' : '' ?>>Admin
                                    </option>
                                    <option value="midwife" <?= ($old['account_type'] === 'midwife') ? 'selected' : '' ?>>
                                        Midwife</option>
                                </select>
                            </div>
                            <div class="col-md-6">
                                <label class="form-label fw-semibold">Email</label>
                                <input type="email" name="email_address" class="form-control"
                                    value="<?= htmlspecialchars($old['email_address']) ?>" required>
                            </div>
                            <div class="col-md-6">
                                <label class="form-label fw-semibold">First Name</label>
                                <input type="text" name="first_name" class="form-control"
                                    value="<?= htmlspecialchars($old['first_name']) ?>" required>
                            </div>
                            <div class="col-md-6">
                                <label class="form-label fw-semibold">Last Name</label>
                                <input type="text" name="last_name" class="form-control"
                                    value="<?= htmlspecialchars($old['last_name']) ?>" required>
                            </div>
                            <div class="col-md-6">
                                <label class="form-label fw-semibold">Middle Name</label>
                                <input type="text" name="middle_name" class="form-control"
                                    value="<?= htmlspecialchars($old['middle_name']) ?>">
                            </div>
                            <div class="col-md-6">
                                <label class="form-label fw-semibold">Extension</label>
                                <input type="text" name="extension_name" class="form-control"
                                    placeholder="Jr, III, etc." value="<?= htmlspecialchars($old['extension_name']) ?>">
                            </div>
                            <div class="col-md-6">
                                <label class="form-label fw-semibold">Phone Number</label>
                                <input type="text" name="phone_number" class="form-control"
                                    value="<?= htmlspecialchars($old['phone_number']) ?>">
                            </div>
                            <div class="col-md-6">
                                <label class="form-label fw-semibold">Password</label>
                                <input type="password" name="password" class="form-control" required>
                            </div>
                            <div class="col-12" id="bhc-wrapper">
                                <label class="form-label fw-semibold">Assigned Barangay Health Center (midwife)</label>
                                <select name="bhc_id" class="form-select">
                                    <option value="">Select BHC</option>
                                    <?php foreach ($bhc as $b): ?>
                                        <option value="<?= (int) $b['bhc_id'] ?>" <?= ($old['bhc_id'] == $b['bhc_id']) ? 'selected' : '' ?>>
                                            <?= htmlspecialchars($b['bhc_name']) ?>
                                        </option>
                                    <?php endforeach; ?>
                                </select>
                            </div>
                            <div class="d-flex justify-content-between mt-3">
                                <a href="admin_account_management.php" class="btn btn-outline-secondary">Back to
                                    Accounts</a>
                                <button type="submit" class="btn btn-brand text-white">Create Account</button>
                            </div>
                        </form>
                    </div>
                </div>
            </div>
        </div>
    </main>

    <script>
        const typeSelect = document.querySelector('select[name="account_type"]');
        const bhcWrapper = document.getElementById('bhc-wrapper');
        const bhcSelect = bhcWrapper.querySelector('select');
        function toggleBhc() {
            const isMidwife = typeSelect.value === 'midwife';
            bhcWrapper.style.display = isMidwife ? 'block' : 'none';
            bhcSelect.required = isMidwife;
        }
        typeSelect.addEventListener('change', toggleBhc);
        toggleBhc();
    </script>
</body>

</html>