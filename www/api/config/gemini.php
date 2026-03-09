<?php

define('GEMINI_API_KEY', 'AIzaSyA85gtvaCcWHTSuqcE8HwmlN49jJn0kGYw');

/**
 * Generate AI text using Google Gemini
 */
function generateGeminiText(string $prompt): string
{
    $url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=' . GEMINI_API_KEY;

    $payload = [
        'contents' => [
            [
                'parts' => [
                    ['text' => $prompt]
                ]
            ]
        ]
    ];

    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
        CURLOPT_POSTFIELDS => json_encode($payload),
        CURLOPT_TIMEOUT => 20,
    ]);

    $response = curl_exec($ch);
    curl_close($ch);

    if (!$response) {
        return '';
    }

    $data = json_decode($response, true);

    return $data['candidates'][0]['content']['parts'][0]['text'] ?? '';
}
