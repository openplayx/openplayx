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
