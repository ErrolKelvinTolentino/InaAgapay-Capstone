<?php
require_once __DIR__ . '/../db.php';

ob_start();
require_once __DIR__ . '/../auth/auth_check.php';
ob_end_clean();

header('Content-Type: application/json');

try {
    if (($AUTH_USER['account_type'] ?? null) !== 'midwife') {
        throw new Exception('Only midwives can access context');
    }

    $stmt = $conn->prepare("SELECT m.midwife_id, m.assigned_bhc_id, b.bhc_name FROM midwives m JOIN bhc b ON b.bhc_id = m.assigned_bhc_id WHERE m.account_id = ? LIMIT 1");
    $stmt->bind_param('i', $AUTH_USER['account_id']);
    $stmt->execute();
    $res = $stmt->get_result()->fetch_assoc();

    if (!$res) {
        throw new Exception('Midwife context not found');
    }

    echo json_encode([
        'success' => true,
        'midwife_id' => (int) $res['midwife_id'],
        'assigned_bhc_id' => (int) $res['assigned_bhc_id'],
        'bhc_name' => $res['bhc_name'] ?? null,
    ]);
} catch (Throwable $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
    ]);
}
