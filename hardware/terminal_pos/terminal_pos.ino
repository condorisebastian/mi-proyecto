// Transita Bolivia - terminal POS de demostracion para Tinkercad.
// Los botones simulan una tarjeta: NO leen NFC ni descuentan saldo real.
#include <LiquidCrystal.h>
LiquidCrystal lcd(12, 11, 5, 4, 3, 2);
const byte APPROVE_BUTTON = 6, DECLINE_BUTTON = 7, ROUTE_BUTTON = 8;
const byte GREEN_LED = 9, RED_LED = 10, BUZZER = A0;
int fareCents = 800;
long demoBalanceCents = 2550;
unsigned long lastPress = 0;
unsigned long resultUntil = 0;
bool locked = false;
bool wasPressed = false;

void printMoney(long cents) {
  lcd.print(cents / 100); lcd.print('.');
  if (cents % 100 < 10) lcd.print('0');
  lcd.print(cents % 100);
}
void readyScreen() {
  lcd.clear(); lcd.setCursor(0, 0);
  lcd.print(fareCents == 800 ? "La Guardia" : "El Torno");
  lcd.setCursor(0, 1); lcd.print("DEMO Bs "); printMoney(fareCents);
  digitalWrite(GREEN_LED, LOW); digitalWrite(RED_LED, LOW);
}
void setup() {
  pinMode(APPROVE_BUTTON, INPUT_PULLUP); pinMode(DECLINE_BUTTON, INPUT_PULLUP);
  pinMode(ROUTE_BUTTON, INPUT_PULLUP); pinMode(GREEN_LED, OUTPUT);
  pinMode(RED_LED, OUTPUT); pinMode(BUZZER, OUTPUT);
  Serial.begin(9600); lcd.begin(16, 2);
  Serial.println("TRANSITA POS DEMO - saldo ficticio. A: tarjeta, R: rechazo, T: ruta, C: recarga demo.");
  readyScreen();
}
void result(bool approved) {
  lcd.clear();
  if (approved && demoBalanceCents >= fareCents) {
    demoBalanceCents -= fareCents;
    lcd.print("PAGO DEMO OK"); digitalWrite(GREEN_LED, HIGH); tone(BUZZER, 1600, 150);
    lcd.setCursor(0, 1); lcd.print("Saldo "); printMoney(demoBalanceCents);
    Serial.println("DEMO APROBADA. Descuento ficticio unico.");
  } else {
    lcd.print(approved ? "SALDO INSUFIC." : "TARJETA RECHAZ.");
    lcd.setCursor(0, 1); lcd.print("SIN DESCUENTO");
    digitalWrite(RED_LED, HIGH); tone(BUZZER, 400, 350);
    Serial.println("DEMO RECHAZADA. Saldo ficticio sin cambios.");
  }
  locked = true; resultUntil = millis() + 2200;
}
void loop() {
  const unsigned long now = millis();
  if (locked) { if ((long)(now - resultUntil) >= 0) { locked = false; readyScreen(); } return; }
  char command = Serial.available() ? Serial.read() : 0;
  bool card = digitalRead(APPROVE_BUTTON) == LOW;
  bool reject = digitalRead(DECLINE_BUTTON) == LOW;
  bool route = digitalRead(ROUTE_BUTTON) == LOW;
  bool pressed = card || reject || route;
  bool edge = pressed && !wasPressed && now - lastPress > 180;
  wasPressed = pressed;
  if (edge) lastPress = now;
  if ((edge && route) || command == 'T') { fareCents = fareCents == 800 ? 850 : 800; readyScreen(); }
  else if ((edge && card) || command == 'A') result(true);
  else if ((edge && reject) || command == 'R') result(false);
  else if (command == 'C') { demoBalanceCents += 500; Serial.println("Recarga DEMO de Bs 5.00."); }
}
