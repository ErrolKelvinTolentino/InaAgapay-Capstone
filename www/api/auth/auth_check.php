<?php
require_once __DIR__ . '/../db.php';

$headers = getallheaders();
$authHeader = $headers['Authorization'] ?? '';

if (!preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    echo json_encode([
        'success' => false,
        'message' => 'Unauthorized'
    ]);
    exit;
}

$token = $matches[1];

$stmt = $conn->prepare("
    SELECT account_id, account_type
    FROM accounts
    WHERE last_login_token = ?
      AND status = 'active'
    LIMIT 1
");
$stmt->bind_param("s", $token);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows !== 1) {
    echo json_encode([
        'success' => false,
        'message' => 'Invalid or expired token'
    ]);
    exit;
}

$AUTH_USER = $result->fetch_assoc();
