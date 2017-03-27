package com.outsystems.plugins.appfeedback;

import android.app.Activity;
import android.preference.Preference;
import android.preference.PreferenceManager;
import android.support.v4.view.GestureDetectorCompat;
import android.support.v4.view.MotionEventCompat;
import android.util.Log;
import android.view.GestureDetector;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.WebView;
import android.widget.LinearLayout;
import android.widget.RelativeLayout;

import com.outsystems.android.mobileect.MobileECTController;
import com.outsystems.android.mobileect.api.interfaces.OSECTProviderAPIHandler;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaActivity;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaPreferences;
import org.apache.cordova.engine.SystemWebViewEngine;
import org.json.JSONArray;
import org.json.JSONException;

import java.lang.ref.WeakReference;
import java.util.Timer;
import java.util.TimerTask;

public class OSAppFeedback extends CordovaPlugin {

    private static final String DEFAULT_HOSTNAME = "DefaultHostname";
    private static final String DEFAULT_HANDLER = "DefaultAppFeedbackHandler";

    private OSAppFeedbackListener appFeedbackListener;

    private ViewGroup mainViewGroup;
    private ViewGroup ectViewGroup;
    private boolean inBackground;
    private String defaultHostname;

    protected ViewGroup getMainViewGroup() {
        return mainViewGroup;
    }

    protected void setMainViewGroup(ViewGroup mainViewGroup) {
        this.mainViewGroup = mainViewGroup;
    }

    protected ViewGroup getEctViewGroup() {
        return ectViewGroup;
    }

    protected void setEctViewGroup(ViewGroup ectViewGroup) {
        this.ectViewGroup = ectViewGroup;
    }


    @Override
    protected void pluginInitialize() {

        this.defaultHostname = preferences.getString(DEFAULT_HOSTNAME,null);
        final boolean defautHandler = preferences.getBoolean(DEFAULT_HANDLER,true);

        cordova.getActivity().runOnUiThread(new Runnable() {
            @SuppressWarnings("ResourceType")
            @Override
            public void run() {

                final CordovaActivity cordovaActivity = (CordovaActivity) cordova.getActivity();

                ViewGroup mainViewGroup = (ViewGroup) webView.getView().getParent();

                ViewGroup rootView = (ViewGroup) mainViewGroup.getParent();

                if (rootView instanceof LinearLayout) {
                    LinearLayout linearLayout = (LinearLayout) rootView;
                    linearLayout.setOrientation(LinearLayout.VERTICAL);
                }

                RelativeLayout ectViewGroup = new RelativeLayout(cordovaActivity);
                RelativeLayout.LayoutParams params = new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.MATCH_PARENT, RelativeLayout.LayoutParams.MATCH_PARENT);
                ectViewGroup.setLayoutParams(params);
                ectViewGroup.setId(2001);
                ectViewGroup.setVisibility(View.GONE);

                rootView.addView(ectViewGroup);
                rootView.invalidate();

                setMainViewGroup(mainViewGroup);
                setEctViewGroup(ectViewGroup);

                if(defautHandler){
                    registerGestureHandler();
                }
            }
        });

    }

    @Override
    public void onResume(boolean multitasking) {
        super.onResume(multitasking);
        inBackground = false;
    }

    @Override
    public void onPause(boolean multitasking) {
        super.onPause(multitasking);
        inBackground = true;
    }

    @Override
    public boolean execute(String action, JSONArray args, final CallbackContext callbackContext) throws JSONException {
        if (!inBackground) {
            if (action.equals("deviceready")) {

                if(defaultHostname == null || defaultHostname.isEmpty()){
                    defaultHostname = args.getString(0);
                }

                handleDeviceReady(defaultHostname);

                return true;
            } else {
                if (action.equals("isAvailable")) {
                    handleIsECTAvailable(callbackContext);

                    return true;
                } else {
                    if (action.equals("openECT")) {
                        handleOpenECT(callbackContext);

                        return true;
                    }
                }
            }

            callbackContext.error("Invalid plugin action.");
            return false;
        } else {
            callbackContext.error("Can't open ECT while in background.");
            return false;
        }
    }


    private void handleDeviceReady(String hostname) {
        SystemWebViewEngine webViewEngine = (SystemWebViewEngine) webView.getEngine();
        WebView currentWebView = (WebView) webViewEngine.getView();

        appFeedbackListener = new OSAppFeedbackListener(cordova.getActivity(), mainViewGroup, ectViewGroup, currentWebView, hostname);

        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                appFeedbackListener.handleDeviceReady();
            }
        });

    }

    private void handleIsECTAvailable(final CallbackContext callbackContext) {
        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                appFeedbackListener.handleECTAvailable(new OSECTProviderAPIHandler() {
                    @Override
                    public void execute(boolean result) {
                        if (result) {
                            callbackContext.success(1);
                        } else {
                            callbackContext.error("App Feedback is not available.");
                        }
                    }
                });
            }
        });
    }

    private void handleOpenECT(final CallbackContext callbackContext) {
        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                appFeedbackListener.handleOpenECT(new OSECTProviderAPIHandler() {
                    @Override
                    public void execute(boolean result) {
                        if (result) {
                            callbackContext.success(1);
                        } else {
                            callbackContext.error("App Feedback is not available.");
                        }
                    }
                });
            }
        });
    }

    /**
     * Gesture Detector
     */

    private long mSecondFingerTimeDown = 0;
    private Timer mGestureRecognizerTimer;
    private int INTERVAL_TO_SHOW_MENU = 600;

    private class GestureRecognizerTimedTask extends TimerTask {

        WeakReference<CordovaActivity> hRef;

        public GestureRecognizerTimedTask(CordovaActivity activity) {
            hRef = new WeakReference<CordovaActivity>(activity);
        }

        @Override
        public void run() {

            final CordovaActivity activity = hRef.get();

            if (activity == null)
                return;

            activity.runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    appFeedbackListener.handleECTAvailable(new OSECTProviderAPIHandler() {
                        @Override
                        public void execute(boolean result) {
                            if(result) {
                                appFeedbackListener.handleOpenECT(null);
                            }
                        }
                    });
                }
            });

        }
    }

    private void registerGestureHandler(){
        final CordovaActivity cordovaActivity = (CordovaActivity) cordova.getActivity();

        webView.getView().setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event) {
                int action = MotionEventCompat.getActionMasked(event);

                if(event.getPointerCount() == 2) {
                    switch (action) {
                        case MotionEvent.ACTION_POINTER_DOWN:
                            mSecondFingerTimeDown = System.currentTimeMillis();
                            mGestureRecognizerTimer = new Timer();
                            mGestureRecognizerTimer.schedule(new GestureRecognizerTimedTask(cordovaActivity), INTERVAL_TO_SHOW_MENU);
                            break;
                        case MotionEvent.ACTION_POINTER_UP:
                            if ((System.currentTimeMillis() - mSecondFingerTimeDown) <= INTERVAL_TO_SHOW_MENU) {
                                mGestureRecognizerTimer.cancel();
                            }
                            if ((System.currentTimeMillis() - mSecondFingerTimeDown) >= INTERVAL_TO_SHOW_MENU) {
                                mSecondFingerTimeDown = 0;
                            }
                            break;
                    }

                }
                else{
                    if(mGestureRecognizerTimer != null){
                        mGestureRecognizerTimer.cancel();
                    }
                    mSecondFingerTimeDown = 0;
                }

                return webView.getView().onTouchEvent(event);
            }
        });
    }

}