#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <map>
#include <memory>
#include <optional>

#include "desktop_multi_window/desktop_multi_window_plugin.h"
#include "flutter/generated_plugin_registrant.h"

namespace {

// Per player window: holds back a native close (title-bar button, Alt+F4)
// until Dart stopped playback, then lets the `close` call through.
struct PlayerWindowBridge {
  WNDPROC original = nullptr;
  bool confirmed = false;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> pip_channel;
  bool pip = false;
  LONG_PTR saved_style = 0;
  bool saved_topmost = false;
  WINDOWPLACEMENT saved_placement = {sizeof(WINDOWPLACEMENT)};
};

std::map<HWND, std::unique_ptr<PlayerWindowBridge>> g_player_windows;

LRESULT CALLBACK PlayerWindowProc(HWND hwnd, UINT message, WPARAM wparam,
                                  LPARAM lparam) {
  auto found = g_player_windows.find(hwnd);
  if (found == g_player_windows.end()) {
    return DefWindowProc(hwnd, message, wparam, lparam);
  }
  PlayerWindowBridge* bridge = found->second.get();
  WNDPROC original = bridge->original;
  if (bridge->pip && message == WM_GETMINMAXINFO) {
    auto* limits = reinterpret_cast<MINMAXINFO*>(lparam);
    limits->ptMinTrackSize = {240, 135};
    return 0;
  }
  if (bridge->pip && message == WM_NCHITTEST) {
    const LRESULT hit = CallWindowProc(original, hwnd, message, wparam, lparam);
    POINT point = {static_cast<short>(LOWORD(lparam)),
                   static_cast<short>(HIWORD(lparam))};
    ScreenToClient(hwnd, &point);
    RECT client;
    GetClientRect(hwnd, &client);
    if (hit == HTCLIENT && point.y < 24 && point.x < client.right - 60) {
      return HTCAPTION;
    }
    return hit;
  }
  if (message == WM_CLOSE && !bridge->confirmed) {
    bridge->channel->InvokeMethod("windowClosing", nullptr);
    return 0;
  }
  if (message == WM_NCDESTROY) {
    SetWindowLongPtr(hwnd, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(original));
    g_player_windows.erase(found);
  }
  return CallWindowProc(original, hwnd, message, wparam, lparam);
}

void ConfigurePlayerWindow(flutter::FlutterViewController* controller) {
  HWND top = GetAncestor(controller->view()->GetNativeWindow(), GA_ROOT);
  if (!top || g_player_windows.count(top)) return;
  auto bridge = std::make_unique<PlayerWindowBridge>();
  bridge->channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          controller->engine()->messenger(), "openplayx/player_window",
          &flutter::StandardMethodCodec::GetInstance());
  PlayerWindowBridge* raw = bridge.get();
  bridge->pip_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          controller->engine()->messenger(), "openplayx/picture_in_picture",
          &flutter::StandardMethodCodec::GetInstance());
  bridge->pip_channel->SetMethodCallHandler(
      [top, raw](const flutter::MethodCall<flutter::EncodableValue>& call,
                 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "isSupported") {
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "enter") {
          if (!raw->pip) {
            GetWindowPlacement(top, &raw->saved_placement);
            raw->saved_style = GetWindowLongPtr(top, GWL_STYLE);
            raw->saved_topmost = (GetWindowLongPtr(top, GWL_EXSTYLE) & WS_EX_TOPMOST) != 0;
            raw->pip = true;
            ShowWindow(top, SW_RESTORE);
            SetWindowLongPtr(top, GWL_STYLE,
                (raw->saved_style & ~(WS_CAPTION | WS_MAXIMIZEBOX | WS_MINIMIZEBOX)) | WS_THICKFRAME);
            MONITORINFO monitor = {sizeof(MONITORINFO)};
            GetMonitorInfo(MonitorFromWindow(top, MONITOR_DEFAULTTONEAREST), &monitor);
            double ratio = 16.0 / 9.0;
            const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
            if (args) {
              const auto found = args->find(flutter::EncodableValue("aspectRatio"));
              if (found != args->end()) {
                if (const auto* value = std::get_if<double>(&found->second)) ratio = *value;
              }
            }
            if (!(ratio >= 1.0 / 2.39 && ratio <= 2.39)) ratio = 16.0 / 9.0;
            const int width = 420;
            const int height = static_cast<int>(width / ratio);
            SetWindowPos(top, HWND_TOPMOST, monitor.rcWork.right - width - 20,
                         monitor.rcWork.bottom - height - 20, width, height,
                         SWP_FRAMECHANGED | SWP_SHOWWINDOW);
            raw->pip_channel->InvokeMethod("changed", std::make_unique<flutter::EncodableValue>(true));
          }
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "exit") {
          if (raw->pip) {
            raw->pip = false;
            SetWindowLongPtr(top, GWL_STYLE, raw->saved_style);
            SetWindowPlacement(top, &raw->saved_placement);
            SetWindowPos(top, raw->saved_topmost ? HWND_TOPMOST : HWND_NOTOPMOST,
                         0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED);
            raw->pip_channel->InvokeMethod("changed", std::make_unique<flutter::EncodableValue>(false));
          }
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
  bridge->channel->SetMethodCallHandler(
      [top, raw](const flutter::MethodCall<flutter::EncodableValue>& call,
                 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                     result) {
        if (call.method_name() == "close") {
          raw->confirmed = true;
          PostMessage(top, WM_CLOSE, 0, 0);
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
  bridge->original = reinterpret_cast<WNDPROC>(SetWindowLongPtr(
      top, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(PlayerWindowProc)));
  g_player_windows[top] = std::move(bridge);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  // Playback opens in its own window with its own engine, which needs the
  // plugins registered and the close bridge.
  DesktopMultiWindowSetWindowCreatedCallback([](void* controller) {
    auto* view_controller =
        reinterpret_cast<flutter::FlutterViewController*>(controller);
    RegisterPlugins(view_controller->engine());
    ConfigurePlayerWindow(view_controller);
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
