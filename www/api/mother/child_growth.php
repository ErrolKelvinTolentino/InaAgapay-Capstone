<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../auth/auth_check.php';
require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/../config/gemini.php';

// ============================
// VALIDATION
// ============================
$childId = isset($_GET['child_id']) ? intval($_GET['child_id']) : 0;

if ($childId <= 0) {
    echo json_encode([
        'success' => false,
        'message' => 'Invalid child ID'
    ]);
    exit;
}

// ============================
// FETCH GROWTH RECORDS
// ============================
$stmt = $conn->prepare("
    SELECT child_height, child_weight, created_at
    FROM child_details
    WHERE child_id = ?
    ORDER BY created_at ASC
");
$stmt->bind_param("i", $childId);
$stmt->execute();
$result = $stmt->get_result();

$heightValues = [];
$weightValues = [];

while ($row = $result->fetch_assoc()) {
    if ($row['child_height'] !== null) {
        $heightValues[] = (float)$row['child_height'];
    }
    if ($row['child_weight'] !== null) {
        $weightValues[] = (float)$row['child_weight'];
    }
}

if (empty($heightValues) && empty($weightValues)) {
    echo json_encode([
        'success' => true,
        'height' => [
            'values' => [],
            'start' => '--',
            'latest' => '--',
            'gain' => '--'
        ],
        'weight' => [
            'values' => [],
            'start' => '--',
            'latest' => '--',
            'gain' => '--'
        ],
        'ai' => [
            'height' => 'No growth records available yet.',
            'weight' => 'No growth records available yet.'
        ]
    ]);
    exit;
}

// ============================
// COMPUTE HEIGHT
// ============================
$startHeight = $heightValues[0] ?? null;
$latestHeight = end($heightValues);
$heightGain = ($startHeight !== null && $latestHeight !== null)
    ? round($latestHeight - $startHeight, 2)
    : null;

// ============================
// COMPUTE WEIGHT
// ============================
$startWeight = $weightValues[0] ?? null;
$latestWeight = end($weightValues);
$weightGain = ($startWeight !== null && $latestWeight !== null)
    ? round($latestWeight - $startWeight, 2)
    : null;

// ============================
// AI PROMPT
// ============================
$prompt = "
You are a pediatric health assistant.

Analyze the child's growth data below and give a short, reassuring explanation for parents.

Height:
- Starting: {$startHeight} cm
- Latest: {$latestHeight} cm
- Change: {$heightGain} cm

Weight:
- Starting: {$startWeight} kg
- Latest: {$latestWeight} kg
- Change: {$weightGain} kg

Rules:
- No diagnosis
- Friendly tone
- Simple language
- 2–3 sentences only
";

// ============================
// AI GENERATION
// ============================
$aiText = generateGeminiText($prompt);

if (!$aiText) {
    $aiText = 'The child’s growth trend appears steady and healthy based on the recorded measurements.';
}

// ============================
// RESPONSE
// ============================
echo json_encode([
    'success' => true,

    'height' => [
        'values' => $heightValues,
        'start' => $startHeight,
        'latest' => $latestHeight,
        'gain' => $heightGain
    ],

    'weight' => [
        'values' => $weightValues,
        'start' => $startWeight,
        'latest' => $latestWeight,
        'gain' => $weightGain
    ],

    'ai' => [
        'height' => $aiText,
        'weight' => $aiText
    ]
]);
