#include <ArduinoJson.h>
#include <DHT.h>
#include <HTTPClient.h>
#include <LiquidCrystal_I2C.h>
#include <WiFi.h>
#include <WiFiManager.h>
#include <WiFiClientSecure.h>
#include <Wire.h>
#include <esp_system.h>
#include <vector>

// ---------------------------------------------------------------------------
// User config
// ---------------------------------------------------------------------------
const char* PORTAL_AP_NAME = "ChestGateway";
const char* PORTAL_AP_PASS = "12345678";
const char* PORTAL_USER = "admin";
const char* PORTAL_PASS = "123456";
constexpr uint16_t PORTAL_TIMEOUT_SEC = 180;

const char* DATABASE_URL =
    "https://odienpremiumiot-default-rtdb.asia-southeast1.firebasedatabase.app";
const char* DATABASE_AUTH = "";

const char* DEVICE_ID = "device01";
const char* DEVICE_NAME = "O dien thong minh";
const char* DEVICE_LOCATION = "Phong khach";

// ---------------------------------------------------------------------------
// Hardware mapping
// ---------------------------------------------------------------------------
constexpr uint8_t DHT_PIN = 4;
constexpr uint8_t BUZZER_PIN = 26;
constexpr uint8_t LIGHT_DO_PIN = 14;
constexpr uint8_t LIGHT_AO_PIN = 27;
constexpr uint8_t LCD_SDA_PIN = 21;
constexpr uint8_t LCD_SCL_PIN = 22;

constexpr uint8_t RELAY_PINS[4] = {16, 17, 18, 19};
constexpr uint8_t BUTTON_PINS[4] = {33, 32, 35, 34};
const char* RELAY_IDS[4] = {"relay1", "relay2", "relay3", "relay4"};
const char* RELAY_LABELS[4] = {"Den ban", "Quat", "Sac", "Du phong"};

// ---------------------------------------------------------------------------
// Behavior config
// ---------------------------------------------------------------------------
constexpr bool RELAY_ACTIVE_LOW = false;
constexpr bool BUTTON_ACTIVE_LOW = true;
constexpr bool BUZZER_ACTIVE_HIGH = true;
constexpr bool LIGHT_DO_ACTIVE_LOW = true;
constexpr bool ENABLE_LEGACY_SMART_HOME_MIRROR = false;
constexpr bool ENABLE_LIGHT_ANALOG = false;

constexpr uint8_t DHT_TYPE = DHT11;
constexpr uint8_t LCD_I2C_ADDRESS = 0x27;
constexpr uint8_t LCD_I2C_FALLBACK_ADDRESS = 0x3F;
constexpr uint16_t LCD_COLUMNS = 16;
constexpr uint16_t LCD_ROWS = 2;

constexpr unsigned long BUTTON_DEBOUNCE_MS = 55;
constexpr unsigned long BUTTON1_SOFT_HOLD_MS = 220;
constexpr unsigned long WIFI_RETRY_MS = 10000;
constexpr unsigned long SENSOR_READ_MS = 3000;
constexpr unsigned long COMMAND_POLL_MS = 500;
constexpr unsigned long SETTINGS_POLL_MS = 15000;
constexpr unsigned long STATE_PUSH_MS = 5000;
constexpr unsigned long HISTORY_FLUSH_MS = 600;
constexpr unsigned long LCD_REFRESH_MS = 1000;
constexpr unsigned long LCD_PAGE_MS = 2500;
constexpr uint16_t HTTP_TIMEOUT_MS = 7000;
constexpr unsigned long HTTP_ACTION_GAP_MS = 120;

// GPIO27 is ADC2 on ESP32 and may conflict with WiFi. If AO becomes unstable,
// keep using DO14 for threshold logic or move AO to an ADC1 pin later.
// Analog light read is disabled by default for stability while WiFi is active.
constexpr int LIGHT_ADC_MIN = 0;
constexpr int LIGHT_ADC_MAX = 4095;
constexpr bool LIGHT_PERCENT_INVERTED = false;

// GPIO34 and GPIO35 do not have internal pull-up/down on ESP32.
// If you wire buttons active-low to GND, add external pull-up resistors.

// ---------------------------------------------------------------------------
// Globals
// ---------------------------------------------------------------------------
DHT dht(DHT_PIN, DHT_TYPE);
LiquidCrystal_I2C lcd(LCD_I2C_ADDRESS, LCD_COLUMNS, LCD_ROWS);
WiFiManager wm;
bool portalLoggedIn = false;
bool wifiPortalActive = false;
bool lcdReady = false;
uint8_t activeLcdAddress = LCD_I2C_ADDRESS;

const char LOGIN_PAGE[] PROGMEM = R"rawliteral(
<!doctype html><html lang="vi"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Chest Gateway Login</title>
<style>
body{font-family:system-ui;background:#0b1220;color:#e5e7eb;display:flex;min-height:100vh;align-items:center;justify-content:center;margin:0}
.card{width:min(380px,92vw);background:#111a2e;border:1px solid rgba(148,163,184,.35);border-radius:18px;padding:18px 16px;box-shadow:0 18px 60px rgba(0,0,0,.5)}
input{width:100%;padding:10px 11px;border-radius:12px;border:1px solid rgba(148,163,184,.35);background:#0b1220;color:#e5e7eb;font-size:14px;outline:none;margin-bottom:10px}
button{width:100%;padding:11px;border-radius:999px;border:none;background:linear-gradient(135deg,#3b82f6,#6366f1);color:white;font-weight:700;cursor:pointer}
.err{min-height:16px;margin-top:10px;color:#fb7185;font-size:12px;text-align:center}
</style></head><body>
<div class="card">
<h2>Secure login</h2>
<form method="POST" action="/login">
<input name="user" placeholder="admin" required>
<input name="pass" type="password" placeholder="password" required>
<button type="submit">Continue</button>
</form>
<div class="err">%ERR%</div>
</div></body></html>
)rawliteral";

struct ButtonState {
  bool stablePressed = false;
  bool lastReadingPressed = false;
  bool holdHandled = false;
  unsigned long lastDebounceAt = 0;
  unsigned long pressedAt = 0;
};

struct HistoryEvent {
  bool used = false;
  String eventType;
  String target;
  String source;
  bool hasOldValue = false;
  bool oldValue = false;
  bool hasNewValue = false;
  bool newValue = false;
  float temperature = NAN;
  float humidity = NAN;
  int light = -1;
};

constexpr size_t HISTORY_QUEUE_CAPACITY = 12;
HistoryEvent historyQueue[HISTORY_QUEUE_CAPACITY];
size_t historyHead = 0;
size_t historyCount = 0;

ButtonState buttons[4];
bool relayStates[4] = {false, false, false, false};

float temperatureC = NAN;
float humidityPct = NAN;
int lightRaw = -1;
int lightPercent = -1;
bool lightTriggered = false;
bool alarmActive = false;
bool buzzerEnabled = true;
float tempLimitC = 40.0f;
float lightLimitPercent = 75.0f;
String mode = "manual";
String lastProcessedCommandId = "";
String lastActionSource = "boot";
String lastAppliedCommandId = "";
String lastAppliedCommandTarget = "";
String lastAppliedCommandAction = "";
String lastAppliedCommandSource = "";
String lastAppliedCommandStatus = "";
String relayLastSources[4] = {"boot", "boot", "boot", "boot"};

bool relayMetaDirty[4] = {false, false, false, false};
bool commandAckDirty = false;

bool stateDirty = true;

unsigned long lastWifiAttemptAt = 0;
unsigned long lastHttpActionFinishedAt = 0;
unsigned long lastSensorReadAt = 0;
unsigned long lastCommandPollAt = 0;
unsigned long lastSettingsPollAt = 0;
unsigned long lastStatePushAt = 0;
unsigned long lastHistoryFlushAt = 0;
unsigned long lastLcdRefreshAt = 0;
unsigned long lcdPageStartedAt = 0;
uint8_t lcdPageIndex = 0;

// ---------------------------------------------------------------------------
// Helper functions
// ---------------------------------------------------------------------------
String deviceBasePath() {
  return String("devices/") + DEVICE_ID;
}

String devicePath(const String& child) {
  return deviceBasePath() + "/" + child;
}

String firebaseUrlFor(const String& path, const String& extraQuery = "") {
  String url = DATABASE_URL;
  if (url.endsWith("/")) {
    url.remove(url.length() - 1);
  }
  url += "/" + path + ".json";
  char queryJoin = '?';
  if (strlen(DATABASE_AUTH) > 0) {
    url += "?auth=" + String(DATABASE_AUTH);
    queryJoin = '&';
  }
  if (extraQuery.length() > 0) {
    url += queryJoin;
    url += extraQuery;
  }
  return url;
}

uint8_t relayOutputLevel(bool isOn) {
  if (RELAY_ACTIVE_LOW) {
    return isOn ? LOW : HIGH;
  }
  return isOn ? HIGH : LOW;
}

uint8_t buzzerActiveLevel() {
  return BUZZER_ACTIVE_HIGH ? HIGH : LOW;
}

uint8_t buzzerIdleLevel() {
  return BUZZER_ACTIVE_HIGH ? LOW : HIGH;
}

void logLine(const String& message) {
  Serial.println(message);
}

const char* resetReasonLabel(esp_reset_reason_t reason) {
  switch (reason) {
    case ESP_RST_POWERON:
      return "POWERON";
    case ESP_RST_EXT:
      return "EXT";
    case ESP_RST_SW:
      return "SW";
    case ESP_RST_PANIC:
      return "PANIC";
    case ESP_RST_INT_WDT:
      return "INT_WDT";
    case ESP_RST_TASK_WDT:
      return "TASK_WDT";
    case ESP_RST_WDT:
      return "WDT";
    case ESP_RST_DEEPSLEEP:
      return "DEEPSLEEP";
    case ESP_RST_BROWNOUT:
      return "BROWNOUT";
    case ESP_RST_SDIO:
      return "SDIO";
    case ESP_RST_UNKNOWN:
    default:
      return "UNKNOWN";
  }
}

void logBootDiagnostics() {
  const esp_reset_reason_t reason = esp_reset_reason();
  logLine(String("[BOOT] Reset reason: ") + resetReasonLabel(reason) + " (" +
          static_cast<int>(reason) + ")");
  logLine(String("[BOOT] Heap free: ") + ESP.getFreeHeap() + " bytes");
  logLine(String("[BOOT] Heap min : ") + ESP.getMinFreeHeap() + " bytes");
}

void waitForHttpGap() {
  if (lastHttpActionFinishedAt == 0) {
    return;
  }

  const unsigned long elapsed = millis() - lastHttpActionFinishedAt;
  if (elapsed < HTTP_ACTION_GAP_MS) {
    delay(HTTP_ACTION_GAP_MS - elapsed);
  }
}

void markHttpActionFinished() {
  lastHttpActionFinishedAt = millis();
}

bool i2cDeviceExists(uint8_t address) {
  Wire.beginTransmission(address);
  return Wire.endTransmission() == 0;
}

uint8_t detectLcdAddress() {
  if (i2cDeviceExists(LCD_I2C_ADDRESS)) {
    return LCD_I2C_ADDRESS;
  }

  if (LCD_I2C_FALLBACK_ADDRESS != LCD_I2C_ADDRESS &&
      i2cDeviceExists(LCD_I2C_FALLBACK_ADDRESS)) {
    return LCD_I2C_FALLBACK_ADDRESS;
  }

  for (uint8_t address = 1; address < 127; address++) {
    if (i2cDeviceExists(address)) {
      return address;
    }
  }

  return 0;
}

bool initializeLcd() {
  activeLcdAddress = detectLcdAddress();

  if (activeLcdAddress == 0) {
    logLine("[LCD] Khong tim thay thiet bi I2C nao");
    lcdReady = false;
    return false;
  }

  if (activeLcdAddress != LCD_I2C_ADDRESS) {
    logLine(String("[LCD] Doi dia chi tu 0x") + String(LCD_I2C_ADDRESS, HEX) +
            " sang 0x" + String(activeLcdAddress, HEX));
    lcd = LiquidCrystal_I2C(activeLcdAddress, LCD_COLUMNS, LCD_ROWS);
  } else {
    logLine(String("[LCD] Tim thay LCD tai 0x") +
            String(activeLcdAddress, HEX));
  }

  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcdReady = true;
  return true;
}

String buildWifiList() {
  String out;
  const int networkCount = WiFi.scanNetworks();

  if (networkCount <= 0) {
    out +=
        "<div style='color:#9ca3af;font-size:13px'>Khong tim thay mang Wi-Fi.</div>";
    return out;
  }

  out +=
      "<div style='display:flex;flex-direction:column;gap:6px;max-height:240px;overflow:auto;padding:6px;border:1px solid rgba(148,163,184,.25);border-radius:12px;background:#0b1220'>";

  for (int i = 0; i < networkCount; i++) {
    String ssid = WiFi.SSID(i);
    ssid.replace("\\", "\\\\");
    ssid.replace("'", "\\'");

    out +=
        "<button type='button' style='text-align:left;padding:10px;border-radius:10px;border:1px solid rgba(148,163,184,.20);background:#111a2e;color:#e5e7eb;cursor:pointer' ";
    out += "onclick=\"document.getElementById('ssid').value='";
    out += ssid;
    out += "'\">";
    out += "<div style='font-weight:600'>" + WiFi.SSID(i) + "</div>";
    out += "<div style='font-size:12px;color:#9ca3af'>RSSI " +
           String(WiFi.RSSI(i)) + " dBm</div>";
    out += "</button>";
  }

  out += "</div>";
  WiFi.scanDelete();
  return out;
}

void sendLoginPage(const String& errorMessage = "") {
  String page = FPSTR(LOGIN_PAGE);
  page.replace("%ERR%", errorMessage);
  wm.server->send(200, "text/html", page);
}

void sendWifiPage() {
  if (!portalLoggedIn) {
    wm.server->sendHeader("Location", "/", true);
    wm.server->send(302, "text/plain", "");
    return;
  }

  String page;
  page +=
      "<!doctype html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>";
  page +=
      "<style>body{font-family:system-ui;background:#0b1220;color:#e5e7eb;display:flex;min-height:100vh;align-items:center;justify-content:center;margin:0}.card{width:min(440px,92vw);background:#111a2e;border:1px solid rgba(148,163,184,.35);border-radius:18px;padding:18px 16px}input{width:100%;padding:10px;border-radius:12px;border:1px solid rgba(148,163,184,.35);background:#0b1220;color:#e5e7eb;margin:8px 0}button{width:100%;padding:11px;border-radius:999px;border:none;background:#16a34a;color:white;font-weight:800;margin-top:8px}</style>";
  page += "</head><body><div class='card'>";
  page += "<h2>Wi-Fi Setup</h2>";
  page += "<div style='font-size:12px;color:#9ca3af;margin-bottom:10px'>AP: " +
          wm.getConfigPortalSSID() + "</div>";
  page += buildWifiList();
  page += "<form method='GET' action='/wifisave'>";
  page += "<input id='ssid' name='s' placeholder='SSID' required>";
  page += "<input name='p' type='password' placeholder='Password'>";
  page += "<button type='submit'>Luu & ket noi</button></form>";
  page += "</div></body></html>";

  wm.server->send(200, "text/html", page);
}

void bindServerCallback() {
  if (!wm.server) {
    return;
  }

  wm.server->on("/", []() {
    if (portalLoggedIn) {
      wm.server->sendHeader("Location", "/wifi", true);
      wm.server->send(302, "text/plain", "");
    } else {
      sendLoginPage();
    }
  });

  wm.server->on("/login", []() {
    if (!wm.server->hasArg("user") || !wm.server->hasArg("pass")) {
      sendLoginPage("Missing fields");
      return;
    }

    const String user = wm.server->arg("user");
    const String pass = wm.server->arg("pass");

    if (user == PORTAL_USER && pass == PORTAL_PASS) {
      portalLoggedIn = true;
      wm.server->sendHeader("Location", "/wifi", true);
      wm.server->send(302, "text/plain", "");
    } else {
      portalLoggedIn = false;
      sendLoginPage("Wrong user/pass");
    }
  });

  wm.server->on("/wifi", []() {
    sendWifiPage();
  });
}

bool setupWiFiWithPortal(const char* apName = PORTAL_AP_NAME,
                         const char* apPass = PORTAL_AP_PASS,
                         uint16_t timeoutSec = PORTAL_TIMEOUT_SEC) {
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  portalLoggedIn = false;
  wifiPortalActive = false;

  wm.setConfigPortalBlocking(false);
  wm.setConfigPortalTimeout(timeoutSec);
  std::vector<const char*> menu = {"wifi", "exit"};
  wm.setMenu(menu);
  wm.setWebServerCallback(bindServerCallback);

  const bool connected = wm.autoConnect(apName, apPass);

  if (connected) {
    logLine(String("WiFi OK IP: ") + WiFi.localIP().toString());
  } else {
    wifiPortalActive = true;
    logLine("[WiFi] Config portal running in background");
  }

  return connected;
}

void processWifiPortal() {
  if (!wifiPortalActive) {
    return;
  }

  wm.process();

  if (WiFi.status() == WL_CONNECTED) {
    wifiPortalActive = false;
    portalLoggedIn = false;
    logLine(String("WiFi OK IP: ") + WiFi.localIP().toString());
  }
}

template <typename TDoc>
bool sendJsonRequest(const char* method,
                     const String& path,
                     const TDoc& doc,
                     String* responseBody = nullptr) {
  if (WiFi.status() != WL_CONNECTED) {
    return false;
  }

  waitForHttpGap();

  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;
  http.setTimeout(HTTP_TIMEOUT_MS);
  if (!http.begin(client, firebaseUrlFor(path, "print=silent"))) {
    markHttpActionFinished();
    return false;
  }

  http.addHeader("Content-Type", "application/json");

  String payload;
  serializeJson(doc, payload);

  int httpCode = http.sendRequest(
      method,
      reinterpret_cast<uint8_t*>(const_cast<char*>(payload.c_str())),
      payload.length());

  if (responseBody != nullptr) {
    *responseBody = http.getString();
  } else {
    http.getString();
  }

  http.end();
  markHttpActionFinished();

  if (httpCode < 200 || httpCode >= 300) {
    logLine(String("[HTTP] ") + method + " " + path + " -> " + httpCode);
    return false;
  }
  return true;
}

bool getJson(const String& path, DynamicJsonDocument& doc) {
  doc.clear();

  if (WiFi.status() != WL_CONNECTED) {
    return false;
  }

  waitForHttpGap();

  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;
  http.setTimeout(HTTP_TIMEOUT_MS);
  if (!http.begin(client, firebaseUrlFor(path, "timeout=4s"))) {
    markHttpActionFinished();
    return false;
  }

  const int httpCode = http.GET();
  const String body = http.getString();
  http.end();
  markHttpActionFinished();

  if (httpCode < 200 || httpCode >= 300) {
    logLine(String("[HTTP] GET ") + path + " -> " + httpCode);
    return false;
  }

  if (body.length() == 0 || body == "null") {
    return true;
  }

  const DeserializationError error = deserializeJson(doc, body);
  if (error) {
    logLine(String("[JSON] ") + path + " -> " + error.c_str());
    return false;
  }

  return true;
}

int relayIndexFromTarget(const String& target) {
  for (int index = 0; index < 4; index++) {
    if (target == RELAY_IDS[index]) {
      return index;
    }
  }
  return -1;
}

int calculateLightPercent(int raw) {
  if (raw < 0) {
    return -1;
  }

  const long constrained = constrain(raw, LIGHT_ADC_MIN, LIGHT_ADC_MAX);
  long percent = map(constrained, LIGHT_ADC_MIN, LIGHT_ADC_MAX, 0, 100);
  percent = constrain(percent, 0, 100);

  if (LIGHT_PERCENT_INVERTED) {
    percent = 100 - percent;
  }

  return static_cast<int>(percent);
}

bool readButtonPressed(uint8_t index) {
  const int raw = digitalRead(BUTTON_PINS[index]);
  return BUTTON_ACTIVE_LOW ? (raw == LOW) : (raw == HIGH);
}

bool readLightTriggered() {
  const int raw = digitalRead(LIGHT_DO_PIN);
  return LIGHT_DO_ACTIVE_LOW ? (raw == LOW) : (raw == HIGH);
}

void beep(uint16_t durationMs) {
  if (!buzzerEnabled) {
    return;
  }

  digitalWrite(BUZZER_PIN, buzzerActiveLevel());
  delay(durationMs);
  digitalWrite(BUZZER_PIN, buzzerIdleLevel());
}

void setRelayHardware(uint8_t index, bool newState) {
  relayStates[index] = newState;
  digitalWrite(RELAY_PINS[index], relayOutputLevel(newState));
}

void enqueueHistoryEvent(const String& eventType,
                         const String& target,
                         bool hasOldValue,
                         bool oldValue,
                         bool hasNewValue,
                         bool newValue,
                         const String& source) {
  if (historyCount == HISTORY_QUEUE_CAPACITY) {
    historyHead = (historyHead + 1) % HISTORY_QUEUE_CAPACITY;
    historyCount--;
  }

  const size_t tail = (historyHead + historyCount) % HISTORY_QUEUE_CAPACITY;
  historyQueue[tail].used = true;
  historyQueue[tail].eventType = eventType;
  historyQueue[tail].target = target;
  historyQueue[tail].source = source;
  historyQueue[tail].hasOldValue = hasOldValue;
  historyQueue[tail].oldValue = oldValue;
  historyQueue[tail].hasNewValue = hasNewValue;
  historyQueue[tail].newValue = newValue;
  historyQueue[tail].temperature = temperatureC;
  historyQueue[tail].humidity = humidityPct;
  historyQueue[tail].light = lightRaw;
  historyCount++;
}

bool flushOneHistoryEvent() {
  if (historyCount == 0 || WiFi.status() != WL_CONNECTED) {
    return false;
  }

  HistoryEvent& event = historyQueue[historyHead];
  if (!event.used) {
    historyHead = (historyHead + 1) % HISTORY_QUEUE_CAPACITY;
    historyCount--;
    return false;
  }

  DynamicJsonDocument doc(512);
  JsonObject root = doc.to<JsonObject>();
  root["eventType"] = event.eventType;
  root["target"] = event.target;
  root["source"] = event.source;

  if (event.hasOldValue) {
    root["oldValue"] = event.oldValue;
  }
  if (event.hasNewValue) {
    root["newValue"] = event.newValue;
  }
  if (!isnan(event.temperature)) {
    root["temperature"] = event.temperature;
  }
  if (!isnan(event.humidity)) {
    root["humidity"] = event.humidity;
  }
  if (event.light >= 0) {
    root["light"] = event.light;
  }

  JsonObject timeObject = root.createNestedObject("time");
  timeObject[".sv"] = "timestamp";

  if (!sendJsonRequest("POST", devicePath("history"), doc)) {
    return false;
  }

  event.used = false;
  historyHead = (historyHead + 1) % HISTORY_QUEUE_CAPACITY;
  historyCount--;
  return true;
}

void updateAlarmState() {
  const bool nextAlarm =
      (!isnan(temperatureC) && temperatureC >= tempLimitC);

  if (nextAlarm && !alarmActive) {
    beep(180);
  }

  alarmActive = nextAlarm;
}

bool publishState(bool forcePush = false) {
  const bool intervalReady =
      millis() - lastStatePushAt >= STATE_PUSH_MS;

  if (!forcePush && !stateDirty && !intervalReady) {
    return false;
  }

  if (WiFi.status() != WL_CONNECTED) {
    return false;
  }

  DynamicJsonDocument doc(1536);
  JsonObject root = doc.to<JsonObject>();
  root["online"] = true;
  root["mode"] = mode;
  root["relay1"] = relayStates[0];
  root["relay2"] = relayStates[1];
  root["relay3"] = relayStates[2];
  root["relay4"] = relayStates[3];
  root["buzzerEnabled"] = buzzerEnabled;
  root["buzzerMuted"] = !buzzerEnabled;
  root["alarm"] = alarmActive;
  root["overTempLock"] = alarmActive;
  root["lastSource"] = lastActionSource;
  root["lastCommandId"] = lastProcessedCommandId;
  root["uptime"] = String(millis() / 1000) + "s";
  root["lightText"] = lightTriggered ? "Sang" : "Toi";

  for (uint8_t index = 0; index < 4; index++) {
    const String relaySourceKey = String(RELAY_IDS[index]) + "Source";
    root[relaySourceKey] = relayLastSources[index];

    if (!relayMetaDirty[index]) {
      continue;
    }

    const String relayChangedAtKey = String(RELAY_IDS[index]) + "ChangedAt";
    JsonObject changedAt = root.createNestedObject(relayChangedAtKey);
    changedAt[".sv"] = "timestamp";
  }

  if (commandAckDirty) {
    root["lastAppliedCommandId"] = lastAppliedCommandId;
    root["lastAppliedCommandTarget"] = lastAppliedCommandTarget;
    root["lastAppliedCommandAction"] = lastAppliedCommandAction;
    root["lastAppliedCommandSource"] = lastAppliedCommandSource;
    root["lastAppliedCommandStatus"] = lastAppliedCommandStatus;
    JsonObject appliedAt = root.createNestedObject("lastAppliedCommandAt");
    appliedAt[".sv"] = "timestamp";
  }

  if (!isnan(temperatureC)) {
    root["temperature"] = temperatureC;
  }
  if (!isnan(humidityPct)) {
    root["humidity"] = humidityPct;
  }
  if (lightRaw >= 0) {
    root["light"] = lightRaw;
  }
  if (lightPercent >= 0) {
    root["lightPercent"] = lightPercent;
  }
  root["lightDigital"] = lightTriggered;

  JsonObject lastSeen = root.createNestedObject("lastSeen");
  lastSeen[".sv"] = "timestamp";

  if (!sendJsonRequest("PATCH", devicePath("state"), doc)) {
    return false;
  }

  lastStatePushAt = millis();
  stateDirty = false;
  commandAckDirty = false;
  for (uint8_t index = 0; index < 4; index++) {
    relayMetaDirty[index] = false;
  }
  return true;
}

void syncSettingsFromFirebase() {
  if (WiFi.status() != WL_CONNECTED) {
    return;
  }

  DynamicJsonDocument doc(768);
  if (!getJson(devicePath("settings"), doc)) {
    return;
  }

  if (doc.size() == 0) {
    return;
  }

  JsonObjectConst root = doc.as<JsonObjectConst>();

  if (!root["mode"].isNull()) {
    mode = String(root["mode"].as<const char*>());
    mode.toLowerCase();
  }
  if (!root["buzzerEnabled"].isNull()) {
    buzzerEnabled = root["buzzerEnabled"].as<bool>();
  } else if (!root["buzzerEnable"].isNull()) {
    buzzerEnabled = root["buzzerEnable"].as<bool>();
  }
  if (!root["tempLimit"].isNull()) {
    tempLimitC = root["tempLimit"].as<float>();
  }
  if (!root["lightLimit"].isNull()) {
    lightLimitPercent = root["lightLimit"].as<float>();
  }
}

void syncDeviceInfoNode() {
  if (WiFi.status() != WL_CONNECTED) {
    return;
  }

  DynamicJsonDocument doc(256);
  JsonObject root = doc.to<JsonObject>();
  root["name"] = DEVICE_NAME;
  root["location"] = DEVICE_LOCATION;

  sendJsonRequest("PATCH", devicePath("info"), doc);
}

void restoreStateFromFirebase() {
  if (WiFi.status() != WL_CONNECTED) {
    return;
  }

  DynamicJsonDocument doc(768);
  if (getJson(devicePath("state"), doc) && doc.size() > 0) {
    JsonObjectConst root = doc.as<JsonObjectConst>();

    for (uint8_t index = 0; index < 4; index++) {
      if (!root[RELAY_IDS[index]].isNull()) {
        setRelayHardware(index, root[RELAY_IDS[index]].as<bool>());
      }
    }

    if (!root["lastCommandId"].isNull()) {
      lastProcessedCommandId = String(root["lastCommandId"].as<const char*>());
    }
    for (uint8_t index = 0; index < 4; index++) {
      const String relaySourceKey = String(RELAY_IDS[index]) + "Source";
      if (!root[relaySourceKey].isNull()) {
        relayLastSources[index] =
            String(root[relaySourceKey].as<const char*>());
      }
    }
  }
}

void markCommandAck(const String& commandId,
                    const String& target,
                    const String& action,
                    const String& source,
                    const String& status) {
  lastAppliedCommandId = commandId;
  lastAppliedCommandTarget = target;
  lastAppliedCommandAction = action;
  lastAppliedCommandSource = source;
  lastAppliedCommandStatus = status;
  commandAckDirty = true;
}

bool applyRelayState(uint8_t relayIndex,
                     bool newState,
                     const String& source,
                     bool addHistory) {
  if (relayIndex >= 4) {
    return false;
  }

  const bool oldState = relayStates[relayIndex];
  if (oldState == newState) {
    lastActionSource = source;
    stateDirty = true;
    return false;
  }

  setRelayHardware(relayIndex, newState);
  lastActionSource = source;
  relayLastSources[relayIndex] = source;
  relayMetaDirty[relayIndex] = true;
  stateDirty = true;

  if (addHistory) {
    enqueueHistoryEvent("relay_change",
                        RELAY_IDS[relayIndex],
                        true,
                        oldState,
                        true,
                        newState,
                        source);
  }

  beep(70);
  return true;
}

void handleLocalButton(uint8_t relayIndex) {
  const bool newState = !relayStates[relayIndex];
  logLine(String("[BUTTON] ") + RELAY_IDS[relayIndex] + " pressed -> " +
          (newState ? "ON" : "OFF"));
  applyRelayState(relayIndex, newState, "button", true);
  publishState(true);
}

void pollFirebaseCommand() {
  if (WiFi.status() != WL_CONNECTED) {
    return;
  }

  DynamicJsonDocument doc(512);
  if (!getJson(devicePath("command/latest"), doc)) {
    return;
  }

  if (doc.size() == 0) {
    return;
  }

  JsonObjectConst root = doc.as<JsonObjectConst>();
  const char* commandIdChars = root["commandId"] | "";
  const char* targetChars = root["target"] | "";
  const char* actionChars = root["action"] | "";
  const char* sourceChars = root["source"] | "app";

  const String commandId = String(commandIdChars);
  if (commandId.length() == 0 || commandId == lastProcessedCommandId) {
    return;
  }

  String target = String(targetChars);
  String action = String(actionChars);
  String source = String(sourceChars);
  target.toLowerCase();
  action.toLowerCase();

  const int relayIndex = relayIndexFromTarget(target);
  if (relayIndex < 0) {
    lastProcessedCommandId = commandId;
    markCommandAck(commandId, target, action, source, "ignored_target");
    stateDirty = true;
    publishState(true);
    return;
  }

  bool nextState = relayStates[relayIndex];
  if (action == "on") {
    nextState = true;
  } else if (action == "off") {
    nextState = false;
  } else if (action == "toggle") {
    nextState = !relayStates[relayIndex];
  } else {
    lastProcessedCommandId = commandId;
    markCommandAck(commandId, target, action, source, "ignored_action");
    stateDirty = true;
    publishState(true);
    return;
  }

  const bool changed = applyRelayState(relayIndex, nextState, source, true);
  lastProcessedCommandId = commandId;
  markCommandAck(commandId,
                 target,
                 action,
                 source,
                 changed ? "applied" : "noop");
  publishState(true);
}

void readSensors() {
  const float nextTemperature = dht.readTemperature();
  const float nextHumidity = dht.readHumidity();

  if (!isnan(nextTemperature)) {
    temperatureC = nextTemperature;
  }
  if (!isnan(nextHumidity)) {
    humidityPct = nextHumidity;
  }

  lightTriggered = readLightTriggered();
  if (ENABLE_LIGHT_ANALOG) {
    lightRaw = analogRead(LIGHT_AO_PIN);
    lightPercent = calculateLightPercent(lightRaw);
  } else {
    lightRaw = -1;
    lightPercent = -1;
  }

  updateAlarmState();
  stateDirty = true;
}

void scanButtons() {
  for (uint8_t index = 0; index < 4; index++) {
    const bool readingPressed = readButtonPressed(index);

    if (readingPressed != buttons[index].lastReadingPressed) {
      buttons[index].lastReadingPressed = readingPressed;
      buttons[index].lastDebounceAt = millis();
    }

    if (millis() - buttons[index].lastDebounceAt < BUTTON_DEBOUNCE_MS) {
      continue;
    }

    if (readingPressed != buttons[index].stablePressed) {
      buttons[index].stablePressed = readingPressed;
      if (buttons[index].stablePressed) {
        buttons[index].pressedAt = millis();
        buttons[index].holdHandled = false;

        if (index != 0) {
          handleLocalButton(index);
          buttons[index].holdHandled = true;
        }
      } else {
        buttons[index].pressedAt = 0;
        buttons[index].holdHandled = false;
      }
    }

    if (index == 0 &&
        buttons[index].stablePressed &&
        !buttons[index].holdHandled &&
        buttons[index].pressedAt != 0 &&
        millis() - buttons[index].pressedAt >= BUTTON1_SOFT_HOLD_MS) {
      handleLocalButton(index);
      buttons[index].holdHandled = true;
    }
  }
}

void refreshLcd() {
  if (!lcdReady) {
    return;
  }

  if (millis() - lcdPageStartedAt >= LCD_PAGE_MS) {
    lcdPageStartedAt = millis();
    lcdPageIndex = (lcdPageIndex + 1) % 4;
  }

  lcd.clear();

  switch (lcdPageIndex) {
    case 0:
      lcd.setCursor(0, 0);
      lcd.print("WiFi:");
      lcd.print(WiFi.status() == WL_CONNECTED ? "OK " : "OFF");
      lcd.print(" ");
      lcd.print(mode == "auto" ? "AUTO" : "MAN");
      lcd.setCursor(0, 1);
      lcd.print("Alarm:");
      lcd.print(alarmActive ? "ON " : "OFF");
      lcd.print(" Q:");
      lcd.print(historyCount);
      break;

    case 1:
      lcd.setCursor(0, 0);
      lcd.print("R1:");
      lcd.print(relayStates[0] ? "ON " : "OFF");
      lcd.print(" R2:");
      lcd.print(relayStates[1] ? "ON" : "OFF");
      lcd.setCursor(0, 1);
      lcd.print("R3:");
      lcd.print(relayStates[2] ? "ON " : "OFF");
      lcd.print(" R4:");
      lcd.print(relayStates[3] ? "ON" : "OFF");
      break;

    case 2:
      lcd.setCursor(0, 0);
      lcd.print("T:");
      if (isnan(temperatureC)) {
        lcd.print("--");
      } else {
        lcd.print(temperatureC, 1);
      }
      lcd.print("C H:");
      if (isnan(humidityPct)) {
        lcd.print("--");
      } else {
        lcd.print(humidityPct, 0);
      }
      lcd.print("%");
      lcd.setCursor(0, 1);
      lcd.print("TempLim:");
      lcd.print(tempLimitC, 0);
      lcd.print("C");
      break;

    case 3:
    default:
      lcd.setCursor(0, 0);
      lcd.print("Light:");
      if (lightRaw < 0) {
        lcd.print("--");
      } else {
        lcd.print(lightRaw);
      }
      lcd.setCursor(0, 1);
      lcd.print("Pct:");
      if (lightPercent < 0) {
        lcd.print("--");
      } else {
        lcd.print(lightPercent);
      }
      lcd.print("% DO:");
      lcd.print(lightTriggered ? "1" : "0");
      break;
  }
}

void ensureWifiConnected() {
  if (WiFi.status() == WL_CONNECTED) {
    return;
  }

  if (wifiPortalActive) {
    return;
  }

  if (millis() - lastWifiAttemptAt < WIFI_RETRY_MS) {
    return;
  }

  lastWifiAttemptAt = millis();
  logLine("[WiFi] Reconnecting...");
  WiFi.reconnect();
}

void initializePins() {
  for (uint8_t index = 0; index < 4; index++) {
    pinMode(RELAY_PINS[index], OUTPUT);
    setRelayHardware(index, false);
  }

  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, buzzerIdleLevel());

  pinMode(LIGHT_DO_PIN, INPUT);
  pinMode(BUTTON_PINS[0], INPUT_PULLUP);
  pinMode(BUTTON_PINS[1], INPUT_PULLUP);
  pinMode(BUTTON_PINS[2], INPUT);
  pinMode(BUTTON_PINS[3], INPUT);

  for (uint8_t index = 0; index < 4; index++) {
    const bool pressed = readButtonPressed(index);
    buttons[index].stablePressed = pressed;
    buttons[index].lastReadingPressed = pressed;
    buttons[index].holdHandled = false;
    buttons[index].lastDebounceAt = millis();
    buttons[index].pressedAt = 0;
  }

  if (ENABLE_LIGHT_ANALOG) {
    analogReadResolution(12);
    analogSetPinAttenuation(LIGHT_AO_PIN, ADC_11db);
  }
}

void setup() {
  Serial.begin(115200);
  delay(300);
  logBootDiagnostics();

  initializePins();
  dht.begin();

  Wire.begin(LCD_SDA_PIN, LCD_SCL_PIN);
  if (initializeLcd()) {
    lcd.setCursor(0, 0);
    lcd.print("Khoi dong ESP32");
    lcd.setCursor(0, 1);
    lcd.print(DEVICE_ID);
  }

  setupWiFiWithPortal(PORTAL_AP_NAME, PORTAL_AP_PASS, PORTAL_TIMEOUT_SEC);
  syncSettingsFromFirebase();
  restoreStateFromFirebase();
  syncDeviceInfoNode();
  readSensors();
  publishState(true);
  enqueueHistoryEvent("boot", "system", false, false, false, false, "esp32");
  flushOneHistoryEvent();

  lcdPageStartedAt = millis();
}

void loop() {
  processWifiPortal();
  ensureWifiConnected();
  scanButtons();

  if (millis() - lastSensorReadAt >= SENSOR_READ_MS) {
    lastSensorReadAt = millis();
    readSensors();
  }

  if (millis() - lastCommandPollAt >= COMMAND_POLL_MS) {
    lastCommandPollAt = millis();
    pollFirebaseCommand();
  }

  if (millis() - lastSettingsPollAt >= SETTINGS_POLL_MS) {
    lastSettingsPollAt = millis();
    syncSettingsFromFirebase();
  }

  if (millis() - lastStatePushAt >= STATE_PUSH_MS || stateDirty) {
    publishState(false);
  }

  if (millis() - lastHistoryFlushAt >= HISTORY_FLUSH_MS) {
    lastHistoryFlushAt = millis();
    flushOneHistoryEvent();
  }

  if (millis() - lastLcdRefreshAt >= LCD_REFRESH_MS) {
    lastLcdRefreshAt = millis();
    refreshLcd();
  }
}
