<?php
require_once __DIR__ . '/../db.php';

// swallow auth output for JSON safety
ob_start();
require_once __DIR__ . '/../auth/auth_check.php';
ob_end_clean();

header('Content-Type: application/json');

function expect(bool $condition, string $message): void
{
    if (!$condition) {
        throw new Exception($message);
    }
}

function fmtDate(?string $value): ?string
{
    if (empty($value)) {
        return null;
    }
    return date('Y-m-d', strtotime($value));
}

try {
    expect(isset($AUTH_USER['account_type']), 'Unauthorized');
    expect($AUTH_USER['account_type'] === 'midwife', 'Only midwives can conclude pregnancies');

    $raw = file_get_contents('php://input');
    $input = json_decode($raw, true);
    expect(is_array($input), 'Invalid JSON payload');

    $pregnancyId = $input['pregnancy_id'] ?? null;
    $outcome = $input['outcome'] ?? null; // live_birth, stillbirth, miscarriage, abortion, ectopic
    $outcomeDate = fmtDate($input['outcome_date'] ?? null);
    $deliveryDate = fmtDate($input['delivery_date'] ?? null);
    $deliveryMethod = $input['delivery_method'] ?? null;
    $placeOfDelivery = $input['place_of_delivery'] ?? null;
    $gestationalAgeAtEnd = $input['gestational_age_at_end'] ?? null;
    $isOutcomeDateEstimated = (bool) ($input['is_outcome_date_estimated'] ?? false);

    expect(!empty($pregnancyId), 'pregnancy_id is required');
    expect(!empty($outcome), 'outcome is required');

    // normalize outcome values
    $outcome = strtolower(trim((string) $outcome));
    if ($outcome === 'livebirth' || $outcome === 'live birth') {
        $outcome = 'live_birth';
    }

    // midwife context
    $ctx = $conn->prepare("SELECT m.midwife_id, m.assigned_bhc_id FROM midwives m WHERE m.account_id = ? LIMIT 1");
    $authAccountId = $AUTH_USER['account_id'];
    $ctx->bind_param('i', $authAccountId);
    $ctx->execute();
    $ctxRes = $ctx->get_result()->fetch_assoc();
    expect($ctxRes !== null, 'Midwife context not found');
    $midwifeBhcId = (int) $ctxRes['assigned_bhc_id'];

    // pregnancy context
    $pregStmt = $conn->prepare("SELECT p.pregnancy_id, p.mother_id, p.status, m.assigned_bhc_id AS mother_bhc_id FROM pregnancies p JOIN mothers m ON m.mother_id = p.mother_id WHERE p.pregnancy_id = ? LIMIT 1");
    $pregStmt->bind_param('i', $pregnancyId);
    $pregStmt->execute();
    $pregRow = $pregStmt->get_result()->fetch_assoc();
    expect($pregRow !== null, 'Pregnancy not found');
    expect($pregRow['status'] === 'ongoing', 'Pregnancy already concluded');
    expect((int) $pregRow['mother_bhc_id'] === $midwifeBhcId, 'Pregnancy is not assigned to your BHC');

    // Resolve dates
    if (in_array($outcome, ['live_birth', 'stillbirth'], true)) {
        expect(!empty($deliveryDate), 'delivery_date is required for delivery outcomes');
        $outcomeDate = $deliveryDate; // align outcome date with delivery
    } else {
        expect(!empty($outcomeDate), 'outcome_date is required');
    }

    $conn->begin_transaction();

    // Insert/update delivery when applicable
    if (in_array($outcome, ['live_birth', 'stillbirth'], true)) {
        $delStmt = $conn->prepare(
            "INSERT INTO deliveries (pregnancy_id, delivery_date, is_delivery_date_estimated, place_of_delivery, delivery_method) " .
            "VALUES (?, ?, ?, ?, ?) " .
            "ON DUPLICATE KEY UPDATE delivery_date = VALUES(delivery_date), is_delivery_date_estimated = VALUES(is_delivery_date_estimated), place_of_delivery = VALUES(place_of_delivery), delivery_method = VALUES(delivery_method)"
        );
        $delStmt->bind_param(
            'isiss',
            $pregnancyId,
            $deliveryDate,
            $isOutcomeDateEstimated,
            $placeOfDelivery,
            $deliveryMethod
        );
        $delStmt->execute();
    }

    // End pregnancy
    $endStmt = $conn->prepare(
        "UPDATE pregnancies SET status = 'ended', outcome = ?, outcome_date = ?, is_outcome_date_estimated = ?, gestational_age_at_end = ?, ended_at = NOW() WHERE pregnancy_id = ?"
    );
    $endStmt->bind_param('ssidi', $outcome, $outcomeDate, $isOutcomeDateEstimated, $gestationalAgeAtEnd, $pregnancyId);
    $endStmt->execute();

    $conn->commit();

    echo json_encode([
        'success' => true,
        'pregnancy_id' => $pregnancyId,
        'outcome' => $outcome,
        'outcome_date' => $outcomeDate,
    ]);
} catch (Throwable $e) {
    $conn->rollback();
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
    ]);
}
