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
    $rawSms = $postData['sms'] ?? $postData['message'] ?? $_GET['message'] ?? '';
    // Normalize unicode Naira symbol ₦ to standard ASCII 'N' to prevent 5x UCS-2 unicode charge explosion
    $sms    = str_replace(["\xE2\x82\xA6", '₦'], 'N', $rawSms);
    $to     = formatNigerianPhone($rawTo);

    if (empty($apiKey) || empty($to) || empty($sms)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'SmartSMS API Token, Recipient Phone, and Message body are required.']);
        exit();
    }

    if (strlen($to) !== 13 || substr($to, 0, 3) !== '234') {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid Nigerian phone number format: ' . $rawTo]);
        exit();
    }

    // ── SmartSMS Solutions Gateway (Primary: app.smartsmssolutions.com/io/api, Fallback: smartsmssolutions.com/api) ──
    $smartSmsUrl = 'https://app.smartsmssolutions.com/io/api/client/v1/sms/';
    $smartParams = [
        'token'   => $apiKey,
        'sender'  => $from,
        'to'      => $to,
        'message' => $sms,
        'routing' => '3' // Smart / Mixed DND Route
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

    // Fallback to legacy endpoint if v1 returned server error or 404
    if ($response === false || $httpCode === 404 || $httpCode >= 500) {
        $smartSmsUrl = 'https://smartsmssolutions.com/api/json.php';
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
    }

    if ($response !== false && ($httpCode === 200 || $httpCode === 201)) {
        $data = json_decode($response, true);
        $code = isset($data['code']) ? (string)$data['code'] : '';
        $comment = isset($data['comment']) ? (string)$data['comment'] : '';
        $successField = $data['success'] ?? null;
        $statusField = strtoupper((string)($data['status'] ?? ''));

        // Strict error checks: detect explicit failure phrases
        $lowerComment = strtolower($comment);
        $hasFailureWord = (
            strpos($lowerComment, 'unsuccessful') !== false ||
            strpos($lowerComment, 'insufficient') !== false ||
            strpos($lowerComment, 'fail') !== false ||
            strpos($lowerComment, 'invalid') !== false ||
            strpos($lowerComment, 'error') !== false ||
            strpos($lowerComment, 'rejected') !== false ||
            strpos($lowerComment, 'not allowed') !== false
        );

        $isOk = false;
        if (!$hasFailureWord && $successField !== false && $statusField !== 'ERROR') {
            // ONLY code 1000 is success in SmartSMS! 1001, 1002, 1003 etc. are error codes.
            if ($code === '1000' || !empty($data['successful']) || $successField === true || $statusField === 'OK' || $statusField === 'SUCCESS') {
                $isOk = true;
            }
        }

        if ($isOk) {
            http_response_code(200);
            echo json_encode(['success' => true, 'message' => 'Delivered via SmartSMS Solutions', 'raw' => $data]);
            exit();
        }

        $errMsg = !empty($comment) ? $comment : (!empty($data['error']) ? $data['error'] : (!empty($data['message']) ? $data['message'] : 'SmartSMS Error (Code ' . $code . ')'));
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
