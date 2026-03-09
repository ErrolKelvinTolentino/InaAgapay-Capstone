<?php
require_once __DIR__ . '/../auth/auth_check.php';
require_once __DIR__ . '/../db.php';

header('Content-Type: application/json');

if (($AUTH_USER['account_type'] ?? null) !== 'mother') {
    echo json_encode([
        'success' => false,
        'message' => 'Unauthorized'
    ]);
    exit;
}

$accountId = $AUTH_USER['account_id'];

// Base identity
$stmt = $conn->prepare("
    SELECT
        a.first_name,
        a.middle_name,
        a.last_name,
        a.extension_name,
        b.bhc_name
    FROM accounts a
    LEFT JOIN mothers m ON m.account_id = a.account_id
    LEFT JOIN bhc b ON b.bhc_id = m.assigned_bhc_id
    WHERE a.account_id = ?
    LIMIT 1
");
$stmt->bind_param("i", $accountId);
$stmt->execute();

$data = $stmt->get_result()->fetch_assoc();

if (!$data) {
    echo json_encode([
        'success' => false,
        'message' => 'Mother not found'
    ]);
    exit;
}

echo json_encode([
    'success' => true,
    'first_name' => $data['first_name'],
    'middle_name' => $data['middle_name'],
    'last_name' => $data['last_name'],
    'extension_name' => $data['extension_name'],
    'bhc_name' => $data['bhc_name'] ?? 'No Barangay Assigned'
]);
