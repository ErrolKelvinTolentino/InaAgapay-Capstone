<?php
require_once __DIR__ . '/../auth/auth_check.php';
require_once __DIR__ . '/../db.php';

header('Content-Type: application/json');

$accountId = $AUTH_USER['account_id'];
$role = $AUTH_USER['account_type'];

/**
 * Base identity (common to all roles)
 */
$stmt = $conn->prepare("
    SELECT
        first_name,
        middle_name,
        last_name,
        extension_name
    FROM accounts
    WHERE account_id = ?
    LIMIT 1
");
$stmt->bind_param("i", $accountId);
$stmt->execute();
$account = $stmt->get_result()->fetch_assoc();

if (!$account) {
    echo json_encode(['success' => false, 'message' => 'Account not found']);
    exit;
}

$response = [
    'success' => true,
    'role' => $role,
    'first_name' => $account['first_name'],
    'middle_name' => $account['middle_name'],
    'last_name' => $account['last_name'],
    'extension_name' => $account['extension_name'],
    'bhc_name' => null
];

/**
 * Role-specific BHC lookup
 */
if ($role === 'midwife') {
    $stmt = $conn->prepare("
        SELECT b.bhc_name
        FROM midwives m
        JOIN bhc b ON b.bhc_id = m.assigned_bhc_id
        WHERE m.account_id = ?
        LIMIT 1
    ");
    $stmt->bind_param("i", $accountId);
    $stmt->execute();
    $bhc = $stmt->get_result()->fetch_assoc();

    $response['bhc_name'] = $bhc['bhc_name'] ?? null;
}

if ($role === 'mother') {
    $stmt = $conn->prepare("
        SELECT b.bhc_name
        FROM mothers mo
        LEFT JOIN bhc b ON b.bhc_id = mo.assigned_bhc_id
        WHERE mo.account_id = ?
        LIMIT 1
    ");
    $stmt->bind_param("i", $accountId);
    $stmt->execute();
    $bhc = $stmt->get_result()->fetch_assoc();

    $response['bhc_name'] = $bhc['bhc_name'] ?? 'No Barangay Assigned';
}

echo json_encode($response);
