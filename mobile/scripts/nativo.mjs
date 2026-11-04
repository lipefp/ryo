// Coloca o código nativo do Ryo (leitor de notificações) no projeto Android gerado pelo Capacitor.
// Rode dentro da pasta mobile/, depois de "npx cap add android".
import { cpSync, readdirSync, readFileSync, writeFileSync } from "node:fs";

const destino = "android/app/src/main/java/app/caixa/livro/";
for (const f of readdirSync("native")) if (f.endsWith(".java")) cpSync("native/" + f, destino + f);

const arq = "android/app/src/main/AndroidManifest.xml";
let xml = readFileSync(arq, "utf8");

const servico = `
        <service
            android:name=".RyoNotificationListener"
            android:label="Ryo"
            android:exported="true"
            android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE">
            <intent-filter>
                <action android:name="android.service.notification.NotificationListenerService" />
            </intent-filter>
        </service>
`;
// pra listar os apps instalados (Android 11+)
const consultas = `
    <queries>
        <intent>
            <action android:name="android.intent.action.MAIN" />
            <category android:name="android.intent.category.LAUNCHER" />
        </intent>
    </queries>
`;

if (!xml.includes("RyoNotificationListener")) {
  if (!xml.includes("</application>")) throw new Error("AndroidManifest sem </application>");
  xml = xml.replace("</application>", servico + "    </application>");
}
if (!xml.includes("<queries>")) xml = xml.replace(/(\s*<application)/, "\n" + consultas + "$1");
writeFileSync(arq, xml);
console.log("código nativo e manifest prontos");
