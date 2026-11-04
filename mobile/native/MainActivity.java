package app.caixa.livro;

import android.os.Bundle;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(RyoNotifPlugin.class);
        super.onCreate(savedInstanceState);
    }
}
