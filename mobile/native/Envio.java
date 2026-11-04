package app.caixa.livro;

import android.content.Context;
import android.content.SharedPreferences;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.json.JSONArray;
import org.json.JSONObject;

/** Manda as notificações pro Supabase. O que falhar por falta de internet fica numa fila e vai depois. */
final class Envio {
    static final String PREFS = "ryo_notif";
    private static final int MAX_FILA = 200;
    private static final ExecutorService fila = Executors.newSingleThreadExecutor();

    private Envio() {}

    static SharedPreferences prefs(Context c) {
        return c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    static void enfileirar(Context ctx, String app, String titulo, String texto) {
        final Context c = ctx.getApplicationContext();
        fila.execute(() -> {
            try {
                JSONObject item = new JSONObject();
                item.put("p_app", app);
                item.put("p_titulo", titulo);
                item.put("p_texto", texto);
                synchronized (Envio.class) {
                    JSONArray arr = lerFila(c);
                    arr.put(item);
                    while (arr.length() > MAX_FILA) arr.remove(0);
                    salvarFila(c, arr);
                }
            } catch (Exception ignored) {}
            esvaziar(c);
        });
    }

    static void tentarDeNovo(Context ctx) {
        final Context c = ctx.getApplicationContext();
        fila.execute(() -> esvaziar(c));
    }

    static int pendentes(Context c) {
        return lerFila(c).length();
    }

    /** Roda na thread da fila. Para no primeiro erro de rede pra manter a ordem. */
    private static void esvaziar(Context c) {
        SharedPreferences p = prefs(c);
        String url = p.getString("url", null), chave = p.getString("chave", null), token = p.getString("token", null);
        if (url == null || chave == null || token == null) return;
        while (true) {
            JSONObject item;
            synchronized (Envio.class) {
                JSONArray arr = lerFila(c);
                if (arr.length() == 0) return;
                item = arr.optJSONObject(0);
            }
            int codigo;
            try {
                JSONObject corpo = new JSONObject(item.toString());
                corpo.put("p_token", token);
                codigo = post(url, chave, corpo).codigo;
            } catch (Exception e) {
                codigo = -1;
            }
            // sem internet ou servidor fora: tenta na próxima notificação
            if (codigo < 0 || codigo >= 500 || codigo == 429) return;
            // enviado (2xx) ou recusado de vez (chave errada, 4xx): sai da fila
            synchronized (Envio.class) {
                JSONArray arr = lerFila(c);
                if (arr.length() > 0) arr.remove(0);
                salvarFila(c, arr);
            }
            p.edit().putLong("ultimo_envio", System.currentTimeMillis()).putInt("ultimo_codigo", codigo).apply();
        }
    }

    static final class Resposta {
        final int codigo;
        final String corpo;
        Resposta(int codigo, String corpo) { this.codigo = codigo; this.corpo = corpo; }
    }

    static Resposta post(String url, String chave, JSONObject corpo) throws Exception {
        HttpURLConnection con = (HttpURLConnection) new URL(url.replaceAll("/+$", "") + "/rest/v1/rpc/registrar_notificacao").openConnection();
        try {
            con.setRequestMethod("POST");
            con.setConnectTimeout(15000);
            con.setReadTimeout(20000);
            con.setDoOutput(true);
            con.setRequestProperty("Content-Type", "application/json");
            con.setRequestProperty("apikey", chave);
            byte[] dados = corpo.toString().getBytes(StandardCharsets.UTF_8);
            try (OutputStream os = con.getOutputStream()) { os.write(dados); }
            int codigo = con.getResponseCode();
            InputStream is = codigo >= 400 ? con.getErrorStream() : con.getInputStream();
            String txt = "";
            if (is != null) {
                try (InputStream in = is; ByteArrayOutputStream out = new ByteArrayOutputStream()) {
                    byte[] buf = new byte[4096];
                    int n;
                    while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
                    txt = out.toString("UTF-8");
                }
            }
            return new Resposta(codigo, txt);
        } finally {
            con.disconnect();
        }
    }

    private static JSONArray lerFila(Context c) {
        try { return new JSONArray(prefs(c).getString("fila", "[]")); } catch (Exception e) { return new JSONArray(); }
    }

    private static void salvarFila(Context c, JSONArray arr) {
        prefs(c).edit().putString("fila", arr.toString()).apply();
    }
}
