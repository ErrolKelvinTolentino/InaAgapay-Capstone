<?php
require_once __DIR__ . '/../config/gemini.php';

$url = 'https://generativelanguage.googleapis.com/v1/models?key=' . GEMINI_API_KEY;

$ch = curl_init($url);
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
]);

$response = curl_exec($ch);
curl_close($ch);

header('Content-Type: application/json');
echo $response;
