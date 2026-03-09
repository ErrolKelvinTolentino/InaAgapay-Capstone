<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);

header("Content-Type: application/json");
require_once __DIR__ . '/../db.php';

$filter = $_GET['filter'] ?? 'all';

$dateCondition = "";
if ($filter === "today") {
    $dateCondition = "AND DATE(p.created_at) = CURDATE()";
} elseif ($filter === "week") {
    $dateCondition = "AND YEARWEEK(p.created_at,1) = YEARWEEK(CURDATE(),1)";
} elseif ($filter === "month") {
    $dateCondition = "AND MONTH(p.created_at)=MONTH(CURDATE()) AND YEAR(p.created_at)=YEAR(CURDATE())";
}

// Get the current midwife's BHC
$token = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
$token = str_replace('Bearer ', '', $token);

if (empty($token)) {
    echo json_encode(["success" => false, "error" => "No token provided"]);
    exit;
}

// Get account from token (simplified - adjust based on your auth system)
$accountQuery = $conn->prepare("
    SELECT a.account_id, a.account_type, m.assigned_bhc_id 
    FROM accounts a 
    LEFT JOIN midwives m ON a.account_id = m.account_id 
    WHERE a.last_login_token = ? AND a.status = 'active'
");
$accountQuery->bind_param("s", $token);
$accountQuery->execute();
$accountResult = $accountQuery->get_result();
$account = $accountResult->fetch_assoc();

if (!$account || $account['account_type'] !== 'midwife') {
    echo json_encode(["success" => false, "error" => "Unauthorized"]);
    exit;
}

$midwifeBHC = $account['assigned_bhc_id'];

/* ================= REGISTERED COUNTS (FOR CURRENT BHC) ================= */
$registeredSql = "
SELECT
  (SELECT COUNT(*) FROM mothers m WHERE m.assigned_bhc_id = ?) AS registered_mothers,
  (SELECT COUNT(*) FROM children c 
   JOIN mothers m ON c.mother_id = m.mother_id 
   WHERE m.assigned_bhc_id = ?) AS registered_children
";
$stmt = $conn->prepare($registeredSql);
$stmt->bind_param("ii", $midwifeBHC, $midwifeBHC);
$stmt->execute();
$registered = $stmt->get_result()->fetch_assoc();
$stmt->close();

/* ================= TRIMESTERS (FOR CURRENT BHC) ================= */
$trimesterSql = "
SELECT
  COALESCE(SUM(CASE WHEN TIMESTAMPDIFF(WEEK, last_menstrual_period, CURDATE()) <= 12 THEN 1 ELSE 0 END),0) AS first_trimester,
  COALESCE(SUM(CASE WHEN TIMESTAMPDIFF(WEEK, last_menstrual_period, CURDATE()) BETWEEN 13 AND 27 THEN 1 ELSE 0 END),0) AS second_trimester,
  COALESCE(SUM(CASE WHEN TIMESTAMPDIFF(WEEK, last_menstrual_period, CURDATE()) >= 28 THEN 1 ELSE 0 END),0) AS third_trimester
FROM pregnancies p
JOIN mothers m ON p.mother_id = m.mother_id
WHERE p.status = 'ongoing'
AND p.last_menstrual_period IS NOT NULL
AND m.assigned_bhc_id = ?
$dateCondition
";
$stmt = $conn->prepare($trimesterSql);
$stmt->bind_param("i", $midwifeBHC);
$stmt->execute();
$trimester = $stmt->get_result()->fetch_assoc();
$stmt->close();

/* ================= MEDICATION/VACCINE STATS (LAST 30 DAYS FOR CURRENT BHC) ================= */
$medicationSql = "
SELECT
  COALESCE(SUM(CASE WHEN REPLACE(UPPER(pc.td_vaccine_dose), ' ', '') IN ('TD1','TD2','TD3','TD4','TD5') THEN 1 ELSE 0 END), 0) AS td_doses_given,
  (SELECT COALESCE(SUM(gm.quantity), 0) FROM given_medications gm 
   JOIN mothers m2 ON gm.mother_id = m2.mother_id 
   WHERE m2.assigned_bhc_id = ?
     AND gm.date_given >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
     AND LOWER(gm.given_medication_name) LIKE '%ferrous%') AS ferrous_given,
  (SELECT COALESCE(SUM(gm.quantity), 0) FROM given_medications gm 
   JOIN mothers m3 ON gm.mother_id = m3.mother_id 
   WHERE m3.assigned_bhc_id = ?
     AND gm.date_given >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
     AND LOWER(gm.given_medication_name) LIKE '%calcium%') AS calcium_given
FROM prenatal_checkups pc
JOIN pregnancies p ON pc.pregnancy_id = p.pregnancy_id
JOIN mothers m ON p.mother_id = m.mother_id
WHERE pc.checkup_datetime >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
AND m.assigned_bhc_id = ?
";
$stmt = $conn->prepare($medicationSql);
$stmt->bind_param("iii", $midwifeBHC, $midwifeBHC, $midwifeBHC);
$stmt->execute();
$medication = $stmt->get_result()->fetch_assoc();
$stmt->close();

/* ================= CHECKUPS (MOTHERS NEEDING CHECKUPS - CURRENT BHC) ================= */
$checkupSql = "
SELECT
  COALESCE(COUNT(DISTINCT m.mother_id),0) AS mothers_due,
  (SELECT COUNT(DISTINCT c.child_id) 
   FROM children c 
   JOIN mothers m2 ON c.mother_id = m2.mother_id 
   WHERE m2.assigned_bhc_id = ?) AS children
FROM checkup_schedule cs
JOIN mothers m ON cs.mother_id = m.mother_id
WHERE cs.status = 'scheduled'
AND cs.scheduled_date >= CURDATE()
AND m.assigned_bhc_id = ?
";
$stmt = $conn->prepare($checkupSql);
$stmt->bind_param("ii", $midwifeBHC, $midwifeBHC);
$stmt->execute();
$checkups = $stmt->get_result()->fetch_assoc();
$stmt->close();

/* ================= RECENT VISITS (LAST 7 DAYS - CURRENT BHC) ================= */
$recentVisitsSql = "
SELECT 
  CONCAT(a.first_name, ' ', a.last_name) AS full_name,
  'Prenatal Check-up' AS visit_type,
  CASE 
    WHEN DATE(pc.checkup_datetime) = CURDATE() THEN 'Today'
    WHEN DATE(pc.checkup_datetime) = DATE_SUB(CURDATE(), INTERVAL 1 DAY) THEN 'Yesterday'
    ELSE CONCAT(DATEDIFF(CURDATE(), DATE(pc.checkup_datetime)), ' days ago')
  END AS time_label
FROM prenatal_checkups pc
JOIN pregnancies p ON pc.pregnancy_id = p.pregnancy_id
JOIN mothers m ON p.mother_id = m.mother_id
JOIN accounts a ON m.account_id = a.account_id
WHERE pc.checkup_datetime >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
AND m.assigned_bhc_id = ?
ORDER BY pc.checkup_datetime DESC
LIMIT 3
";
$stmt = $conn->prepare($recentVisitsSql);
$stmt->bind_param("i", $midwifeBHC);
$stmt->execute();
$visitsResult = $stmt->get_result();
$recentVisits = [];
while ($row = $visitsResult->fetch_assoc()) {
    $recentVisits[] = $row;
}
$stmt->close();

/* ================= BHC DAILY VISITS (LAST 7 DAYS - CURRENT BHC) ================= */
$chartDataSql = "
SELECT 
  DATE(pc.checkup_datetime) AS visit_day,
  DAYNAME(pc.checkup_datetime) AS day_name,
  COUNT(*) AS visit_count
FROM prenatal_checkups pc
JOIN pregnancies p ON pc.pregnancy_id = p.pregnancy_id
JOIN mothers m ON p.mother_id = m.mother_id
WHERE pc.checkup_datetime >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
AND m.assigned_bhc_id = ?
GROUP BY DATE(pc.checkup_datetime), DAYNAME(pc.checkup_datetime)
ORDER BY pc.checkup_datetime
";
$stmt = $conn->prepare($chartDataSql);
$stmt->bind_param("i", $midwifeBHC);
$stmt->execute();
$chartResult = $stmt->get_result();

$daysMap = ['Monday' => 'Mon', 'Tuesday' => 'Tue', 'Wednesday' => 'Wed', 
            'Thursday' => 'Thu', 'Friday' => 'Fri', 'Saturday' => 'Sat', 'Sunday' => 'Sun'];
$values = array_fill(0, 7, 0);
$labels = array_values($daysMap);

while ($row = $chartResult->fetch_assoc()) {
    $dayIndex = array_search($row['day_name'], array_keys($daysMap));
    if ($dayIndex !== false) {
        $values[$dayIndex] = (int)$row['visit_count'];
    }
}
$stmt->close();

/* ================= BIRTH OUTCOMES (CURRENT BHC) ================= */
$outcomeSql = "
SELECT
  COALESCE(SUM(p.outcome = 'live_birth'),0) AS live_birth,
  COALESCE(SUM(p.outcome = 'stillbirth'),0) AS stillbirth,
  COALESCE(SUM(p.outcome = 'miscarriage'),0) AS miscarriage,
  COALESCE(SUM(p.outcome = 'abortion'),0) AS abortion,
  COALESCE(SUM(p.outcome = 'ectopic'),0) AS ectopic
FROM pregnancies p
JOIN mothers m ON p.mother_id = m.mother_id
WHERE p.status = 'ended'
AND m.assigned_bhc_id = ?
$dateCondition
";
$stmt = $conn->prepare($outcomeSql);
$stmt->bind_param("i", $midwifeBHC);
$stmt->execute();
$outcomes = $stmt->get_result()->fetch_assoc();
$stmt->close();

/* ================= PLACE OF DELIVERY (CURRENT BHC) ================= */
$deliverySql = "
SELECT
  COALESCE(SUM(d.place_of_delivery LIKE '%hospital%'),0) AS hospital,
  COALESCE(SUM(d.place_of_delivery LIKE '%center%'),0) AS center,
  COALESCE(SUM(d.place_of_delivery LIKE '%home%'),0) AS home
FROM deliveries d
JOIN pregnancies p ON d.pregnancy_id = p.pregnancy_id
JOIN mothers m ON p.mother_id = m.mother_id
WHERE m.assigned_bhc_id = ?
$dateCondition
";
$stmt = $conn->prepare($deliverySql);
$stmt->bind_param("i", $midwifeBHC);
$stmt->execute();
$delivery = $stmt->get_result()->fetch_assoc();
$stmt->close();

/* ================= OUTPUT ================= */
echo json_encode([
    "success"   => true,
    "trimester" => $trimester,
    
    // Registered counts
    "registered" => [
        "mothers" => (int)$registered['registered_mothers'],
        "children" => (int)$registered['registered_children'],
    ],
    
    // Medication stats
    "medications" => [
        "ferrous_given" => (int)$medication['ferrous_given'],
        "calcium_given" => (int)$medication['calcium_given'],
        "td_doses_given" => (int)$medication['td_doses_given'],
    ],
    
    // Checkups
    "checkups"  => [
        "mothers_due"  => (int)$checkups['mothers_due'],
        "children"     => (int)$checkups['children'],
    ],
    
    // Recent visits for history card
    "recent_visits" => $recentVisits,
    
    // Chart data
    "chart_data" => [
        "values" => $values,
        "labels" => $labels,
        "highest" => max($values) ?: 0,
        "lowest" => min($values) ?: 0,
    ],
    
    "outcomes"  => $outcomes,
    "delivery"  => $delivery,
]);