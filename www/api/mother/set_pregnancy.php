<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../auth/auth_check.php';
require_once __DIR__ . '/../db.php';

$accountId = $AUTH_USER['account_id'] ?? null;
if (!$accountId) {
    echo json_encode(['success' => false]);
    exit;
}

$data = json_decode(file_get_contents('php://input'), true);

$lmpInput = $data['last_menstrual_period'] ?? null;
$eddInput = $data['expected_date_of_delivery'] ?? null;
$aogWeeks = isset($data['age_of_gestation'])
    ? (int) $data['age_of_gestation']
    : null;

/**
 * GET MOTHER
 */
$stmt = $conn->prepare("
    SELECT mother_id FROM mothers WHERE account_id=? LIMIT 1
");
$stmt->bind_param('i', $accountId);
$stmt->execute();
$mother = $stmt->get_result()->fetch_assoc();

if (!$mother) {
    echo json_encode(['success' => false, 'message' => 'Mother not found']);
    exit;
}

$motherId = (int) $mother['mother_id'];

/**
 * PREVENT DUPLICATE PREGNANCY
 */
$stmt = $conn->prepare("
    SELECT pregnancy_id
    FROM pregnancies
    WHERE mother_id=? AND status='ongoing'
    LIMIT 1
");
$stmt->bind_param('i', $motherId);
$stmt->execute();

if ($stmt->get_result()->fetch_assoc()) {
    echo json_encode(['success' => true]);
    exit;
}

/**
 * DERIVE LMP + EDD
 */
$lmp = null;
$edd = null;

if ($lmpInput) {
    $d = DateTime::createFromFormat('m/d/Y', $lmpInput);
    if ($d) {
        $lmp = $d->format('Y-m-d');
        $edd = (new DateTime($lmp))->modify('+280 days')->format('Y-m-d');
    }
} elseif ($eddInput) {
    $d = DateTime::createFromFormat('m/d/Y', $eddInput);
    if ($d) {
        $edd = $d->format('Y-m-d');
        $lmp = (new DateTime($edd))->modify('-280 days')->format('Y-m-d');
    }
} elseif ($aogWeeks !== null) {
    $today = new DateTime();
    $lmp = $today->modify("-{$aogWeeks} weeks")->format('Y-m-d');
    $edd = (new DateTime($lmp))->modify('+280 days')->format('Y-m-d');
}

if (!$lmp || !$edd) {
    echo json_encode(['success' => false, 'message' => 'Invalid pregnancy data']);
    exit;
}

/**
 * INSERT
 */
$stmt = $conn->prepare("
    INSERT INTO pregnancies
    (mother_id, last_menstrual_period, expected_date_of_delivery, status)
    VALUES (?, ?, ?, 'ongoing')
");
$stmt->bind_param('iss', $motherId, $lmp, $edd);
$stmt->execute();

echo json_encode(['success' => true]);
