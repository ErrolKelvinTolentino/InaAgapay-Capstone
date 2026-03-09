<?php
// admin/index.php

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

$isAdmin = isset($_SESSION['account_id']) && ($_SESSION['account_type'] ?? '') === 'admin';

if ($isAdmin) {
    header('Location: /admin/dashboard.php');
} else {
    header('Location: /admin/login.php');
}
exit;