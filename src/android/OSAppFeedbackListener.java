package com.outsystems.plugins.appfeedback;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.SharedPreferences;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.util.Log;
import android.view.ViewGroup;
import android.webkit.WebView;

import com.outsystems.android.mobileect.MobileECTController;
import com.outsystems.android.mobileect.api.interfaces.OSECTProviderAPIHandler;
import com.outsystems.android.mobileect.interfaces.OSECTContainerListener;

import org.apache.cordova.CallbackContext;

public class OSAppFeedbackListener implements OSECTContainerListener {

    private final String SHAREDPREF_NAME = "com.outsystems.plugins.appfeedback.preferences";
    private final String SHAREDPREF_KEY_SKIP_HELP = "com.outsystems.plugins.appfeedback.key.skiphelp";

    private MobileECTController mobileECTController;

    private boolean appFeedbackAvailable;

    private Context context;

    public OSAppFeedbackListener(Activity activity, ViewGroup mainViewGroup, ViewGroup ectViewGroup, WebView currentWebView, String hostname) {

        this.context = activity;

        SharedPreferences sharedPref = context.getSharedPreferences(SHAREDPREF_NAME, Context.MODE_PRIVATE);
        boolean skipHelp = sharedPref.getBoolean(SHAREDPREF_KEY_SKIP_HELP, false);

        this.mobileECTController = new MobileECTController(activity,
                mainViewGroup,
                ectViewGroup,
                currentWebView,
                hostname,
                skipHelp,
                this);
    }

    @Override
    public void onSendFeedbackClickListener() {
        mobileECTController.sendFeedback();
    }

    @Override
    public void onCloseECTClickListener() {
        mobileECTController.closeECTNativeUI();
    }

    @Override
    public void onCloseECTHelperClickListener() {
        mobileECTController.setSkipECTHelper(true);
    }


    public boolean isAppFeedbackAvailable() {
        return appFeedbackAvailable;
    }


    public void openECT() {
        mobileECTController.openECTNativeUI();
        SharedPreferences sharedPref = this.context.getSharedPreferences(SHAREDPREF_NAME, Activity.MODE_PRIVATE);
        SharedPreferences.Editor editor = sharedPref.edit();
        editor.putBoolean(SHAREDPREF_KEY_SKIP_HELP, true);
        editor.commit();
    }

    /**
     * Public API for Plugin
     */

    public void handleDeviceReady(){
        this.mobileECTController.prepareECTData(new OSECTProviderAPIHandler() {
            @Override
            public void execute(boolean result) {
                // Do Nothing
            }
        });
    }

    private boolean isNetworkAvailable(Context context) {
        ConnectivityManager connectivityManager
                = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        Network nw = connectivityManager.getActiveNetwork();
        if (nw == null) {
            return false;
        }
        NetworkCapabilities actNw = connectivityManager.getNetworkCapabilities(nw);
        return actNw != null && (actNw.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) || actNw.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) || actNw.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) || actNw.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH));
    
    }

    public void handleECTAvailable(final OSECTProviderAPIHandler apiHandler) {
        if(isNetworkAvailable(context)) {
            mobileECTController.checkECTAvailability(new OSECTProviderAPIHandler() {
                @Override
                public void execute(boolean result) {
                    appFeedbackAvailable = result;
                    if(apiHandler != null)
                        apiHandler.execute(result);
                }
            });
        } else {
            AlertDialog.Builder alert = new AlertDialog.Builder(context);
            alert.setTitle("Can't send feedback");
            alert.setMessage("Make sure your device has internet connection and try again.");
            alert.setPositiveButton("OK", new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialog, int which) {
                    dialog.dismiss();
                }
            });

            alert.show();
        }
    }

    public void handleOpenECT(final OSECTProviderAPIHandler apiHandler) {
        if (this.isAppFeedbackAvailable()) {
            this.openECT();
            if(apiHandler != null) {
                apiHandler.execute(true);
            }
        } else {
            if(apiHandler != null) {
                apiHandler.execute(false);
            }
        }
    }

}
