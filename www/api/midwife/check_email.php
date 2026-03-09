<?php
require_once __DIR__ . '/../auth/auth_check.php';
header('Content-Type: application/json');

try {
    if (!isset($_GET['email']) || trim($_GET['email']) === '') {
        throw new Exception('Email is required');
    }

    $email = trim($_GET['email']);

    // basic format check
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        echo json_encode([
            'success' => true,
            'valid' => false,
            'available' => false,
            'message' => 'Invalid email format',
        ]);
        exit;
    }

    $stmt = $conn->prepare("SELECT COUNT(*) AS cnt FROM accounts WHERE email_address = ? LIMIT 1");
    $stmt->bind_param('s', $email);
    $stmt->execute();
    $res = $stmt->get_result()->fetch_assoc();
    $count = (int) ($res['cnt'] ?? 0);

    echo json_encode([
        'success' => true,
        'valid' => true,
        'available' => $count === 0,
    ]);
} catch (Throwable $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
    ]);
}
