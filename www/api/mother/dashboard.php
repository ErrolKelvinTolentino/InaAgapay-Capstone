<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../auth/auth_check.php';
require_once __DIR__ . '/../db.php';

$accountId = $AUTH_USER['account_id'] ?? null;

if (!$accountId) {
    echo json_encode(['success' => false]);
    exit;
}

/**
 * ============================
 * BASE ACCOUNT INFO
 * ============================
 */
$stmt = $conn->prepare("
    SELECT first_name
    FROM accounts
    WHERE account_id = ?
    LIMIT 1
");
$stmt->bind_param('i', $accountId);
$stmt->execute();
$account = $stmt->get_result()->fetch_assoc();

$firstName = $account['first_name'] ?? '';

/**
 * ============================
 * MOTHER LOOKUP
 * ============================
 */
$stmt = $conn->prepare("
    SELECT mother_id
    FROM mothers
    WHERE account_id = ?
    LIMIT 1
");
$stmt->bind_param('i', $accountId);
$stmt->execute();
$mother = $stmt->get_result()->fetch_assoc();

if (!$mother) {
    // 🔴 No mother profile yet → return SAFE defaults
    echo json_encode([
        'success' => true,
        'first_name' => $firstName,
        'week' => 0,
        'weeks_left' => 0,
        'trimester' => '—',
        'due_date' => '—'
    ]);
    exit;
}

$motherId = (int) $mother['mother_id'];

/**
 * ============================
 * ONGOING PREGNANCY
 * ============================
 */
$stmt = $conn->prepare("
    SELECT
        last_menstrual_period,
        expected_date_of_delivery
    FROM pregnancies
    WHERE mother_id = ?
      AND status = 'ongoing'
    ORDER BY created_at DESC
    LIMIT 1
");
$stmt->bind_param('i', $motherId);
$stmt->execute();
$pregnancy = $stmt->get_result()->fetch_assoc();

if (!$pregnancy || !$pregnancy['last_menstrual_period']) {
    // 🟡 Mother exists but no pregnancy yet
    echo json_encode([
        'success' => true,
        'first_name' => $firstName,
        'week' => 0,
        'weeks_left' => 0,
        'trimester' => '—',
        'due_date' => '—'
    ]);
    exit;
}

/**
 * ============================
 * CALCULATIONS
 * ============================
 */
$lmp = new DateTime($pregnancy['last_menstrual_period']);
$today = new DateTime();

$daysPregnant = $lmp->diff($today)->days;
$week = max(1, (int) floor($daysPregnant / 7));
$weeksLeft = max(0, 40 - $week);

if ($week <= 13) {
    $trimester = 'First Trimester';
} elseif ($week <= 27) {
    $trimester = 'Second Trimester';
} else {
    $trimester = 'Third Trimester';
}

$dueDate = $pregnancy['expected_date_of_delivery']
    ? date('F d, Y', strtotime($pregnancy['expected_date_of_delivery']))
    : '—';

/**
 * ============================
 * FINAL RESPONSE (ALWAYS COMPLETE)
 * ============================
 */
echo json_encode([
    'success' => true,
    'first_name' => $firstName,
    'week' => $week,
    'weeks_left' => $weeksLeft,
    'trimester' => $trimester,
    'due_date' => $dueDate
]);
