use crate::{
    models::config::{AppSettings, LLMConfig},
    services::{memory_manager::MemoryManager, tts_service::TtsService},
};
use commands::{config::*, file_tools::*, llm::*, memory::*, tts::*};
use tauri::{
    image::Image,
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    AppHandle, Manager, WebviewWindowBuilder,
};
use tokio::sync::Mutex;

pub mod commands;
pub mod models;
pub mod services;

pub struct AppState {
    pub config: Mutex<LLMConfig>,
    pub settings: Mutex<AppSettings>,
    pub memory: Mutex<MemoryManager>,
    pub tts: Mutex<TtsService>,
}

impl AppState {
    fn new() -> Self {
        Self {
            config: Mutex::new(LLMConfig::default()),
            settings: Mutex::new(AppSettings::default()),
            memory: Mutex::new(MemoryManager::new(Default::default())),
            tts: Mutex::new(TtsService::new()),
        }
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_store::Builder::new().build())
        .plugin(tauri_plugin_single_instance::init(|app, _, _| {
            if let Some(window) = app.get_webview_window("pet") {
                let _ = window.show();
                let _ = window.set_focus();
            }
        }))
        .manage(AppState::new())
        .invoke_handler(tauri::generate_handler![
            // llm
            send_message,
            send_message_stream,
            cancel_request,
            save_llm_config,
            // file tools
            execute_tool,
            // config
            load_config,
            save_config,
            load_settings,
            save_settings,
            // memory
            build_memory_context,
            process_conversation,
            end_session,
            get_long_term_memory,
            clear_memory,
            set_memory_enabled,
            // tts
            speak_text,
            stop_speaking,
        ])
        .setup(|app| {
            // 从 store 恢复已保存的配置
            {
                use tauri_plugin_store::StoreExt;
                if let Ok(store) = app.handle().store("settings.json") {
                    if let Some(val) = store.get("llm_config") {
                        if let Ok(config) = serde_json::from_value::<LLMConfig>(val) {
                            let mut config = config;
                            config.normalize_openrouter();
                            let state = app.state::<AppState>();
                            *state.config.blocking_lock() = config;
                        }
                    }
                    if let Some(val) = store.get("app_settings") {
                        if let Ok(settings) = serde_json::from_value::<AppSettings>(val) {
                            let state = app.state::<AppState>();
                            *state.settings.blocking_lock() = settings;
                        }
                    }
                }
            }

            let app_icon = load_runtime_app_icon();
            #[cfg(target_os = "macos")]
            set_macos_dock_icon();

            setup_tray(app.handle(), app_icon.clone())?;
            if let Some(window) = app.get_webview_window("pet") {
                if let Some(icon) = app_icon {
                    let _ = window.set_icon(icon);
                }
                let _ = window.set_always_on_top(true);
                #[cfg(target_os = "macos")]
                {
                    use cocoa::appkit::{NSColor, NSWindow};
                    use cocoa::base::{id, NO};
                    let _ = window.with_webview(move |webview| {
                        #[allow(deprecated)]
                        unsafe {
                            let ns_window: id = webview.ns_window() as id;
                            ns_window
                                .setBackgroundColor_(NSColor::clearColor(std::ptr::null_mut()));
                            ns_window.setOpaque_(NO);
                        }
                    });
                }
                let _ = window.show();
                let _ = window.set_focus();
            }
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

fn load_runtime_app_icon() -> Option<Image<'static>> {
    Image::from_bytes(include_bytes!("../icons/128x128@2x.png")).ok()
}

#[cfg(target_os = "macos")]
#[allow(deprecated)]
fn set_macos_dock_icon() {
    use cocoa::appkit::{NSApp, NSApplication, NSImage};
    use cocoa::base::nil;
    use cocoa::foundation::{NSData, NSUInteger};
    use std::ffi::c_void;

    let icon_bytes = include_bytes!("../icons/128x128@2x.png");

    unsafe {
        let data = NSData::dataWithBytes_length_(
            nil,
            icon_bytes.as_ptr() as *const c_void,
            icon_bytes.len() as NSUInteger,
        );
        let image = NSImage::initWithData_(NSImage::alloc(nil), data);
        if image != nil {
            NSApp().setApplicationIconImage_(image);
        }
    }
}

fn setup_tray(app: &AppHandle, runtime_icon: Option<Image<'static>>) -> tauri::Result<()> {
    let show_hide = MenuItem::with_id(app, "show_hide", "显示/隐藏小黑", true, None::<&str>)?;
    let settings = MenuItem::with_id(app, "settings", "设置...", true, None::<&str>)?;
    let quit = MenuItem::with_id(app, "quit", "退出", true, None::<&str>)?;

    let menu = Menu::with_items(app, &[&show_hide, &settings, &quit])?;
    let tray_icon = runtime_icon
        .or_else(|| app.default_window_icon().cloned())
        .expect("application icon should be available");

    TrayIconBuilder::new()
        .icon(tray_icon)
        .icon_as_template(false)
        .menu(&menu)
        .on_menu_event(|app, event| match event.id.as_ref() {
            "show_hide" => {
                if let Some(window) = app.get_webview_window("pet") {
                    if window.is_visible().unwrap_or(false) {
                        let _ = window.hide();
                    } else {
                        let _ = window.show();
                        let _ = window.set_focus();
                    }
                }
            }
            "settings" => open_settings(app),
            "quit" => app.exit(0),
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click {
                button: MouseButton::Left,
                button_state: MouseButtonState::Up,
                ..
            } = event
            {
                let app = tray.app_handle();
                if let Some(window) = app.get_webview_window("pet") {
                    if window.is_visible().unwrap_or(false) {
                        let _ = window.hide();
                    } else {
                        let _ = window.show();
                        let _ = window.set_focus();
                    }
                }
            }
        })
        .build(app)?;

    Ok(())
}

fn open_settings(app: &AppHandle) {
    if let Some(w) = app.get_webview_window("settings") {
        let _ = w.show();
        let _ = w.set_focus();
        return;
    }
    let window = WebviewWindowBuilder::new(
        app,
        "settings",
        tauri::WebviewUrl::App("index.html#settings".into()),
    )
    .title("罗小黑桌宠 - 设置")
    .inner_size(500.0, 520.0)
    .resizable(false)
    .decorations(false)
    .center()
    .build();

    if let Ok(window) = window {
        if let Some(icon) = load_runtime_app_icon() {
            let _ = window.set_icon(icon);
        }
    }
}
