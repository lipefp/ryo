package app.caixa.livro;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.net.Uri;
import android.provider.Settings;
import androidx.core.app.NotificationManagerCompat;
import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.TreeMap;
import java.util.regex.Pattern;
import org.json.JSONObject;

@CapacitorPlugin(name = "RyoNotif")
public class RyoNotifPlugin extends Plugin {
    private static final Pattern BANCO = Pattern.compile(
        "(banco|bank|santander|nubank|\\bnu\\b|ita[uú]|bradesco|caixa|\\binter\\b|c6|picpay|mercado ?pago|pagbank|pagseguro|neon|\\bnext\\b|sicoob|sicredi|banrisul|btg|\\bxp\\b|original|\\bpan\\b|will|digio|agibank|inter&co|\\bbb\\b|ourocard|cart[aã]o|wallet|carteira)",
        Pattern.CASE_INSENSITIVE);

    private boolean permitido() {
        Context c = getContext();
        return NotificationManagerCompat.getEnabledListenerPackages(c).contains(c.getPackageName());
    }

    @PluginMethod
    public void status(PluginCall call) {
        SharedPreferences p = Envio.prefs(getContext());
        JSObject r = new JSObject();
        r.put("permitido", permitido());
        r.put("ativo", p.getBoolean("ativo", false));
        r.put("temChave", p.getString("token", null) != null);
        JSArray pac = new JSArray();
        for (String s : p.getStringSet("pacotes", Collections.emptySet())) pac.put(s);
        r.put("pacotes", pac);
        r.put("pendentes", Envio.pendentes(getContext()));
        r.put("ultimoEnvio", p.getLong("ultimo_envio", 0));
        r.put("ultimoCodigo", p.getInt("ultimo_codigo", 0));
        call.resolve(r);
    }

    @PluginMethod
    public void abrirConfiguracao(PluginCall call) {
        Intent i = new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS);
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try {
            getContext().startActivity(i);
            call.resolve();
        } catch (Exception e) {
            call.reject("Não consegui abrir as configurações");
        }
    }

    /** Pro Android 13+: app instalado fora da loja precisa liberar "configurações restritas" aqui. */
    @PluginMethod
    public void abrirInfoDoApp(PluginCall call) {
        Intent i = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", getContext().getPackageName(), null));
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try {
            getContext().startActivity(i);
            call.resolve();
        } catch (Exception e) {
            call.reject("Não consegui abrir as informações do app");
        }
    }

    @PluginMethod
    public void listarApps(PluginCall call) {
        getBridge().execute(() -> {
            Context c = getContext();
            PackageManager pm = c.getPackageManager();
            Intent launcher = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER);
            List<ResolveInfo> lista = pm.queryIntentActivities(launcher, 0);
            TreeMap<String, JSObject> ordenado = new TreeMap<>();
            for (ResolveInfo ri : lista) {
                String pacote = ri.activityInfo.packageName;
                if (pacote.equals(c.getPackageName())) continue;
                String nome = String.valueOf(ri.loadLabel(pm));
                boolean banco = BANCO.matcher(nome).find() || BANCO.matcher(pacote.replace('.', ' ')).find();
                JSObject o = new JSObject();
                o.put("pacote", pacote);
                o.put("nome", nome);
                o.put("banco", banco);
                ordenado.put((banco ? "0" : "1") + nome.toLowerCase(Locale.ROOT) + "|" + pacote, o);
            }
            JSArray arr = new JSArray();
            for (JSObject o : ordenado.values()) arr.put(o);
            JSObject r = new JSObject();
            r.put("apps", arr);
            call.resolve(r);
        });
    }

    /** Salva a conexão e os apps escolhidos. token é opcional (mantém o atual). */
    @PluginMethod
    public void salvar(PluginCall call) {
        SharedPreferences.Editor ed = Envio.prefs(getContext()).edit();
        String url = call.getString("url"), chave = call.getString("chave"), token = call.getString("token");
        if (url != null) ed.putString("url", url);
        if (chave != null) ed.putString("chave", chave);
        if (token != null) ed.putString("token", token);
        JSArray pac = call.getArray("pacotes");
        if (pac != null) {
            Set<String> s = new HashSet<>();
            try { for (Object o : pac.toList()) s.add(String.valueOf(o)); } catch (Exception ignored) {}
            ed.putStringSet("pacotes", s);
        }
        ed.putBoolean("ativo", true);
        ed.apply();
        Envio.tentarDeNovo(getContext());
        call.resolve();
    }

    @PluginMethod
    public void desativar(PluginCall call) {
        Envio.prefs(getContext()).edit().putBoolean("ativo", false).remove("token").remove("fila").apply();
        call.resolve();
    }

    /** Manda uma notificação de teste (sem valor, então não vira lançamento) e devolve a resposta. */
    @PluginMethod
    public void testar(PluginCall call) {
        getBridge().execute(() -> {
            SharedPreferences p = Envio.prefs(getContext());
            String url = p.getString("url", null), chave = p.getString("chave", null), token = p.getString("token", null);
            if (url == null || chave == null || token == null) { call.reject("Automação não configurada"); return; }
            try {
                JSONObject corpo = new JSONObject();
                corpo.put("p_token", token);
                corpo.put("p_app", "Ryo");
                corpo.put("p_titulo", "Teste do Ryo");
                corpo.put("p_texto", "Conexão funcionando");
                Envio.Resposta r = Envio.post(url, chave, corpo);
                JSObject o = new JSObject();
                o.put("codigo", r.codigo);
                o.put("ok", r.codigo >= 200 && r.codigo < 300);
                call.resolve(o);
            } catch (Exception e) {
                call.reject("Sem conexão: " + e.getMessage());
            }
        });
    }
}
