<?php
require_once __DIR__ . '/../auth/auth_check.php';
require_once __DIR__ . '/../db.php';

header('Content-Type: application/json');

if ($AUTH_USER['account_type'] !== 'mother') {
    echo json_encode(['success' => false]);
    exit;
}

/**
 * Get mother_id
 */
$stmt = $conn->prepare("
    SELECT mother_id
    FROM mothers
    WHERE account_id = ?
    LIMIT 1
");
$stmt->bind_param('i', $AUTH_USER['account_id']);
$stmt->execute();
$mother = $stmt->get_result()->fetch_assoc();

if (!$mother) {
    echo json_encode(['success' => true, 'prenatal' => 0, 'ultrasound' => 0, 'laboratory' => 0, 'pregnancy' => 0]);
    exit;
}

$motherId = (int) $mother['mother_id'];

/**
 * Prenatal checkups
 */
$stmt = $conn->prepare("
    SELECT COUNT(*) total
    FROM prenatal_checkups pc
    JOIN pregnancies p ON p.pregnancy_id = pc.pregnancy_id
    WHERE p.mother_id = ?
");
$stmt->bind_param('i', $motherId);
$stmt->execute();
$prenatal = $stmt->get_result()->fetch_assoc()['total'];

/**
 * Ultrasounds
 */
$stmt = $conn->prepare("
    SELECT COUNT(*) total
    FROM ultrasounds u
    JOIN pregnancies p ON p.pregnancy_id = u.pregnancy_id
    WHERE p.mother_id = ?
");
$stmt->bind_param('i', $motherId);
$stmt->execute();
$ultrasound = $stmt->get_result()->fetch_assoc()['total'];

/**
 * Lab tests
 */
$stmt = $conn->prepare("
    SELECT COUNT(*) total
    FROM lab_tests l
    JOIN pregnancies p ON p.pregnancy_id = l.pregnancy_id
    WHERE p.mother_id = ?
");
$stmt->bind_param('i', $motherId);
$stmt->execute();
$laboratory = $stmt->get_result()->fetch_assoc()['total'];

/**
 * Pregnancy history
 */
$stmt = $conn->prepare("
    SELECT COUNT(*) total
    FROM pregnancies
    WHERE mother_id = ?
");
$stmt->bind_param('i', $motherId);
$stmt->execute();
$pregnancy = $stmt->get_result()->fetch_assoc()['total'];

echo json_encode([
    'success' => true,
    'prenatal' => (int) $prenatal,
    'ultrasound' => (int) $ultrasound,
    'laboratory' => (int) $laboratory,
    'pregnancy' => (int) $pregnancy,
]);
