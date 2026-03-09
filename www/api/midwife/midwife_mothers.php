<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../db.php';

/**
 * Auth check (silenced output)
 */
ob_start();
require_once __DIR__ . '/../auth/auth_check.php';
ob_end_clean();

/**
 * Assertion helper
 */
function expect(bool $condition, string $message): void
{
    if (!$condition) {
        throw new Exception($message);
    }
}

try {
    // 🔐 Authorization
    expect(isset($AUTH_USER['account_type']), 'Unauthorized');
    expect($AUTH_USER['account_type'] === 'midwife', 'Only midwives can view mothers');

    // 🏥 Get midwife context
    $ctx = $conn->prepare(
        "SELECT assigned_bhc_id 
         FROM midwives 
         WHERE account_id = ? 
         LIMIT 1"
    );

    if (!$ctx) {
        throw new Exception($conn->error);
    }

    $authAccountId = (int) $AUTH_USER['account_id'];
    $ctx->bind_param('i', $authAccountId);
    $ctx->execute();

    $ctxRes = $ctx->get_result()->fetch_assoc();
    expect($ctxRes !== null, 'Midwife context not found');

    $assignedBhcId = (int) $ctxRes['assigned_bhc_id'];

    // 👩‍🍼 Fetch mothers + ongoing pregnancy
    $stmt = $conn->prepare(
        "
        SELECT
            m.mother_id,
            a.first_name,
            a.middle_name,
            a.last_name,
            a.extension_name,
            a.phone_number,
            m.barangay,
            m.city_municipality,
            m.province,
            p.pregnancy_id,
            p.pregnancy_risk_level,
            p.status AS pregnancy_status,
            p.expected_date_of_delivery,
            p.last_menstrual_period
        FROM mothers m
        JOIN accounts a 
            ON m.account_id = a.account_id
        LEFT JOIN pregnancies p 
            ON p.mother_id = m.mother_id 
            AND p.status = 'ongoing'
        WHERE m.assigned_bhc_id = ?
        ORDER BY a.last_name ASC
        "
    );

    if (!$stmt) {
        throw new Exception($conn->error);
    }

    $stmt->bind_param('i', $assignedBhcId);
    $stmt->execute();

    $result = $stmt->get_result();

    $mothers = [];
    while ($row = $result->fetch_assoc()) {
        $mothers[] = $row;
    }

    // ✅ Success response
    echo json_encode([
        'success' => true,
        'data' => $mothers
    ]);

} catch (Throwable $e) {
    http_response_code(400);

    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
