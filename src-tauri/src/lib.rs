use crate::{
    models::config::{AppSettings, LLMConfig},
    services::{memory_manager::MemoryManager, tts_service::TtsService},
};
use commands::{config::*, file_tools::*, llm::*, memory::*, tts::*};
use tauri::{
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
            setup_tray(app.handle())?;
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

fn setup_tray(app: &AppHandle) -> tauri::Result<()> {
    let show_hide = MenuItem::with_id(app, "show_hide", "显示/隐藏小黑", true, None::<&str>)?;
    let settings = MenuItem::with_id(app, "settings", "设置...", true, None::<&str>)?;
    let quit = MenuItem::with_id(app, "quit", "退出", true, None::<&str>)?;

    let menu = Menu::with_items(app, &[&show_hide, &settings, &quit])?;

    TrayIconBuilder::new()
        .icon(app.default_window_icon().cloned().unwrap())
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
    let _ = WebviewWindowBuilder::new(app, "settings", tauri::WebviewUrl::App("index.html#settings".into()))
        .title("罗小黑桌宠 - 设置")
        .inner_size(500.0, 520.0)
        .resizable(false)
        .center()
        .build();
}
