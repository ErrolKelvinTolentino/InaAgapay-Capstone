<?php
session_start();
require_once __DIR__ . '/../api/db.php';

$error = '';

// Redirect if already logged in
if (isset($_SESSION['account_id'])) {
    switch ($_SESSION['account_type']) {
        case 'admin':
            header('Location: /admin/dashboard.php');
            break;
    }
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = trim($_POST['email'] ?? '');
    $password = $_POST['password'] ?? '';

    $stmt = $conn->prepare("
        SELECT account_id, first_name, middle_name, last_name, extension_name, password_hash, account_type, is_verified, status
        FROM accounts
        WHERE email_address = ? AND account_type = 'admin'
        LIMIT 1
    ");
    $stmt->bind_param('s', $email);
    $stmt->execute();
    $res = $stmt->get_result();

    if ($res->num_rows === 1) {
        $u = $res->fetch_assoc();

        if (
            $u['is_verified'] &&
            $u['status'] === 'active' &&
            password_verify($password, $u['password_hash'])
        ) {
            session_regenerate_id(true);

            $fullName = trim(($u['first_name'] ?? '') . ' ' . ($u['middle_name'] ?? '') . ' ' . ($u['last_name'] ?? ''));
            if (!empty($u['extension_name'])) {
                $fullName .= ' ' . $u['extension_name'];
            }

            $_SESSION['account_id'] = $u['account_id'];
            $_SESSION['account_type'] = $u['account_type'];
            $_SESSION['user_name'] = $fullName ?: 'User';

            $upd = $conn->prepare("UPDATE accounts SET last_login_at = NOW() WHERE account_id = ?");
            $upd->bind_param('i', $u['account_id']);
            $upd->execute();

            header('Location: /admin/dashboard.php');
            exit;
        }
    }

    $error = 'Invalid email or password';
}
?>

<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Login | InaAgapay</title>
    <link rel="stylesheet" href="/admin/styles/login.css">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700&display=swap" rel="stylesheet">
</head>

<body>
    <form method="POST" class="login-card" autocomplete="off">
        <h2>Admin Portal</h2>
        <p class="subtext">Sign in with your admin credentials.</p>

        <?php if ($error): ?>
            <p class="error"><?= htmlspecialchars($error) ?></p>
        <?php endif; ?>

        <label for="email">Admin Email</label>
        <input type="email" id="email" name="email" placeholder="admin@inaagapay.ph" required>

        <label for="password">Password</label>
        <input type="password" id="password" name="password" placeholder="••••••••" required>

        <button type="submit">Sign In</button>
        <p class="footer-hint">For authorized admins only. Contact system support if you need access.</p>
    </form>
</body>

</html>