package my.peera.app;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

/* The server (Supabase) and what the app keeps between runs: the device's secret for sharing the place (given by the
   site to this phone only; it can do nothing but move or stop this person's shared place) and how the sharing goes. */
final class Peera {
    static final String URL = "https://iasospzhhdedpilykpiu.supabase.co";
    static final String KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlhc29zcHpoaGRlZHBpbHlrcGl1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIzMzk3NzIsImV4cCI6MjEwNzkxNTc3Mn0.iHnk-s1ePtNWJrn0Md3svxbNa2vhUTATNxuS3VPUfhI";

    static SharedPreferences prefs(Context c) {
        return c.getSharedPreferences("loc", Context.MODE_PRIVATE);
    }

    static final class RpcError extends Exception {
        final int code;
        RpcError(int code, String msg) { super(msg); this.code = code; }
    }

    /* POST /rest/v1/rpc/<fn> as the public (anon) role; the secret travels in the body */
    static JSONObject rpc(String fn, JSONObject body) throws Exception {
        HttpURLConnection c = (HttpURLConnection) new URL(URL + "/rest/v1/rpc/" + fn).openConnection();
        try {
            c.setRequestMethod("POST");
            c.setConnectTimeout(15000);
            c.setReadTimeout(20000);
            c.setDoOutput(true);
            c.setRequestProperty("apikey", KEY);
            c.setRequestProperty("Authorization", "Bearer " + KEY);
            c.setRequestProperty("Content-Type", "application/json");
            byte[] b = body.toString().getBytes(StandardCharsets.UTF_8);
            OutputStream o = c.getOutputStream();
            o.write(b);
            o.close();
            int code = c.getResponseCode();
            InputStream in = code >= 400 ? c.getErrorStream() : c.getInputStream();
            String text = read(in);
            if (code >= 400) {
                String msg = text;
                try { msg = new JSONObject(text).optString("message", text); } catch (Exception ignored) { }
                throw new RpcError(code, msg);
            }
            text = text.trim();
            return text.startsWith("{") ? new JSONObject(text) : new JSONObject();
        } finally {
            c.disconnect();
        }
    }

    private static String read(InputStream in) throws Exception {
        if (in == null) return "";
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        byte[] buf = new byte[4096];
        int n;
        while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
        in.close();
        return new String(out.toByteArray(), StandardCharsets.UTF_8);
    }

    private Peera() { }
}
