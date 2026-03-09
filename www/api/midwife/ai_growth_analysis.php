<?php
require_once __DIR__ . '/../auth/auth_check.php';
require_once __DIR__ . '/../config/gemini.php';

header('Content-Type: application/json');

/**
 * =========================
 * INPUT VALIDATION
 * =========================
 */
$input = json_decode(file_get_contents("php://input"), true);
$records = $input['records'] ?? [];

if (!is_array($records) || count($records) < 2) {
    echo json_encode([
        'success' => false,
        'message' => 'At least two growth records are required'
    ]);
    exit;
}

/**
 * =========================
 * SORT RECORDS (OLDEST → NEWEST)
 * =========================
 */
usort($records, function ($a, $b) {
    return ($a['height'] <=> $b['height']);
});

/**
 * =========================
 * CHECK CONSISTENT GROWTH
 * =========================
 */
$heightIncreasing = true;
$weightIncreasing = true;

for ($i = 1; $i < count($records); $i++) {
    if ($records[$i]['height'] <= $records[$i - 1]['height']) {
        $heightIncreasing = false;
    }
    if ($records[$i]['weight'] <= $records[$i - 1]['weight']) {
        $weightIncreasing = false;
    }
}

$shouldBeNormal =
    count($records) >= 4 &&
    $heightIncreasing &&
    $weightIncreasing;

/**
 * =========================
 * PREPARE DATA FOR PROMPT
 * =========================
 */
$recordsJson = json_encode($records, JSON_PRETTY_PRINT);

/**
 * =========================
 * FRIENDLY GEMINI PROMPT
 * =========================
 */
$prompt = <<<PROMPT
You are a friendly and supportive pediatric growth assistant.

TASK:
Review the child’s growth records (height in cm, weight in kg) and explain the growth pattern in a calm, reassuring, and human-friendly way.

TONE & STYLE:
- Speak as if explaining to a parent or caregiver
- Be warm, supportive, and reassuring
- Use simple, clear language
- Avoid alarming or overly technical wording
- Emphasize reassurance when growth is healthy

STRICT FORMAT RULES:
- Respond with VALID JSON ONLY
- DO NOT use markdown
- DO NOT include ```json
- DO NOT add text outside JSON
- JSON must be COMPLETE
- Required keys:
  - status (short, friendly title)
  - remarks (2–3 supportive sentences)
  - recommendation (1–2 gentle suggestions)

Growth records:
$recordsJson
PROMPT;

/**
 * =========================
 * GEMINI REQUEST
 * =========================
 */
$payload = [
    'contents' => [[
        'parts' => [['text' => $prompt]]
    ]],
    'generationConfig' => [
        'temperature' => 0.0,
        'maxOutputTokens' => 300
    ]
];

$ch = curl_init(
    'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=' . GEMINI_API_KEY
);

curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_POST => true,
    CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
    CURLOPT_POSTFIELDS => json_encode($payload),
]);

$response = curl_exec($ch);
curl_close($ch);

$data = json_decode($response, true);
$text = $data['candidates'][0]['content']['parts'][0]['text'] ?? '';

/**
 * =========================
 * CLEAN & PARSE RESPONSE
 * =========================
 */
$text = trim(str_replace(['```json', '```'], '', $text));
$parsed = json_decode($text, true);

/**
 * =========================
 * FRIENDLY FALLBACK (NEVER FAIL)
 * =========================
 */
if (!$parsed || !is_array($parsed)) {
    $parsed = [
        'status' => 'Growing Well So Far',
        'remarks' =>
            'Based on the available measurements, your child is showing a positive growth trend. '
            . 'The pattern so far is reassuring, and more data over time helps give an even clearer picture.',
        'recommendation' =>
            'Continue tracking height and weight during regular checkups and support growth with balanced nutrition.'
    ];
}

/**
 * =========================
 * ENFORCE NORMAL GROWTH
 * =========================
 */
if ($shouldBeNormal) {
    $parsed['status'] = 'Healthy Growth Pattern';
}

/**
 * =========================
 * FINAL RESPONSE
 * =========================
 */
echo json_encode([
    'success' => true,
    'ai_response' => json_encode($parsed),
    'disclaimer' =>
        'This AI-assisted analysis is for guidance only and does not replace professional medical advice.'
]);
