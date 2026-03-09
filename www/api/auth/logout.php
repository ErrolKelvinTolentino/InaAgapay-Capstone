<?php
require_once __DIR__ . '/../auth/auth_check.php';
require_once __DIR__ . '/../db.php';

header('Content-Type: application/json');

// auth_check.php already:
// - validated the token
// - populated $AUTH_USER['account_id']

$stmt = $conn->prepare("
    UPDATE accounts
    SET last_login_token = NULL
    WHERE account_id = ?
");
$stmt->bind_param("i", $AUTH_USER['account_id']);
$stmt->execute();

echo json_encode([
    'success' => true,
    'message' => 'Logged out successfully'
]);
