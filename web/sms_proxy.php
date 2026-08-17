<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

function formatNigerianPhone($phone) {
    $digits = preg_replace('/\D/', '', $phone);
    if (strlen($digits) === 11 && substr($digits, 0, 1) === '0') {
        return '234' . substr($digits, 1);
    }
    if (strlen($digits) === 10 && in_array(substr($digits, 0, 1), ['7', '8', '9'])) {
        return '234' . $digits;
    }
    return $digits;
}

$inputJSON = file_get_contents('php://input');
$postData = json_decode($inputJSON, true) ?? $_POST;
$action = $_GET['action'] ?? $postData['action'] ?? (!empty($postData['to']) ? 'send' : 'balance');

if ($action === 'send') {
    $apiKey = $postData['api_key'] ?? $postData['token'] ?? $_GET['api_key'] ?? $_GET['token'] ?? '';
    $rawTo  = $postData['to'] ?? $_GET['to'] ?? '';
    $from   = $postData['from'] ?? $postData['sender'] ?? $_GET['sender'] ?? 'NIS LTD';
    $sms    = $postData['sms'] ?? $postData['message'] ?? $_GET['message'] ?? '';
    $to     = formatNigerianPhone($rawTo);

    if (empty($apiKey) || empty($to) || empty($sms)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'SmartSMS API Token, Recipient Phone, and Message body are required.']);
        exit();
    }

    // ── SmartSMS Solutions Gateway Only ──
    $smartSmsUrl = 'https://smartsmssolutions.com/api/json.php';
    $smartParams = [
        'token'   => $apiKey,
        'sender'  => $from,
        'to'      => $to,
        'message' => $sms,
        'routing' => '3' // Corporate DND Route
    ];

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $smartSmsUrl);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($smartParams));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 15);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($response !== false && ($httpCode === 200 || $httpCode === 201)) {
        $data = json_decode($response, true);
        $code = isset($data['code']) ? (string)$data['code'] : '';
        $comment = isset($data['comment']) ? (string)$data['comment'] : '';
        $isOk = ($code === '1000' || strpos($code, '100') === 0) ||
                !empty($data['successful']) ||
                (isset($data['status']) && strtoupper((string)$data['status']) === 'OK') ||
                (stripos($comment, 'success') !== false);

        if ($isOk) {
            http_response_code(200);
            echo json_encode(['success' => true, 'message' => 'Delivered via SmartSMS Solutions', 'raw' => $data]);
            exit();
        }

        $errMsg = !empty($comment) ? $comment : (!empty($data['error']) ? $data['error'] : 'SmartSMS Error (Code ' . $code . ')');
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'SmartSMS Gateway: ' . $errMsg, 'raw' => $data]);
        exit();
    }

    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Failed to reach SmartSMS Solutions gateway server.']);
    exit();
}

// Balance Query
$apiKey = $_GET['api_key'] ?? $_GET['token'] ?? $postData['api_key'] ?? '';
if (empty($apiKey)) {
    http_response_code(400);
    echo json_encode(['error' => 'SmartSMS Solutions API Token is required']);
    exit();
}

$smartBalUrl = 'https://app.smartsmssolutions.com/io/api/client/v1/balance/?token=' . urlencode($apiKey);
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $smartBalUrl);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 10);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($response !== false && $httpCode === 200) {
    $trimmed = trim($response);
    if (is_numeric($trimmed)) {
        http_response_code(200);
        echo json_encode(['balance' => (float)$trimmed, 'currency' => 'NGN']);
        exit();
    }
    $data = json_decode($response, true);
    if (isset($data['balance']) && is_numeric($data['balance'])) {
        http_response_code(200);
        echo json_encode(['balance' => (float)$data['balance'], 'currency' => 'NGN']);
        exit();
    }
}

http_response_code(200);
echo json_encode(['balance' => 0, 'currency' => 'NGN', 'error' => 'Could not fetch SmartSMS balance']);
?>
