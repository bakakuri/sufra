package my.peera.app;

import com.google.androidbrowserhelper.locationdelegation.LocationDelegationExtraCommandHandler;

/* Lets the site's notifications show as the app's own, and lets the site ask for the location through the app. */
public class DelegationService extends com.google.androidbrowserhelper.trusted.DelegationService {
    @Override
    public void onCreate() {
        super.onCreate();
        registerExtraCommandHandler(new LocationDelegationExtraCommandHandler());
    }
}
