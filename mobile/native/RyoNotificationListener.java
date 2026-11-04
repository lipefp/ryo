package app.caixa.livro;

import android.app.Notification;
import android.content.SharedPreferences;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import java.util.Collections;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

/** Lê só as notificações dos apps que a pessoa escolheu no Ryo. */
public class RyoNotificationListener extends NotificationListenerService {
    // a mesma notificação costuma ser postada de novo quando é atualizada
    private final Map<String, Long> vistas = new LinkedHashMap<>();
    private static final long JANELA_MS = 10 * 60 * 1000;

    @Override
    public void onListenerConnected() {
        Envio.tentarDeNovo(this);
    }

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        try {
            SharedPreferences p = Envio.prefs(this);
            if (!p.getBoolean("ativo", false)) return;
            Set<String> pacotes = p.getStringSet("pacotes", Collections.emptySet());
            String pacote = sbn.getPackageName();
            if (pacote == null || !pacotes.contains(pacote)) return;

            Notification n = sbn.getNotification();
            if (n == null) return;
            if ((n.flags & Notification.FLAG_GROUP_SUMMARY) != 0) return;
            if ((n.flags & Notification.FLAG_ONGOING_EVENT) != 0) return;

            Bundle e = n.extras;
            String titulo = texto(e.getCharSequence(Notification.EXTRA_TITLE));
            String corpo = texto(e.getCharSequence(Notification.EXTRA_BIG_TEXT));
            if (corpo.isEmpty()) corpo = texto(e.getCharSequence(Notification.EXTRA_TEXT));
            if (corpo.isEmpty()) {
                CharSequence[] linhas = e.getCharSequenceArray(Notification.EXTRA_TEXT_LINES);
                if (linhas != null) {
                    StringBuilder sb = new StringBuilder();
                    for (CharSequence l : linhas) sb.append(texto(l)).append(' ');
                    corpo = sb.toString().trim();
                }
            }
            if (titulo.isEmpty() && corpo.isEmpty()) return;

            String chave = pacote + "|" + titulo + "|" + corpo;
            long agora = System.currentTimeMillis();
            synchronized (vistas) {
                Iterator<Map.Entry<String, Long>> it = vistas.entrySet().iterator();
                while (it.hasNext()) if (agora - it.next().getValue() > JANELA_MS) it.remove();
                if (vistas.containsKey(chave)) return;
                vistas.put(chave, agora);
            }

            Envio.enfileirar(this, nomeDoApp(pacote), titulo, corpo);
        } catch (Exception ignored) {
            // nunca derrubar o serviço por causa de uma notificação estranha
        }
    }

    private String nomeDoApp(String pacote) {
        try {
            PackageManager pm = getPackageManager();
            ApplicationInfo ai = pm.getApplicationInfo(pacote, 0);
            return String.valueOf(pm.getApplicationLabel(ai));
        } catch (Exception e) {
            return pacote;
        }
    }

    /** Tira espaços especiais (os bancos usam espaço fixo em "R$ 10,00"). */
    static String texto(CharSequence cs) {
        if (cs == null) return "";
        return cs.toString().replace(' ', ' ').replace(' ', ' ').replaceAll("\\s+", " ").trim();
    }
}
